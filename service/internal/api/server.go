// Package api is the HTTP surface of the reference checkout service.
package api

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/Riuchek/go-golden-path/service/internal/order"
	"github.com/Riuchek/go-golden-path/service/internal/payment"
	"github.com/Riuchek/go-golden-path/service/internal/telemetry"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/metric"
	"go.opentelemetry.io/otel/trace"
)

// Authorizer charges for an order. payment.Authorize is the default.
type Authorizer func(ctx context.Context, sku string, qty int, force bool) error

// Deps are the replaceable parts of the server. Zero values use the
// in-memory store, the simulated authorizer, and the default logger.
type Deps struct {
	Store     *order.Store
	Authorize Authorizer
	Log       *slog.Logger
}

// NewMux returns the service handler. Probe routes are not traced: a
// readiness scrape would otherwise dominate the RED metrics.
func NewMux(d Deps) http.Handler {
	if d.Store == nil {
		d.Store = order.NewStore()
	}
	if d.Authorize == nil {
		d.Authorize = payment.Authorize
	}
	if d.Log == nil {
		d.Log = slog.Default()
	}

	counter, err := otel.Meter("checkout").Int64Counter(
		"orders.created",
		metric.WithDescription("Orders accepted by the checkout service"),
	)
	if err != nil {
		panic(err)
	}

	h := &handler{deps: d, orders: counter}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", h.health)
	mux.HandleFunc("GET /readyz", h.ready)
	mux.Handle("POST /v1/orders", traced("POST /v1/orders", h.create))
	mux.Handle("GET /v1/orders/{id}", traced("GET /v1/orders/{id}", h.get))
	return mux
}

// traced wraps one route so the span name is the route template, not the
// raw URL. That keeps spanmetrics cardinality stable.
func traced(name string, fn func(http.ResponseWriter, *http.Request)) http.Handler {
	return otelhttp.NewHandler(http.HandlerFunc(fn), name,
		otelhttp.WithSpanNameFormatter(func(_ string, _ *http.Request) string { return name }),
	)
}

type handler struct {
	deps   Deps
	orders metric.Int64Counter
}

func (h *handler) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *handler) ready(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (h *handler) create(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SKU string `json:"sku"`
		Qty int    `json:"qty"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json")
		return
	}
	if req.SKU == "" || req.Qty < 1 || req.Qty > 100 {
		writeError(w, http.StatusBadRequest, "sku is required and qty must be between 1 and 100")
		return
	}

	span := trace.SpanFromContext(r.Context())
	span.SetAttributes(
		attribute.String("order.sku", req.SKU),
		attribute.Int("order.qty", req.Qty),
	)

	force := r.Header.Get("X-Demo-Fault") == "payment"
	if err := h.deps.Authorize(r.Context(), req.SKU, req.Qty, force); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		h.deps.Log.LogAttrs(r.Context(), slog.LevelWarn, "payment declined", telemetry.TraceAttrs(r.Context())...)
		writeError(w, http.StatusBadGateway, "payment declined")
		return
	}

	created := h.deps.Store.Create(req.SKU, req.Qty)
	// SKU stays on the span. A free-form metric attribute would explode cardinality.
	h.orders.Add(r.Context(), 1)
	h.deps.Log.LogAttrs(r.Context(), slog.LevelInfo, "order created",
		append(telemetry.TraceAttrs(r.Context()), slog.String("order_id", created.ID))...)
	writeJSON(w, http.StatusCreated, created)
}

func (h *handler) get(w http.ResponseWriter, r *http.Request) {
	o, ok := h.deps.Store.Get(r.PathValue("id"))
	if !ok {
		writeError(w, http.StatusNotFound, "order not found")
		return
	}
	writeJSON(w, http.StatusOK, o)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(v); err != nil && !errors.Is(err, http.ErrHandlerTimeout) {
		return
	}
}

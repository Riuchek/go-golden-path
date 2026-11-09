// Package telemetry wires the OpenTelemetry SDK from the standard env vars.
// The process never imports a vendor exporter. The platform injects an
// OTLP endpoint and a collector does the rest.
package telemetry

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetrichttp"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
	"go.opentelemetry.io/otel/exporters/stdout/stdoutmetric"
	"go.opentelemetry.io/otel/exporters/stdout/stdouttrace"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.37.0"
	"go.opentelemetry.io/otel/trace"
)

// Providers owns the SDK lifecycle. Shutdown flushes pending spans and metrics,
// which is what ECS and compose need on SIGTERM.
type Providers struct {
	shutdown func(context.Context) error
}

// Setup installs global TracerProvider, MeterProvider, and propagator.
// version is the image revision stamped at build time.
func Setup(ctx context.Context, version string) (*Providers, error) {
	if err := checkProtocol(); err != nil {
		return nil, err
	}

	res, err := newResource(version)
	if err != nil {
		return nil, err
	}

	tracerProvider, stopTraces, err := newTracerProvider(ctx, res)
	if err != nil {
		return nil, err
	}
	meterProvider, stopMetrics, err := newMeterProvider(ctx, res)
	if err != nil {
		_ = stopTraces(ctx)
		return nil, err
	}

	otel.SetTracerProvider(tracerProvider)
	otel.SetMeterProvider(meterProvider)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	return &Providers{shutdown: func(ctx context.Context) error {
		return errors.Join(stopTraces(ctx), stopMetrics(ctx))
	}}, nil
}

// Shutdown flushes exporters. A nil receiver is safe.
func (p *Providers) Shutdown(ctx context.Context) error {
	if p == nil || p.shutdown == nil {
		return nil
	}
	return p.shutdown(ctx)
}

// TraceAttrs returns slog attributes for the span in ctx.
// Cloud-vendor log correlation fields are opt-in via env so the binary
// stays provider-agnostic by default.
func TraceAttrs(ctx context.Context) []slog.Attr {
	sc := trace.SpanFromContext(ctx).SpanContext()
	if !sc.IsValid() {
		return nil
	}
	attrs := []slog.Attr{
		slog.String("trace_id", sc.TraceID().String()),
		slog.String("span_id", sc.SpanID().String()),
	}
	if project := os.Getenv("GOOGLE_CLOUD_PROJECT"); project != "" {
		attrs = append(attrs,
			slog.String("logging.googleapis.com/trace", fmt.Sprintf("projects/%s/traces/%s", project, sc.TraceID())),
			slog.String("logging.googleapis.com/spanId", sc.SpanID().String()),
			slog.Bool("logging.googleapis.com/trace_sampled", sc.IsSampled()),
		)
	}
	return attrs
}

func newResource(version string) (*resource.Resource, error) {
	attrs := []attribute.KeyValue{semconv.ServiceVersion(version)}
	if os.Getenv("OTEL_SERVICE_NAME") == "" {
		attrs = append(attrs, semconv.ServiceName("checkout"))
	}
	extra := resource.NewWithAttributes(semconv.SchemaURL, attrs...)
	res, err := resource.Merge(resource.Default(), extra)
	if err != nil && !errors.Is(err, resource.ErrSchemaURLConflict) {
		return nil, fmt.Errorf("resource: %w", err)
	}
	return res, nil
}

func newTracerProvider(ctx context.Context, res *resource.Resource) (*sdktrace.TracerProvider, func(context.Context) error, error) {
	switch exporterChoice("OTEL_TRACES_EXPORTER") {
	case "none":
		tp := sdktrace.NewTracerProvider(
			sdktrace.WithResource(res),
			sdktrace.WithSampler(sdktrace.NeverSample()),
		)
		return tp, tp.Shutdown, nil
	case "console":
		exp, err := stdouttrace.New(stdouttrace.WithPrettyPrint())
		if err != nil {
			return nil, nil, err
		}
		tp := sdktrace.NewTracerProvider(
			sdktrace.WithResource(res),
			sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.AlwaysSample())),
			sdktrace.WithBatcher(exp),
		)
		return tp, tp.Shutdown, nil
	case "otlp":
		exp, err := otlptracehttp.New(ctx, otlptracehttp.WithEndpointURL(otlpEndpoint()))
		if err != nil {
			return nil, nil, fmt.Errorf("otlp trace exporter: %w", err)
		}
		tp := sdktrace.NewTracerProvider(
			sdktrace.WithResource(res),
			sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.AlwaysSample())),
			sdktrace.WithBatcher(exp),
		)
		return tp, tp.Shutdown, nil
	default:
		return nil, nil, fmt.Errorf("unsupported OTEL_TRACES_EXPORTER %q (use otlp, console, or none)", os.Getenv("OTEL_TRACES_EXPORTER"))
	}
}

func newMeterProvider(ctx context.Context, res *resource.Resource) (*sdkmetric.MeterProvider, func(context.Context) error, error) {
	choice := exporterChoice("OTEL_METRICS_EXPORTER")
	// The stdout metric exporter dumps every instrument on an interval and
	// drowns a local `go run`. Default metrics to none unless an endpoint
	// or an explicit exporter is configured. Traces stay on the console.
	if os.Getenv("OTEL_METRICS_EXPORTER") == "" && os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") == "" {
		choice = "none"
	}

	switch choice {
	case "none":
		mp := sdkmetric.NewMeterProvider(sdkmetric.WithResource(res))
		return mp, mp.Shutdown, nil
	case "console":
		exp, err := stdoutmetric.New()
		if err != nil {
			return nil, nil, err
		}
		mp := sdkmetric.NewMeterProvider(
			sdkmetric.WithResource(res),
			sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exp, sdkmetric.WithInterval(15*time.Second))),
		)
		return mp, mp.Shutdown, nil
	case "otlp":
		exp, err := otlpmetrichttp.New(ctx, otlpmetrichttp.WithEndpointURL(otlpEndpoint()))
		if err != nil {
			return nil, nil, fmt.Errorf("otlp metric exporter: %w", err)
		}
		mp := sdkmetric.NewMeterProvider(
			sdkmetric.WithResource(res),
			sdkmetric.WithReader(sdkmetric.NewPeriodicReader(exp, sdkmetric.WithInterval(15*time.Second))),
		)
		return mp, mp.Shutdown, nil
	default:
		return nil, nil, fmt.Errorf("unsupported OTEL_METRICS_EXPORTER %q (use otlp, console, or none)", os.Getenv("OTEL_METRICS_EXPORTER"))
	}
}

func exporterChoice(key string) string {
	if v := strings.ToLower(strings.TrimSpace(os.Getenv(key))); v != "" {
		return v
	}
	if os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" {
		return "otlp"
	}
	return "console"
}

func otlpEndpoint() string {
	endpoint := strings.TrimSpace(os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"))
	if endpoint == "" {
		return "http://localhost:4318"
	}
	if strings.HasPrefix(endpoint, "http://") || strings.HasPrefix(endpoint, "https://") {
		return endpoint
	}
	// WithEndpointURL requires a scheme. The platform always sets one;
	// this keeps a bare host:port from failing closed.
	return "http://" + endpoint
}

func checkProtocol() error {
	switch strings.TrimSpace(os.Getenv("OTEL_EXPORTER_OTLP_PROTOCOL")) {
	case "", "http/protobuf", "http":
		return nil
	default:
		return fmt.Errorf("OTEL_EXPORTER_OTLP_PROTOCOL=%q is not supported; this service exports OTLP over HTTP", os.Getenv("OTEL_EXPORTER_OTLP_PROTOCOL"))
	}
}

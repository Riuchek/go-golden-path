// Package payment is a stand-in for a downstream call.
// The span it creates is what makes the trace waterfall worth opening.
package payment

import (
	"context"
	"errors"
	"strings"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

// ErrDeclined is returned when the simulated authorizer rejects a charge.
var ErrDeclined = errors.New("payment declined")

// authorizeLatency is long enough to show up on a latency chart and short
// enough that the local demo still feels immediate.
const authorizeLatency = 40 * time.Millisecond

// startSpan is the tracer seam. Tests replace it so they can record spans
// without mutating the process-wide provider (other packages do that too).
var startSpan = func(ctx context.Context, name string, opts ...trace.SpanStartOption) (context.Context, trace.Span) {
	return otel.Tracer("checkout").Start(ctx, name, opts...)
}

// Authorize pretends to charge a card. A sku of "fail", or force == true,
// declines the payment. Callers use the X-Demo-Fault header to set force
// so a dashboard can be driven on purpose.
func Authorize(ctx context.Context, sku string, qty int, force bool) error {
	ctx, span := startSpan(ctx, "payment.authorize", trace.WithSpanKind(trace.SpanKindClient))
	defer span.End()

	span.SetAttributes(
		attribute.String("payment.sku", sku),
		attribute.Int("payment.qty", qty),
	)

	timer := time.NewTimer(authorizeLatency)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		span.RecordError(ctx.Err())
		span.SetStatus(codes.Error, ctx.Err().Error())
		return ctx.Err()
	case <-timer.C:
	}

	if force || strings.EqualFold(sku, "fail") {
		span.RecordError(ErrDeclined)
		span.SetStatus(codes.Error, ErrDeclined.Error())
		return ErrDeclined
	}
	return nil
}

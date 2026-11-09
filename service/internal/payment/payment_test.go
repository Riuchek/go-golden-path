package payment

import (
	"context"
	"errors"
	"testing"

	"go.opentelemetry.io/otel/codes"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
)

func TestAuthorizeSpanOnDecline(t *testing.T) {
	rec := tracetest.NewSpanRecorder()
	tp := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(rec))
	prev := startSpan
	startSpan = func(ctx context.Context, name string, opts ...trace.SpanStartOption) (context.Context, trace.Span) {
		return tp.Tracer("checkout").Start(ctx, name, opts...)
	}
	t.Cleanup(func() { startSpan = prev })

	err := Authorize(context.Background(), "fail", 1, false)
	if !errors.Is(err, ErrDeclined) {
		t.Fatalf("err = %v", err)
	}

	spans := rec.Ended()
	if len(spans) != 1 {
		t.Fatalf("got %d spans", len(spans))
	}
	if spans[0].Name() != "payment.authorize" {
		t.Fatalf("span name %s", spans[0].Name())
	}
	if spans[0].Status().Code != codes.Error {
		t.Fatalf("status %s", spans[0].Status().Code)
	}
}

package telemetry_test

import (
	"context"
	"testing"

	"github.com/Riuchek/go-golden-path/service/internal/telemetry"
)

func TestSetupNone(t *testing.T) {
	t.Setenv("OTEL_TRACES_EXPORTER", "none")
	t.Setenv("OTEL_METRICS_EXPORTER", "none")
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "")

	p, err := telemetry.Setup(context.Background(), "test")
	if err != nil {
		t.Fatal(err)
	}
	if err := p.Shutdown(context.Background()); err != nil {
		t.Fatal(err)
	}
}

func TestSetupRejectsGRPCProtocol(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc")
	if _, err := telemetry.Setup(context.Background(), "test"); err == nil {
		t.Fatal("expected error")
	}
}

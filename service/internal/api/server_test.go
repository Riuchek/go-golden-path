package api

import (
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/Riuchek/go-golden-path/service/internal/payment"
)

func TestCreateAndGet(t *testing.T) {
	mux := newMux(t, func(context.Context, string, int, bool) error { return nil })

	res := request(t, mux, http.MethodPost, "/v1/orders", `{"sku":"widget","qty":2}`, nil)
	if res.Code != http.StatusCreated {
		t.Fatalf("create status %d body %s", res.Code, res.Body.String())
	}
	if !strings.Contains(res.Body.String(), `"sku":"widget"`) {
		t.Fatalf("body %s", res.Body.String())
	}

	id := extractID(t, res.Body.String())
	got := request(t, mux, http.MethodGet, "/v1/orders/"+id, "", nil)
	if got.Code != http.StatusOK {
		t.Fatalf("get status %d body %s", got.Code, got.Body.String())
	}
}

func TestPaymentDeclined(t *testing.T) {
	mux := newMux(t, func(_ context.Context, _ string, _ int, force bool) error {
		if !force {
			t.Fatal("X-Demo-Fault should reach the authorizer")
		}
		return payment.ErrDeclined
	})
	res := request(t, mux, http.MethodPost, "/v1/orders", `{"sku":"widget","qty":1}`, map[string]string{
		"X-Demo-Fault": "payment",
	})
	if res.Code != http.StatusBadGateway {
		t.Fatalf("status %d body %s", res.Code, res.Body.String())
	}
}

func TestRejectsBadInput(t *testing.T) {
	mux := newMux(t, func(context.Context, string, int, bool) error { return nil })
	cases := []struct {
		body string
		want int
	}{
		{body: `{`, want: http.StatusBadRequest},
		{body: `{"sku":"widget","qty":1,"extra":true}`, want: http.StatusBadRequest},
		{body: `{"sku":"","qty":1}`, want: http.StatusBadRequest},
		{body: `{"sku":"widget","qty":0}`, want: http.StatusBadRequest},
	}
	for _, tc := range cases {
		res := request(t, mux, http.MethodPost, "/v1/orders", tc.body, nil)
		if res.Code != tc.want {
			t.Fatalf("body %s status %d", tc.body, res.Code)
		}
	}
}

func TestNotFound(t *testing.T) {
	mux := newMux(t, func(context.Context, string, int, bool) error { return nil })
	res := request(t, mux, http.MethodGet, "/v1/orders/missing", "", nil)
	if res.Code != http.StatusNotFound {
		t.Fatalf("status %d", res.Code)
	}
}

func TestProbes(t *testing.T) {
	mux := newMux(t, func(context.Context, string, int, bool) error { return nil })
	for _, path := range []string{"/healthz", "/readyz"} {
		res := request(t, mux, http.MethodGet, path, "", nil)
		if res.Code != http.StatusOK {
			t.Fatalf("%s status %d", path, res.Code)
		}
	}
}

func newMux(t *testing.T, auth Authorizer) http.Handler {
	t.Helper()
	return NewMux(Deps{
		Authorize: auth,
		Log:       slog.New(slog.NewTextHandler(io.Discard, nil)),
	})
}

func request(t *testing.T, h http.Handler, method, path, body string, headers map[string]string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func extractID(t *testing.T, body string) string {
	t.Helper()
	const key = `"id":"`
	i := strings.Index(body, key)
	if i < 0 {
		t.Fatalf("no id in %s", body)
	}
	rest := body[i+len(key):]
	j := strings.Index(rest, `"`)
	if j < 0 {
		t.Fatalf("no id end in %s", body)
	}
	return rest[:j]
}

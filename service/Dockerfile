# Chainguard build + static runtime. CGO stays off so the binary fits the
# static image (no libc). Digest pins belong in CI once digestabot lands;
# :latest is the Chainguard contract for continuously rebuilt bases.
FROM cgr.dev/chainguard/go:latest AS build

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .

ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w -X main.version=${VERSION}" \
    -o /usr/bin/server ./cmd/server

FROM cgr.dev/chainguard/static:latest
COPY --from=build /usr/bin/server /usr/bin/server
USER nonroot
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/bin/server"]

# ---- build stage (runs NATIVELY on the runner arch, cross-compiles) ----
FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS builder
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT          # e.g. "v7" for linux/arm/v7 -> GOARM=7
ARG VERSION=dev
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT#v} go build \
    -ldflags="-s -w -X github.com/pocketbase/pocketbase.Version=${VERSION}" \
    -o /pocketbase ./examples/base

# ---- runtime stage (target arch; only apk runs emulated here) ----
FROM alpine:latest
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /pocketbase /pb/pocketbase
EXPOSE 8090
VOLUME /pb/pb_data
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD wget -qO- http://127.0.0.1:8090/api/health || exit 1
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data"]

# Multi-stage Docker build: tsl-tool binary for LoTE publishing
# Builds tsl-tool from sirosfoundation/g119612 and sets up a cron-based publisher
FROM golang:1.25-alpine AS builder

# Install CGO build dependencies (needed for pkcs11 + XML signature libraries)
RUN apk add --no-cache \
    git \
    build-base \
    libxml2-dev \
    libxslt-dev \
    pkgconf

WORKDIR /build

# Clone g119612 at a pinned commit for reproducible builds
RUN git clone https://github.com/sirosfoundation/g119612.git . \
    && git checkout f36d655b8b9d38e0bfcf173da9b2f0ecd71e566a

# Download all dependencies to populate go.sum before building
RUN go mod download

# Build tsl-tool binary with CGO enabled
RUN CGO_ENABLED=1 GOOS=linux go build \
    -ldflags="-X main.Version=dev -w -s" \
    -o tsl-tool ./cmd/tsl-tool/main.go

# Final runtime stage
FROM alpine:latest

# Install runtime dependencies and BusyBox crond
RUN apk add --no-cache \
    ca-certificates \
    bash \
    libxml2 \
    libxslt \
    && update-ca-certificates

# Copy tsl-tool binary
COPY --from=builder /build/tsl-tool /usr/local/bin/tsl-tool

# Create required directories
RUN mkdir -p \
    /var/www/html/lote \
    /var/log

# Copy pipeline configuration
COPY config/publish-lote.yaml /etc/lote/publish-lote.yaml

# Install cron job: republish every 6 hours
RUN echo '0 */6 * * * /usr/local/bin/tsl-tool /etc/lote/publish-lote.yaml >> /var/log/lote-publish 2>&1' \
    >> /etc/crontabs/root

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

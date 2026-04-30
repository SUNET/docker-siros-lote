# Multi-stage Docker build: tsl-tool binary for LoTE publishing
# Builds tsl-tool from sirosfoundation/g119612 and sets up a cron-based publisher
FROM golang:1.26-alpine AS builder

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
    && git checkout 28620f4a80abdca4f5fd1f98c688a03837af7ef5

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
    openssl \
    libxml2 \
    libxslt \
    && update-ca-certificates

# Copy tsl-tool binary
COPY --from=builder /build/tsl-tool /usr/local/bin/tsl-tool

# Create required directories
RUN mkdir -p \
    /var/www/html/lote/pid_providers \
    /var/www/html/lote/pubeaa_providers \
    /var/log

# Copy pipeline configurations
COPY config/publish-pid-lote.yaml /etc/lote/publish-pid-lote.yaml
COPY config/publish-pubeaa-lote.yaml /etc/lote/publish-pubeaa-lote.yaml

# Install cron job: republish both LoTEs every 6 hours
RUN echo '0 */6 * * * /usr/local/bin/tsl-tool /etc/lote/publish-pid-lote.yaml >> /var/log/lote-publish 2>&1 && /usr/local/bin/tsl-tool /etc/lote/publish-pubeaa-lote.yaml >> /var/log/lote-publish 2>&1' \
    >> /etc/crontabs/root

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

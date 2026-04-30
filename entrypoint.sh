#!/bin/sh
set -e

# Ensure files written by tsl-tool are world-readable for nginx
umask 022

# Wait for ms-registry to be ready before running tsl-tool.
# depends_on only guarantees the container started, not that Django is serving.
REGISTRY_URL="http://ms-registry:8000/lote-source/pid-providers/"
MAX_RETRIES=30
RETRY_INTERVAL=5

echo "Waiting for ms-registry to be ready..."
i=0
until wget -q --spider "$REGISTRY_URL" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge "$MAX_RETRIES" ]; then
        echo "ms-registry not ready after $((MAX_RETRIES * RETRY_INTERVAL))s, giving up"
        exit 1
    fi
    echo "  ms-registry not ready yet (attempt $i/$MAX_RETRIES), retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done
echo "ms-registry is ready."

echo "Running initial LoTE generation..."
/usr/local/bin/tsl-tool /etc/lote/publish-pid-lote.yaml
/usr/local/bin/tsl-tool /etc/lote/publish-pubeaa-lote.yaml

echo "Starting cron daemon..."
exec crond -f -l 8

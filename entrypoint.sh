#!/bin/sh
set -e

MAX_RETRIES=30
RETRY_INTERVAL=5

# Wait for ms-registry (PID + PuB-EAA providers)
REGISTRY_URL="http://ms-registry:8000/api/lote-source/pid-providers/"
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

# Wait for wp4-onboarding (Wallet, WRPAC, WRPRC, Registrars)
# Use lists/index.json instead of /healthz/ because healthz may reject non-localhost hosts
ONBOARDING_URL="http://wp4-onboarding:8000/lists/index.json"
echo "Waiting for wp4-onboarding to be ready..."
i=0
until wget -q --spider "$ONBOARDING_URL" 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge "$MAX_RETRIES" ]; then
        echo "wp4-onboarding not ready after $((MAX_RETRIES * RETRY_INTERVAL))s, giving up"
        exit 1
    fi
    echo "  wp4-onboarding not ready yet (attempt $i/$MAX_RETRIES), retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done
echo "wp4-onboarding is ready."

mkdir -p /var/www/html/lote/pid_providers \
         /var/www/html/lote/pubeaa_providers \
         /var/www/html/lote/wallet_providers \
         /var/www/html/lote/wrpac_providers \
         /var/www/html/lote/wrprc_providers \
         /var/www/html/lote/registrars_registers

chmod -R o+rx /var/www/html/lote

echo "Running initial LoTE generation..."
# From ms-registry (old flow)
/usr/local/bin/tsl-tool /etc/lote/publish-pid-lote.yaml
/usr/local/bin/tsl-tool /etc/lote/publish-pubeaa-lote.yaml
# From wp4-onboarding (new flow)
/usr/local/bin/tsl-tool /etc/lote/publish-wallet-lote.yaml
/usr/local/bin/tsl-tool /etc/lote/publish-wrpac-lote.yaml
/usr/local/bin/tsl-tool /etc/lote/publish-wrprc-lote.yaml
/usr/local/bin/tsl-tool /etc/lote/publish-registrars-lote.yaml

echo "Starting cron daemon..."
exec crond -f -l 8

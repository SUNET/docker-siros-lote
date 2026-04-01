#!/bin/sh
set -e

echo "Running initial LoTE generation..."
/usr/local/bin/tsl-tool /etc/lote/publish-lote.yaml

echo "Starting cron daemon..."
exec crond -f -l 8

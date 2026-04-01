#!/usr/bin/env bash
# Install the SigNoz OTel Collector as a permanent service.
# Reuses the binary already downloaded during the migration step.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')

echo "==> Creating OTel Collector directories"
mkdir -p /opt/signoz-otel-collector /var/lib/signoz-otel-collector

echo "==> Installing OTel Collector files"
COLLECTOR_SRC="/tmp/signoz-otel-collector-src/signoz-otel-collector_linux_${ARCH}"
if [[ ! -d "${COLLECTOR_SRC}" ]]; then
  echo "ERROR: OTel Collector source not found at ${COLLECTOR_SRC}"
  echo "       Was 04-run-migrations.sh run first?"
  exit 1
fi
cp -r "${COLLECTOR_SRC}/." /opt/signoz-otel-collector/

echo "==> Setting ownership"
# signoz user was created in 05-install-signoz.sh
chown -R signoz:signoz /opt/signoz-otel-collector /var/lib/signoz-otel-collector

echo "==> Writing OTel Collector config"
mkdir -p /opt/signoz-otel-collector/conf
# Substitute the ClickHouse password into the config template
sed "s/__CLICKHOUSE_PASSWORD__/${CLICKHOUSE_PASSWORD}/g" \
  /tmp/packer/otel-collector/config.yaml \
  > /opt/signoz-otel-collector/conf/config.yaml
chmod 640 /opt/signoz-otel-collector/conf/config.yaml
chown signoz:signoz /opt/signoz-otel-collector/conf/config.yaml

echo "==> Writing OpAMP config"
cp /tmp/packer/otel-collector/opamp.yaml /opt/signoz-otel-collector/conf/opamp.yaml
chmod 640 /opt/signoz-otel-collector/conf/opamp.yaml
chown signoz:signoz /opt/signoz-otel-collector/conf/opamp.yaml

echo "==> Installing OTel Collector systemd service"
cp /tmp/packer/systemd/signoz-otel-collector.service /etc/systemd/system/signoz-otel-collector.service
systemctl daemon-reload

echo "==> Cleaning up OTel Collector source"
rm -rf /tmp/signoz-otel-collector.tar.gz /tmp/signoz-otel-collector-src

echo "==> OTel Collector installed"

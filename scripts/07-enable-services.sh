#!/usr/bin/env bash
# Enable all SigNoz services so they start at boot.
# Stops the infrastructure services that were started for migrations so the
# image is clean — systemd will bring them up in dependency order on first boot.
set -euo pipefail

echo "==> Enabling all services"
systemctl enable clickhouse-server.service
systemctl enable zookeeper.service
systemctl enable signoz.service
systemctl enable signoz-otel-collector.service

echo "==> Stopping migration-phase services"
systemctl stop clickhouse-server.service || true
systemctl stop zookeeper.service || true

echo "==> Service status"
for svc in clickhouse-server zookeeper signoz signoz-otel-collector; do
  echo "  ${svc}: $(systemctl is-enabled ${svc}.service)"
done

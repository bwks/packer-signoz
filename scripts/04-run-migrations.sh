#!/usr/bin/env bash
# Start Zookeeper + ClickHouse, download the SigNoz OTel Collector binary,
# and run the three ClickHouse schema migrations required by SigNoz.
set -euo pipefail

ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
CH_DSN="tcp://localhost:9000?password=${CLICKHOUSE_PASSWORD}"

wait_for_port() {
  local host="$1" port="$2" label="$3" retries=30 delay=3
  echo "==> Waiting for ${label} on ${host}:${port}"
  for i in $(seq 1 "${retries}"); do
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
      echo "    ${label} is ready"
      return 0
    fi
    echo "    Attempt ${i}/${retries} — sleeping ${delay}s"
    sleep "${delay}"
  done
  echo "ERROR: ${label} did not become ready in time"
  return 1
}

echo "==> Starting Zookeeper"
systemctl start zookeeper.service
wait_for_port 127.0.0.1 2181 "Zookeeper"

echo "==> Starting ClickHouse"
systemctl start clickhouse-server.service
wait_for_port 127.0.0.1 9000 "ClickHouse"
# Give ClickHouse a moment to finish initialization
sleep 5

echo "==> Downloading SigNoz OTel Collector (for migrations)"
COLLECTOR_URL="https://github.com/SigNoz/signoz-otel-collector/releases/latest/download/signoz-otel-collector_linux_${ARCH}.tar.gz"
curl -fsSL "${COLLECTOR_URL}" -o /tmp/signoz-otel-collector.tar.gz
mkdir -p /tmp/signoz-otel-collector-src
tar -xzf /tmp/signoz-otel-collector.tar.gz -C /tmp/signoz-otel-collector-src

COLLECTOR_BIN="/tmp/signoz-otel-collector-src/signoz-otel-collector_linux_${ARCH}/bin/signoz-otel-collector"

echo "==> Running migration: bootstrap"
"${COLLECTOR_BIN}" migrate bootstrap \
  --clickhouse-dsn="${CH_DSN}" \
  --clickhouse-replication=true

echo "==> Running migration: sync up"
"${COLLECTOR_BIN}" migrate sync up \
  --clickhouse-dsn="${CH_DSN}" \
  --clickhouse-replication=true

echo "==> Running migration: async up"
"${COLLECTOR_BIN}" migrate async up \
  --clickhouse-dsn="${CH_DSN}" \
  --clickhouse-replication=true

echo "==> Migrations complete"

#!/usr/bin/env bash
# Download and install the SigNoz backend binary and its systemd service.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ARCH=$(uname -m | sed 's/x86_64/amd64/g' | sed 's/aarch64/arm64/g')
SIGNOZ_URL="https://github.com/SigNoz/signoz/releases/latest/download/signoz_linux_${ARCH}.tar.gz"

echo "==> Downloading SigNoz"
curl -fsSL "${SIGNOZ_URL}" -o /tmp/signoz.tar.gz
tar -xzf /tmp/signoz.tar.gz -C /tmp

SIGNOZ_DIR=$(find /tmp -maxdepth 1 -name "signoz_linux_*" -type d | head -1)
if [[ -z "${SIGNOZ_DIR}" ]]; then
  echo "ERROR: could not find extracted SigNoz directory in /tmp"
  exit 1
fi

echo "==> Creating SigNoz directories"
mkdir -p /opt/signoz /var/lib/signoz

echo "==> Installing SigNoz files"
cp -r "${SIGNOZ_DIR}/." /opt/signoz/

echo "==> Creating signoz system user"
getent passwd signoz >/dev/null \
  || useradd --system --home /opt/signoz --no-create-home --user-group --shell /sbin/nologin signoz

echo "==> Setting ownership"
chown -R signoz:signoz /opt/signoz /var/lib/signoz

echo "==> Writing SigNoz environment file"
mkdir -p /opt/signoz/conf
cat > /opt/signoz/conf/systemd.env << EOF
SIGNOZ_INSTRUMENTATION_LOGS_LEVEL=info
INVITE_EMAIL_TEMPLATE=/opt/signoz/templates/invitation_email_template.html
SIGNOZ_SQLSTORE_SQLITE_PATH=/var/lib/signoz/signoz.db
SIGNOZ_WEB_ENABLED=true
SIGNOZ_WEB_DIRECTORY=/opt/signoz/web
SIGNOZ_JWT_SECRET=${SIGNOZ_JWT_SECRET}
SIGNOZ_ALERTMANAGER_PROVIDER=signoz
SIGNOZ_TELEMETRYSTORE_PROVIDER=clickhouse
SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=tcp://localhost:9000?password=${CLICKHOUSE_PASSWORD}
DOT_METRICS_ENABLED=true
EOF
chmod 640 /opt/signoz/conf/systemd.env
chown signoz:signoz /opt/signoz/conf/systemd.env

echo "==> Installing SigNoz systemd service"
cp /tmp/packer/systemd/signoz.service /etc/systemd/system/signoz.service
systemctl daemon-reload

echo "==> Cleaning up SigNoz archive"
rm -rf /tmp/signoz.tar.gz "${SIGNOZ_DIR}"

echo "==> SigNoz installed"

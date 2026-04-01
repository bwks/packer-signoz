#!/usr/bin/env bash
# Install ClickHouse and apply the cluster configuration required by SigNoz.
# The service is NOT started here — Zookeeper must come first.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Adding ClickHouse apt repository"
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' \
  | gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" \
  | tee /etc/apt/sources.list.d/clickhouse.list

apt-get update -y
apt-get install -y clickhouse-server clickhouse-client

echo "==> Configuring ClickHouse password"
mkdir -p /etc/clickhouse-server/users.d
cat > /etc/clickhouse-server/users.d/default-password.xml << EOF
<clickhouse>
    <users>
        <default>
            <password>${CLICKHOUSE_PASSWORD}</password>
        </default>
    </users>
</clickhouse>
EOF
chmod 640 /etc/clickhouse-server/users.d/default-password.xml
chown root:clickhouse /etc/clickhouse-server/users.d/default-password.xml

echo "==> Installing ClickHouse cluster config"
cp /tmp/packer/clickhouse/cluster.xml /etc/clickhouse-server/config.d/cluster.xml
chmod 640 /etc/clickhouse-server/config.d/cluster.xml
chown root:clickhouse /etc/clickhouse-server/config.d/cluster.xml

echo "==> ClickHouse installed (service not started — Zookeeper required first)"

#!/usr/bin/env bash
# Download, install, and configure Apache Zookeeper as a systemd service.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
ZOOKEEPER_VERSION="${ZOOKEEPER_VERSION:-3.8.5}"
ZK_ARCHIVE="apache-zookeeper-${ZOOKEEPER_VERSION}-bin"
DOWNLOAD_URL="https://archive.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/${ZK_ARCHIVE}.tar.gz"

echo "==> Downloading Zookeeper ${ZOOKEEPER_VERSION}"
curl -fsSL "${DOWNLOAD_URL}" -o /tmp/zookeeper.tar.gz

echo "==> Extracting Zookeeper"
tar -xzf /tmp/zookeeper.tar.gz -C /tmp

echo "==> Creating Zookeeper directories"
mkdir -p /opt/zookeeper /var/lib/zookeeper /var/log/zookeeper

echo "==> Installing Zookeeper files"
cp -r "/tmp/${ZK_ARCHIVE}/." /opt/zookeeper/

echo "==> Creating Zookeeper system user"
getent passwd zookeeper >/dev/null \
  || useradd --system --home /opt/zookeeper --no-create-home --user-group --shell /sbin/nologin zookeeper

echo "==> Setting ownership"
chown -R zookeeper:zookeeper /opt/zookeeper /var/lib/zookeeper /var/log/zookeeper

echo "==> Installing Zookeeper configuration"
cp /tmp/packer/zookeeper/zoo.cfg /opt/zookeeper/conf/zoo.cfg
cp /tmp/packer/zookeeper/zoo.env /opt/zookeeper/conf/zoo.env
chown zookeeper:zookeeper /opt/zookeeper/conf/zoo.cfg /opt/zookeeper/conf/zoo.env

echo "==> Installing Zookeeper systemd service"
cp /tmp/packer/systemd/zookeeper.service /etc/systemd/system/zookeeper.service
systemctl daemon-reload

echo "==> Cleaning up Zookeeper archive"
rm -rf /tmp/zookeeper.tar.gz "/tmp/${ZK_ARCHIVE}"

echo "==> Zookeeper installed"

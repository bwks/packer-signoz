#!/usr/bin/env bash
# Install system dependencies required by all SigNoz components.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating apt cache"
apt-get update -y

echo "==> Installing system dependencies"
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  default-jdk

echo "==> Dependencies installed"
java -version

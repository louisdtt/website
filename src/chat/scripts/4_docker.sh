#!/usr/bin/env bash
# Install Docker Engine + compose plugin on Ubuntu (official repo).
set -euo pipefail

apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu

echo "=== Done ==="
docker --version
docker compose version
echo "Log out/in (or 'newgrp docker') for the docker group to apply."

# SearxNG setup
mkdir -p ./searxng
{ echo "use_default_settings: true"
  echo "server:"
  echo "  secret_key: \"$(openssl rand -hex 32)\""
  echo "  limiter: false"
  echo "search:"
  echo "  formats:"
  echo "    - html"
  echo "    - json"
} > ./searxng/settings.yml

cat ./searxng/settings.yml   # verify
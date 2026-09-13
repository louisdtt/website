#!/usr/bin/env bash
# Install Hermes Agent + gateway systemd service. Run as ubuntu, NOT sudo.
set -euo pipefail

curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
export PATH="$HOME/.local/bin:$PATH"
grep -q '.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

[ -x "$HOME/.local/bin/hermes" ] || { echo "hermes binary not found after install" >&2; exit 1; }
"$HOME/.local/bin/hermes" --version

source ~/.bashrc

sudo systemctl daemon-reload
sudo systemctl enable --now hermes

hermes config set API_SERVER_HOST 0.0.0.0
hermes config set API_SERVER_ENABLED true
hermes config set API_SERVER_KEY #set_your_api_server_key_here

hermes gateway stop && hermes gateway start
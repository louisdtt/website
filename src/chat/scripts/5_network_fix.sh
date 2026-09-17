#!/bin/sh
# Fix container->host (Hermes gateway :8642) reachability after reboot.

set -eu

# 1. iptables (Oracle layer): allow docker bridges before final REJECT
for IFACE in docker0 br-+; do
    if ! sudo iptables -S INPUT | grep -q -- "-i $IFACE -j ACCEPT"; then
        # insert right before the last INPUT rule (the REJECT)
        N=$(sudo iptables -L INPUT --line-numbers -n | tail -1 | awk '{print $1}')
        sudo iptables -I INPUT "$N" -i "$IFACE" -j ACCEPT
        echo "iptables: added -i $IFACE ACCEPT"
    fi
done

# 2. nftables (our layer): ensure docker bridge accepts exist
sudo nft list chain inet filter input 2>/dev/null | grep -q 'iifname "docker0" accept' || \
    sudo nft add rule inet filter input iifname "docker0" accept
sudo nft list chain inet filter input 2>/dev/null | grep -q 'iifname "br-\*" accept' || \
    sudo nft add rule inet filter input iifname "br-*" accept

# 3. gateway must be listening on all interfaces (0.0.0.0), not just loopback
ENV_FILE="$HOME/.hermes/.env"
if grep -q '^API_SERVER_HOST=' "$ENV_FILE"; then
    sed -i 's/^API_SERVER_HOST=.*/API_SERVER_HOST=0.0.0.0/' "$ENV_FILE"
else
    echo 'API_SERVER_HOST=0.0.0.0' >> "$ENV_FILE"
fi
if ss -tln | grep -q '127.0.0.1:8642'; then
    systemctl --user restart hermes-gateway
    echo "restarted hermes-gateway (was loopback-only)"
fi

# 4. persist iptables for next reboot
sudo netfilter-persistent save 2>/dev/null || sudo iptables-save > /etc/iptables/rules.v4

# 5. verify
sleep 2
echo "--- listener ---"
ss -tln | grep 8642
echo "--- probe from container ---"
docker exec docker-open-webui-1 python3 - <<'EOF' 2>/dev/null || echo "probe failed (is open-webui up?)"
import urllib.request
try:
    urllib.request.urlopen('http://host.docker.internal:8642/v1/models', timeout=5)
except Exception as e:
    # 401 = reachable + auth working = GOOD
    print("OK: gateway reachable (", getattr(e, 'code', e), ")")
EOF


# The Oracle `ip filter` table runs in PARALLEL with the user-managed
# `inet filter` table: both must accept. Removing this rule does NOT affect
# tunnel/loopback logins.
#
# Usage:
#   remove-oracle-22.sh          remove the rule (idempotent, backs up first)
#   remove-oracle-22.sh restore  restore from the latest backup taken by this script
set -euo pipefail

RULES=/etc/iptables/rules.v4
BACKUP_DIR=/root/iptables-backups
TS=$(date +%Y%m%d-%H%M%S)

# The exact rule Oracle's image ships (verified live before writing this):
#   -A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
rule_spec='-p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT'

if [[ ${1:-} == "restore" ]]; then
    latest=$(ls -1t "$BACKUP_DIR"/rules.v4.* 2>/dev/null | head -1) || {
        echo "No backup found in $BACKUP_DIR" >&2; exit 1; }
    cp "$latest" "$RULES"
    iptables-restore < "$RULES"
    # Docker chains were in the restored file; restart docker to be safe.
    systemctl restart docker
    echo "Restored from $latest"
    exit 0
fi

[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }

mkdir -p "$BACKUP_DIR"

# 1. Backup live ruleset + persisted file
iptables-save > "$BACKUP_DIR/rules.v4.$TS"
cp "$RULES" "$BACKUP_DIR/rules.v4.file.$TS"
echo "Backup: $BACKUP_DIR/rules.v4.$TS"

# 2. Remove the rule live (idempotent: check first)
if iptables -C INPUT $rule_spec 2>/dev/null; then
    iptables -D INPUT $rule_spec
    echo "Removed live INPUT rule: $rule_spec"
else
    echo "Live rule not present (already removed?)"
fi

# 3. Update the persisted file so it does not come back on reboot.
#    iptables-save rewrites the whole file; Docker chains are captured too.
iptables-save > "$RULES"

# 4. Sanity checks
echo "--- verify ---"
if iptables -C INPUT $rule_spec 2>/dev/null; then
    echo "FAIL: rule still present in live ruleset" >&2; exit 1
else
    echo "OK: no port-22 accept in ip filter INPUT"
fi
if ! grep -q 'DOCKER-USER' "$RULES"; then
    echo "WARNING: Docker chains missing from $RULES — restart docker" >&2
fi
if ! nft list ruleset | grep -q 'table inet filter'; then
    echo "WARNING: inet filter table not found" >&2
else
    echo "OK: inet filter table intact (your real firewall)"
fi
echo "Done. Logins via cloudflared tunnel (127.0.0.1) are unaffected."
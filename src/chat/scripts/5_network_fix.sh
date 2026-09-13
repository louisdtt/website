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
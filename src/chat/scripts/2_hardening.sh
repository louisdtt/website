#!/usr/bin/env bash
# Lock all inbound ports + auto-update ALL packages + auto-reboot for kernels.
set -euo pipefail

# --- nftables: lock all inbound, loopback untouched ---
apt-get update
apt-get install -y nftables unattended-upgrades

cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
table inet filter
flush table inet filter
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif "lo" accept
        ct state established,related accept
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept
        iifname "docker0" accept
        iifname "br-*" accept
        reject
    }
}
EOF
systemctl enable --now nftables
systemctl restart nftables

# --- unattended upgrades: ALL packages ---
printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > /etc/apt/apt.conf.d/20auto-upgrades

cat > /etc/apt/apt.conf.d/51-all-updates <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-updates";
};
EOF

# --- auto-reboot when an update requires it (kernels) ---
cat > /etc/apt/apt.conf.d/52-auto-reboot <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
EOF

systemctl enable apt-daily-upgrade.timer

# --- verify ---
echo "=== Firewall: ==="
nft list ruleset
echo
echo "=== Update + reboot policy: ==="
cat /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/51-all-updates /etc/apt/apt.conf.d/52-auto-reboot
unattended-upgrades --dry-run --debug 2>&1 | grep -iE 'allowed origins|checking' | head -10
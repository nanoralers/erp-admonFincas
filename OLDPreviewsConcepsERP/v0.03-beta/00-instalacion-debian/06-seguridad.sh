#!/bin/bash
# PASO 06 — UFW + Fail2Ban + hardening kernel
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

info "Instalando UFW y Fail2Ban..."
apt-get install -y -qq ufw fail2ban \
    2>&1 | grep -E "^(Inst|Conf)" | head -5 | sed 's/^/    /' || true
ok "UFW y Fail2Ban instalados"

# ── UFW ───────────────────────────────────────────────────────────────────────
info "Configurando firewall UFW..."
ufw --force reset >/dev/null 2>&1
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    comment 'SSH'
ufw allow 80/tcp    comment 'HTTP → redirige a HTTPS'
ufw allow 443/tcp   comment 'HTTPS — ERP + phpMyAdmin'
ufw allow from 192.168.1.0/24 to any port 53 comment 'DNS local (red interna)'
# FTP: el router ya tiene el puerto abierto, activar si se usa
# ufw allow 21/tcp  comment 'FTP'
ufw --force enable >/dev/null 2>&1
ok "UFW activo"
ufw status | grep -E "ALLOW|DENY" | sed 's/^/    /'

# ── Fail2Ban ──────────────────────────────────────────────────────────────────
info "Configurando Fail2Ban..."
cat > /etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
bantime   = 3600
findtime  = 600
maxretry  = 5
backend   = systemd

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 7200

[apache-auth]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-error.log
           %(apache_error_log)s
maxretry = 5

[apache-badbots]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-access.log
maxretry = 2

[erp-login]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-access.log
filter   = erp-login
maxretry = 5
bantime  = 3600
F2B

mkdir -p /etc/fail2ban/filter.d/
cat > /etc/fail2ban/filter.d/erp-login.conf <<'F2BFILTER'
[Definition]
failregex = ^<HOST> .* "POST /login.*" (401|403|429) .*$
ignoreregex =
F2BFILTER

systemctl enable fail2ban >/dev/null 2>&1 || true
systemctl restart fail2ban
ok "Fail2Ban activo"

# ── Hardening SSH ────────────────────────────────────────────────────────────
info "Hardening SSH..."
SSH_CFG="/etc/ssh/sshd_config"
if [[ -f "$SSH_CFG" ]]; then
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSH_CFG"
    sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 4/'                       "$SSH_CFG"
    sed -i 's/^#\?ClientAliveInterval.*/ClientAliveInterval 300/'       "$SSH_CFG"
    sshd -t 2>/dev/null && systemctl reload sshd 2>/dev/null \
        || systemctl reload ssh 2>/dev/null || true
    ok "SSH hardening aplicado (PermitRootLogin prohibit-password, MaxAuthTries 4)"
fi

# ── Kernel sysctl ────────────────────────────────────────────────────────────
info "Aplicando hardening del kernel..."
cat > /etc/sysctl.d/99-erp-fincas.conf <<'SYSCTL'
net.ipv4.conf.all.rp_filter              = 1
net.ipv4.conf.default.rp_filter          = 1
net.ipv4.conf.all.accept_redirects       = 0
net.ipv6.conf.all.accept_redirects       = 0
net.ipv4.conf.all.send_redirects         = 0
net.ipv4.conf.all.accept_source_route    = 0
net.ipv6.conf.all.accept_source_route    = 0
net.ipv4.tcp_syncookies                  = 1
net.ipv4.tcp_max_syn_backlog             = 2048
net.ipv4.icmp_echo_ignore_broadcasts     = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians           = 1
SYSCTL
sysctl -p /etc/sysctl.d/99-erp-fincas.conf >/dev/null 2>&1 || true
ok "Parámetros del kernel aplicados"

echo ""
ok "PASO 06 completado"
echo ""
echo "    UFW:      activo (22, 80, 443)"
echo "    Fail2Ban: activo (SSH 3 intentos/2h, Apache, ERP login)"
echo "    SSH:      PermitRootLogin prohibit-password"

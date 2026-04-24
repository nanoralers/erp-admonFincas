#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 06 — Seguridad: UFW (firewall) + Fail2Ban + hardening del sistema
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

# ── Instalar herramientas de seguridad ────────────────────────────────────────
info "Instalando paquetes de seguridad..."
apt-get install -y -qq ufw fail2ban 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
ok "UFW y Fail2Ban instalados"

# ════════════════════════════════════════════════════════════════════════════
#  FIREWALL — UFW
# ════════════════════════════════════════════════════════════════════════════
info "Configurando firewall UFW..."

# Resetear reglas existentes (cuidado: solo hacer en instalación limpia)
ufw --force reset 2>/dev/null | tail -1

# Política por defecto: denegar todo entrante, permitir todo saliente
ufw default deny incoming
ufw default allow outgoing

# ── Reglas permitidas ──────────────────────────────────────────────────────
# SSH (mantener siempre habilitado para no perder el acceso)
ufw allow 22/tcp    comment 'SSH - Acceso administración'

# HTTP y HTTPS (web pública + ERP)
ufw allow 80/tcp    comment 'HTTP - Redirigir a HTTPS'
ufw allow 443/tcp   comment 'HTTPS - ERP Fincas'

# FTP si está o estará habilitado (el router ya tiene el puerto abierto)
# ufw allow 21/tcp  comment 'FTP'
# ufw allow 20/tcp  comment 'FTP datos'

# DNS local (dnsmasq solo en red interna)
ufw allow from 192.168.1.0/24 to any port 53 comment 'DNS local red interna'

# MariaDB solo en localhost (NUNCA exponer al exterior)
# ufw allow 3306/tcp  <-- NO habilitado, solo localhost

# ── Habilitar UFW ──────────────────────────────────────────────────────────
ufw --force enable 2>&1 | tail -1
ok "UFW habilitado"

ufw status verbose | grep -E "(Status|To|ALLOW|DENY)" | sed 's/^/    /'

# ════════════════════════════════════════════════════════════════════════════
#  FAIL2BAN
# ════════════════════════════════════════════════════════════════════════════
info "Configurando Fail2Ban..."

# Configuración local (no tocar el .conf original para conservar defaults)
cat > /etc/fail2ban/jail.local <<'FAIL2BAN'
[DEFAULT]
# Banear durante 1 hora tras 5 intentos fallidos en 10 minutos
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

# Email de alertas (configurar si tienes SMTP)
# destemail = admin@nanoserver.es
# sendername = Fail2Ban nanoserver
# action = %(action_mwl)s

# ── SSH ───────────────────────────────────────────────────────────────────────
[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 7200

# ── Apache — intentos de acceso no autorizados ───────────────────────────────
[apache-auth]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-error.log
           %(apache_error_log)s
maxretry = 5

# ── Apache — ataques de fuerza bruta al login del ERP ────────────────────────
[apache-noscript]
enabled  = true
port     = http,https
logpath  = %(apache_error_log)s
maxretry = 6

# ── Apache — bots y scanners ─────────────────────────────────────────────────
[apache-badbots]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-access.log
           %(apache_access_log)s
maxretry = 2

# ── Protección login ERP (PHP) ────────────────────────────────────────────────
# Detecta respuestas 401/403 repetidas al endpoint /login
[erp-login]
enabled  = true
port     = http,https
logpath  = /home/nano/www/logs/erp-access.log
filter   = erp-login
maxretry = 5
bantime  = 3600
FAIL2BAN

# Filtro personalizado para el login del ERP
mkdir -p /etc/fail2ban/filter.d/
cat > /etc/fail2ban/filter.d/erp-login.conf <<'F2BFILTER'
[Definition]
# Detectar intentos de login fallidos al ERP
# Busca peticiones POST a /login con respuesta HTTP 4xx
failregex = ^<HOST> .* "POST /login.*" (401|403|429) .*$
            ^<HOST> .* "POST /login.*" 200 .* "credenciales incorrectas"
ignoreregex =
F2BFILTER

systemctl enable fail2ban 2>/dev/null | true
systemctl restart fail2ban
ok "Fail2Ban configurado y activo"

# ════════════════════════════════════════════════════════════════════════════
#  HARDENING ADICIONAL DEL SISTEMA
# ════════════════════════════════════════════════════════════════════════════
info "Aplicando hardening del sistema..."

# ── Hardening SSH (solo si no rompe la conexión actual) ──────────────────────
SSH_CONFIG="/etc/ssh/sshd_config"
if [[ -f "$SSH_CONFIG" ]]; then
    # Solo modificar parámetros no comentados
    sed -i 's/^#PermitRootLogin yes/PermitRootLogin prohibit-password/' "$SSH_CONFIG"
    sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/'  "$SSH_CONFIG"
    sed -i 's/^#MaxAuthTries 6/MaxAuthTries 4/'  "$SSH_CONFIG"
    sed -i 's/^MaxAuthTries .*/MaxAuthTries 4/'  "$SSH_CONFIG"
    sed -i 's/^#ClientAliveInterval .*/ClientAliveInterval 300/' "$SSH_CONFIG"
    sed -i 's/^ClientAliveInterval .*/ClientAliveInterval 300/'  "$SSH_CONFIG"

    # Verificar sintaxis antes de recargar
    if sshd -t 2>/dev/null; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
        ok "SSH hardening aplicado"
    else
        warn "Error en configuración SSH — no se aplicó hardening"
    fi
fi

# ── Parámetros del kernel (sysctl) ────────────────────────────────────────────
cat > /etc/sysctl.d/99-erp-fincas.conf <<'SYSCTL'
# ERP Fincas - Hardening del kernel

# Protección IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Desactivar ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Desactivar source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Protección SYN flood
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048

# Ignorar broadcast ping
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Log de paquetes sospechosos
net.ipv4.conf.all.log_martians = 1

# Deshabilitar IPv6 si no se usa (comentar si usas IPv6)
# net.ipv6.conf.all.disable_ipv6 = 1
SYSCTL

sysctl -p /etc/sysctl.d/99-erp-fincas.conf 2>&1 | grep -v "^net\." | sed 's/^/    /' || true
ok "Parámetros del kernel aplicados"

# ── Permisos de archivos sensibles ────────────────────────────────────────────
chmod 640 /etc/mysql/conf.d/erp-fincas.cnf 2>/dev/null || true
chmod 600 /root/.erp-fincas-db-credentials 2>/dev/null || true

echo ""
ok "PASO 06 completado — Sistema asegurado"
echo ""
echo "    UFW:       activo — 22(ssh), 80(http), 443(https)"
echo "    Fail2Ban:  activo — SSH(3 intentos/2h), Apache, ERP login"
echo "    Kernel:    hardening SYN flood, IP spoofing, source routing"

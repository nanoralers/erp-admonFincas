#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 01 — Sistema base, herramientas y dependencias
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

# ── Evitar prompts interactivos de apt ───────────────────────────────────────
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

info "Actualizando lista de paquetes..."
apt-get update -qq 2>&1 | tail -1
ok "Lista de paquetes actualizada"

info "Actualizando paquetes del sistema..."
apt-get upgrade -y -qq 2>&1 | tail -1
ok "Sistema actualizado"

# ── Paquetes base esenciales ─────────────────────────────────────────────────
info "Instalando paquetes base..."

BASE_PACKAGES=(
    # Herramientas de sistema
    curl
    wget
    git
    unzip
    zip
    htop
    nano
    vim
    tree
    lsof
    net-tools
    dnsutils          # dig, nslookup
    bind9-utils       # herramientas DNS adicionales

    # Compilación (necesario para algunos módulos pip/certbot)
    build-essential
    libssl-dev
    libffi-dev
    python3
    python3-pip
    python3-venv
    python3-dev
    python3-full

    # SSL/TLS
    ca-certificates
    openssl

    # Otras utilidades
    logrotate
    cron
    rsync
    software-properties-common
    apt-transport-https
    gnupg
    lsb-release
    acl                # Control de acceso a archivos
    sudo
)

apt-get install -y -qq "${BASE_PACKAGES[@]}" 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
ok "Paquetes base instalados"

# ── Configurar zona horaria ──────────────────────────────────────────────────
info "Configurando zona horaria: Europe/Madrid..."
timedatectl set-timezone Europe/Madrid 2>/dev/null || ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
ok "Zona horaria: $(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)"

# ── Configurar locale ────────────────────────────────────────────────────────
info "Configurando locale es_ES.UTF-8..."
if ! locale -a 2>/dev/null | grep -q "es_ES.utf8"; then
    sed -i 's/# es_ES.UTF-8/es_ES.UTF-8/' /etc/locale.gen 2>/dev/null || true
    locale-gen es_ES.UTF-8 2>/dev/null | tail -1 || true
fi
update-locale LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8 2>/dev/null || true
ok "Locale configurado"

# ── Configurar hostname ──────────────────────────────────────────────────────
info "Configurando hostname..."
CURRENT_HOSTNAME=$(hostname)
if [[ "$CURRENT_HOSTNAME" != "nanoserver" ]]; then
    hostnamectl set-hostname nanoserver 2>/dev/null || echo "nanoserver" > /etc/hostname
    ok "Hostname establecido: nanoserver"
else
    ok "Hostname ya es correcto: $CURRENT_HOSTNAME"
fi

# ── Crear usuario del proyecto ───────────────────────────────────────────────
info "Verificando usuario 'nano'..."
if ! id "nano" &>/dev/null; then
    useradd -m -s /bin/bash -G www-data nano
    ok "Usuario 'nano' creado"
else
    # Asegurar que está en el grupo www-data
    usermod -aG www-data nano 2>/dev/null || true
    ok "Usuario 'nano' ya existe — verificado en grupo www-data"
fi

# ── Crear estructura de directorios base ────────────────────────────────────
info "Creando estructura de directorios..."
mkdir -p /home/nano/www/{html,erp-fincas,logs}
mkdir -p /home/nano/www/erp-fincas/{config,core,controllers,views,public/{css,js,img},routes,install,uploads/{logos,docs,avatars},cache,logs,modules,api}

chown -R nano:www-data /home/nano/www/
chmod -R 755 /home/nano/www/
chmod -R 775 /home/nano/www/erp-fincas/uploads/
chmod -R 775 /home/nano/www/erp-fincas/cache/
chmod -R 775 /home/nano/www/logs/

# Página de prueba básica
cat > /home/nano/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><title>nanoserver.es</title>
<style>body{font-family:sans-serif;display:grid;place-items:center;height:100vh;background:#0f172a;color:#fff;margin:0;}
h1{font-size:2rem;}p{color:#94a3b8;}</style></head>
<body><div><h1>🟢 nanoserver.es</h1><p>Servidor operativo</p></div></body>
</html>
HTML
chown nano:www-data /home/nano/www/html/index.html
ok "Estructura de directorios creada"

# ── Configurar logrotate para los logs del ERP ───────────────────────────────
cat > /etc/logrotate.d/erp-fincas <<'LOGROTATE'
/home/nano/www/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}
LOGROTATE
ok "Logrotate configurado"

echo ""
ok "PASO 01 completado — Sistema base listo"

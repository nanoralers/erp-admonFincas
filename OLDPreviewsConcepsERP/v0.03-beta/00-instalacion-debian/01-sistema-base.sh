#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 01 — Sistema base
#  - Actualización del sistema (apt 3.0 en Debian 13)
#  - Activar trixie-backports (necesario para phpMyAdmin 5.2.3)
#  - Herramientas esenciales
#  - Usuario nano, directorios, logrotate
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

# ── APT 3.0 en Debian 13: usar apt-get en scripts (interfaz estable) ─────────
# (apt 3.0 muestra "CLI interface unstable" como aviso — ignorar en scripts)

# ── Activar trixie-backports ─────────────────────────────────────────────────
info "Activando trixie-backports..."
# Debian 13 usa deb822 format (.sources) para los repositorios
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
    # Verificar si backports ya está configurado
    if ! grep -q "trixie-backports" /etc/apt/sources.list.d/debian.sources 2>/dev/null \
       && ! ls /etc/apt/sources.list.d/*backports* 2>/dev/null | head -1 | grep -q .; then
        cat >> /etc/apt/sources.list.d/debian.sources <<'BACKPORTS'

Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
BACKPORTS
        ok "trixie-backports añadido (deb822 format)"
    else
        ok "trixie-backports ya estaba configurado"
    fi
else
    # Fallback: formato clásico sources.list
    if ! grep -q "trixie-backports" /etc/apt/sources.list 2>/dev/null; then
        echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free" \
            >> /etc/apt/sources.list
        ok "trixie-backports añadido (sources.list clásico)"
    else
        ok "trixie-backports ya estaba configurado"
    fi
fi

# ── Actualización del sistema ────────────────────────────────────────────────
info "Actualizando lista de paquetes (apt-get update)..."
# En Debian 13 con apt 3.0, usamos apt-get para output estable en scripts
apt-get update -qq 2>&1 | tail -1
ok "Lista de paquetes actualizada"

info "Actualizando paquetes del sistema..."
apt-get -y -qq upgrade 2>&1 | tail -1
ok "Sistema actualizado"

# ── Paquetes base ────────────────────────────────────────────────────────────
info "Instalando herramientas base..."

# Nota: en Debian 13 los nombres de algunos paquetes t64 han cambiado
# Se usan los nombres estándar modernos
BASE_PACKAGES=(
    # Red y DNS
    curl
    wget
    dnsutils          # dig, nslookup
    net-tools         # ifconfig, netstat

    # Compresión
    unzip
    zip

    # Editores y herramientas de sistema
    nano
    vim
    htop
    lsof
    tree
    rsync

    # Seguridad y certificados
    ca-certificates
    openssl
    gnupg

    # Python (necesario para certbot)
    python3
    python3-pip
    python3-venv
    python3-full

    # Compilación (certbot y algunos módulos)
    build-essential
    libssl-dev
    libffi-dev

    # Utilidades APT
    software-properties-common
    apt-transport-https
    lsb-release

    # Control acceso archivos (setfacl)
    acl

    # Programador de tareas
    cron

    # Rotación de logs
    logrotate
)

apt-get install -y -qq "${BASE_PACKAGES[@]}" 2>&1 \
    | grep -E "^(Inst|Conf)" | sed 's/^/    /' | head -20 || true
ok "Herramientas base instaladas"

# ── Zona horaria ─────────────────────────────────────────────────────────────
info "Configurando zona horaria Europe/Madrid..."
timedatectl set-timezone Europe/Madrid 2>/dev/null \
    || ln -sf /usr/share/zoneinfo/Europe/Madrid /etc/localtime
ok "Zona horaria: $(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)"

# ── Locale ───────────────────────────────────────────────────────────────────
info "Configurando locale es_ES.UTF-8..."
if ! locale -a 2>/dev/null | grep -q "es_ES.utf8"; then
    sed -i 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null \
        || echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen es_ES.UTF-8 2>/dev/null | tail -1 || true
fi
update-locale LANG=es_ES.UTF-8 LC_ALL=es_ES.UTF-8 2>/dev/null || true
ok "Locale configurado"

# ── Hostname ──────────────────────────────────────────────────────────────────
info "Configurando hostname..."
CURRENT_HN=$(hostname 2>/dev/null)
if [[ "$CURRENT_HN" != "nanoserver" ]]; then
    hostnamectl set-hostname nanoserver 2>/dev/null \
        || echo "nanoserver" > /etc/hostname
    ok "Hostname → nanoserver"
else
    ok "Hostname ya correcto: $CURRENT_HN"
fi

# ── Usuario nano ──────────────────────────────────────────────────────────────
info "Verificando usuario 'nano'..."
if ! id "nano" &>/dev/null; then
    useradd -m -s /bin/bash -G www-data nano
    ok "Usuario 'nano' creado y añadido a www-data"
else
    usermod -aG www-data nano 2>/dev/null || true
    ok "Usuario 'nano' ya existe — verificado en grupo www-data"
fi

# ── Estructura de directorios ─────────────────────────────────────────────────
info "Creando estructura de directorios..."
mkdir -p /home/nano/www/{html,logs}
mkdir -p /home/nano/www/erp-fincas/{config,core,controllers/{Economica,Mantenimiento,Juridica,Administrativa},api,views/{layouts,dashboard,errors,auth},public/{css,js,img},routes,install,uploads/{logos,docs,avatars},cache,logs,modules}

# Permisos base
chown -R nano:www-data /home/nano/www/
find /home/nano/www -type d -exec chmod 755 {} \;
find /home/nano/www -type f -exec chmod 644 {} \; 2>/dev/null || true

# Directorios escribibles por Apache/PHP
chmod 775 /home/nano/www/logs/
chmod -R 775 /home/nano/www/erp-fincas/uploads/
chmod -R 775 /home/nano/www/erp-fincas/cache/
chmod -R 775 /home/nano/www/erp-fincas/logs/

# Traversal para www-data
chmod o+x /home/nano
chmod o+x /home/nano/www

# Página de prueba básica
cat > /home/nano/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>nanoserver.es — Operativo</title>
  <style>
    *{margin:0;padding:0;box-sizing:border-box;}
    body{font-family:'Segoe UI',sans-serif;background:#0f172a;
         color:#fff;display:grid;place-items:center;height:100vh;}
    .box{text-align:center;padding:2rem;}
    h1{font-size:2.5rem;font-weight:700;margin-bottom:.5rem;}
    span{color:#38bdf8;}
    p{color:#64748b;margin-top:.5rem;}
  </style>
</head>
<body>
  <div class="box">
    <h1>🟢 <span>nanoserver.es</span></h1>
    <p>ERP Fincas · Servidor operativo · Debian 13 Trixie</p>
  </div>
</body>
</html>
HTML
chown nano:www-data /home/nano/www/html/index.html
ok "Estructura de directorios creada"

# ── Logrotate ─────────────────────────────────────────────────────────────────
info "Configurando logrotate para ERP Fincas..."
cat > /etc/logrotate.d/erp-fincas <<'LOGROTATE'
/home/nano/www/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    create 664 nano www-data
    postrotate
        systemctl reload apache2 > /dev/null 2>&1 || true
    endscript
}
LOGROTATE
ok "Logrotate configurado (30 días, compresión)"

echo ""
ok "PASO 01 completado"
echo ""
echo "    Debian:    $(cat /etc/debian_version)"
echo "    Kernel:    $(uname -r)"
echo "    Backports: trixie-backports activado"

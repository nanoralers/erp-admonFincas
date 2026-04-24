#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 03 — Módulos Apache + configuración completa
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Detectar versión PHP instalada ────────────────────────────────────────────
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3")

# ── Instalar paquetes Apache adicionales ─────────────────────────────────────
info "Instalando paquetes Apache adicionales..."
apt-get install -y -qq \
    apache2 \
    apache2-utils \
    ssl-cert 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
ok "Paquetes Apache instalados"

# ── Activar módulos necesarios ────────────────────────────────────────────────
info "Activando módulos Apache..."

MODULES_ENABLE=(
    rewrite          # URL rewriting (imprescindible para el ERP)
    headers          # Security headers (X-Frame-Options, etc.)
    expires          # Cache de assets estáticos
    deflate          # Compresión GZIP
    ssl              # HTTPS
    socache_shmcb    # Cache para SSL sessions
    "php${PHP_VER}"  # mod_php
    mime             # Tipos MIME
    dir              # DirectoryIndex
    alias            # Alias de rutas
    env              # SetEnv en VirtualHost
    setenvif         # Condiciones de entorno
    authz_host       # Require all / Require ip
    autoindex        # Listado directorios (lo activamos para poder desactivarlo)
)

for MOD in "${MODULES_ENABLE[@]}"; do
    if a2enmod "$MOD" 2>&1 | grep -q "already enabled\|Enabling module"; then
        ok "  mod_${MOD}"
    else
        warn "  mod_${MOD} — no disponible (puede ser normal)"
    fi
done

# ── Desactivar módulos innecesarios/inseguros ─────────────────────────────────
info "Desactivando módulos inseguros..."
MODULES_DISABLE=(autoindex status)
for MOD in "${MODULES_DISABLE[@]}"; do
    a2dismod "$MOD" 2>/dev/null && ok "  mod_${MOD} desactivado" || true
done

# ── Configuración global de seguridad Apache ─────────────────────────────────
info "Aplicando configuración de seguridad global..."
cat > /etc/apache2/conf-available/seguridad.conf <<'APACHECONF'
# ── Ocultar versión del servidor ──────────────────────────────────────────────
ServerTokens Prod
ServerSignature Off

# ── Deshabilitar TRACE (evita XST attacks) ───────────────────────────────────
TraceEnable Off

# ── Timeout y keepalive ───────────────────────────────────────────────────────
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# ── Limitar métodos HTTP ──────────────────────────────────────────────────────
<LimitExcept GET POST PUT DELETE HEAD OPTIONS>
    Require all denied
</LimitExcept>

# ── Headers de seguridad globales ─────────────────────────────────────────────
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options  "nosniff"
    Header always set X-Frame-Options         "SAMEORIGIN"
    Header always set X-XSS-Protection        "1; mode=block"
    Header always set Referrer-Policy         "strict-origin-when-cross-origin"
    Header always set Permissions-Policy      "geolocation=(), microphone=(), camera=()"
    Header unset X-Powered-By
    Header always unset X-Powered-By
</IfModule>

# ── Deshabilitar acceso a archivos ocultos y sensibles ────────────────────────
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
<FilesMatch "(\.env|composer\.(json|lock)|package\.json|\.git)$">
    Require all denied
</FilesMatch>

# ── Deshabilitar browsing de directorios globalmente ─────────────────────────
<Directory />
    Options None
    AllowOverride None
    Require all denied
</Directory>
APACHECONF

a2enconf seguridad 2>/dev/null | grep -q "already enabled\|Enabling" && ok "Configuración de seguridad activada"

# ── Instalar VirtualHost del ERP ──────────────────────────────────────────────
info "Instalando VirtualHost ERP Fincas..."

# Copiar el conf adaptado desde el paquete
VHOST_SRC="$SCRIPT_DIR/../01-servidor-apache/nanoserver_es.conf"
if [[ -f "$VHOST_SRC" ]]; then
    cp "$VHOST_SRC" /etc/apache2/sites-available/nanoserver_es.conf
    ok "nanoserver_es.conf copiado"
else
    warn "nanoserver_es.conf no encontrado — generando configuración básica..."
    # Generar conf básica si no existe el fichero del paquete
    cat > /etc/apache2/sites-available/nanoserver_es.conf <<'BASICVHOST'
# Configuración básica — reemplazar por nanoserver_es.conf del paquete
<VirtualHost *:80>
    ServerName  nanoserver.es
    ServerAlias www.nanoserver.es *.nanoserver.es
    DocumentRoot /home/nano/www/html
    ErrorLog  /home/nano/www/logs/error.log
    CustomLog /home/nano/www/logs/access.log combined
    RewriteEngine on
    RewriteCond %{SERVER_NAME} ^.*\.nanoserver\.es$ [OR]
    RewriteCond %{SERVER_NAME} =nanoserver.es
    RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
BASICVHOST
fi

# Deshabilitar sitio por defecto y habilitar el nuestro
a2dissite 000-default 2>/dev/null || true
a2ensite nanoserver_es.conf 2>/dev/null | grep -q "already enabled\|Enabling" && ok "VirtualHost habilitado"

# ── Configurar puerto 443 en ports.conf ──────────────────────────────────────
if ! grep -q "Listen 443" /etc/apache2/ports.conf; then
    echo "Listen 443" >> /etc/apache2/ports.conf
fi
ok "Puerto 443 configurado en ports.conf"

# ── Dar permisos a Apache sobre los directorios del ERP ──────────────────────
info "Configurando permisos para www-data..."
# /home necesita execute para que Apache pueda traversar
chmod o+x /home/nano 2>/dev/null || true
setfacl -m u:www-data:rx /home/nano 2>/dev/null || chmod 755 /home/nano
setfacl -m u:www-data:rx /home/nano/www 2>/dev/null || chmod 755 /home/nano/www
ok "Permisos de traversal configurados"

# ── Verificar sintaxis ────────────────────────────────────────────────────────
info "Verificando sintaxis de Apache..."
# En este punto el cert wildcard aún no existe, parcheamos temporalmente
# para que configtest no falle por el cert inexistente
if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    ok "Sintaxis Apache correcta"
else
    # El error más probable es el cert SSL inexistente — es esperado
    CONFIGTEST_OUT=$(apache2ctl configtest 2>&1)
    if echo "$CONFIGTEST_OUT" | grep -q "nanoserver.es-wildcard"; then
        warn "Error esperado: certificado wildcard aún no generado (se crea en el paso SSL)"
    else
        echo "$CONFIGTEST_OUT" | head -5 | sed 's/^/    /'
        warn "Revisar errores de Apache antes de continuar"
    fi
fi

# ── Reiniciar Apache ──────────────────────────────────────────────────────────
info "Reiniciando Apache..."
systemctl enable apache2 2>/dev/null | true
# Intentar reload, si falla por cert inexistente es normal
systemctl restart apache2 2>/dev/null && ok "Apache reiniciado" \
    || warn "Apache no pudo reiniciar (normal si el cert SSL no existe aún)"

echo ""
ok "PASO 03 completado — Apache configurado"
echo ""
echo "    Apache: $(apache2 -v 2>/dev/null | head -1 | awk '{print $3}')"
echo "    Módulos activos: $(apache2ctl -M 2>/dev/null | grep -c "_module")"

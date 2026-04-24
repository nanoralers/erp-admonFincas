#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 03 — Módulos Apache 2.4 y configuración
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHP_VER="8.4"

# ── Paquetes Apache adicionales ───────────────────────────────────────────────
info "Instalando paquetes Apache adicionales..."
apt-get install -y -qq \
    apache2 \
    apache2-utils \
    ssl-cert 2>&1 | grep -E "^(Inst|Conf)" | sed 's/^/    /' | head -5 || true
ok "Paquetes Apache verificados"

# ── Activar módulos necesarios ────────────────────────────────────────────────
info "Activando módulos Apache..."
MODS_ON=(
    rewrite          # URL rewriting — imprescindible para el ERP
    headers          # Security headers (X-Frame, HSTS, etc.)
    expires          # Cache de assets estáticos
    deflate          # Compresión GZIP de respuestas
    ssl              # HTTPS / TLS
    socache_shmcb    # Cache compartida (sesiones SSL)
    "php${PHP_VER}"  # mod_php — procesar PHP
    mime             # Tipos MIME
    dir              # DirectoryIndex
    alias            # Rutas con alias
    env              # SetEnv en VirtualHost
    setenvif         # Condiciones de entorno
)

for MOD in "${MODS_ON[@]}"; do
    OUT=$(a2enmod "$MOD" 2>&1)
    if echo "$OUT" | grep -qE "Enabling module|already enabled"; then
        ok "    mod_${MOD}"
    else
        warn "    mod_${MOD} — $OUT"
    fi
done

# ── Desactivar módulos innecesarios y peligrosos ──────────────────────────────
info "Desactivando módulos innecesarios..."
for MOD in autoindex status info; do
    a2dismod "$MOD" 2>/dev/null && ok "    mod_${MOD} desactivado" || true
done

# ── Configuración global de seguridad ────────────────────────────────────────
info "Aplicando hardening global de Apache..."
cat > /etc/apache2/conf-available/seguridad-erp.conf <<'SECCONF'
# ════════════════════════════════════════════════════════
#  Hardening global Apache — ERP Fincas nanoserver.es
# ════════════════════════════════════════════════════════

# Ocultar versión del servidor
ServerTokens Prod
ServerSignature Off

# Deshabilitar TRACE (Cross-Site Tracing)
TraceEnable Off

# Timeouts y keep-alive
Timeout 60
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5

# Limitar tamaño de peticiones (protección DoS básica)
LimitRequestBody 20971520

# Headers de seguridad globales
<IfModule mod_headers.c>
    Header always set X-Content-Type-Options  "nosniff"
    Header always set X-Frame-Options         "SAMEORIGIN"
    Header always set X-XSS-Protection        "1; mode=block"
    Header always set Referrer-Policy         "strict-origin-when-cross-origin"
    Header always set Permissions-Policy      "geolocation=(), microphone=(), camera=()"
    Header unset  X-Powered-By
    Header always unset X-Powered-By
</IfModule>

# Denegar acceso a archivos ocultos y sensibles
<FilesMatch "^\.">
    Require all denied
</FilesMatch>
<FilesMatch "(\.env|composer\.(json|lock)|\.git|package\.json|README\.md)$">
    Require all denied
</FilesMatch>

# Deshabilitar listado de directorios globalmente
<Directory />
    Options None
    AllowOverride None
    Require all denied
</Directory>
SECCONF

a2enconf seguridad-erp 2>/dev/null && ok "Configuración de seguridad activada" || warn "ya activa"

# ── Configurar ports.conf ────────────────────────────────────────────────────
info "Verificando ports.conf..."
grep -q "^Listen 443" /etc/apache2/ports.conf \
    || echo "Listen 443" >> /etc/apache2/ports.conf
ok "Puertos 80 y 443 configurados"

# ── Instalar VirtualHosts ─────────────────────────────────────────────────────
info "Instalando VirtualHosts..."

# VirtualHost principal del ERP
VHOST_ERP="$SCRIPT_DIR/../01-servidor-apache/nanoserver_es.conf"
if [[ -f "$VHOST_ERP" ]]; then
    cp "$VHOST_ERP" /etc/apache2/sites-available/nanoserver_es.conf
    ok "nanoserver_es.conf instalado"
else
    warn "nanoserver_es.conf no encontrado — se instalará en paso de despliegue"
fi

# VirtualHost phpMyAdmin
VHOST_PMA="$SCRIPT_DIR/../04-vhosts-apache/phpmyadmin.nanoserver.es.conf"
if [[ -f "$VHOST_PMA" ]]; then
    cp "$VHOST_PMA" /etc/apache2/sites-available/phpmyadmin.nanoserver.es.conf
    ok "phpmyadmin.nanoserver.es.conf instalado"
else
    warn "phpmyadmin.nanoserver.es.conf no encontrado — se instalará en paso phpMyAdmin"
fi

# Deshabilitar el sitio por defecto y habilitar los nuestros
a2dissite 000-default 2>/dev/null || true
a2dissite default-ssl 2>/dev/null || true

[[ -f "/etc/apache2/sites-available/nanoserver_es.conf" ]] \
    && a2ensite nanoserver_es.conf 2>/dev/null | grep -q "already enabled\|Enabling" \
    && ok "nanoserver_es.conf habilitado"

ok "Configuración Apache completada"

# ── Permisos de traversal ────────────────────────────────────────────────────
info "Configurando permisos de traversal para www-data..."
if command -v setfacl &>/dev/null; then
    setfacl -m u:www-data:rx /home/nano       2>/dev/null || chmod o+x /home/nano
    setfacl -m u:www-data:rx /home/nano/www   2>/dev/null || chmod o+x /home/nano/www
    ok "ACL de traversal configurado"
else
    chmod o+x /home/nano
    chmod o+x /home/nano/www
    ok "Permisos chmod o+x aplicados"
fi

# ── Verificar sintaxis (puede fallar si el cert wildcard aún no existe) ───────
info "Verificando sintaxis de Apache..."
CONFIGTEST=$(apache2ctl configtest 2>&1)
if echo "$CONFIGTEST" | grep -q "Syntax OK"; then
    ok "Sintaxis Apache correcta"
else
    if echo "$CONFIGTEST" | grep -q "nanoserver.es-wildcard\|does not exist\|cannot open"; then
        warn "Error esperado: certificado wildcard aún no generado — se crea en paso 07"
    else
        echo "$CONFIGTEST" | head -3 | sed 's/^/    /'
        warn "Verificar la configuración manualmente: apache2ctl configtest"
    fi
fi

# ── Iniciar Apache ────────────────────────────────────────────────────────────
info "Habilitando y reiniciando Apache..."
systemctl enable apache2 2>/dev/null || true
systemctl restart apache2 2>/dev/null && ok "Apache iniciado" \
    || warn "Apache no pudo iniciar (normal si falta el cert SSL — se resuelve en paso 07)"

echo ""
ok "PASO 03 completado"
echo ""
echo "    Apache: $(apache2 -v 2>/dev/null | head -1 | awk '{print $3}')"
echo "    Módulos activos: $(apache2ctl -M 2>/dev/null | grep -c "_module") módulos"

#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 09 — phpMyAdmin 5.2.3 (trixie-backports)
#  Accesible en: https://phpmyadmin.nanoserver.es
#
#  Método de instalación: apt (paquete oficial Debian)
#  Versión: 5.2.2 en trixie estable / 5.2.3 en trixie-backports
#  Ubicación tras instalación: /usr/share/phpmyadmin
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VHOST_SRC="$SCRIPT_DIR/../04-vhosts-apache/phpmyadmin.nanoserver.es.conf"
CREDS_FILE="/root/.erp-fincas-db-credentials"
PMA_DIR="/usr/share/phpmyadmin"
PMA_CONFIG="/etc/phpmyadmin"

# ── Leer contraseña de MariaDB ────────────────────────────────────────────────
DB_ROOT_PASS=""
DB_USER_PASS=""
if [[ -f "$CREDS_FILE" ]]; then
    DB_ROOT_PASS=$(grep "^DB_ROOT_PASS=" "$CREDS_FILE" | cut -d= -f2- || true)
    DB_USER_PASS=$(grep "^DB_PASS="      "$CREDS_FILE" | cut -d= -f2- || true)
fi

# ── Pre-selección para el instalador dbconfig-common de phpMyAdmin ────────────
# Esto evita el diálogo interactivo del instalador apt
info "Pre-configurando instalador no interactivo..."

# phpMyAdmin se instala con dbconfig-common que pide configuración de BD
# Usamos debconf-set-selections para evitar los prompts
debconf-set-selections <<DEBCONF
phpmyadmin  phpmyadmin/dbconfig-install          boolean  true
phpmyadmin  phpmyadmin/app-password-confirm       password ${DB_USER_PASS:-phpmyadmin}
phpmyadmin  phpmyadmin/mysql/app-pass             password ${DB_USER_PASS:-phpmyadmin}
phpmyadmin  phpmyadmin/reconfigure-webserver      multiselect apache2
phpmyadmin  phpmyadmin/mysql/admin-pass           password ${DB_ROOT_PASS}
phpmyadmin  phpmyadmin/internal/skip-preseed      boolean  false
DEBCONF
ok "Debconf pre-configurado"

# ── Instalar phpMyAdmin desde trixie-backports ────────────────────────────────
info "Instalando phpMyAdmin 5.2.3 desde trixie-backports..."

# Verificar versión disponible
PMA_BACKPORTS=$(apt-cache madison phpmyadmin 2>/dev/null \
    | grep "backports" | awk '{print $3}' | head -1)
PMA_STABLE=$(apt-cache madison phpmyadmin 2>/dev/null \
    | grep -v "backports" | awk '{print $3}' | head -1)

info "Versión estable:   ${PMA_STABLE:-no disponible}"
info "Versión backports: ${PMA_BACKPORTS:-no disponible}"

if [[ -n "$PMA_BACKPORTS" ]]; then
    # Instalar desde backports (versión más nueva)
    apt-get install -y -qq -t trixie-backports phpmyadmin \
        2>&1 | grep -E "^(Inst|Conf)" | head -10 | sed 's/^/    /' || true
    ok "phpMyAdmin instalado desde trixie-backports"
elif [[ -n "$PMA_STABLE" ]]; then
    # Fallback: versión estable
    apt-get install -y -qq phpmyadmin \
        2>&1 | grep -E "^(Inst|Conf)" | head -10 | sed 's/^/    /' || true
    ok "phpMyAdmin instalado desde trixie estable"
else
    warn "phpMyAdmin no encontrado en apt — verificar que trixie-backports está activo"
    warn "Intentando sin especificar repo..."
    apt-get update -qq && apt-get install -y -qq phpmyadmin \
        2>&1 | head -5 | sed 's/^/    /' || true
fi

# Verificar instalación
PMA_VERSION=$(dpkg -l phpmyadmin 2>/dev/null | grep "^ii" | awk '{print $3}')
[[ -n "$PMA_VERSION" ]] && ok "phpMyAdmin instalado: versión $PMA_VERSION" \
    || { warn "phpMyAdmin no se instaló correctamente"; exit 1; }

# ── Configuración personalizada de phpMyAdmin ─────────────────────────────────
info "Configurando phpMyAdmin..."

# Generar blowfish_secret (clave de 32 chars para cookies cifradas)
BLOWFISH=$(php -r "echo bin2hex(random_bytes(16));" 2>/dev/null \
    || openssl rand -hex 16)

# Directorio para archivos temporales de phpMyAdmin
mkdir -p /var/lib/phpmyadmin/tmp
chown -R www-data:www-data /var/lib/phpmyadmin/
chmod 755 /var/lib/phpmyadmin/
chmod 777 /var/lib/phpmyadmin/tmp/

# Configuración personalizada (no tocar config.inc.php principal)
mkdir -p "$PMA_CONFIG/conf.d"

cat > "$PMA_CONFIG/conf.d/erp-fincas.php" <<PMACONF
<?php
/**
 * phpMyAdmin — Configuración personalizada para nanoserver.es
 * No modificar config.inc.php directamente — usar este archivo
 */

\$i = 1;

// ── Seguridad ────────────────────────────────────────────────────────────────
// Clave de cifrado para cookies (generada aleatoriamente durante la instalación)
\$cfg['blowfish_secret'] = '${BLOWFISH}';

// Controlar el acceso: solo usuarios de BD definidos
\$cfg['AllowArbitraryServer']   = false;
\$cfg['AllowUserDropDatabase']  = false;

// Sesiones
\$cfg['LoginCookieValidity']    = 1440;   // 24 minutos (estándar)
\$cfg['LoginCookieDeleteAll']   = true;

// Archivos temporales
\$cfg['TempDir']                = '/var/lib/phpmyadmin/tmp';
\$cfg['UploadDir']              = '';    // Desactivado por seguridad
\$cfg['SaveDir']                = '';    // Desactivado por seguridad

// ── UI y comportamiento ──────────────────────────────────────────────────────
\$cfg['DefaultLang']            = 'es';  // Idioma español
\$cfg['ServerDefault']          = 1;
\$cfg['ShowPhpInfo']            = false; // No mostrar info PHP

// ── Servidor MariaDB ─────────────────────────────────────────────────────────
\$cfg['Servers'][\$i]['host']           = '127.0.0.1';
\$cfg['Servers'][\$i]['port']           = '3306';
\$cfg['Servers'][\$i]['auth_type']      = 'cookie';  // Login por formulario
\$cfg['Servers'][\$i]['AllowRoot']      = false;     // No permitir login como root
\$cfg['Servers'][\$i]['compress']       = false;
\$cfg['Servers'][\$i]['AllowNoPassword']= false;     // Requerir siempre contraseña

// Configuración de almacenamiento phpMyAdmin (tabla de configuración)
\$cfg['Servers'][\$i]['controlhost']    = '127.0.0.1';
\$cfg['Servers'][\$i]['controlport']    = '';
\$cfg['Servers'][\$i]['controluser']    = 'pma';
\$cfg['Servers'][\$i]['controlpass']    = ''; // Se rellena si se crea el usuario pma
\$cfg['Servers'][\$i]['pmadb']          = 'phpmyadmin';
PMACONF

ok "Configuración phpMyAdmin creada"

# ── Instalar VirtualHost para phpmyadmin.nanoserver.es ───────────────────────
info "Instalando VirtualHost phpmyadmin.nanoserver.es..."
if [[ -f "$VHOST_SRC" ]]; then
    cp "$VHOST_SRC" /etc/apache2/sites-available/phpmyadmin.nanoserver.es.conf
    a2ensite phpmyadmin.nanoserver.es.conf 2>/dev/null \
        | grep -q "already enabled\|Enabling" && ok "VirtualHost phpMyAdmin habilitado"
else
    warn "VirtualHost src no encontrado: $VHOST_SRC"
    warn "Instalar manualmente desde 04-vhosts-apache/"
fi

# Asegurar que la conf de phpMyAdmin de Apache está habilitada
if [[ -f /etc/phpmyadmin/apache.conf ]]; then
    ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf 2>/dev/null || true
    a2enconf phpmyadmin 2>/dev/null || true
fi

# ── Recargar Apache ──────────────────────────────────────────────────────────
info "Recargando Apache..."
if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    systemctl reload apache2 && ok "Apache recargado"
else
    apache2ctl configtest 2>&1 | grep -v "^AH\|^$" | head -5 | sed 's/^/    /'
    warn "Error en configuración — verificar antes de continuar"
fi

# ── Verificación ──────────────────────────────────────────────────────────────
info "Verificando phpMyAdmin..."
if [[ -f "$PMA_DIR/index.php" ]]; then
    ok "phpMyAdmin instalado en: $PMA_DIR"
else
    warn "No encontrado en $PMA_DIR — verificar instalación"
fi

HTTP_PMA=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -H "Host: phpmyadmin.nanoserver.es" http://127.0.0.1/ 2>/dev/null || echo "000")
case "$HTTP_PMA" in
    200|301|302) ok "phpMyAdmin responde HTTP $HTTP_PMA" ;;
    000) warn "Sin respuesta — ¿Apache corriendo?" ;;
    *)   warn "HTTP $HTTP_PMA — puede necesitar SSL (normal en este punto)" ;;
esac

echo ""
ok "PASO 09 completado"
echo ""
echo "    phpMyAdmin: $PMA_VERSION"
echo "    URL (tras SSL): https://phpmyadmin.nanoserver.es"
echo "    Login: con usuario erp_user / tu contraseña de MariaDB"
echo "    Root NO permitido por configuración de seguridad"

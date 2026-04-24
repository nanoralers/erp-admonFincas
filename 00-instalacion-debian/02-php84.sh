#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 02 — PHP 8.4 + extensiones
#
#  Debian 13 Trixie incluye PHP 8.4 en sus repos oficiales.
#  NO se necesita el repositorio externo sury.org.
#  Versión disponible: 8.4.16-1~deb13u1 (confirmado abril 2026)
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

# ── Verificar disponibilidad de PHP 8.4 ──────────────────────────────────────
info "Verificando disponibilidad de PHP 8.4 en repos de Trixie..."
if apt-cache show php8.4 &>/dev/null 2>&1; then
    CANDIDATE=$(apt-cache policy php8.4 2>/dev/null | grep "Candidate:" | awk '{print $2}')
    ok "PHP 8.4 disponible — candidato: $CANDIDATE"
else
    warn "PHP 8.4 no encontrado en repos. Intentando apt-get update primero..."
    apt-get update -qq
    if apt-cache show php8.4 &>/dev/null 2>&1; then
        ok "PHP 8.4 disponible tras actualizar"
    else
        echo -e "${R}    ✗ PHP 8.4 no disponible.${NC}"
        echo    "    Verifica que estás en Debian 13 Trixie con repos correctos."
        echo    "    Comprueba: cat /etc/apt/sources.list.d/debian.sources"
        exit 1
    fi
fi

PHP_VER="8.4"

# ── Instalar PHP 8.4 y extensiones ───────────────────────────────────────────
info "Instalando PHP ${PHP_VER} y extensiones..."

# El metapaquete 'php' en Trixie apunta a 8.4
# Instalamos explícitamente php8.4 para garantizar la versión correcta
PHP_PACKAGES=(
    "php${PHP_VER}"                      # PHP core (metapaquete)
    "php${PHP_VER}-cli"                  # CLI (php en terminal)
    "libapache2-mod-php${PHP_VER}"       # mod_php para Apache
    # -- Base de datos --
    "php${PHP_VER}-mysql"                # PDO MySQL + MySQLi (MariaDB compatible)
    # -- Strings y encoding --
    "php${PHP_VER}-mbstring"             # Multibyte strings ← requerido ERP
    "php${PHP_VER}-iconv"                # Conversión de charset
    # -- XML y DOM --
    "php${PHP_VER}-xml"                  # XML/SimpleXML
    "php${PHP_VER}-dom"                  # DOM (HTML/XML generation)
    # -- Imágenes --
    "php${PHP_VER}-gd"                   # GD (logos, avatares, captchas)
    # -- Red --
    "php${PHP_VER}-curl"                 # cURL (llamadas HTTP, SMTP, APIs)
    # -- Archivos --
    "php${PHP_VER}-zip"                  # ZIP (exports, uploads)
    "php${PHP_VER}-fileinfo"             # Detección de tipo de archivo
    # -- Matemáticas --
    "php${PHP_VER}-bcmath"               # Precisión decimal (contabilidad)
    "php${PHP_VER}-intl"                 # Internacionalización (fechas ES)
    # -- Rendimiento --
    "php${PHP_VER}-opcache"              # Caché de bytecode
    # -- Seguridad --
    "php${PHP_VER}-sodium"               # Criptografía moderna (libsodium)
    # -- Otros requeridos por ERP / phpMyAdmin --
    "php${PHP_VER}-ctype"                # Validación de tipos de caracteres
    "php${PHP_VER}-tokenizer"            # Tokenizer de PHP
    "php${PHP_VER}-readline"             # Readline para CLI interactivo
    # -- Extra para phpMyAdmin --
    "php${PHP_VER}-bz2"                  # Compresión BZ2
)

apt-get install -y -qq "${PHP_PACKAGES[@]}" 2>&1 \
    | grep -E "^(Inst|Conf)" | sed 's/^/    /' | head -25 || true

ok "PHP ${PHP_VER} y extensiones instaladas"

# ── Verificar instalación ────────────────────────────────────────────────────
info "Verificando versión instalada..."
PHP_ACTUAL=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
[[ -n "$PHP_ACTUAL" ]] && ok "php --version: $PHP_ACTUAL" \
    || warn "No se pudo verificar la versión de PHP"

info "Verificando extensiones críticas..."
REQUIRED_EXT=(pdo pdo_mysql mbstring json openssl curl gd zip intl bcmath opcache)
for EXT in "${REQUIRED_EXT[@]}"; do
    if php -m 2>/dev/null | grep -qi "^${EXT}$"; then
        ok "    ext-${EXT}"
    else
        warn "    ext-${EXT} no detectada (puede ser built-in)"
    fi
done

# ── Configurar php.ini para producción ───────────────────────────────────────
info "Configurando php.ini para producción..."

PHP_INI_APACHE="/etc/php/${PHP_VER}/apache2/php.ini"
PHP_INI_CLI="/etc/php/${PHP_VER}/cli/php.ini"

tune_php_ini() {
    local FILE="$1"
    [[ ! -f "$FILE" ]] && warn "No encontrado: $FILE" && return

    # Seguridad
    sed -i 's/^expose_php *= *On/expose_php = Off/'                     "$FILE"
    sed -i 's/^display_errors *= *On/display_errors = Off/'             "$FILE"
    sed -i 's/^display_startup_errors *= *On/display_startup_errors = Off/' "$FILE"
    sed -i 's/^log_errors *= *Off/log_errors = On/'                     "$FILE"

    # Rendimiento
    sed -i 's/^memory_limit *= *.*/memory_limit = 256M/'                "$FILE"
    sed -i 's/^max_execution_time *= *.*/max_execution_time = 60/'       "$FILE"
    sed -i 's/^max_input_time *= *.*/max_input_time = 60/'               "$FILE"
    sed -i 's/^;*max_input_vars *= *.*/max_input_vars = 3000/'           "$FILE"

    # Uploads
    sed -i 's/^upload_max_filesize *= *.*/upload_max_filesize = 20M/'   "$FILE"
    sed -i 's/^post_max_size *= *.*/post_max_size = 20M/'               "$FILE"

    # Charset
    sed -i 's/^;*default_charset *= *.*/default_charset = "UTF-8"/'    "$FILE"

    # Timezone
    sed -i 's|^;*date\.timezone *= *.*|date.timezone = "Europe/Madrid"|' "$FILE"

    # Sesiones (para ERP)
    sed -i 's/^;*session\.cookie_httponly *= *.*/session.cookie_httponly = 1/' "$FILE"
    sed -i 's/^;*session\.cookie_secure *= *.*/session.cookie_secure = 1/'    "$FILE"
    sed -i 's/^;*session\.use_strict_mode *= *.*/session.use_strict_mode = 1/' "$FILE"
    sed -i 's|^;*session\.save_path *= *.*|session.save_path = "/tmp"|'        "$FILE"

    # Error log
    sed -i "s|^;*error_log *= *.*|error_log = /home/nano/www/logs/erp-php-errors.log|" "$FILE"
}

tune_php_ini "$PHP_INI_APACHE"
tune_php_ini "$PHP_INI_CLI"
ok "php.ini configurado"

# ── OPcache ──────────────────────────────────────────────────────────────────
info "Configurando OPcache..."
OPCACHE_CONF="/etc/php/${PHP_VER}/apache2/conf.d/99-opcache-erp.ini"
cat > "$OPCACHE_CONF" <<'OPCACHE'
; OPcache optimizado para ERP Fincas — PHP 8.4
opcache.enable = 1
opcache.enable_cli = 0
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 16
opcache.max_accelerated_files = 4000
opcache.revalidate_freq = 60
opcache.fast_shutdown = 1
opcache.save_comments = 1
; PHP 8.4: JIT habilitado (experimental, desactivar si hay problemas)
; opcache.jit = tracing
; opcache.jit_buffer_size = 64M
OPCACHE
ok "OPcache configurado (128MB RAM, 4000 archivos)"

echo ""
ok "PASO 02 completado"
echo ""
echo "    PHP versión:    $(php -r 'echo PHP_VERSION;' 2>/dev/null)"
echo "    Módulos PHP:    $(php -m 2>/dev/null | wc -l) extensiones cargadas"
echo "    php.ini Apache: $PHP_INI_APACHE"

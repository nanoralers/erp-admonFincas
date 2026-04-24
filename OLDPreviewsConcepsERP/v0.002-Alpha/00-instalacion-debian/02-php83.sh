#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 02 — PHP 8.3 + todas las extensiones necesarias
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

# ── Detectar versión PHP disponible en Debian 13 ─────────────────────────────
info "Detectando versión de PHP disponible..."

# Debian 13 Trixie incluye PHP 8.3 en sus repos oficiales
# Primero intentamos repos oficiales, si no está disponible usamos sury.org
PHP_VER=""
for V in 8.3 8.2; do
    if apt-cache show "php${V}" &>/dev/null 2>&1; then
        PHP_VER="$V"
        break
    fi
done

if [[ -z "$PHP_VER" ]]; then
    warn "PHP no encontrado en repos oficiales. Añadiendo repositorio sury.org..."
    curl -sSLo /tmp/apt.gpg.key https://packages.sury.org/php/apt.gpg
    install -D -o root -g root -m 644 /tmp/apt.gpg.key /etc/apt/keyrings/sury-php.gpg
    echo "deb [signed-by=/etc/apt/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/sury-php.list
    apt-get update -qq
    PHP_VER="8.3"
fi

ok "PHP $PHP_VER disponible"

# ── Instalar PHP y extensiones ────────────────────────────────────────────────
info "Instalando PHP ${PHP_VER} + extensiones..."

PHP_PACKAGES=(
    "php${PHP_VER}"                        # PHP core
    "php${PHP_VER}-cli"                    # CLI
    "libapache2-mod-php${PHP_VER}"         # Módulo Apache (mod_php)
    "php${PHP_VER}-mysql"                  # PDO MySQL + MySQLi
    "php${PHP_VER}-mbstring"               # Multibyte strings (requerido ERP)
    "php${PHP_VER}-xml"                    # XML / SimpleXML
    "php${PHP_VER}-curl"                   # cURL (HTTP requests)
    "php${PHP_VER}-zip"                    # ZIP (uploads, exports)
    "php${PHP_VER}-gd"                     # Imágenes (logos, avatares)
    "php${PHP_VER}-intl"                   # Internacionalización (fechas ES)
    "php${PHP_VER}-bcmath"                 # Matemáticas precisas (contabilidad)
    "php${PHP_VER}-opcache"                # OPcache (rendimiento)
    "php${PHP_VER}-json"                   # JSON (API interna)
    "php${PHP_VER}-ctype"                  # Validación de tipos
    "php${PHP_VER}-fileinfo"               # Detección tipos de archivo
    "php${PHP_VER}-tokenizer"              # Tokenizer
    "php${PHP_VER}-dom"                    # DOM (generación HTML/PDF)
    "php${PHP_VER}-iconv"                  # Conversión de charset
    "php${PHP_VER}-sodium"                 # Criptografía moderna
    "php${PHP_VER}-readline"               # Readline (CLI interactivo)
)

apt-get install -y -qq "${PHP_PACKAGES[@]}" 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
ok "PHP ${PHP_VER} y extensiones instaladas"

# ── Verificar extensiones ─────────────────────────────────────────────────────
info "Verificando extensiones instaladas..."
REQUIRED_EXT=(pdo pdo_mysql mbstring json openssl curl zip gd intl bcmath opcache)
MISSING=()
for EXT in "${REQUIRED_EXT[@]}"; do
    if php -m 2>/dev/null | grep -qi "^${EXT}$"; then
        ok "  ext-${EXT}"
    else
        warn "  ext-${EXT} — no detectada (puede estar integrada)"
        MISSING+=("$EXT")
    fi
done
[[ ${#MISSING[@]} -gt 0 ]] && warn "Extensiones no detectadas: ${MISSING[*]} (puede ser normal para extensiones integradas)" || true

# ── Configurar php.ini para producción ───────────────────────────────────────
info "Configurando PHP para producción..."

PHP_INI_APACHE="/etc/php/${PHP_VER}/apache2/php.ini"
PHP_INI_CLI="/etc/php/${PHP_VER}/cli/php.ini"

configure_php_ini() {
    local FILE="$1"
    [[ ! -f "$FILE" ]] && return

    # Seguridad
    sed -i 's/^expose_php = On/expose_php = Off/'                   "$FILE"
    sed -i 's/^display_errors = On/display_errors = Off/'           "$FILE"
    sed -i 's/^display_startup_errors = On/display_startup_errors = Off/' "$FILE"
    sed -i 's/^log_errors = Off/log_errors = On/'                   "$FILE"

    # Rendimiento
    sed -i 's/^memory_limit = .*/memory_limit = 256M/'              "$FILE"
    sed -i 's/^max_execution_time = .*/max_execution_time = 60/'    "$FILE"
    sed -i 's/^max_input_time = .*/max_input_time = 60/'            "$FILE"

    # Uploads
    sed -i 's/^upload_max_filesize = .*/upload_max_filesize = 20M/' "$FILE"
    sed -i 's/^post_max_size = .*/post_max_size = 20M/'             "$FILE"
    sed -i 's/^max_input_vars = .*/max_input_vars = 3000/'          "$FILE"

    # Sesiones
    sed -i 's|^;session.save_path =.*|session.save_path = "/tmp"|'  "$FILE"
    sed -i 's/^session.cookie_httponly =.*/session.cookie_httponly = 1/' "$FILE"
    sed -i 's/^;session.cookie_secure =.*/session.cookie_secure = 1/'   "$FILE"
    sed -i 's/^;session.cookie_samesite =.*/session.cookie_samesite = "Lax"/' "$FILE"
    sed -i 's/^session.use_strict_mode =.*/session.use_strict_mode = 1/' "$FILE"

    # Charset
    sed -i 's/^;default_charset =.*/default_charset = "UTF-8"/'    "$FILE"

    # Error log
    sed -i "s|^;error_log = .*|error_log = /home/nano/www/logs/erp-php-errors.log|" "$FILE"

    # Timezone
    sed -i 's|^;date.timezone =.*|date.timezone = "Europe/Madrid"|' "$FILE"
    sed -i 's|^date.timezone =.*|date.timezone = "Europe/Madrid"|'  "$FILE"
}

configure_php_ini "$PHP_INI_APACHE"
configure_php_ini "$PHP_INI_CLI"
ok "php.ini configurado para producción"

# ── Configurar OPcache ────────────────────────────────────────────────────────
info "Configurando OPcache..."
OPCACHE_INI="/etc/php/${PHP_VER}/apache2/conf.d/10-opcache.ini"
[[ ! -f "$OPCACHE_INI" ]] && OPCACHE_INI="/etc/php/${PHP_VER}/mods-available/opcache.ini"

cat > "/etc/php/${PHP_VER}/apache2/conf.d/99-opcache-erp.ini" <<OPCACHE
; OPcache optimizado para ERP Fincas
opcache.enable=1
opcache.enable_cli=0
opcache.memory_consumption=128
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.save_comments=1
OPCACHE
ok "OPcache configurado (128MB, 4000 archivos)"

# ── Resumen de versiones ──────────────────────────────────────────────────────
echo ""
ok "PASO 02 completado"
echo ""
echo "    PHP version: $(php -r 'echo PHP_VERSION;' 2>/dev/null)"
echo "    Extensiones: $(php -m 2>/dev/null | wc -l) módulos cargados"
echo "    php.ini Apache: $PHP_INI_APACHE"

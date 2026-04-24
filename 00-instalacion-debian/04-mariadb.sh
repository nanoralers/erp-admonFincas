#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 04 — MariaDB 11.8 (Debian 13 Trixie)
#  Hardening + creación de BD erp_fincas + usuario + schema
#
#  MariaDB 11.8 en Trixie usa autenticación unix_socket por defecto para root.
#  Esto significa que "sudo mysql" funciona sin contraseña.
#  Aquí lo configuramos con contraseña nativa para mayor seguridad.
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_SQL="$SCRIPT_DIR/../02-proyecto-erp/install/schema.sql"
DB_NAME="erp_fincas"
DB_USER="erp_user"
CREDS_FILE="/root/.erp-fincas-db-credentials"

# ── Verificar MariaDB ────────────────────────────────────────────────────────
info "Verificando MariaDB..."
if ! command -v mysql &>/dev/null; then
    info "Instalando mariadb-server..."
    apt-get install -y -qq mariadb-server mariadb-client \
        2>&1 | grep -E "^(Inst|Conf)" | head -5 | sed 's/^/    /' || true
fi

systemctl enable mariadb 2>/dev/null || true
systemctl is-active --quiet mariadb || systemctl start mariadb
sleep 1

MARIADB_VER=$(mysql --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
ok "MariaDB $MARIADB_VER activo"

# ── En MariaDB 11.x con unix_socket, root se conecta sin contraseña via sudo ─
# Verificar el método de autenticación actual
AUTH_PLUGIN=$(mysql -u root -e "SELECT plugin FROM mysql.user WHERE User='root' AND Host='localhost';" \
    2>/dev/null | tail -1 || echo "unknown")
info "Plugin de autenticación root actual: $AUTH_PLUGIN"

# ── Pedir contraseñas ────────────────────────────────────────────────────────
echo ""
echo -e "${Y}    ┌──────────────────────────────────────────────────────────────┐"
echo    "    │  Configuración de contraseñas de MariaDB                       │"
echo    "    │                                                                 │"
echo    "    │  Con MariaDB 11.x en Debian 13, root usa unix_socket           │"
echo    "    │  (conectar con: sudo mysql   ← sin contraseña)                 │"
echo -e "    └──────────────────────────────────────────────────────────────┘${NC}"
echo ""
read -p "    Nueva contraseña para root MariaDB (recomendado establecerla): " -s ROOT_PASS
echo ""
read -p "    Contraseña para usuario '$DB_USER' del ERP (no dejar vacía): " -s DB_PASS
echo ""

[[ -z "$DB_PASS" ]] && { echo -e "${R}    ✗ La contraseña de $DB_USER no puede estar vacía${NC}"; exit 1; }

# ── Hardening equivalente a mysql_secure_installation ────────────────────────
info "Aplicando hardening de MariaDB..."
mysql -u root <<MYSQL_SECURE
-- Establecer contraseña de root con plugin nativo (opcional pero recomendado)
$(if [[ -n "$ROOT_PASS" ]]; then
    echo "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${ROOT_PASS}');"
fi)

-- Eliminar usuarios anónimos
DELETE FROM mysql.user WHERE User='';

-- Eliminar base de datos test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Deshabilitar acceso root remoto
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Aplicar
FLUSH PRIVILEGES;
MYSQL_SECURE
ok "Hardening de MariaDB aplicado"

# Función para ejecutar SQL (con o sin contraseña root)
mysql_exec() {
    if [[ -n "$ROOT_PASS" ]]; then
        mysql -u root -p"$ROOT_PASS" "$@"
    else
        mysql -u root "$@"
    fi
}

# ── Crear BD y usuario del ERP ────────────────────────────────────────────────
info "Creando base de datos '$DB_NAME' y usuario '$DB_USER'..."
mysql_exec <<MYSQL_SETUP
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';

-- Usuario de solo lectura para phpMyAdmin (opcional)
CREATE USER IF NOT EXISTS 'pma_readonly'@'localhost'
    IDENTIFIED BY '${DB_PASS}_pma';
GRANT SELECT ON \`${DB_NAME}\`.* TO 'pma_readonly'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SETUP
ok "BD '$DB_NAME' y usuario '$DB_USER' creados"

# ── Importar schema SQL del ERP ───────────────────────────────────────────────
if [[ -f "$SCHEMA_SQL" ]]; then
    info "Importando schema ERP..."
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SCHEMA_SQL"
    TABLE_COUNT=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SHOW TABLES;" 2>/dev/null | wc -l)
    ok "Schema importado — ${TABLE_COUNT} tablas"
else
    warn "Schema SQL no encontrado en: $SCHEMA_SQL"
    warn "Importar manualmente: mysql -u $DB_USER -p $DB_NAME < 02-proyecto-erp/install/schema.sql"
fi

# ── Guardar credenciales temporales ──────────────────────────────────────────
cat > "$CREDS_FILE" <<CREDS
# ERP Fincas — Credenciales MariaDB temporales
# Generado: $(date)
# ¡BORRAR TRAS CONFIGURAR EL .env!  →  rm -f $CREDS_FILE

DB_HOST=localhost
DB_PORT=3306
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_ROOT_PASS=${ROOT_PASS}
PMA_READONLY_PASS=${DB_PASS}_pma
CREDS
chmod 600 "$CREDS_FILE"
ok "Credenciales guardadas en $CREDS_FILE (solo root)"

# ── Optimización de MariaDB 11.8 ─────────────────────────────────────────────
info "Optimizando configuración de MariaDB 11.8..."
cat > /etc/mysql/conf.d/erp-fincas.cnf <<'MYCNF'
# MariaDB 11.8 — Optimización para ERP Fincas
# /etc/mysql/conf.d/erp-fincas.cnf

[mysqld]
# Charset
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
character_set_client_handshake = FALSE

# Rendimiento InnoDB
innodb_buffer_pool_size   = 128M
innodb_log_file_size      = 48M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method       = O_DIRECT
innodb_file_per_table     = 1

# Conexiones
max_connections           = 100
max_allowed_packet        = 64M
wait_timeout              = 600
interactive_timeout       = 600
connect_timeout           = 10

# Seguridad
bind-address              = 127.0.0.1
local-infile              = 0
# MariaDB 11.x: sin skip-networking (bind-address lo controla)

# Logs
slow_query_log            = 1
slow_query_log_file       = /home/nano/www/logs/mariadb-slow.log
long_query_time           = 2
log_error                 = /home/nano/www/logs/mariadb-error.log

[client]
default-character-set     = utf8mb4

[mysql]
default-character-set     = utf8mb4
MYCNF

systemctl restart mariadb
sleep 1
systemctl is-active --quiet mariadb && ok "MariaDB reiniciado con configuración optimizada" \
    || warn "MariaDB no reinició — revisar: journalctl -u mariadb"

echo ""
ok "PASO 04 completado"
echo ""
echo "    MariaDB:   $MARIADB_VER"
echo "    BD ERP:    $DB_NAME (usuario: $DB_USER)"
echo "    Creds tmp: $CREDS_FILE  ← borrar tras configurar .env"

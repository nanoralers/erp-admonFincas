#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 04 — MariaDB: seguridad + creación de BD para el ERP
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_SQL="$SCRIPT_DIR/../02-proyecto-erp/install/schema.sql"

DB_NAME="erp_fincas"
DB_USER="erp_user"

# ── Asegurar que MariaDB está instalada y corriendo ──────────────────────────
info "Verificando MariaDB..."
if ! command -v mysql &>/dev/null; then
    info "MariaDB no encontrado. Instalando..."
    apt-get install -y -qq mariadb-server mariadb-client 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
fi

systemctl enable mariadb 2>/dev/null | true
if ! systemctl is-active --quiet mariadb; then
    systemctl start mariadb
    sleep 2
fi
ok "MariaDB corriendo: $(mysql --version 2>/dev/null | awk '{print $1, $2, $3}')"

# ── mysql_secure_installation sin interacción ────────────────────────────────
info "Aplicando configuración de seguridad a MariaDB..."

# Pedir contraseña root de MariaDB
echo ""
echo -e "${Y}    ┌─────────────────────────────────────────────────────┐"
echo    "    │  Define la contraseña ROOT de MariaDB                 │"
echo    "    │  (si es recién instalada, estará en blanco → Enter)   │"
echo -e "    └─────────────────────────────────────────────────────┘${NC}"
read -p "    Contraseña actual de root MariaDB (Enter si está vacía): " -s CURRENT_ROOT_PASS
echo ""
read -p "    Nueva contraseña root MariaDB (dejar vacío = no cambiar): " -s NEW_ROOT_PASS
echo ""
read -p "    Contraseña para usuario '$DB_USER' del ERP: " -s DB_PASS
echo ""

# Verificar conexión con contraseña actual
if [[ -n "$CURRENT_ROOT_PASS" ]]; then
    mysql -u root -p"$CURRENT_ROOT_PASS" -e "SELECT 1;" &>/dev/null \
        || { echo -e "${R}    ✗ Contraseña root incorrecta${NC}"; exit 1; }
else
    mysql -u root -e "SELECT 1;" &>/dev/null \
        || { echo -e "${R}    ✗ No se puede conectar a MariaDB. ¿Está iniciado?${NC}"; exit 1; }
fi
ok "Conexión a MariaDB verificada"

# Función para ejecutar SQL como root
MYSQL_CMD() {
    if [[ -n "$CURRENT_ROOT_PASS" ]]; then
        mysql -u root -p"$CURRENT_ROOT_PASS" "$@"
    else
        mysql -u root "$@"
    fi
}

# Hardening equivalente a mysql_secure_installation
info "Aplicando hardening de MariaDB..."
MYSQL_CMD <<MYSQLEOF
-- Cambiar contraseña root si se especificó
$(if [[ -n "$NEW_ROOT_PASS" ]]; then
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${NEW_ROOT_PASS}';"
    echo "FLUSH PRIVILEGES;"
fi)

-- Eliminar usuarios anónimos
DELETE FROM mysql.user WHERE User='';

-- Eliminar base de datos de test
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Deshabilitar acceso root remoto
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Aplicar cambios
FLUSH PRIVILEGES;
MYSQLEOF
ok "Hardening de MariaDB aplicado"

# Actualizar contraseña si cambió
[[ -n "$NEW_ROOT_PASS" ]] && CURRENT_ROOT_PASS="$NEW_ROOT_PASS"

# ── Crear base de datos y usuario del ERP ────────────────────────────────────
info "Creando base de datos '$DB_NAME'..."
MYSQL_CMD <<MYSQLEOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Crear usuario si no existe
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASS}';

-- Asignar privilegios solo sobre la BD del ERP
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
MYSQLEOF
ok "Base de datos '$DB_NAME' creada"
ok "Usuario '$DB_USER'@'localhost' creado con acceso a '$DB_NAME'"

# ── Importar schema ───────────────────────────────────────────────────────────
if [[ -f "$SCHEMA_SQL" ]]; then
    info "Importando schema del ERP..."
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$SCHEMA_SQL"
    TABLE_COUNT=$(mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SHOW TABLES;" 2>/dev/null | wc -l)
    ok "Schema importado — ${TABLE_COUNT} tablas creadas"
else
    warn "Schema SQL no encontrado en $SCHEMA_SQL"
    warn "Importar manualmente: mysql -u $DB_USER -p $DB_NAME < install/schema.sql"
fi

# ── Guardar credenciales en archivo seguro ───────────────────────────────────
CREDS_FILE="/root/.erp-fincas-db-credentials"
cat > "$CREDS_FILE" <<CREDS
# ERP Fincas - Credenciales de base de datos
# Generado: $(date)
# ¡ELIMINAR ESTE ARCHIVO cuando hayas configurado el .env del proyecto!

DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
DB_ROOT_PASS=${CURRENT_ROOT_PASS}
CREDS
chmod 600 "$CREDS_FILE"
ok "Credenciales guardadas temporalmente en $CREDS_FILE (solo root puede leerlo)"

# ── Configurar MariaDB para mejor rendimiento ─────────────────────────────────
info "Optimizando configuración de MariaDB..."
cat > /etc/mysql/conf.d/erp-fincas.cnf <<'MYCNF'
[mysqld]
# Charset por defecto
character-set-server = utf8mb4
collation-server     = utf8mb4_unicode_ci
character_set_client_handshake = FALSE

# Rendimiento
innodb_buffer_pool_size    = 128M
innodb_log_file_size       = 32M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method        = O_DIRECT

# Conexiones
max_connections            = 100
connect_timeout            = 10
wait_timeout               = 600
interactive_timeout        = 600
max_allowed_packet         = 64M

# Logs
slow_query_log             = 1
slow_query_log_file        = /home/nano/www/logs/mysql-slow.log
long_query_time            = 2

# Seguridad
bind-address               = 127.0.0.1
skip-networking            = 0
local-infile               = 0

[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
MYCNF

systemctl restart mariadb
ok "MariaDB optimizado y reiniciado"

echo ""
ok "PASO 04 completado — MariaDB configurado"
echo ""
echo "    Base de datos: $DB_NAME"
echo "    Usuario ERP:   $DB_USER@localhost"
echo "    Credenciales:  $CREDS_FILE  ← Borrar tras configurar .env"

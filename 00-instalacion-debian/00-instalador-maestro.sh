#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  ERP FINCAS — INSTALADOR MAESTRO PARA DEBIAN 13 TRIXIE
#  Servidor limpio: Apache básico + SSH + MariaDB recién instalados
#
#  Uso: sudo bash 00-instalador-maestro.sh
#
#  Versiones instaladas (repos oficiales Trixie, sin PPAs externos):
#    PHP        8.4.x   (repos oficiales Debian 13)
#    Apache     2.4.x   (repos oficiales)
#    MariaDB    11.8.x  (repos oficiales Debian 13)
#    phpMyAdmin 5.2.3   (via trixie-backports)
#    Certbot    último  (repos oficiales)
#    dnsmasq    último  (repos oficiales)
#    UFW        último  (repos oficiales)
#    Fail2Ban   último  (repos oficiales)
#
#  Estado DNS en IONOS (ya configurado, no hay que tocar nada):
#    A     @    → IP dinámica (DDNS router)
#    A     www  → IP dinámica (DDNS router)
#    CNAME *    → nanoserver.es  ← wildcard para todos los subdominios ✅
#
#  IP interna del servidor: 192.168.1.254
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/erp-fincas-install.log"
START_TIME=$(date +%s)

log()  { echo "$(date '+%H:%M:%S') $*" >> "$LOG_FILE"; }
ok()   { echo -e "${G}  ✓${NC} $1"; log "OK: $1"; }
info() { echo -e "${C}  ▸ $1${NC}"; log "INFO: $1"; }
warn() { echo -e "${Y}  ⚠ $1${NC}"; log "WARN: $1"; }
fail() { echo -e "${R}  ✗ FALLO: $1${NC}"; log "FAIL: $1"; exit 1; }
hdr()  {
    echo -e "\n${BOLD}${B}╔══════════════════════════════════════════════╗${NC}"
    echo -e   "${BOLD}${B}║  $1${NC}"
    echo -e   "${BOLD}${B}╚══════════════════════════════════════════════╝${NC}"
}

step() {
    local N="$1" SCRIPT="$SCRIPT_DIR/$2" DESC="$3"
    hdr "PASO $N · $DESC"
    [[ -f "$SCRIPT" ]] || fail "Script no encontrado: $2"
    bash "$SCRIPT" || fail "Falló el paso $N: $DESC"
    ok "Paso $N completado ✓"
}

# ── Cabecera ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ╔═════════════════════════════════════════════════════════════╗"
echo "  ║   ERP FINCAS — Instalación completa en Debian 13 Trixie    ║"
echo "  ║   nanoserver.es · IP interna: 192.168.1.254                ║"
echo "  ╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Comprobaciones previas ────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && fail "Ejecuta como root: sudo bash 00-instalador-maestro.sh"

# Verificar Debian 13
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    [[ "${VERSION_CODENAME:-}" == "trixie" ]] \
        && ok "Debian 13 Trixie confirmado (kernel $(uname -r))" \
        || warn "Sistema detectado: ${PRETTY_NAME:-desconocido} — continúa bajo tu responsabilidad"
else
    fail "No se detecta /etc/os-release — ¿es Debian?"
fi

# Verificar internet
curl -s --max-time 8 https://deb.debian.org > /dev/null 2>&1 \
    && ok "Conexión a internet disponible" \
    || fail "Sin conexión a internet"

# Crear log
mkdir -p "$(dirname "$LOG_FILE")"
echo "=== ERP Fincas — Instalación $(date) ===" > "$LOG_FILE"
info "Log en tiempo real: tail -f $LOG_FILE"
echo ""

# ── Resumen de lo que se va a instalar ───────────────────────────────────────
echo -e "${Y}  Componentes a instalar:${NC}"
echo "    • PHP 8.4 + 15 extensiones (repos oficiales Trixie)"
echo "    • Apache 2.4 + módulos (rewrite, headers, ssl, expires, deflate...)"
echo "    • MariaDB 11.8 — hardening + BD erp_fincas + schema"
echo "    • dnsmasq — DNS local *.nanoserver.es → 192.168.1.254"
echo "    • UFW (fw: 22/80/443) + Fail2Ban (SSH/Apache/login ERP)"
echo "    • Certbot — cliente Let's Encrypt + cert temporal wildcard"
echo "    • ERP Fincas — despliegue completo en /home/nano/www/"
echo "    • phpMyAdmin 5.2.3 — acceso en phpmyadmin.nanoserver.es"
echo ""
echo -e "${Y}  DNS IONOS (ya configurado, no hay que tocar nada):${NC}"
echo "    ✅ CNAME * → nanoserver.es  (wildcard subdominios)"
echo "    ✅ A @ y www → IP dinámica (DDNS del router)"
echo ""
read -p "  ¿Continuar con la instalación? [S/n]: " CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && echo "  Cancelado." && exit 0
echo ""

# ── Ejecución de pasos ────────────────────────────────────────────────────────
step  "1" "01-sistema-base.sh"     "Sistema base, herramientas, backports y directorios"
step  "2" "02-php84.sh"            "PHP 8.4 + extensiones (repos oficiales Trixie)"
step  "3" "03-apache-modulos.sh"   "Módulos y hardening de Apache 2.4"
step  "4" "04-mariadb.sh"          "MariaDB 11.8 — seguridad + BD erp_fincas + schema"
step  "5" "05-dns-local.sh"        "dnsmasq — DNS local wildcard *.nanoserver.es"
step  "6" "06-seguridad.sh"        "Firewall UFW + Fail2Ban + hardening kernel"
step  "7" "07-certbot.sh"          "Certbot + certificado temporal wildcard"
step  "8" "08-desplegar-erp.sh"    "Despliegue ERP Fincas + .env"
step  "9" "09-phpmyadmin.sh"       "phpMyAdmin 5.2.3 en phpmyadmin.nanoserver.es"

# ── Resumen final ─────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo -e "${BOLD}${G}"
echo "  ╔═════════════════════════════════════════════════════════════╗"
echo "  ║   ✓  INSTALACIÓN COMPLETADA en ${MINS}m ${SECS}s                      ║"
echo "  ╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}Paso final obligatorio — SSL wildcard real:${NC}"
echo -e "  ${C}sudo bash ../03-scripts-despliegue/ssl-wildcard.sh${NC}"
echo ""
echo -e "  ${BOLD}Verificación completa:${NC}"
echo -e "  ${C}bash ../03-scripts-despliegue/verificar.sh${NC}"
echo ""
echo -e "  ${BOLD}Accesos tras SSL:${NC}"
echo "    ERP Admin:   https://admin.nanoserver.es"
echo "    phpMyAdmin:  https://phpmyadmin.nanoserver.es"
echo "    Web:         https://nanoserver.es"
echo ""
echo "  Log completo: $LOG_FILE"
echo ""
echo -e "  ${Y}Recuerda borrar las credenciales temporales:${NC}"
echo -e "  ${R}rm -f /root/.erp-fincas-db-credentials${NC}"
echo ""

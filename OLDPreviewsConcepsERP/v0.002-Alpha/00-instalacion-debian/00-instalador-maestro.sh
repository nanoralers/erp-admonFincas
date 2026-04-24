#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  ERP FINCAS — INSTALADOR MAESTRO PARA DEBIAN 13 (TRIXIE)
#  Servidor limpio con Apache básico + SSH + MariaDB recién instalados
#
#  Uso:  sudo bash 00-instalador-maestro.sh
#
#  Ejecuta en orden:
#    01 → Sistema base y herramientas
#    02 → PHP 8.3 + extensiones
#    03 → Módulos y configuración de Apache
#    04 → MariaDB (seguridad + BD del ERP)
#    05 → DNS local con dnsmasq (*.nanoserver.es → 127.0.0.1)
#    06 → Seguridad (UFW, Fail2Ban, hardening PHP)
#    07 → Certbot (solo instalación, SSL se lanza aparte)
#    08 → Despliegue del ERP
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colores ───────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/erp-fincas-install.log"
START_TIME=$(date +%s)

# ── Funciones ─────────────────────────────────────────────────────────────────
log()  { echo "$(date '+%H:%M:%S') $*" >> "$LOG_FILE"; }
ok()   { echo -e "${G}  ✓${NC} $1"; log "OK: $1"; }
info() { echo -e "${C}  ▸ $1${NC}"; log "INFO: $1"; }
warn() { echo -e "${Y}  ⚠ $1${NC}"; log "WARN: $1"; }
fail() { echo -e "${R}  ✗ FALLO: $1${NC}"; log "FAIL: $1"; exit 1; }
hdr()  { echo -e "\n${BOLD}${B}┌─────────────────────────────────────────────┐${NC}";
         echo -e   "${BOLD}${B}│  $1${NC}";
         echo -e   "${BOLD}${B}└─────────────────────────────────────────────┘${NC}"; }

step() {
    local N="$1"; local SCRIPT="$SCRIPT_DIR/$2"
    hdr "PASO $N: $3"
    if [[ ! -f "$SCRIPT" ]]; then
        fail "Script no encontrado: $SCRIPT"
    fi
    bash "$SCRIPT" || fail "Falló el paso $N: $3"
    ok "Paso $N completado"
}

# ── Cabecera ──────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║        ERP FINCAS — Instalación completa                  ║"
echo "  ║        Debian 13 Trixie · nanoserver.es                   ║"
echo "  ║        IP interna: 192.168.1.254                          ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Comprobaciones previas ────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && fail "Ejecuta como root: sudo bash 00-instalador-maestro.sh"

# Detectar Debian 13
if [[ -f /etc/debian_version ]]; then
    DEB_VER=$(cat /etc/debian_version | cut -d. -f1)
    [[ "$DEB_VER" == "13" ]] || [[ "$(cat /etc/debian_version)" == "trixie/sid" ]] \
        && ok "Debian 13 (Trixie) detectado" \
        || warn "No es Debian 13. Detectado: $(cat /etc/debian_version). Continúa bajo tu responsabilidad."
else
    fail "No parece ser un sistema Debian"
fi

# Verificar conexión a internet
if curl -s --max-time 8 https://deb.debian.org > /dev/null 2>&1; then
    ok "Conexión a internet disponible"
else
    fail "Sin conexión a internet. Necesaria para descargar paquetes."
fi

# Crear log
mkdir -p "$(dirname "$LOG_FILE")"
echo "=== Instalación ERP Fincas $(date) ===" > "$LOG_FILE"
info "Log guardado en: $LOG_FILE"
echo ""

# ── Confirmación ──────────────────────────────────────────────────────────────
echo -e "${Y}  Se instalarán y configurarán los siguientes componentes:${NC}"
echo "    • PHP 8.3 + 14 extensiones"
echo "    • Apache 2.4 + 8 módulos"
echo "    • MariaDB (seguridad + BD erp_fincas)"
echo "    • dnsmasq (DNS local wildcard *.nanoserver.es)"
echo "    • UFW (firewall: 22, 80, 443)"
echo "    • Fail2Ban (protección SSH + Apache)"
echo "    • Certbot (cliente Let's Encrypt)"
echo "    • ERP Fincas (despliegue completo)"
echo ""
read -p "  ¿Continuar? [S/n]: " CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && echo "  Instalación cancelada." && exit 0
echo ""

# ── Ejecutar pasos ────────────────────────────────────────────────────────────
step "1" "01-sistema-base.sh"    "Sistema base, herramientas y dependencias"
step "2" "02-php83.sh"           "PHP 8.3 y extensiones"
step "3" "03-apache-modulos.sh"  "Módulos y configuración de Apache"
step "4" "04-mariadb.sh"         "MariaDB — seguridad y base de datos ERP"
step "5" "05-dns-local.sh"       "DNS local (dnsmasq para *.nanoserver.es)"
step "6" "06-seguridad.sh"       "Firewall UFW y Fail2Ban"
step "7" "07-certbot.sh"         "Certbot (cliente Let's Encrypt)"
step "8" "08-desplegar-erp.sh"   "Despliegue del ERP Fincas"

# ── Resumen final ─────────────────────────────────────────────────────────────
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo -e "${BOLD}${G}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║   ✓  INSTALACIÓN COMPLETA en ${MINS}m ${SECS}s                       ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Siguiente paso obligatorio:"
echo -e "  ${C}sudo bash ../03-scripts-despliegue/ssl-wildcard.sh${NC}"
echo ""
echo "  Verificación completa del sistema:"
echo -e "  ${C}bash ../03-scripts-despliegue/verificar.sh${NC}"
echo ""
echo "  Log completo en: $LOG_FILE"
echo ""

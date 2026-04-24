#!/bin/bash
# ════════════════════════════════════════════════════════════════════
#  ERP FINCAS — Obtención de certificado SSL wildcard
#  Let's Encrypt *.nanoserver.es via DNS Challenge (IONOS manual)
#  Uso: sudo bash ssl-wildcard.sh
# ════════════════════════════════════════════════════════════════════

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'; RED='\033[0;31m'

ok()   { echo -e "${GREEN}  ✓ $1${NC}"; }
info() { echo -e "${CYAN}  ► $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $1${NC}"; }

[[ $EUID -ne 0 ]] && { echo -e "${RED}  Ejecuta como root: sudo bash ssl-wildcard.sh${NC}"; exit 1; }

echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║    SSL Wildcard — *.nanoserver.es                ║"
echo "  ║    Let's Encrypt + DNS Challenge (IONOS)         ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Verificar certbot ─────────────────────────────────────────────
if ! command -v certbot &>/dev/null; then
    info "Instalando certbot..."
    apt-get update -qq && apt-get install -y certbot python3-certbot-apache
    ok "Certbot instalado"
else
    ok "Certbot disponible ($(certbot --version 2>&1 | head -1))"
fi

# ── Comprobar si ya existe el certificado wildcard ────────────────
if certbot certificates 2>/dev/null | grep -q "nanoserver.es-wildcard"; then
    warn "El certificado wildcard ya existe."
    echo ""
    certbot certificates 2>/dev/null | grep -A5 "nanoserver.es-wildcard" | sed 's/^/  /'
    echo ""
    read -p "  ¿Renovar igualmente? [s/N]: " RENEW
    [[ "${RENEW,,}" != "s" ]] && echo "  Saliendo." && exit 0
fi

# ── Instrucciones previas ─────────────────────────────────────────
echo ""
echo -e "${BOLD}  ┌─ ANTES DE CONTINUAR ──────────────────────────────────┐${NC}"
echo    "  │                                                       │"
echo    "  │  Certbot pedirá añadir un registro TXT en IONOS.     │"
echo    "  │  Ten abierto el panel DNS de IONOS en el navegador:  │"
echo    "  │                                                       │"
echo -e "  │  ${CYAN}https://mein.ionos.es${NC} → Dominios & SSL               │"
echo    "  │  → nanoserver.es → DNS → Añadir registro             │"
echo    "  │                                                       │"
echo    "  │  Tipo: TXT  |  Host: _acme-challenge  |  TTL: 60     │"
echo    "  │                                                       │"
echo    "  └───────────────────────────────────────────────────────┘"
echo ""
read -p "  Tengo el panel DNS de IONOS abierto, continuar [Enter]..."

# ── Ejecutar certbot ──────────────────────────────────────────────
echo ""
info "Lanzando certbot — sigue las instrucciones en pantalla..."
echo ""

certbot certonly \
    --manual \
    --preferred-challenges dns \
    --cert-name nanoserver.es-wildcard \
    -d "nanoserver.es" \
    -d "*.nanoserver.es" \
    --agree-tos \
    -m admin@nanoserver.es

# ── Verificación post-instalación ────────────────────────────────
echo ""
if certbot certificates 2>/dev/null | grep -q "nanoserver.es-wildcard"; then
    ok "Certificado wildcard obtenido correctamente"
    echo ""
    certbot certificates 2>/dev/null | grep -A6 "nanoserver.es-wildcard" | sed 's/^/  /'

    # Verificar que Apache puede leer el cert
    CERT="/etc/letsencrypt/live/nanoserver.es-wildcard/fullchain.pem"
    if [[ -f "$CERT" ]]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
        DOMAINS=$(openssl x509 -text -noout -in "$CERT" | grep "DNS:" | tr -d ' ')
        ok "Expira: $EXPIRY"
        ok "Dominios cubiertos: $DOMAINS"
    fi

    echo ""
    info "Recargando Apache con el nuevo certificado..."
    apache2ctl configtest 2>&1 | grep -q "Syntax OK" && systemctl reload apache2 && ok "Apache recargado"

    echo ""
    echo -e "${BOLD}${GREEN}  ╔══════════════════════════════════════════════════╗"
    echo    "  ║  ✓  SSL Wildcard activo y funcionando            ║"
    echo -e "  ╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Prueba ahora:"
    echo -e "  ${CYAN}curl -I https://admin.nanoserver.es${NC}"
    echo -e "  ${CYAN}curl -I https://demo.nanoserver.es${NC}"
    echo ""
    echo "  ────────────────────────────────────────────────────"
    echo "  ⚠  IMPORTANTE: Elimina el registro _acme-challenge"
    echo "     del panel DNS de IONOS (ya no es necesario)"
    echo "  ────────────────────────────────────────────────────"
    echo ""
    echo "  Próxima renovación manual (en ~85 días):"
    echo -e "  ${CYAN}sudo bash ssl-wildcard.sh${NC}"
else
    echo -e "${RED}  ✗ No se encontró el certificado. Revisa los errores arriba.${NC}"
    exit 1
fi

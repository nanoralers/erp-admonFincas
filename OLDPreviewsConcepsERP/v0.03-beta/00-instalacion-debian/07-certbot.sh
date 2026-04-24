#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 07 — Certbot + certificado auto-firmado temporal para wildcard
#  El cert real se obtiene con: sudo bash ../03-scripts-despliegue/ssl-wildcard.sh
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

# ── Instalar certbot ──────────────────────────────────────────────────────────
info "Instalando certbot y plugin Apache..."
apt-get install -y -qq certbot python3-certbot-apache \
    2>&1 | grep -E "^(Inst|Conf)" | head -5 | sed 's/^/    /' || true
ok "Certbot instalado: $(certbot --version 2>&1)"

# ── Crear directorio y cert temporal wildcard ─────────────────────────────────
# Necesario para que Apache arranque aunque aún no exista el cert real de Let's Encrypt
WILDCARD_DIR="/etc/letsencrypt/live/nanoserver.es-wildcard"
info "Creando certificado auto-firmado temporal para *.nanoserver.es..."

if [[ ! -f "$WILDCARD_DIR/fullchain.pem" ]]; then
    mkdir -p "$WILDCARD_DIR"
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$WILDCARD_DIR/privkey.pem" \
        -out    "$WILDCARD_DIR/fullchain.pem" \
        -days   3 \
        -subj   "/C=ES/ST=Spain/L=Madrid/O=NanoServer/CN=*.nanoserver.es" \
        -addext "subjectAltName=DNS:nanoserver.es,DNS:*.nanoserver.es" \
        2>/dev/null
    cp "$WILDCARD_DIR/fullchain.pem" "$WILDCARD_DIR/chain.pem"
    chmod 600 "$WILDCARD_DIR/privkey.pem"
    chmod 644 "$WILDCARD_DIR/fullchain.pem" "$WILDCARD_DIR/chain.pem"
    ok "Cert auto-firmado temporal creado en $WILDCARD_DIR (3 días)"
else
    ok "Directorio de cert wildcard ya existe"
fi

# ── Cert para el dominio raíz via certbot --apache ───────────────────────────
info "¿Obtener certificado real para nanoserver.es y www ahora?"
echo ""
echo -e "${Y}    Esto funciona si Apache está activo y"
echo -e "    el DNS ya resuelve nanoserver.es → esta IP.${NC}"
echo ""
read -p "    ¿Obtener cert para nanoserver.es/www ahora? [S/n]: " GET_ROOT
echo ""

if [[ "${GET_ROOT,,}" != "n" ]]; then
    if systemctl is-active --quiet apache2; then
        certbot --apache \
            -d nanoserver.es \
            -d www.nanoserver.es \
            --non-interactive \
            --agree-tos \
            -m admin@nanoserver.es \
            2>&1 | tail -8 | sed 's/^/    /' \
            && ok "Cert nanoserver.es obtenido" \
            || warn "No se pudo obtener el cert — verificar DNS y Apache"
    else
        warn "Apache no está activo — saltando"
    fi
fi

# ── Renovación automática ─────────────────────────────────────────────────────
info "Configurando renovación automática..."
if systemctl list-timers 2>/dev/null | grep -q "certbot"; then
    ok "Timer certbot ya activo"
elif systemctl enable certbot.timer 2>/dev/null && systemctl start certbot.timer 2>/dev/null; then
    ok "Timer certbot habilitado (renueva automáticamente)"
else
    CRON="0 3 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload apache2' >> /home/nano/www/logs/certbot-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON") | crontab -
    ok "Cron de renovación configurado (diario 3:00 AM)"
fi

# ── Reiniciar Apache con el cert temporal ────────────────────────────────────
info "Reiniciando Apache con certificado temporal..."
if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    systemctl restart apache2 && ok "Apache reiniciado con certificado temporal" \
        || warn "Apache no pudo reiniciar — revisar: journalctl -u apache2 -n 20"
else
    apache2ctl configtest 2>&1 | grep -v "^AH\|^$" | head -5 | sed 's/^/    /'
    warn "Error en configuración Apache — verificar y reiniciar manualmente"
fi

echo ""
ok "PASO 07 completado"
echo ""
echo "    Certbot:  $(certbot --version 2>&1)"
echo "    Cert tmp: $WILDCARD_DIR (caduca en 3 días)"
echo ""
echo -e "    ${Y}⚠ Obtener certificado REAL tras la instalación:${NC}"
echo    "    sudo bash ../03-scripts-despliegue/ssl-wildcard.sh"

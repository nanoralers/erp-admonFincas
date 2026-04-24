#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 07 — Certbot: instalación del cliente Let's Encrypt
#  (El certificado wildcard se obtiene en ssl-wildcard.sh)
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

# ── Instalar certbot ──────────────────────────────────────────────────────────
info "Instalando Certbot..."

# En Debian 13 certbot está en los repos oficiales
apt-get install -y -qq \
    certbot \
    python3-certbot-apache \
    python3-certbot-dns-standalone 2>&1 | \
    grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true

ok "Certbot instalado: $(certbot --version 2>&1)"

# ── Certificado para nanoserver.es (dominio raíz, sin wildcard) ──────────────
# Este certbot --apache para el dominio principal puede usarse sin DNS challenge
# ya que el dominio apunta directamente al servidor
info "¿Obtener certificado SSL para nanoserver.es ahora? (sin wildcard)"
echo ""
echo -e "${Y}    Nota: Para el ERP necesitas el wildcard *.nanoserver.es"
echo    "    que se obtiene con ssl-wildcard.sh (requiere añadir TXT en IONOS)."
echo    ""
echo    "    Este paso obtiene el certificado básico para nanoserver.es"
echo -e "    (solo el dominio principal, sin subdominios)${NC}"
echo ""
read -p "    ¿Obtener certificado para nanoserver.es ahora? [S/n]: " GET_BASIC
echo ""

if [[ "${GET_BASIC,,}" != "n" ]]; then
    info "Obteniendo certificado para nanoserver.es..."
    # Apache debe estar corriendo con el VirtualHost HTTP
    if systemctl is-active --quiet apache2; then
        certbot --apache \
            -d nanoserver.es \
            -d www.nanoserver.es \
            --non-interactive \
            --agree-tos \
            -m admin@nanoserver.es \
            --redirect 2>&1 | tail -5 | sed 's/^/    /' \
            && ok "Certificado nanoserver.es obtenido" \
            || warn "No se pudo obtener el certificado — verificar que Apache está activo y el DNS apunta al servidor"
    else
        warn "Apache no está activo — no se puede obtener el certificado ahora"
        warn "Ejecutar manualmente: sudo certbot --apache -d nanoserver.es -d www.nanoserver.es"
    fi
else
    info "Saltando — recuerda obtenerlo manualmente más adelante"
fi

# ── Configurar renovación automática ─────────────────────────────────────────
info "Verificando renovación automática..."
if systemctl is-active --quiet certbot.timer 2>/dev/null; then
    ok "Timer de renovación automática activo"
elif systemctl enable certbot.timer 2>/dev/null && systemctl start certbot.timer 2>/dev/null; then
    ok "Timer de renovación automática habilitado"
else
    # Alternativa: cron job
    CRON_JOB="0 3 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload apache2' >> /home/nano/www/logs/certbot-renew.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_JOB") | crontab -
    ok "Cron de renovación automática configurado (cada día a las 3:00)"
fi

# ── Crear certificados auto-firmados temporales para el wildcard ──────────────
# Esto permite que Apache arranque aunque aún no exista el cert de Let's Encrypt
info "Creando certificados auto-firmados temporales para wildcard..."

WILDCARD_DIR="/etc/letsencrypt/live/nanoserver.es-wildcard"
if [[ ! -d "$WILDCARD_DIR" ]]; then
    mkdir -p "$WILDCARD_DIR"
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$WILDCARD_DIR/privkey.pem" \
        -out    "$WILDCARD_DIR/fullchain.pem" \
        -days 1 \
        -subj "/C=ES/ST=Spain/L=Madrid/O=NanoServer/CN=*.nanoserver.es" \
        -addext "subjectAltName=DNS:nanoserver.es,DNS:*.nanoserver.es" \
        2>/dev/null
    # Crear symlink chain.pem requerido por certbot
    cp "$WILDCARD_DIR/fullchain.pem" "$WILDCARD_DIR/chain.pem"
    chmod 600 "$WILDCARD_DIR/privkey.pem"
    chmod 644 "$WILDCARD_DIR/fullchain.pem" "$WILDCARD_DIR/chain.pem"
    ok "Certificado auto-firmado temporal creado en $WILDCARD_DIR"
    warn "⚠ Solo para que Apache arranque — REEMPLAZAR con Let's Encrypt wildcard real"
    warn "  Ejecutar: sudo bash 03-scripts-despliegue/ssl-wildcard.sh"
else
    ok "Directorio de certificado wildcard ya existe"
fi

# Ahora Apache debería poder arrancar con el certificado temporal
info "Reiniciando Apache con certificado temporal..."
if apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    systemctl restart apache2 && ok "Apache reiniciado correctamente" \
        || warn "Apache no pudo reiniciar — revisar logs: journalctl -u apache2"
else
    apache2ctl configtest 2>&1 | head -5 | sed 's/^/    /'
    warn "Error en configuración Apache — revisar y reiniciar manualmente"
fi

echo ""
ok "PASO 07 completado — Certbot listo"
echo ""
echo "    Certbot: $(certbot --version 2>&1)"
echo "    Cert temporal wildcard: $WILDCARD_DIR (⚠ reemplazar con real)"
echo ""
echo "    Para obtener el certificado real:"
echo "    sudo bash 03-scripts-despliegue/ssl-wildcard.sh"

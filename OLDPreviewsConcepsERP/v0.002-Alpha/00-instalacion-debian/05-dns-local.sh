#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 05 — DNS local con dnsmasq
#  Resuelve *.nanoserver.es → 127.0.0.1 internamente en el servidor
#
#  Por qué es necesario:
#  El router tiene el puerto 80/443 apuntando a 192.168.1.254.
#  Cuando el propio servidor intenta resolver gestoria.nanoserver.es,
#  obtiene la IP externa (79.117.59.x) y el paquete va al router, que
#  puede no hacer "hairpin NAT" y la conexión falla.
#  dnsmasq resuelve el wildcard localmente, evitando el bucle.
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠ $1${NC}"; }

INTERNAL_IP="192.168.1.254"
DOMAIN="nanoserver.es"

# ── Instalar dnsmasq ──────────────────────────────────────────────────────────
info "Instalando dnsmasq..."
apt-get install -y -qq dnsmasq 2>&1 | grep -E "(Unpacking|Setting up)" | sed 's/^/    /' || true
ok "dnsmasq instalado"

# ── Deshabilitar systemd-resolved si está activo (conflicto puerto 53) ───────
info "Verificando conflictos con systemd-resolved..."
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    # Desactivar solo el stub listener, no el servicio completo
    mkdir -p /etc/systemd/resolved.conf.d/
    cat > /etc/systemd/resolved.conf.d/dnsmasq.conf <<'RESOLVED'
[Resolve]
DNSStubListener=no
RESOLVED
    systemctl restart systemd-resolved 2>/dev/null || true
    ok "systemd-resolved stub listener desactivado"
fi

# Verificar que nada ocupe el puerto 53
if ss -tlunp 2>/dev/null | grep -q ":53 "; then
    warn "Puerto 53 ocupado — verificando..."
    ss -tlunp | grep ":53 " | sed 's/^/    /'
fi

# ── Configurar dnsmasq ────────────────────────────────────────────────────────
info "Configurando dnsmasq para wildcard *.${DOMAIN}..."

# Backup de la configuración original
[[ -f /etc/dnsmasq.conf ]] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

cat > /etc/dnsmasq.d/erp-fincas.conf <<DNSMASQ
# ════════════════════════════════════════════════════════════════════
#  dnsmasq — Resolución local de *.${DOMAIN}
#  ERP Fincas · nanoserver.es
# ════════════════════════════════════════════════════════════════════

# Solo escuchar en loopback e interfaz interna (NO exponer al exterior)
listen-address=127.0.0.1,${INTERNAL_IP}
bind-interfaces

# No leer /etc/hosts para resolución (usamos la sección de abajo)
# no-hosts

# ── Resolución wildcard ───────────────────────────────────────────────────────
# Cualquier subdominio de ${DOMAIN} → servidor local
# Esto cubre admin.${DOMAIN}, gestoria.${DOMAIN}, etc.
address=/${DOMAIN}/${INTERNAL_IP}

# ── DNS upstream para el resto de consultas ──────────────────────────────────
# Usar los DNS de Cloudflare + Google como fallback
server=1.1.1.1
server=8.8.8.8
server=8.8.4.4

# No reenviar consultas de dominio local al upstream
domain-needed
bogus-priv

# Cache DNS local (256 entradas)
cache-size=256

# Log de consultas DNS (solo para debug, comentar en producción)
# log-queries
# log-facility=/home/nano/www/logs/dnsmasq.log
DNSMASQ

ok "Configuración dnsmasq creada"

# ── Configurar /etc/hosts para los dominios fijos ────────────────────────────
info "Añadiendo entradas en /etc/hosts para dominios fijos..."

# Backup
cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d)

# Eliminar entradas previas del ERP si existen
sed -i '/# ERP FINCAS/,/# FIN ERP FINCAS/d' /etc/hosts

# Añadir entradas
cat >> /etc/hosts <<HOSTS

# ERP FINCAS — Resolución local (añadido por instalador)
# IP interna del servidor: ${INTERNAL_IP}
${INTERNAL_IP}  ${DOMAIN}
${INTERNAL_IP}  www.${DOMAIN}
${INTERNAL_IP}  admin.${DOMAIN}
127.0.0.1       localhost.${DOMAIN}
# FIN ERP FINCAS
HOSTS
ok "/etc/hosts actualizado con dominios fijos"

# ── Configurar resolv.conf para usar dnsmasq primero ─────────────────────────
info "Configurando resolv.conf..."

# Si resolv.conf está gestionado por systemd, usar el resolvconf
if [[ -L /etc/resolv.conf ]]; then
    # Es un symlink — configurar via resolved
    mkdir -p /etc/systemd/resolved.conf.d/
    cat > /etc/systemd/resolved.conf.d/upstream.conf <<'RCONF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=1.1.1.1 8.8.8.8
Domains=~.
RCONF
    systemctl restart systemd-resolved 2>/dev/null || true
    warn "resolv.conf es symlink — configurado via systemd-resolved"
else
    # resolv.conf estático
    cat > /etc/resolv.conf <<RESOLV
# Generado por instalador ERP Fincas
# dnsmasq local primero, luego DNS externos
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 8.8.8.8
search ${DOMAIN}
RESOLV
    ok "resolv.conf configurado"
fi

# ── Iniciar y habilitar dnsmasq ───────────────────────────────────────────────
info "Iniciando dnsmasq..."
systemctl enable dnsmasq 2>/dev/null | true
systemctl restart dnsmasq

sleep 1  # Dar tiempo para que arranque

if systemctl is-active --quiet dnsmasq; then
    ok "dnsmasq activo y escuchando"
else
    warn "dnsmasq no arrancó correctamente"
    journalctl -u dnsmasq --no-pager -n 10 | sed 's/^/    /'
fi

# ── Verificación ──────────────────────────────────────────────────────────────
info "Verificando resolución DNS local..."
sleep 1

for HOST in "${DOMAIN}" "www.${DOMAIN}" "admin.${DOMAIN}" "demo-gestoria.${DOMAIN}"; do
    RESOLVED=$(dig +short "@127.0.0.1" "$HOST" 2>/dev/null | tail -1)
    if [[ "$RESOLVED" == "$INTERNAL_IP" ]]; then
        ok "  $HOST → $RESOLVED ✓"
    else
        warn "  $HOST → '${RESOLVED}' (esperado ${INTERNAL_IP})"
    fi
done

# Verificar que DNS externo sigue funcionando
GOOGLE_RESOLVED=$(dig +short "@127.0.0.1" "google.com" 2>/dev/null | tail -1)
if [[ -n "$GOOGLE_RESOLVED" ]]; then
    ok "  DNS externo funcionando (google.com → $GOOGLE_RESOLVED)"
else
    warn "  DNS externo no resuelve — verificar servidor upstream"
fi

echo ""
ok "PASO 05 completado — DNS local configurado"
echo ""
echo "    *.${DOMAIN} → ${INTERNAL_IP} (resuelto localmente)"
echo "    DNS externo → 1.1.1.1, 8.8.8.8 (Cloudflare + Google)"

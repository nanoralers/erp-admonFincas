#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
#  PASO 05 — DNS local con dnsmasq
#
#  Problema que resuelve (hairpin NAT):
#  El DNS de IONOS resuelve *.nanoserver.es → 79.117.59.x (IP pública)
#  Cuando el servidor intenta contactarse a sí mismo por subdominio,
#  el paquete va al router → puede no volver (hairpin NAT no soportado).
#  dnsmasq resuelve *.nanoserver.es → 192.168.1.254 LOCALMENTE,
#  evitando el bucle y garantizando que el ERP funcione internamente.
#
#  El DNS externo de IONOS (ya configurado) NO se toca en este script:
#    ✅ CNAME * → nanoserver.es  (ya está en IONOS)
#    ✅ A @ y www → DDNS del router
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${G}    ✓${NC} $1"; }
info() { echo -e "${C}    ▸ $1${NC}"; }
warn() { echo -e "${Y}    ⚠${NC} $1"; }

INTERNAL_IP="192.168.1.254"
DOMAIN="nanoserver.es"

# ── Instalar dnsmasq ──────────────────────────────────────────────────────────
info "Instalando dnsmasq..."
apt-get install -y -qq dnsmasq 2>&1 | grep -E "^(Inst|Conf)" | sed 's/^/    /' | head -3 || true
ok "dnsmasq instalado"

# ── Resolver conflicto con systemd-resolved ────────────────────────────────
# En Debian 13 systemd-resolved ocupa el puerto 53 como stub listener
info "Desactivando stub listener de systemd-resolved..."
mkdir -p /etc/systemd/resolved.conf.d/
cat > /etc/systemd/resolved.conf.d/no-stub.conf <<'RESOLVED'
[Resolve]
DNSStubListener=no
RESOLVED
systemctl restart systemd-resolved 2>/dev/null || true
sleep 1

# Verificar que el puerto 53 está libre
if ss -ulnp 2>/dev/null | grep -q ":53 "; then
    warn "Puerto 53 UDP aún ocupado — dnsmasq puede fallar"
    ss -ulnp | grep ":53 " | sed 's/^/    /'
fi

# ── Configurar dnsmasq ────────────────────────────────────────────────────────
info "Configurando dnsmasq wildcard *.${DOMAIN} → ${INTERNAL_IP}..."

cat > /etc/dnsmasq.d/erp-fincas.conf <<DNSMASQ
# ════════════════════════════════════════════════════════════════
#  dnsmasq — Resolución local para ERP Fincas
#  *.${DOMAIN} → ${INTERNAL_IP} (sin hairpin NAT)
# ════════════════════════════════════════════════════════════════

# Solo escuchar en localhost e IP interna
listen-address = 127.0.0.1,${INTERNAL_IP}
bind-interfaces

# ── Resolución wildcard ───────────────────────────────────────────────
# TODOS los subdominios de ${DOMAIN} → servidor local
# Esto incluye: admin, gestoria-demo, phpmyadmin, etc.
address = /${DOMAIN}/${INTERNAL_IP}

# ── DNS upstream para el resto ────────────────────────────────────────
server = 1.1.1.1
server = 8.8.8.8
server = 9.9.9.9

# No reenviar nombres locales al upstream
domain-needed
bogus-priv

# Cache de 512 entradas
cache-size = 512

# No leer /etc/hosts para las consultas DNS (usamos la configuración arriba)
# no-hosts
DNSMASQ

ok "Configuración dnsmasq creada"

# ── Actualizar /etc/hosts con dominios fijos ──────────────────────────────────
info "Actualizando /etc/hosts..."
cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d%H%M%S)

# Eliminar entradas previas del ERP
sed -i '/# ERP FINCAS START/,/# ERP FINCAS END/d' /etc/hosts

cat >> /etc/hosts <<HOSTS

# ERP FINCAS START — Resolución local (no modificar manualmente)
${INTERNAL_IP}  ${DOMAIN}
${INTERNAL_IP}  www.${DOMAIN}
${INTERNAL_IP}  admin.${DOMAIN}
${INTERNAL_IP}  phpmyadmin.${DOMAIN}
127.0.0.1       localhost
# ERP FINCAS END
HOSTS
ok "/etc/hosts actualizado"

# ── Configurar resolv.conf ────────────────────────────────────────────────────
info "Configurando resolv.conf para usar dnsmasq..."

# Detectar si resolv.conf es un symlink de systemd
if [[ -L /etc/resolv.conf ]]; then
    # Configurar a través de systemd-resolved
    cat > /etc/systemd/resolved.conf.d/dns-local.conf <<'RCONF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=1.1.1.1 8.8.8.8
Domains=~.
RCONF
    systemctl restart systemd-resolved 2>/dev/null || true
    ok "DNS configurado via systemd-resolved"
else
    cat > /etc/resolv.conf <<RESOLV
# Generado por instalador ERP Fincas — no modificar
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 8.8.8.8
search ${DOMAIN}
RESOLV
    # Proteger contra sobreescritura por DHCP
    chattr +i /etc/resolv.conf 2>/dev/null || true
    ok "resolv.conf configurado y protegido"
fi

# ── Iniciar dnsmasq ────────────────────────────────────────────────────────────
info "Iniciando dnsmasq..."
systemctl enable dnsmasq 2>/dev/null || true
systemctl restart dnsmasq
sleep 2

if systemctl is-active --quiet dnsmasq; then
    ok "dnsmasq activo"
else
    warn "dnsmasq no arrancó"
    journalctl -u dnsmasq --no-pager -n 5 | sed 's/^/    /'
fi

# ── Verificación ──────────────────────────────────────────────────────────────
info "Verificando resolución DNS local..."
sleep 1
for HOST in "${DOMAIN}" "admin.${DOMAIN}" "phpmyadmin.${DOMAIN}" "gestoria-demo.${DOMAIN}"; do
    RES=$(dig +short "@127.0.0.1" "$HOST" 2>/dev/null | tail -1)
    [[ "$RES" == "$INTERNAL_IP" ]] \
        && ok "    $HOST → $RES" \
        || warn "    $HOST → '${RES:-sin respuesta}' (esperado $INTERNAL_IP)"
done

# Verificar DNS externo
EXTERN=$(dig +short "@127.0.0.1" "debian.org" 2>/dev/null | tail -1)
[[ -n "$EXTERN" ]] \
    && ok "    DNS externo funciona (debian.org → $EXTERN)" \
    || warn "    DNS externo no responde — verificar conexión"

echo ""
ok "PASO 05 completado"
echo ""
echo "    *.${DOMAIN} → ${INTERNAL_IP}  (resuelto localmente)"
echo "    Upstream DNS: 1.1.1.1, 8.8.8.8, 9.9.9.9"

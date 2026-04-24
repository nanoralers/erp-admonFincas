#!/bin/bash
# ERP FINCAS — Verificación completa
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC}  $1"; ERRORS=$((ERRORS+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; WARNS=$((WARNS+1)); }
hdr()  { echo -e "\n${BOLD}${CYAN}▸ $1${NC}"; }
ERRORS=0; WARNS=0
PROJECT_DIR="/home/nano/www/erp-fincas"

echo -e "\n${BOLD}  ERP Fincas — Verificación del sistema${NC}"
echo "  ─────────────────────────────────────────────"
echo "  $(date '+%d/%m/%Y %H:%M:%S') · $(hostname)"
echo "  ─────────────────────────────────────────────"

hdr "PHP 8.4"
PHP_VER=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
[[ $(echo "$PHP_VER" | cut -d. -f1-2) == "8.4" ]] && ok "PHP $PHP_VER" || fail "PHP $PHP_VER (esperado 8.4)"
for EXT in pdo pdo_mysql mbstring json openssl curl gd zip intl bcmath opcache sodium; do
    php -m 2>/dev/null | grep -qi "^${EXT}$" && ok "  ext-${EXT}" || fail "  ext-${EXT}"
done

hdr "Apache"
systemctl is-active --quiet apache2 && ok "Apache activo" || fail "Apache NO activo"
apache2ctl configtest 2>&1 | grep -q "Syntax OK" && ok "Sintaxis OK" || fail "Error de sintaxis — apache2ctl configtest"
for MOD in rewrite headers expires deflate ssl; do
    apache2ctl -M 2>/dev/null | grep -q "${MOD}_module" && ok "  mod_${MOD}" || fail "  mod_${MOD}"
done
for VH in nanoserver_es.conf phpmyadmin.nanoserver.es.conf; do
    [[ -f "/etc/apache2/sites-enabled/$VH" ]] && ok "  $VH habilitado" || fail "  $VH NO habilitado"
done

hdr "MariaDB 11.8"
systemctl is-active --quiet mariadb && ok "MariaDB activo" || fail "MariaDB NO activo"
DB_VER=$(mysql --version 2>/dev/null | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)
[[ -n "$DB_VER" ]] && ok "MariaDB $DB_VER" || warn "No se detectó versión"
if [[ -f "$PROJECT_DIR/.env" ]]; then
    DB_HOST=$(grep "^DB_HOST=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_NAME=$(grep "^DB_NAME=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_USER=$(grep "^DB_USER=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    DB_PASS=$(grep "^DB_PASS=" "$PROJECT_DIR/.env" | cut -d= -f2-)
    mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1;" &>/dev/null \
        && ok "Conexión BD '$DB_NAME'" || fail "No se puede conectar a la BD"
    TABLES=$(mysql -h"${DB_HOST:-localhost}" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SHOW TABLES;" 2>/dev/null | wc -l)
    [[ $TABLES -ge 20 ]] && ok "$TABLES tablas" || fail "Solo $TABLES tablas (¿schema importado?)"
else
    warn "Sin .env — no se verifica BD"
fi

hdr "Archivos ERP"
for F in index.php config/config.php .env core/Database.php core/Auth.php \
          core/SubdomainResolver.php core/Router.php public/index.php \
          public/.htaccess public/css/app.css public/js/app.js install/schema.sql admin/routes.php; do
    [[ -f "$PROJECT_DIR/$F" ]] && ok "$F" || fail "FALTA: $F"
done
for D in uploads cache logs; do
    [[ -w "$PROJECT_DIR/$D" ]] && ok "$D/ escribible" || fail "$D/ NO escribible"
done

hdr "phpMyAdmin"
if dpkg -l phpmyadmin 2>/dev/null | grep -q "^ii"; then
    PMA_VER=$(dpkg -l phpmyadmin 2>/dev/null | grep "^ii" | awk '{print $3}')
    ok "phpMyAdmin $PMA_VER instalado"
    [[ -f "/usr/share/phpmyadmin/index.php" ]] && ok "Archivos en /usr/share/phpmyadmin/" || fail "Archivos phpMyAdmin no encontrados"
    [[ -f "/etc/phpmyadmin/conf.d/erp-fincas.php" ]] && ok "Config personalizada activa" || warn "Config personalizada no encontrada"
else
    fail "phpMyAdmin NO instalado → ejecutar 09-phpmyadmin.sh"
fi

hdr "SSL"
for CERT in "nanoserver.es" "nanoserver.es-wildcard"; do
    CPATH="/etc/letsencrypt/live/$CERT/fullchain.pem"
    if [[ -f "$CPATH" ]]; then
        EXPIRY=$(openssl x509 -enddate -noout -in "$CPATH" 2>/dev/null | cut -d= -f2)
        DAYS=$(( ( $(date -d "$EXPIRY" +%s 2>/dev/null) - $(date +%s) ) / 86400 ))
        openssl x509 -text -noout -in "$CPATH" 2>/dev/null | grep -qi "fake\|self-signed" \
            && warn "$CERT — TEMPORAL auto-firmado ($DAYS días) → ssl-wildcard.sh" \
            || { [[ $DAYS -gt 30 ]] && ok "$CERT — válido $DAYS días" || warn "$CERT — expira en $DAYS días"; }
    else
        [[ "$CERT" == "nanoserver.es-wildcard" ]] \
            && fail "Cert wildcard no encontrado → sudo bash 03-scripts-despliegue/ssl-wildcard.sh" \
            || warn "Cert $CERT no encontrado"
    fi
done

hdr "DNS local (dnsmasq)"
systemctl is-active --quiet dnsmasq && ok "dnsmasq activo" || fail "dnsmasq NO activo"
MY_IP="192.168.1.254"
for HOST in nanoserver.es admin.nanoserver.es phpmyadmin.nanoserver.es demo.nanoserver.es; do
    R=$(dig +short "@127.0.0.1" "$HOST" 2>/dev/null | tail -1)
    [[ "$R" == "$MY_IP" ]] && ok "  $HOST → $R" || warn "  $HOST → '${R:-sin respuesta}'"
done

hdr "Firewall UFW"
ufw status 2>/dev/null | head -1 | grep -qi "active" && ok "UFW activo" || warn "UFW inactivo"
for P in 22 80 443; do
    ufw status 2>/dev/null | grep -q "^$P" && ok "  Puerto $P" || warn "  Puerto $P no en UFW"
done

hdr "Conectividad HTTP(S)"
for URL in "nanoserver.es" "admin.nanoserver.es" "phpmyadmin.nanoserver.es"; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
        -H "Host: $URL" "http://127.0.0.1/" 2>/dev/null || echo "000")
    case $CODE in
        200|301|302) ok "https://$URL → $CODE" ;;
        000) fail "https://$URL → Sin respuesta" ;;
        *) warn "https://$URL → HTTP $CODE" ;;
    esac
done

echo ""
echo "  ─────────────────────────────────────────────"
if [[ $ERRORS -eq 0 && $WARNS -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓  TODO CORRECTO — Sistema listo${NC}"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}⚠  $WARNS advertencia(s)${NC}"
else
    echo -e "  ${RED}${BOLD}✗  $ERRORS error(es), $WARNS advertencia(s)${NC}"
fi
echo ""
echo "    https://nanoserver.es              Sitio principal"
echo "    https://admin.nanoserver.es        Panel ERP admin"
echo "    https://phpmyadmin.nanoserver.es   phpMyAdmin"
echo ""

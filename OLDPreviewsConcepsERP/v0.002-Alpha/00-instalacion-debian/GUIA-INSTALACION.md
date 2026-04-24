# 📋 GUÍA DE INSTALACIÓN — Debian 13 limpio
## ERP Fincas · nanoserver.es · IP interna 192.168.1.254

---

## ⚡ Instalación en un comando

```bash
cd erp-fincas-FINAL/00-instalacion-debian
sudo bash 00-instalador-maestro.sh
```

Duración aproximada: **8-15 minutos** según velocidad de conexión.

---

## 📋 Punto de partida (tu servidor actual)

| Componente | Estado | Notas |
|---|---|---|
| Debian 13 Trixie | ✅ Instalado | Limpio |
| Apache 2.4 | ✅ Instalado | Sin módulos |
| MariaDB | ✅ Instalado | Sin configurar |
| SSH | ✅ Activo | Acceso por PuTTY |
| PHP | ❌ | Lo instala el script |
| Certbot / SSL | ❌ | Lo instala el script |
| UFW / Fail2Ban | ❌ | Lo instala el script |
| dnsmasq | ❌ | Lo instala el script |

---

## 🔢 Qué hace cada script

| Script | Qué instala/configura | Tiempo |
|---|---|---|
| `01-sistema-base.sh` | apt update, herramientas, zona horaria, usuario `nano`, directorios | ~3 min |
| `02-php83.sh` | PHP 8.3 + 14 extensiones, php.ini, OPcache | ~3 min |
| `03-apache-modulos.sh` | 8 módulos Apache, security headers, VirtualHost | ~1 min |
| `04-mariadb.sh` | mysql_secure_installation, BD `erp_fincas`, usuario, schema SQL, optimización | ~2 min |
| `05-dns-local.sh` | dnsmasq, `*.nanoserver.es → 192.168.1.254`, resolv.conf | ~1 min |
| `06-seguridad.sh` | UFW (22/80/443), Fail2Ban, hardening SSH/kernel | ~2 min |
| `07-certbot.sh` | Certbot, cert temporal wildcard para que Apache arranque | ~1 min |
| `08-desplegar-erp.sh` | Copiar archivos, generar `.env`, permisos finales, recarga servicios | ~1 min |

---

## 🌐 Red y DNS

```
Internet → 79.117.59.24 (IP dinámica)
              ↓
           Router DDNS (IONOS actualiza automáticamente)
              ↓  puertos 80, 443 → NAT
         192.168.1.254 (tu servidor Debian)
              ↓
           Apache 2.4
              ↓
          ERP Fincas
```

**DNS local (dnsmasq):**
```
*.nanoserver.es → 192.168.1.254  (resuelto localmente)
resto           → 1.1.1.1        (Cloudflare)
```

---

## 🔓 Puertos abiertos en UFW

| Puerto | Protocolo | Para qué |
|--------|-----------|----------|
| 22     | TCP | SSH (PuTTY) |
| 80     | TCP | HTTP → redirige a HTTPS |
| 443    | TCP | HTTPS (ERP Fincas) |
| 53     | UDP/TCP | DNS local (solo red interna 192.168.1.0/24) |

---

## ✅ Después de la instalación

```bash
# 1. Obtener certificado SSL wildcard REAL (obligatorio para HTTPS)
sudo bash ../03-scripts-despliegue/ssl-wildcard.sh

# 2. Verificar todo el sistema
bash ../03-scripts-despliegue/verificar.sh

# 3. Borrar credenciales temporales
rm -f /root/.erp-fincas-db-credentials

# 4. Configurar contraseña del correo en el .env
nano /home/nano/www/erp-fincas/.env
```

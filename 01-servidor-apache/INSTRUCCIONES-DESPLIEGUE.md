# 📋 GUÍA COMPLETA DE DESPLIEGUE Y SSL WILDCARD
## ERP Fincas en nanoserver.es — Adaptado a tu configuración actual

---

## 🔍 ANÁLISIS DE TU CONFIGURACIÓN ACTUAL

### Lo que tienes
- ✅ Apache2 (Debian) con estructura estándar `/etc/apache2/sites-enabled/`
- ✅ SSL Let's Encrypt activo para `nanoserver.es` y `www.nanoserver.es`
- ✅ Certificado en `/etc/letsencrypt/live/nanoserver.es/`
- ✅ DocumentRoot en `/home/nano/www/html`
- ✅ Logs en `/home/nano/www/logs/`
- ✅ `AllowOverride All` activo globalmente en `/`
- ✅ mod_rewrite cargado (ya lo usas en el VirtualHost HTTP)

### Lo que falta para el ERP
- ❌ Soporte wildcard `*.nanoserver.es` (subdominios por gestora)
- ❌ Certificado SSL wildcard para `*.nanoserver.es`
- ❌ VirtualHost separado para el ERP
- ❌ Despliegue del proyecto en `/home/nano/www/erp-fincas/`

---

## 📁 ESTRUCTURA DE DIRECTORIOS EN EL SERVIDOR

```
/home/nano/www/
├── html/                    ← Tu sitio actual (intacto)
├── logs/
│   ├── error.log            ← Logs actuales
│   ├── access.log
│   ├── erp-error.log        ← Nuevos logs del ERP (se crean solos)
│   ├── erp-access.log
│   └── erp-php-errors.log
└── erp-fincas/              ← ERP (nuevo directorio)
    ├── config/
    │   └── config.php
    ├── core/
    ├── controllers/
    ├── views/
    ├── uploads/
    ├── logs → ../logs/      ← Enlace simbólico (opcional)
    ├── cache/
    ├── install/
    ├── routes/
    ├── .env                 ← Tus credenciales reales (NO subir a git)
    └── public/              ← Document root del VirtualHost
        ├── index.php
        ├── .htaccess
        ├── css/
        └── js/
```

---

## 🚀 PASO 1 — Desplegar el proyecto

```bash
# En el servidor, como usuario nano o root
cd /home/nano/www/

# Descomprimir el ERP
tar -xzf erp-fincas.tar.gz

# Verificar estructura
ls -la erp-fincas/

# Crear directorios necesarios
mkdir -p erp-fincas/uploads/{logos,docs,avatars}
mkdir -p erp-fincas/cache

# Permisos correctos (www-data es el usuario de Apache en Debian)
chown -R nano:www-data erp-fincas/
find erp-fincas/ -type d -exec chmod 755 {} \;
find erp-fincas/ -type f -exec chmod 644 {} \;

# Permisos de escritura para uploads y cache
chmod -R 775 erp-fincas/uploads/
chmod -R 775 erp-fincas/cache/
chmod 664 erp-fincas/.env   # Solo legible por dueño y grupo
```

---

## 🗄️ PASO 2 — Base de datos

```bash
# Conectar como root de MySQL
mysql -u root -p

# Crear DB y usuario
CREATE DATABASE erp_fincas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'erp_user'@'localhost' IDENTIFIED BY 'TU_PASSWORD_SEGURA_AQUI';
GRANT ALL PRIVILEGES ON erp_fincas.* TO 'erp_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Importar el schema
mysql -u erp_user -p erp_fincas < /home/nano/www/erp-fincas/install/schema.sql

# Verificar tablas importadas
mysql -u erp_user -p erp_fincas -e "SHOW TABLES;"
```

---

## 📝 PASO 3 — Archivo .env

```bash
# Crear el .env a partir del ejemplo
cp /home/nano/www/erp-fincas/.env.example /home/nano/www/erp-fincas/.env

# Editar con tus valores reales
nano /home/nano/www/erp-fincas/.env
```

Contenido del `.env` (ajusta los valores):

```env
APP_ENV=production
APP_DEBUG=false
BASE_DOMAIN=nanoserver.es

DB_HOST=localhost
DB_PORT=3306
DB_NAME=erp_fincas
DB_USER=erp_user
DB_PASS=TU_PASSWORD_SEGURA_AQUI

MAIL_HOST=smtp.nanoserver.es
MAIL_PORT=587
MAIL_USERNAME=noreply@nanoserver.es
MAIL_PASSWORD=TU_PASSWORD_CORREO

# Genera con: php -r "echo bin2hex(random_bytes(16));"
ENCRYPTION_KEY=GENERA_CLAVE_ALEATORIA_32_CHARS
```

**Generar ENCRYPTION_KEY:**
```bash
php -r "echo bin2hex(random_bytes(16)) . PHP_EOL;"
```

---

## 🔐 PASO 4 — Certificado SSL Wildcard *.nanoserver.es

Este es el paso más importante. Tu certificado actual solo cubre `nanoserver.es` y `www.nanoserver.es`. Necesitas uno wildcard para los subdominios del ERP.

### ⚠️ Requisito: DNS Challenge
Los certificados wildcard de Let's Encrypt **requieren validación DNS** (no HTTP). Necesitas acceso a la zona DNS de tu dominio para añadir registros TXT temporales.

### Opción A — Certbot manual (si tienes acceso al panel DNS)

```bash
# Instalar certbot si no está (en Debian/Ubuntu)
sudo apt install certbot python3-certbot-apache -y

# Solicitar certificado wildcard con validación DNS manual
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d "nanoserver.es" \
  -d "*.nanoserver.es" \
  --cert-name nanoserver.es-wildcard

# Certbot te pedirá que añadas un registro TXT en tu DNS:
# _acme-challenge.nanoserver.es  →  [VALOR_QUE_TE_DA_CERTBOT]
# 
# Añade el registro, espera 1-2 min a que propague, luego pulsa ENTER
```

El certificado se guardará en:
```
/etc/letsencrypt/live/nanoserver.es-wildcard/fullchain.pem
/etc/letsencrypt/live/nanoserver.es-wildcard/privkey.pem
```

### Opción B — Certbot con plugin DNS automático (recomendado para renovación automática)

Si tu DNS está en Cloudflare, OVH, Namecheap, etc., existe un plugin de certbot que lo hace todo automático.

**Ejemplo con Cloudflare:**
```bash
# Instalar plugin
sudo apt install python3-certbot-dns-cloudflare -y

# Crear credenciales
sudo nano /etc/letsencrypt/cloudflare.ini
# Añadir:
# dns_cloudflare_email = tu@email.com
# dns_cloudflare_api_key = TU_API_KEY_CLOUDFLARE

sudo chmod 600 /etc/letsencrypt/cloudflare.ini

# Obtener certificado wildcard
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  -d "nanoserver.es" \
  -d "*.nanoserver.es" \
  --cert-name nanoserver.es-wildcard
```

### Verificar el certificado obtenido

```bash
sudo certbot certificates

# Debes ver algo como:
# Certificate Name: nanoserver.es-wildcard
#   Domains: nanoserver.es, *.nanoserver.es
#   Expiry Date: 2025-07-XX
#   Certificate Path: /etc/letsencrypt/live/nanoserver.es-wildcard/fullchain.pem
```

---

## ⚙️ PASO 5 — Actualizar configuración Apache

### 5a. Verificar módulos necesarios
```bash
# Comprobar módulos activos
apache2ctl -M | grep -E "rewrite|headers|expires|deflate|ssl"

# Activar los que falten
sudo a2enmod rewrite headers expires deflate
```

### 5b. Instalar el nuevo VirtualHost
```bash
# Copiar el archivo de configuración del ERP
sudo cp /ruta/a/nanoserver_es.conf /etc/apache2/sites-available/nanoserver_es.conf

# Si ya existe y está habilitado, solo sobreescribir
# (el enlace simbólico en sites-enabled apuntará al nuevo)
sudo cp /ruta/a/nanoserver_es.conf /etc/apache2/sites-available/nanoserver_es.conf

# Si no está habilitado aún:
sudo a2ensite nanoserver_es.conf
```

### 5c. Instalar el .htaccess del ERP
```bash
# Copiar el .htaccess a la carpeta public del ERP
cp /ruta/a/public-.htaccess /home/nano/www/erp-fincas/public/.htaccess
```

### 5d. Instalar los archivos PHP actualizados
```bash
# config.php actualizado con las rutas reales
cp /ruta/a/config.php /home/nano/www/erp-fincas/config/config.php

# Auth.php con SESSION_DOMAIN correcto para subdominios
cp /ruta/a/Auth.php /home/nano/www/erp-fincas/core/Auth.php
```

### 5e. Verificar y recargar Apache
```bash
# Comprobar sintaxis (MUY IMPORTANTE antes de recargar)
sudo apache2ctl configtest

# Si dice "Syntax OK":
sudo systemctl reload apache2

# Verificar que esté corriendo
sudo systemctl status apache2
```

---

## 🌐 PASO 6 — DNS Wildcard

Para que `*.nanoserver.es` apunte a tu servidor, necesitas un registro DNS wildcard.

En tu panel de DNS (Cloudflare, OVH, Namecheap, etc.), añade:

| Tipo | Nombre | Valor          | TTL  |
|------|--------|----------------|------|
| A    | `*`    | `TU.IP.DEL.VPS`| 3600 |
| A    | `@`    | `TU.IP.DEL.VPS`| 3600 |
| A    | `www`  | `TU.IP.DEL.VPS`| 3600 |

**Verificar tu IP actual:**
```bash
curl -s ifconfig.me
# o
ip addr show | grep "inet " | grep -v 127.0.0.1
```

**Verificar propagación DNS:**
```bash
# Desde el servidor o tu máquina local
dig admin.nanoserver.es
dig gestoria-demo.nanoserver.es
# Ambos deben apuntar a la misma IP del servidor
```

---

## ✅ PASO 7 — Verificación final

```bash
# 1. Probar acceso a la landing (dominio raíz)
curl -I https://nanoserver.es

# 2. Probar acceso al panel admin del ERP
curl -I https://admin.nanoserver.es

# 3. Simular acceso de un tenant
curl -I https://demo.nanoserver.es

# 4. Verificar que HTTP redirige a HTTPS
curl -I http://demo.nanoserver.es
# Debe responder: HTTP/1.1 301 Moved Permanently + Location: https://...

# 5. Verificar logs del ERP
tail -f /home/nano/www/logs/erp-error.log
tail -f /home/nano/www/logs/erp-access.log

# 6. Verificar SSL del wildcard
echo | openssl s_client -connect admin.nanoserver.es:443 2>/dev/null | openssl x509 -noout -subject -issuer
```

---

## 🔄 Renovación automática del certificado wildcard

Si usaste el método manual (Opción A), la renovación automática NO funciona sola. Configura un cron job:

```bash
# Si usas plugin DNS automático (Opción B), certbot se renueva solo.
# Verificar que el cron de certbot esté activo:
sudo systemctl status certbot.timer
sudo certbot renew --dry-run

# Si usaste Opción A (manual), añadir recordatorio:
# crontab -e
# 0 3 1 * * /usr/bin/certbot renew --manual --preferred-challenges dns 2>&1 >> /home/nano/www/logs/certbot.log
```

---

## 🐛 Troubleshooting

### Error: "403 Forbidden" al acceder al ERP
```bash
# Verificar permisos
ls -la /home/nano/www/erp-fincas/public/
# El usuario www-data debe poder leer los archivos

# Solución:
sudo chown -R nano:www-data /home/nano/www/erp-fincas/
sudo chmod -R 755 /home/nano/www/erp-fincas/public/
```

### Error: "500 Internal Server Error"
```bash
# Revisar logs de PHP
tail -50 /home/nano/www/logs/erp-php-errors.log
tail -50 /home/nano/www/logs/erp-error.log

# Activar debug temporalmente (solo para diagnóstico):
# En .env: APP_DEBUG=true
# Recuerda desactivarlo después
```

### Error: "No input file specified" o "Not Found"
```bash
# Verificar que el DocumentRoot apunta a /public y no a la raíz
grep -n DocumentRoot /etc/apache2/sites-enabled/nanoserver_es.conf

# Verificar que el .htaccess existe y tiene permisos
ls -la /home/nano/www/erp-fincas/public/.htaccess
cat /home/nano/www/erp-fincas/public/.htaccess
```

### Error: Subdominio no resuelve
```bash
# Verificar DNS
dig *.nanoserver.es
dig admin.nanoserver.es

# Verificar que el VirtualHost tiene ServerAlias correcto
grep -n ServerAlias /etc/apache2/sites-enabled/nanoserver_es.conf
```

### Error: Sesión no persiste entre páginas
```bash
# Verificar que SESSION_DOMAIN es '.nanoserver.es' (con punto)
# Verificar que SESSION_SECURE=true (requiere HTTPS)
# Verificar que las cookies se están enviando:
curl -v https://admin.nanoserver.es/login 2>&1 | grep -i "set-cookie"
```

---

## 📊 Resumen de archivos generados

| Archivo                    | Destino en el servidor                                          |
|----------------------------|-----------------------------------------------------------------|
| `nanoserver_es.conf`       | `/etc/apache2/sites-available/nanoserver_es.conf`              |
| `public-.htaccess`         | `/home/nano/www/erp-fincas/public/.htaccess`                   |
| `config.php`               | `/home/nano/www/erp-fincas/config/config.php`                  |
| `Auth.php`                 | `/home/nano/www/erp-fincas/core/Auth.php`                      |
| `erp-fincas.tar.gz`        | Extraer en `/home/nano/www/erp-fincas/`                        |
| `.env` (crear desde .example) | `/home/nano/www/erp-fincas/.env`                            |

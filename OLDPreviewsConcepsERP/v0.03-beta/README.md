# 🚀 ERP FINCAS — LÉEME PRIMERO
## Debian 13 Trixie · nanoserver.es · IP interna 192.168.1.254

## ✅ Estado DNS IONOS (ya configurado, NO tocar nada)

| Tipo | Host | Valor | Estado |
|------|------|-------|--------|
| `A` | `@` | IP dinámica | ✅ DDNS automático |
| `A` | `www` | IP dinámica | ✅ DDNS automático |
| `CNAME` | `*` | `nanoserver.es` | ✅ Wildcard subdominios |
| TXT | `@` | SPF, MS, OpenAI | ✅ Ya configurados |

## ⚡ Instalación en un comando

```bash
cd erp-fincas-FINAL/00-instalacion-debian
chmod +x *.sh
sudo bash 00-instalador-maestro.sh
# Después:
sudo bash ../03-scripts-despliegue/ssl-wildcard.sh
bash ../03-scripts-despliegue/verificar.sh
```

## 🔢 Versiones (confirmadas Debian 13 Trixie, abril 2026)

| Componente | Versión | Fuente |
|---|---|---|
| PHP | **8.4.16** | Repos oficiales Debian 13 — sin Sury |
| Apache | **2.4.x** | Repos oficiales |
| MariaDB | **11.8.x** | Repos oficiales Debian 13 |
| phpMyAdmin | **5.2.3** | trixie-backports |
| Certbot | último | Repos oficiales |

## 📂 Estructura del paquete

```
erp-fincas-FINAL/
├── LEEME-PRIMERO.md
├── 00-instalacion-debian/      ← Instala TODO desde cero
│   ├── 00-instalador-maestro.sh
│   ├── 01-sistema-base.sh      (backports, herramientas, usuario nano)
│   ├── 02-php84.sh             (PHP 8.4 repos oficiales)
│   ├── 03-apache-modulos.sh    (módulos + hardening)
│   ├── 04-mariadb.sh           (MariaDB 11.8 + BD + schema)
│   ├── 05-dns-local.sh         (dnsmasq wildcard *.nanoserver.es)
│   ├── 06-seguridad.sh         (UFW + Fail2Ban + kernel)
│   ├── 07-certbot.sh           (Certbot + cert temporal)
│   ├── 08-desplegar-erp.sh     (archivos + .env)
│   └── 09-phpmyadmin.sh        (phpMyAdmin 5.2.3)
├── 01-servidor-apache/
│   └── nanoserver_es.conf      (VirtualHost ERP actualizado)
├── 02-proyecto-erp/            (Código fuente completo ERP)
├── 03-scripts-despliegue/
│   ├── ssl-wildcard.sh         (SSL wildcard real — obligatorio)
│   ├── verificar.sh            (Verificación completa)
│   └── deploy.sh               (Redespliegue rápido)
└── 04-vhosts-apache/           ← NUEVO
    └── phpmyadmin.nanoserver.es.conf
```

## 🌐 URLs disponibles

| URL | Descripción |
|-----|-------------|
| `https://nanoserver.es` | Sitio principal |
| `https://admin.nanoserver.es` | Panel superadmin ERP |
| `https://gestoria.nanoserver.es` | Tenant ERP (ejemplo) |
| `https://phpmyadmin.nanoserver.es` | phpMyAdmin |

## ⚠️ Tras la instalación

```bash
sudo bash 03-scripts-despliegue/ssl-wildcard.sh   # SSL real
nano /home/nano/www/erp-fincas/.env               # Configurar SMTP
rm -f /root/.erp-fincas-db-credentials            # Borrar creds temp
```

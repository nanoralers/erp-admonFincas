# 🚀 ERP FINCAS — LÉEME PRIMERO
## Guía de inicio rápido · nanoserver.es

---

## 📁 Contenido de este paquete

```
erp-fincas-FINAL/
│
├── 📂 01-servidor-apache/
│   ├── nanoserver_es.conf          → Configuración Apache completa (3 VirtualHosts)
│   └── INSTRUCCIONES-DESPLIEGUE.md → Guía detallada paso a paso
│
├── 📂 02-proyecto-erp/             → Código fuente completo del ERP
│   ├── config/config.php           ★ Adaptado a /home/nano/www/
│   ├── core/Auth.php               ★ SESSION_DOMAIN correcto para subdominios
│   ├── public/.htaccess            ★ Adaptado a tu Apache y rutas reales
│   ├── core/                       → Database, Router, SubdomainResolver, helpers
│   ├── controllers/                → Auth, Dashboard (+ carpetas para módulos)
│   ├── views/                      → Login, Layout, Dashboard, Errores
│   ├── public/css/app.css          → Sistema de diseño completo (~1700 líneas)
│   ├── public/js/app.js            → UI, notificaciones, búsqueda, modales
│   ├── routes/                     → 80+ endpoints definidos
│   ├── install/schema.sql          → 27 tablas + datos iniciales
│   ├── install/install.sh          → Script de instalación manual
│   ├── .env.example                → Plantilla de configuración
│   └── README.md                   → Documentación completa del proyecto
│
└── 📂 03-scripts-despliegue/
    ├── deploy.sh                   → Despliegue automático completo ⭐
    ├── ssl-wildcard.sh             → Obtención certificado wildcard ⭐
    └── verificar.sh                → Comprobación de todo el sistema ⭐
```

> **★** = Archivo actualizado/adaptado específicamente para tu servidor

---

## ⚡ INICIO RÁPIDO — Orden de ejecución

### En tu servidor, como root:

```bash
# 1. Subir y descomprimir este ZIP
unzip erp-fincas-FINAL.zip -d /tmp/erp-fincas
cd /tmp/erp-fincas

# 2. Dar permisos de ejecución a los scripts
chmod +x 03-scripts-despliegue/*.sh

# 3. Desplegar el proyecto (archivos + BD + Apache)
sudo bash 03-scripts-despliegue/deploy.sh

# 4. Obtener el certificado SSL wildcard *.nanoserver.es
sudo bash 03-scripts-despliegue/ssl-wildcard.sh

# 5. Verificar que todo funciona
bash 03-scripts-despliegue/verificar.sh
```

---

## 📋 Estado del DNS (ya configurado ✅)

Tu DNS en IONOS ya está correcto. No hay que tocar nada más:

| Registro | Host | Valor | Para qué |
|----------|------|-------|----------|
| `A`      | `@`  | IP dinámica | nanoserver.es |
| `A`      | `www`| IP dinámica | www.nanoserver.es |
| `CNAME`  | `*`  | nanoserver.es | **Todos los subdominios del ERP** ✅ |

El wildcard `*` ya cubre automáticamente:
- `admin.nanoserver.es` → Panel superadministrador
- `gestoria-perez.nanoserver.es` → Cualquier gestora del ERP
- `demo.nanoserver.es` → Demo / pruebas

---

## 🔐 SSL — Lo único que falta

El DNS ya funciona. Solo necesitas el certificado wildcard. El script `ssl-wildcard.sh` lo guía, pero en resumen:

1. Ejecutas el script
2. Certbot te da un **valor TXT** para `_acme-challenge`
3. Lo añades en IONOS → DNS (30 segundos de trabajo)
4. Esperas 2 min, pulsas Enter
5. Certificado instalado para 90 días

---

## 🗂️ Dónde va cada archivo en el servidor

| Archivo del paquete | Destino en el servidor |
|---------------------|------------------------|
| `01-servidor-apache/nanoserver_es.conf` | `/etc/apache2/sites-available/` |
| `02-proyecto-erp/` (todo) | `/home/nano/www/erp-fincas/` |
| Crear `.env` desde `.env.example` | `/home/nano/www/erp-fincas/.env` |

---

## 🔑 Primer acceso tras el despliegue

Una vez todo esté arriba:

- **URL Admin**: `https://admin.nanoserver.es`
- **Email**: `admin@nanoserver.es`
- **Password**: definida en el schema SQL (cámbiala inmediatamente)

Para crear la primera gestora:
1. Accede al panel admin
2. Crea una gestora con subdominio (ej: `demo`)
3. Accede a `https://demo.nanoserver.es`

---

## 📞 Archivos de log para diagnóstico

```bash
tail -f /home/nano/www/logs/erp-error.log      # Errores Apache del ERP
tail -f /home/nano/www/logs/erp-php-errors.log # Errores PHP del ERP
tail -f /home/nano/www/logs/erp-access.log     # Accesos al ERP
sudo journalctl -u apache2 -f                  # Log general de Apache
```

---

*ERP Fincas v1.0.0 · Adaptado para nanoserver.es · Abril 2025*

# ERP FINCAS - Plataforma Modular SaaS para Administración de Fincas

Sistema ERP completo y modular diseñado para empresas de administración de fincas, con arquitectura multi-tenant (subdominio por cliente), personalización white-label, y 4 módulos principales: Económica y Contable, Mantenimiento y Técnica, Jurídica y Legal, y Gestión Administrativa.

---

## 🎯 Características Principales

### Arquitectura Multi-Tenant
- **Subdominios por cliente**: Cada gestora accede vía `https://nombregestora.nanoserver.es`
- **Aislamiento de datos**: Base de datos única con separación lógica por `gestora_id`
- **Personalización total**: Logo, colores, favicon y nombre de la aplicación por cliente

### Sistema de Planes y Módulos
- **4 Planes**: Starter, Profesional, Business, Enterprise
- **Módulos activables**: Cada plan incluye diferentes combinaciones de módulos
- **Escalabilidad**: Fácil upgrade entre planes

### Módulos Funcionales

#### 📊 Económica y Contable
- Presupuestos anuales por comunidad
- Emisión y gestión de recibos
- Remesas SEPA automatizadas
- Liquidaciones de cuentas anuales
- Movimientos contables
- Pago a proveedores

#### 🔧 Mantenimiento y Técnica
- Gestión de averías urgentes
- Contratos de servicios (limpieza, ascensores, etc.)
- Solicitud y seguimiento de presupuestos de obras
- Registro ITE/IEE
- Base de datos de proveedores con valoración

#### ⚖️ Jurídica y Legal
- Reclamación de cuotas a morosos
- Seguimiento de procedimientos judiciales
- Tramitación de siniestros con seguros
- Custodia de documentación legal
- Asesoramiento sobre Ley de Propiedad Horizontal

#### 📋 Gestión Administrativa
- Convocatoria de Juntas (ordinarias, extraordinarias, urgentes)
- Redacción y envío de actas
- Libro de actas digital
- Comunicaciones masivas (email, SMS, circulares)
- Ejecución y seguimiento de acuerdos
- Tareas y recordatorios

---

## 🛠️ Stack Tecnológico

- **Backend**: PHP 8.1+ (sin frameworks, arquitectura MVC limpia)
- **Frontend**: HTML5, CSS3 (variables CSS para theming), JavaScript vanilla
- **Base de datos**: MySQL 8 / MariaDB 10.6+
- **Fuentes**: Sora (Google Fonts) para UI elegante y moderna
- **Iconos**: Font Awesome 6.5
- **Arquitectura**: PSR-4 autoloading, Single Responsibility, Repository pattern

---

## 📦 Instalación

### Requisitos
- PHP 8.1 o superior con extensiones: `pdo_mysql`, `mbstring`, `json`
- MySQL 8.0+ o MariaDB 10.6+
- Servidor web: Apache con `mod_rewrite` o Nginx
- Composer (opcional, para futuras dependencias)

### Paso 1: Clonar el repositorio
```bash
git clone https://github.com/tu-usuario/erp-fincas.git
cd erp-fincas
```

### Paso 2: Configurar la base de datos
```bash
# Crear la base de datos y usuario
mysql -u root -p <<EOF
CREATE DATABASE erp_fincas CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'erp_user'@'localhost' IDENTIFIED BY 'TU_PASSWORD_SEGURA';
GRANT ALL PRIVILEGES ON erp_fincas.* TO 'erp_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Importar el schema
mysql -u erp_user -p erp_fincas < install/schema.sql
```

### Paso 3: Configurar variables de entorno
```bash
cp .env.example .env
nano .env
```

Ajusta los valores:
```env
APP_ENV=production
APP_DEBUG=false
BASE_DOMAIN=nanoserver.es

DB_HOST=localhost
DB_PORT=3306
DB_NAME=erp_fincas
DB_USER=erp_user
DB_PASS=TU_PASSWORD_SEGURA

MAIL_HOST=smtp.nanoserver.es
MAIL_PORT=587
MAIL_USERNAME=noreply@nanoserver.es
MAIL_PASSWORD=TU_PASSWORD_SMTP

ENCRYPTION_KEY=GENERA_UNA_CLAVE_ALEATORIA_32_CHARS
```

Generar encryption key:
```bash
php -r "echo bin2hex(random_bytes(16));"
```

### Paso 4: Configurar servidor web

#### Apache (.htaccess)
El sistema incluye `.htaccess` configurado. Asegúrate de que `AllowOverride All` esté habilitado en tu VirtualHost.

```apache
<VirtualHost *:80>
    ServerName nanoserver.es
    ServerAlias *.nanoserver.es
    DocumentRoot /var/www/erp-fincas/public
    
    <Directory /var/www/erp-fincas/public>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/erp-fincas-error.log
    CustomLog ${APACHE_LOG_DIR}/erp-fincas-access.log combined
</VirtualHost>
```

#### Nginx
```nginx
server {
    listen 80;
    server_name nanoserver.es *.nanoserver.es;
    root /var/www/erp-fincas/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### Paso 5: Configurar SSL (Producción)
```bash
sudo certbot --apache -d nanoserver.es -d *.nanoserver.es
# o con nginx:
sudo certbot --nginx -d nanoserver.es -d *.nanoserver.es
```

### Paso 6: Permisos de carpetas
```bash
chown -R www-data:www-data /var/www/erp-fincas
chmod -R 755 /var/www/erp-fincas
chmod -R 775 uploads logs cache
```

### Paso 7: Acceso inicial
1. Accede a `https://admin.nanoserver.es` (panel superadmin)
2. Usuario inicial: `admin@nanoserver.es`
3. Contraseña: (definida durante la instalación del schema)

---

## 🎨 Personalización White-Label

Cada gestora puede personalizar:
- **Logo**: Sube desde `/configuracion` → Branding
- **Colores**: 
  - Color primario (botones, enlaces)
  - Color secundario (sidebar, encabezados)
  - Color de acento (badges, notificaciones)
- **Nombre de la aplicación**: Aparece en el login y sidebar
- **Favicon**: Icono del navegador

Todo se almacena en la tabla `gestoras` y se carga dinámicamente vía CSS variables:
```css
:root {
  --c-primary:   <?= $gestora['color_primario'] ?>;
  --c-secondary: <?= $gestora['color_secundario'] ?>;
  --c-accent:    <?= $gestora['color_acento'] ?>;
}
```

---

## 📊 Estructura del Proyecto

```
erp-fincas/
├── admin/              # Panel superadministrador global
├── api/                # Endpoints JSON internos
├── config/             # Configuración (config.php, .env)
├── controllers/        # Controllers MVC
│   ├── Economica/
│   ├── Mantenimiento/
│   ├── Juridica/
│   └── Administrativa/
├── core/               # Clases core (Database, Auth, Router, etc.)
├── install/            # Schema SQL y scripts de instalación
├── modules/            # Módulos independientes (futuro)
├── public/             # Document root (index.php, assets)
│   ├── css/
│   ├── js/
│   └── img/
├── routes/             # Definición de rutas
│   ├── app.php         # Rutas de la app tenant
│   ├── public.php      # Landing / marketing
│   └── admin.php       # Rutas superadmin
├── uploads/            # Archivos subidos (logos, docs, etc.)
│   ├── logos/
│   ├── docs/
│   └── avatars/
├── views/              # Vistas PHP
│   ├── layouts/
│   ├── dashboard/
│   ├── economica/
│   ├── mantenimiento/
│   ├── juridica/
│   ├── administrativa/
│   └── errors/
├── logs/               # Logs de aplicación
├── cache/              # Cache temporal
├── .htaccess           # Rewrite rules Apache
└── README.md
```

---

## 🔐 Seguridad

- **CSRF Protection**: Tokens en todos los formularios
- **Password Hashing**: Bcrypt con cost 12
- **Session Security**: HttpOnly, Secure (HTTPS), SameSite
- **SQL Injection**: Prepared statements (PDO)
- **XSS Prevention**: htmlspecialchars en todas las salidas
- **Rate Limiting**: Intentos de login limitados (5 intentos → bloqueo 15 min)
- **2FA Ready**: Campos en BD para TOTP (por implementar en UI)

---

## 🚀 Roadmap / Próximas Funcionalidades

### Fase 2 (Q2 2025)
- [ ] API REST pública con OAuth2
- [ ] Exportación masiva (Excel, PDF, CSV)
- [ ] Generador de informes personalizados
- [ ] Portal del propietario (acceso lectura para residentes)
- [ ] App móvil (React Native)

### Fase 3 (Q3 2025)
- [ ] Integración con pasarelas de pago (Stripe, Redsys)
- [ ] Firma digital de actas y documentos
- [ ] Agenda compartida de eventos
- [ ] Chat interno entre administradores
- [ ] BI Dashboard con gráficos avanzados (Chart.js)

### Fase 4 (Q4 2025)
- [ ] Marketplace de proveedores verificados
- [ ] Sistema de cotizaciones y licitaciones
- [ ] Módulo de CRM (leads, prospectos)
- [ ] Integración con contabilidad externa (Sage, A3)

---

## 🧪 Testing

```bash
# Unit tests (PHPUnit - por configurar)
./vendor/bin/phpunit tests/

# Linting PHP
./vendor/bin/phpcs --standard=PSR12 core/ controllers/

# Test de carga (Apache Bench)
ab -n 1000 -c 10 https://demo.nanoserver.es/
```

---

## 📝 Convenciones de Código

- **PHP**: PSR-12, type hints estrictos, PHPDoc en clases públicas
- **SQL**: Snake_case para tablas y columnas
- **CSS**: Metodología BEM-light, variables CSS para theming
- **JavaScript**: ES6+, funciones puras cuando sea posible
- **Commits**: Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)

---

## 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama feature: `git checkout -b feature/nueva-funcionalidad`
3. Commit cambios: `git commit -am 'feat: añade exportación PDF de recibos'`
4. Push: `git push origin feature/nueva-funcionalidad`
5. Crea un Pull Request

---

## 📄 Licencia

Propietario © 2025 NanoServer Solutions. Todos los derechos reservados.

Este software es propietario. No se permite su distribución, modificación o uso comercial sin autorización expresa.

---

## 📞 Soporte

- **Email**: soporte@nanoserver.es
- **Documentación**: https://docs.erpfincas.nanoserver.es
- **Demo**: https://demo.nanoserver.es (usuario: `demo`, contraseña: `Demo123!`)

---

## 🙏 Agradecimientos

Desarrollado con dedicación por el equipo de NanoServer Solutions.

Tecnologías utilizadas:
- PHP (lenguaje backend)
- MariaDB (base de datos)
- Font Awesome (iconografía)
- Google Fonts (tipografía Sora)

---

**Versión**: 1.0.0  
**Última actualización**: Abril 2025

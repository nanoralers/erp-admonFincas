-- ============================================================
--  ERP FINCAS PLATFORM - Database Schema
--  Versión 1.0.0 | Motor: MariaDB / MySQL 8+
-- ============================================================

SET NAMES utf8mb4;
SET time_zone = '+02:00';
SET foreign_key_checks = 0;

CREATE DATABASE IF NOT EXISTS `erp_fincas`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `erp_fincas`;

-- ============================================================
--  PLANS & MODULES (SaaS tier system)
-- ============================================================

CREATE TABLE `planes` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre`        VARCHAR(60)  NOT NULL,
  `slug`          VARCHAR(60)  NOT NULL UNIQUE,
  `descripcion`   TEXT,
  `precio_mes`    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `precio_anual`  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `max_comunidades` INT UNSIGNED NOT NULL DEFAULT 10,
  `max_usuarios`    INT UNSIGNED NOT NULL DEFAULT 3,
  `max_storage_mb`  INT UNSIGNED NOT NULL DEFAULT 512,
  `color_badge`   VARCHAR(20)  NOT NULL DEFAULT '#3b82f6',
  `activo`        TINYINT(1)   NOT NULL DEFAULT 1,
  `orden`         INT UNSIGNED NOT NULL DEFAULT 0,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `modulos` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codigo`        VARCHAR(40)  NOT NULL UNIQUE,
  `nombre`        VARCHAR(80)  NOT NULL,
  `descripcion`   TEXT,
  `icono`         VARCHAR(60)  NOT NULL DEFAULT 'fa-cube',
  `color`         VARCHAR(20)  NOT NULL DEFAULT '#6366f1',
  `ruta_base`     VARCHAR(100) NOT NULL,
  `activo`        TINYINT(1)   NOT NULL DEFAULT 1,
  `orden`         INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `planes_modulos` (
  `plan_id`    INT UNSIGNED NOT NULL,
  `modulo_id`  INT UNSIGNED NOT NULL,
  PRIMARY KEY (`plan_id`, `modulo_id`),
  FOREIGN KEY (`plan_id`)   REFERENCES `planes`(`id`)  ON DELETE CASCADE,
  FOREIGN KEY (`modulo_id`) REFERENCES `modulos`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `acciones_modulo` (
  `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `modulo_id` INT UNSIGNED NOT NULL,
  `codigo`    VARCHAR(80)  NOT NULL,
  `nombre`    VARCHAR(120) NOT NULL,
  `descripcion` TEXT,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mod_codigo` (`modulo_id`, `codigo`),
  FOREIGN KEY (`modulo_id`) REFERENCES `modulos`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  GESTORAS (tenant / client companies)
-- ============================================================

CREATE TABLE `gestoras` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `plan_id`         INT UNSIGNED NOT NULL,
  `subdominio`      VARCHAR(60)  NOT NULL UNIQUE,
  `nombre`          VARCHAR(120) NOT NULL,
  `razon_social`    VARCHAR(150),
  `nif`             VARCHAR(20),
  `email_contacto`  VARCHAR(150) NOT NULL,
  `telefono`        VARCHAR(20),
  `direccion`       VARCHAR(200),
  `ciudad`          VARCHAR(80),
  `cp`              VARCHAR(10),
  `provincia`       VARCHAR(80),
  `pais`            VARCHAR(60)  NOT NULL DEFAULT 'España',
  -- Branding / white-label
  `logo_path`       VARCHAR(255),
  `favicon_path`    VARCHAR(255),
  `color_primario`  VARCHAR(7)   NOT NULL DEFAULT '#1e40af',
  `color_secundario` VARCHAR(7)  NOT NULL DEFAULT '#0f172a',
  `color_acento`    VARCHAR(7)   NOT NULL DEFAULT '#38bdf8',
  `fuente_principal` VARCHAR(60) NOT NULL DEFAULT 'Poppins',
  `nombre_app`      VARCHAR(80)  NOT NULL DEFAULT 'GestorFincas',
  -- Estado
  `activo`          TINYINT(1)   NOT NULL DEFAULT 1,
  `trial_hasta`     DATE,
  `suscripcion_desde` DATE,
  `suscripcion_hasta` DATE,
  -- Config
  `timezone`        VARCHAR(50)  NOT NULL DEFAULT 'Europe/Madrid',
  `moneda`          VARCHAR(3)   NOT NULL DEFAULT 'EUR',
  `idioma`          VARCHAR(5)   NOT NULL DEFAULT 'es_ES',
  `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`plan_id`) REFERENCES `planes`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Configuración extra por gestora (key-value)
CREATE TABLE `gestoras_config` (
  `gestora_id`  INT UNSIGNED NOT NULL,
  `clave`       VARCHAR(80)  NOT NULL,
  `valor`       TEXT,
  PRIMARY KEY (`gestora_id`, `clave`),
  FOREIGN KEY (`gestora_id`) REFERENCES `gestoras`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  USUARIOS
-- ============================================================

CREATE TABLE `roles` (
  `id`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codigo`   VARCHAR(40)  NOT NULL UNIQUE,
  `nombre`   VARCHAR(80)  NOT NULL,
  `nivel`    INT          NOT NULL DEFAULT 10,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `usuarios` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED,                 -- NULL = superadmin global
  `rol_id`          INT UNSIGNED NOT NULL,
  `nombre`          VARCHAR(80)  NOT NULL,
  `apellidos`       VARCHAR(120),
  `email`           VARCHAR(150) NOT NULL,
  `password_hash`   VARCHAR(255) NOT NULL,
  `avatar_path`     VARCHAR(255),
  `telefono`        VARCHAR(20),
  `activo`          TINYINT(1)   NOT NULL DEFAULT 1,
  `email_verified`  TINYINT(1)   NOT NULL DEFAULT 0,
  `2fa_secret`      VARCHAR(64),
  `2fa_enabled`     TINYINT(1)   NOT NULL DEFAULT 0,
  `ultimo_acceso`   DATETIME,
  `ip_ultimo_acceso` VARCHAR(45),
  `token_reset`     VARCHAR(64),
  `token_reset_exp` DATETIME,
  `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_email_gestora` (`gestora_id`, `email`),
  FOREIGN KEY (`gestora_id`) REFERENCES `gestoras`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`rol_id`)     REFERENCES `roles`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `sesiones` (
  `id`           VARCHAR(64)  NOT NULL,
  `usuario_id`   INT UNSIGNED NOT NULL,
  `ip`           VARCHAR(45),
  `user_agent`   VARCHAR(255),
  `payload`      TEXT,
  `expires_at`   DATETIME     NOT NULL,
  `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `audit_log` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`  INT UNSIGNED,
  `usuario_id`  INT UNSIGNED,
  `accion`      VARCHAR(80)  NOT NULL,
  `entidad`     VARCHAR(60),
  `entidad_id`  INT UNSIGNED,
  `datos_antes` JSON,
  `datos_despues` JSON,
  `ip`          VARCHAR(45),
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora_fecha` (`gestora_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  COMUNIDADES (buildings / HOAs)
-- ============================================================

CREATE TABLE `comunidades` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `codigo`          VARCHAR(20),
  `nombre`          VARCHAR(150) NOT NULL,
  `tipo`            ENUM('horizontal','vertical','mixta','unifamiliar','urbanizacion') NOT NULL DEFAULT 'horizontal',
  `nif`             VARCHAR(20),
  `direccion`       VARCHAR(200) NOT NULL,
  `ciudad`          VARCHAR(80),
  `cp`              VARCHAR(10),
  `provincia`       VARCHAR(80),
  `num_viviendas`   INT UNSIGNED NOT NULL DEFAULT 0,
  `num_locales`     INT UNSIGNED NOT NULL DEFAULT 0,
  `num_garajes`     INT UNSIGNED NOT NULL DEFAULT 0,
  `num_trasteros`   INT UNSIGNED NOT NULL DEFAULT 0,
  `superficie_total` DECIMAL(10,2),
  `cuota_mensual_defecto` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  -- Seguro
  `seguro_compania` VARCHAR(100),
  `seguro_poliza`   VARCHAR(50),
  `seguro_vencimiento` DATE,
  -- ITE / IEE
  `ite_realizada`   TINYINT(1) NOT NULL DEFAULT 0,
  `ite_fecha`       DATE,
  `ite_proxima`     DATE,
  `iee_realizada`   TINYINT(1) NOT NULL DEFAULT 0,
  `iee_fecha`       DATE,
  -- Cuentas bancarias
  `iban_principal`  VARCHAR(34),
  `banco_nombre`    VARCHAR(80),
  -- Estado
  `activo`          TINYINT(1) NOT NULL DEFAULT 1,
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora` (`gestora_id`),
  FOREIGN KEY (`gestora_id`) REFERENCES `gestoras`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  PROPIETARIOS / INQUILINOS
-- ============================================================

CREATE TABLE `propietarios` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`   INT UNSIGNED NOT NULL,
  `usuario_id`   INT UNSIGNED,               -- si tiene acceso al portal
  `tipo`         ENUM('propietario','inquilino','empresa') NOT NULL DEFAULT 'propietario',
  `nombre`       VARCHAR(80)  NOT NULL,
  `apellidos`    VARCHAR(120),
  `razon_social` VARCHAR(150),
  `nif`          VARCHAR(20),
  `email`        VARCHAR(150),
  `telefono`     VARCHAR(20),
  `telefono2`    VARCHAR(20),
  `direccion_fiscal` VARCHAR(200),
  `iban`         VARCHAR(34),
  `titular_cuenta` VARCHAR(150),
  `mandato_sepa` VARCHAR(50),
  `mandato_fecha` DATE,
  `acepta_notif_email` TINYINT(1) NOT NULL DEFAULT 1,
  `acepta_notif_sms`   TINYINT(1) NOT NULL DEFAULT 0,
  `moroso`       TINYINT(1) NOT NULL DEFAULT 0,
  `notas`        TEXT,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`) REFERENCES `gestoras`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `inmuebles` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `propietario_id` INT UNSIGNED,
  `inquilino_id`   INT UNSIGNED,
  `tipo`           ENUM('vivienda','local','garaje','trastero','otro') NOT NULL DEFAULT 'vivienda',
  `referencia`     VARCHAR(20) NOT NULL,  -- ej: "1A", "3B", "G-12"
  `planta`         VARCHAR(10),
  `puerta`         VARCHAR(10),
  `superficie`     DECIMAL(8,2),
  `coeficiente`    DECIMAL(8,5) NOT NULL DEFAULT 0.00000,  -- % participación
  `cuota_mensual`  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `iban_cobro`     VARCHAR(34),
  `mandato_sepa`   VARCHAR(50),
  `activo`         TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_com_ref` (`comunidad_id`, `referencia`),
  FOREIGN KEY (`comunidad_id`)   REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`propietario_id`) REFERENCES `propietarios`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`inquilino_id`)   REFERENCES `propietarios`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  MÓDULO ECONÓMICO Y CONTABLE
-- ============================================================

CREATE TABLE `ejercicios` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id` INT UNSIGNED NOT NULL,
  `anio`         SMALLINT UNSIGNED NOT NULL,
  `fecha_inicio` DATE NOT NULL,
  `fecha_fin`    DATE NOT NULL,
  `estado`       ENUM('borrador','activo','cerrado') NOT NULL DEFAULT 'borrador',
  `presupuesto_aprobado` TINYINT(1) NOT NULL DEFAULT 0,
  `fecha_aprobacion`     DATE,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_com_anio` (`comunidad_id`, `anio`),
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `categorias_contables` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`   INT UNSIGNED NOT NULL,
  `comunidad_id` INT UNSIGNED,             -- NULL = global de la gestora
  `codigo`       VARCHAR(20) NOT NULL,
  `nombre`       VARCHAR(120) NOT NULL,
  `tipo`         ENUM('ingreso','gasto') NOT NULL,
  `padre_id`     INT UNSIGNED,
  `orden`        INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`padre_id`)     REFERENCES `categorias_contables`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `presupuestos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ejercicio_id`    INT UNSIGNED NOT NULL,
  `categoria_id`    INT UNSIGNED NOT NULL,
  `descripcion`     VARCHAR(200),
  `importe_previsto` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `importe_real`    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `notas`           TEXT,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`ejercicio_id`) REFERENCES `ejercicios`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`categoria_id`) REFERENCES `categorias_contables`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `recibos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `ejercicio_id`    INT UNSIGNED NOT NULL,
  `inmueble_id`     INT UNSIGNED NOT NULL,
  `propietario_id`  INT UNSIGNED NOT NULL,
  `numero`          VARCHAR(30) NOT NULL,
  `concepto`        VARCHAR(200) NOT NULL,
  `periodo`         VARCHAR(20) NOT NULL,        -- ej: "2024-01"
  `importe`         DECIMAL(10,2) NOT NULL,
  `importe_pendiente` DECIMAL(10,2) NOT NULL,
  `fecha_emision`   DATE NOT NULL,
  `fecha_vencimiento` DATE NOT NULL,
  `fecha_cobro`     DATE,
  `estado`          ENUM('pendiente','cobrado','devuelto','anulado','fraccionado') NOT NULL DEFAULT 'pendiente',
  `metodo_cobro`    ENUM('domiciliacion','transferencia','efectivo','otro') NOT NULL DEFAULT 'domiciliacion',
  `referencia_pago` VARCHAR(100),
  `remesa_id`       INT UNSIGNED,
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora_comunidad` (`gestora_id`, `comunidad_id`),
  KEY `idx_estado` (`estado`),
  KEY `idx_periodo` (`periodo`),
  FOREIGN KEY (`gestora_id`)    REFERENCES `gestoras`(`id`)     ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`)  REFERENCES `comunidades`(`id`)  ON DELETE CASCADE,
  FOREIGN KEY (`ejercicio_id`)  REFERENCES `ejercicios`(`id`),
  FOREIGN KEY (`inmueble_id`)   REFERENCES `inmuebles`(`id`),
  FOREIGN KEY (`propietario_id`) REFERENCES `propietarios`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `remesas` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `nombre`          VARCHAR(120) NOT NULL,
  `fecha_cargo`     DATE NOT NULL,
  `total_importe`   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `num_recibos`     INT UNSIGNED NOT NULL DEFAULT 0,
  `estado`          ENUM('borrador','enviada','procesada','rechazada') NOT NULL DEFAULT 'borrador',
  `fichero_sepa`    VARCHAR(255),
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `movimientos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `ejercicio_id`    INT UNSIGNED NOT NULL,
  `categoria_id`    INT UNSIGNED,
  `recibo_id`       INT UNSIGNED,
  `tipo`            ENUM('ingreso','gasto','transferencia') NOT NULL,
  `fecha`           DATE NOT NULL,
  `concepto`        VARCHAR(200) NOT NULL,
  `importe`         DECIMAL(12,2) NOT NULL,
  `proveedor_id`    INT UNSIGNED,
  `factura_num`     VARCHAR(50),
  `documento_path`  VARCHAR(255),
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ejercicio` (`ejercicio_id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`ejercicio_id`) REFERENCES `ejercicios`(`id`),
  FOREIGN KEY (`categoria_id`) REFERENCES `categorias_contables`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`recibo_id`)    REFERENCES `recibos`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `cuentas_bancarias` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `nombre`         VARCHAR(100) NOT NULL,
  `iban`           VARCHAR(34) NOT NULL,
  `banco`          VARCHAR(80),
  `saldo_actual`   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `principal`      TINYINT(1) NOT NULL DEFAULT 0,
  `activa`         TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  MÓDULO MANTENIMIENTO Y TÉCNICA
-- ============================================================

CREATE TABLE `proveedores` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `nombre`         VARCHAR(120) NOT NULL,
  `razon_social`   VARCHAR(150),
  `nif`            VARCHAR(20),
  `email`          VARCHAR(150),
  `telefono`       VARCHAR(20),
  `telefono_urgencias` VARCHAR(20),
  `direccion`      VARCHAR(200),
  `categoria`      VARCHAR(80),   -- limpieza, ascensores, electricidad...
  `valoracion`     TINYINT UNSIGNED NOT NULL DEFAULT 0,  -- 0-5
  `activo`         TINYINT(1) NOT NULL DEFAULT 1,
  `notas`          TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora` (`gestora_id`),
  FOREIGN KEY (`gestora_id`) REFERENCES `gestoras`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `contratos_servicios` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `proveedor_id`   INT UNSIGNED NOT NULL,
  `tipo_servicio`  VARCHAR(80) NOT NULL,
  `descripcion`    TEXT,
  `fecha_inicio`   DATE NOT NULL,
  `fecha_fin`      DATE,
  `importe_mes`    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `periodicidad`   ENUM('mensual','trimestral','semestral','anual','puntual') NOT NULL DEFAULT 'mensual',
  `estado`         ENUM('activo','vencido','cancelado','revision') NOT NULL DEFAULT 'activo',
  `documento_path` VARCHAR(255),
  `notas`          TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`proveedor_id`) REFERENCES `proveedores`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `averias` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `numero`         VARCHAR(20) NOT NULL,
  `titulo`         VARCHAR(200) NOT NULL,
  `descripcion`    TEXT NOT NULL,
  `urgencia`       ENUM('baja','media','alta','critica') NOT NULL DEFAULT 'media',
  `categoria`      VARCHAR(80),
  `estado`         ENUM('abierta','asignada','en_proceso','resuelta','cerrada','cancelada') NOT NULL DEFAULT 'abierta',
  `reportado_por`  INT UNSIGNED,
  `proveedor_id`   INT UNSIGNED,
  `fecha_apertura` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `fecha_asignacion` DATETIME,
  `fecha_resolucion` DATETIME,
  `coste_estimado` DECIMAL(10,2),
  `coste_real`     DECIMAL(10,2),
  `inmueble_id`    INT UNSIGNED,
  `zona`           VARCHAR(80),   -- "portal", "ascensor", "tejado"...
  `notas_resolucion` TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora_estado` (`gestora_id`, `estado`),
  FOREIGN KEY (`gestora_id`)    REFERENCES `gestoras`(`id`)     ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`)  REFERENCES `comunidades`(`id`)  ON DELETE CASCADE,
  FOREIGN KEY (`proveedor_id`)  REFERENCES `proveedores`(`id`)  ON DELETE SET NULL,
  FOREIGN KEY (`reportado_por`) REFERENCES `usuarios`(`id`)     ON DELETE SET NULL,
  FOREIGN KEY (`inmueble_id`)   REFERENCES `inmuebles`(`id`)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `averia_seguimiento` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `averia_id`   INT UNSIGNED NOT NULL,
  `usuario_id`  INT UNSIGNED,
  `estado_nuevo` VARCHAR(30),
  `comentario`  TEXT,
  `adjunto_path` VARCHAR(255),
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`averia_id`)  REFERENCES `averias`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `obras_presupuestos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `titulo`          VARCHAR(200) NOT NULL,
  `descripcion`     TEXT,
  `tipo`            ENUM('mantenimiento','mejora','urgente','ite','legal','otro') NOT NULL DEFAULT 'mantenimiento',
  `estado`          ENUM('solicitud','presupuestando','aprobada','en_curso','finalizada','rechazada') NOT NULL DEFAULT 'solicitud',
  `aprobada_en_junta` TINYINT(1) NOT NULL DEFAULT 0,
  `junta_id`        INT UNSIGNED,
  `fecha_solicitud` DATE NOT NULL,
  `fecha_inicio`    DATE,
  `fecha_fin`       DATE,
  `importe_aprobado` DECIMAL(12,2),
  `importe_final`   DECIMAL(12,2),
  `zona_afectada`   VARCHAR(100),
  `proveedor_seleccionado_id` INT UNSIGNED,
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`proveedor_seleccionado_id`) REFERENCES `proveedores`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `obras_ofertas` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `obra_id`      INT UNSIGNED NOT NULL,
  `proveedor_id` INT UNSIGNED NOT NULL,
  `importe`      DECIMAL(12,2) NOT NULL,
  `plazo_dias`   INT UNSIGNED,
  `descripcion`  TEXT,
  `documento_path` VARCHAR(255),
  `seleccionada` TINYINT(1) NOT NULL DEFAULT 0,
  `fecha`        DATE NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`obra_id`)      REFERENCES `obras_presupuestos`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`proveedor_id`) REFERENCES `proveedores`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `ite_iee` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `tipo`           ENUM('ITE','IEE') NOT NULL,
  `estado`         ENUM('pendiente','solicitada','en_proceso','favorable','desfavorable','con_deficiencias') NOT NULL DEFAULT 'pendiente',
  `tecnico`        VARCHAR(120),
  `empresa`        VARCHAR(120),
  `fecha_inspeccion` DATE,
  `fecha_informe`  DATE,
  `fecha_vencimiento` DATE,
  `resultado`      TEXT,
  `deficiencias`   TEXT,
  `documento_path` VARCHAR(255),
  `notas`          TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  MÓDULO JURÍDICO Y LEGAL
-- ============================================================

CREATE TABLE `morosos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `propietario_id`  INT UNSIGNED NOT NULL,
  `inmueble_id`     INT UNSIGNED NOT NULL,
  `deuda_total`     DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `fecha_inicio_morosidad` DATE NOT NULL,
  `estado`          ENUM('activo','acuerdo_pago','judicial','resuelto','condonado') NOT NULL DEFAULT 'activo',
  `abogado_nombre`  VARCHAR(120),
  `abogado_email`   VARCHAR(150),
  `num_procedimiento` VARCHAR(50),
  `juzgado`         VARCHAR(100),
  `fecha_demanda`   DATE,
  `sentencia`       ENUM('pendiente','favorable','desfavorable','sobreseido'),
  `fecha_sentencia` DATE,
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)    REFERENCES `gestoras`(`id`)     ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`)  REFERENCES `comunidades`(`id`)  ON DELETE CASCADE,
  FOREIGN KEY (`propietario_id`) REFERENCES `propietarios`(`id`),
  FOREIGN KEY (`inmueble_id`)   REFERENCES `inmuebles`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `morosos_recibos` (
  `moroso_id` INT UNSIGNED NOT NULL,
  `recibo_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`moroso_id`, `recibo_id`),
  FOREIGN KEY (`moroso_id`) REFERENCES `morosos`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`recibo_id`) REFERENCES `recibos`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `siniestros` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `numero`         VARCHAR(30) NOT NULL,
  `tipo`           VARCHAR(80) NOT NULL,  -- inundación, incendio, vandalismo...
  `descripcion`    TEXT NOT NULL,
  `fecha_siniestro` DATE NOT NULL,
  `fecha_aviso_seguro` DATE,
  `num_expediente` VARCHAR(80),
  `seguro_compania` VARCHAR(100),
  `poliza`         VARCHAR(50),
  `perito_nombre`  VARCHAR(120),
  `perito_telefono` VARCHAR(20),
  `estado`         ENUM('pendiente','tramitando','peritado','indemnizado','cerrado','rechazado') NOT NULL DEFAULT 'pendiente',
  `importe_danios`  DECIMAL(12,2),
  `importe_indemnizacion` DECIMAL(12,2),
  `inmueble_id`    INT UNSIGNED,
  `zona`           VARCHAR(80),
  `notas`          TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`inmueble_id`)  REFERENCES `inmuebles`(`id`)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `documentos_legales` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `tipo`           ENUM('estatutos','reglamento','acta','escritura','licencia','otro') NOT NULL,
  `nombre`         VARCHAR(150) NOT NULL,
  `descripcion`    TEXT,
  `fecha_documento` DATE,
  `fecha_vencimiento` DATE,
  `archivo_path`   VARCHAR(255),
  `publico`        TINYINT(1) NOT NULL DEFAULT 0,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  MÓDULO ADMINISTRATIVO
-- ============================================================

CREATE TABLE `juntas` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`      INT UNSIGNED NOT NULL,
  `comunidad_id`    INT UNSIGNED NOT NULL,
  `tipo`            ENUM('ordinaria','extraordinaria','urgente') NOT NULL DEFAULT 'ordinaria',
  `titulo`          VARCHAR(200) NOT NULL,
  `fecha_convocatoria` DATETIME NOT NULL,
  `fecha_primera`   DATETIME NOT NULL,
  `fecha_segunda`   DATETIME,
  `lugar`           VARCHAR(200),
  `modalidad`       ENUM('presencial','online','mixta') NOT NULL DEFAULT 'presencial',
  `url_reunion`     VARCHAR(255),  -- para juntas online
  `quorum_primera`  DECIMAL(5,2),
  `quorum_segunda`  DECIMAL(5,2),
  `estado`          ENUM('convocada','celebrada','suspendida','cancelada') NOT NULL DEFAULT 'convocada',
  `orden_del_dia`   TEXT,
  `convocatoria_path` VARCHAR(255),
  `acta_path`       VARCHAR(255),
  `acta_firmada`    TINYINT(1) NOT NULL DEFAULT 0,
  `fecha_firma_acta` DATE,
  `notas`           TEXT,
  `created_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora_fecha` (`gestora_id`, `fecha_primera`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `juntas_asistentes` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `junta_id`       INT UNSIGNED NOT NULL,
  `propietario_id` INT UNSIGNED NOT NULL,
  `inmueble_id`    INT UNSIGNED NOT NULL,
  `asistencia`     ENUM('presente','delegado','ausente') NOT NULL DEFAULT 'ausente',
  `delegado_en_id` INT UNSIGNED,
  `coeficiente`    DECIMAL(8,5) NOT NULL DEFAULT 0.00000,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_junta_prop` (`junta_id`, `propietario_id`),
  FOREIGN KEY (`junta_id`)       REFERENCES `juntas`(`id`)       ON DELETE CASCADE,
  FOREIGN KEY (`propietario_id`) REFERENCES `propietarios`(`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `acuerdos` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `junta_id`        INT UNSIGNED NOT NULL,
  `numero_punto`    INT UNSIGNED NOT NULL,
  `titulo`          VARCHAR(200) NOT NULL,
  `descripcion`     TEXT,
  `tipo_mayoria`    ENUM('simple','cualificada','unanimidad') NOT NULL DEFAULT 'simple',
  `resultado`       ENUM('aprobado','rechazado','aplazado','retirado') NOT NULL DEFAULT 'aplazado',
  `votos_favor`     INT UNSIGNED NOT NULL DEFAULT 0,
  `votos_contra`    INT UNSIGNED NOT NULL DEFAULT 0,
  `votos_abstenciones` INT UNSIGNED NOT NULL DEFAULT 0,
  `coef_favor`      DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `coef_contra`     DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  `plazo_ejecucion` DATE,
  `responsable`     VARCHAR(100),
  `ejecutado`       TINYINT(1) NOT NULL DEFAULT 0,
  `fecha_ejecucion` DATE,
  `notas`           TEXT,
  PRIMARY KEY (`id`),
  KEY `uk_junta_punto` (`junta_id`, `numero_punto`),
  FOREIGN KEY (`junta_id`) REFERENCES `juntas`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `libros_actas` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `comunidad_id`   INT UNSIGNED NOT NULL,
  `numero_acta`    INT UNSIGNED NOT NULL,
  `junta_id`       INT UNSIGNED,
  `fecha`          DATE NOT NULL,
  `contenido`      LONGTEXT,
  `archivo_path`   VARCHAR(255),
  `firmado`        TINYINT(1) NOT NULL DEFAULT 0,
  `secretario`     VARCHAR(120),
  `presidente`     VARCHAR(120),
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_com_num` (`comunidad_id`, `numero_acta`),
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`junta_id`)     REFERENCES `juntas`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `comunicaciones` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `comunidad_id`   INT UNSIGNED,
  `tipo`           ENUM('email','sms','carta','circular','burofax') NOT NULL DEFAULT 'email',
  `asunto`         VARCHAR(200),
  `contenido`      TEXT NOT NULL,
  `destinatarios`  JSON,
  `enviado`        TINYINT(1) NOT NULL DEFAULT 0,
  `fecha_envio`    DATETIME,
  `num_enviados`   INT UNSIGNED NOT NULL DEFAULT 0,
  `num_errores`    INT UNSIGNED NOT NULL DEFAULT 0,
  `created_by`     INT UNSIGNED,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`created_by`)   REFERENCES `usuarios`(`id`)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `tareas` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `gestora_id`     INT UNSIGNED NOT NULL,
  `comunidad_id`   INT UNSIGNED,
  `titulo`         VARCHAR(200) NOT NULL,
  `descripcion`    TEXT,
  `tipo`           VARCHAR(60),
  `prioridad`      ENUM('baja','normal','alta','urgente') NOT NULL DEFAULT 'normal',
  `estado`         ENUM('pendiente','en_curso','completada','cancelada') NOT NULL DEFAULT 'pendiente',
  `asignada_a`     INT UNSIGNED,
  `fecha_limite`   DATE,
  `completada_en`  DATETIME,
  `notas`          TEXT,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_gestora_estado` (`gestora_id`, `estado`),
  FOREIGN KEY (`gestora_id`)   REFERENCES `gestoras`(`id`)    ON DELETE CASCADE,
  FOREIGN KEY (`comunidad_id`) REFERENCES `comunidades`(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`asignada_a`)   REFERENCES `usuarios`(`id`)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `notificaciones` (
  `id`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usuario_id`   INT UNSIGNED NOT NULL,
  `tipo`         VARCHAR(40) NOT NULL,
  `titulo`       VARCHAR(120) NOT NULL,
  `mensaje`      TEXT,
  `url`          VARCHAR(255),
  `leida`        TINYINT(1) NOT NULL DEFAULT 0,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_usuario_leida` (`usuario_id`, `leida`),
  FOREIGN KEY (`usuario_id`) REFERENCES `usuarios`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
--  DATOS INICIALES
-- ============================================================

INSERT INTO `roles` (`codigo`, `nombre`, `nivel`) VALUES
  ('superadmin',   'Superadministrador',      100),
  ('admin_gestora','Administrador Gestora',    80),
  ('gestor',       'Gestor de Fincas',         60),
  ('auxiliar',     'Auxiliar Administrativo',  40),
  ('propietario',  'Propietario / Portal',     10);

INSERT INTO `planes` (`nombre`, `slug`, `descripcion`, `precio_mes`, `precio_anual`, `max_comunidades`, `max_usuarios`, `max_storage_mb`, `color_badge`, `orden`) VALUES
  ('Starter',     'starter',      'Para pequeñas administraciones. Módulo administrativo básico.',                          49.00,   470.00,   15,   3,    512,  '#64748b', 1),
  ('Profesional', 'profesional',  'La solución más popular. Incluye gestión económica y mantenimiento.',                   89.00,   854.00,   50,  10,   2048, '#3b82f6', 2),
  ('Business',    'business',     'Para gestoras medianas. Todos los módulos + soporte prioritario.',                      149.00,  1430.00,  150,  25,   5120, '#8b5cf6', 3),
  ('Enterprise',  'enterprise',   'Sin límites. White-label completo, API acceso, gestor de cuenta dedicado. Precio/mes.',  0.00,     0.00,    999, 999, 51200, '#f59e0b', 4);

INSERT INTO `modulos` (`codigo`, `nombre`, `descripcion`, `icono`, `color`, `ruta_base`, `orden`) VALUES
  ('admin',       'Gestión Administrativa', 'Convocatoria de juntas, actas, comunicaciones y acuerdos', 'fa-clipboard-list', '#0ea5e9', '/admin',        1),
  ('economica',   'Económica y Contable',   'Presupuestos, recibos, cobros, movimientos y liquidaciones', 'fa-chart-line',    '#10b981', '/economica',    2),
  ('mantenimiento','Mantenimiento y Técnica','Averías, contratos de servicios, obras y presupuestos',    'fa-wrench',         '#f59e0b', '/mantenimiento', 3),
  ('juridica',    'Jurídica y Legal',       'Morosos, siniestros, documentación legal y asesoramiento', 'fa-balance-scale',  '#ef4444', '/juridica',      4);

-- Starter: sólo admin
INSERT INTO `planes_modulos` SELECT p.id, m.id FROM `planes` p, `modulos` m
  WHERE p.slug='starter' AND m.codigo='admin';

-- Profesional: admin + economica + mantenimiento
INSERT INTO `planes_modulos` SELECT p.id, m.id FROM `planes` p, `modulos` m
  WHERE p.slug='profesional' AND m.codigo IN ('admin','economica','mantenimiento');

-- Business y Enterprise: todos
INSERT INTO `planes_modulos` SELECT p.id, m.id FROM `planes` p, `modulos` m
  WHERE p.slug IN ('business','enterprise');

-- Acciones por módulo
INSERT INTO `acciones_modulo` (`modulo_id`, `codigo`, `nombre`) VALUES
  -- Administrativo
  ((SELECT id FROM modulos WHERE codigo='admin'), 'convocatoria_juntas',    'Convocatoria de Juntas'),
  ((SELECT id FROM modulos WHERE codigo='admin'), 'redaccion_actas',        'Redacción y Envío de Actas'),
  ((SELECT id FROM modulos WHERE codigo='admin'), 'ejecucion_acuerdos',     'Ejecución de Acuerdos'),
  ((SELECT id FROM modulos WHERE codigo='admin'), 'representacion_oficial', 'Representación ante Organismos Oficiales'),
  ((SELECT id FROM modulos WHERE codigo='admin'), 'comunicaciones',         'Envío de Comunicaciones Masivas'),
  ((SELECT id FROM modulos WHERE codigo='admin'), 'libro_actas',            'Custodia Libro de Actas'),
  -- Económica
  ((SELECT id FROM modulos WHERE codigo='economica'), 'presupuesto_anual',  'Elaboración del Presupuesto Anual'),
  ((SELECT id FROM modulos WHERE codigo='economica'), 'gestion_recibos',    'Emisión y Gestión de Cobro de Recibos'),
  ((SELECT id FROM modulos WHERE codigo='economica'), 'liquidacion_anual',  'Liquidación de Cuentas Anuales'),
  ((SELECT id FROM modulos WHERE codigo='economica'), 'pago_proveedores',   'Pago a Proveedores y Nóminas'),
  ((SELECT id FROM modulos WHERE codigo='economica'), 'remesas_sepa',       'Generación de Remesas SEPA'),
  -- Mantenimiento
  ((SELECT id FROM modulos WHERE codigo='mantenimiento'), 'contratos_servicios', 'Contratación de Servicios'),
  ((SELECT id FROM modulos WHERE codigo='mantenimiento'), 'averias_urgentes',    'Gestión de Averías Urgentes'),
  ((SELECT id FROM modulos WHERE codigo='mantenimiento'), 'ite_iee',             'Seguimiento de la ITE/IEE'),
  ((SELECT id FROM modulos WHERE codigo='mantenimiento'), 'presupuestos_obras',  'Solicitud de Presupuestos para Obras'),
  -- Jurídica
  ((SELECT id FROM modulos WHERE codigo='juridica'), 'reclamacion_morosos',  'Reclamación de Cuotas a Morosos'),
  ((SELECT id FROM modulos WHERE codigo='juridica'), 'asesoria_lph',         'Asesoramiento Ley Propiedad Horizontal'),
  ((SELECT id FROM modulos WHERE codigo='juridica'), 'tramitacion_siniestros','Tramitación de Siniestros con el Seguro'),
  ((SELECT id FROM modulos WHERE codigo='juridica'), 'custodia_actas',        'Custodia de Libros de Actas');

-- Superadministrador del sistema
INSERT INTO `usuarios` (`gestora_id`, `rol_id`, `nombre`, `apellidos`, `email`, `password_hash`, `activo`, `email_verified`)
  VALUES (NULL, (SELECT id FROM roles WHERE codigo='superadmin'), 'Super', 'Admin', 'admin@nanoserver.es',
          '$2y$12$placeholder_hash_change_on_install', 1, 1);

SET foreign_key_checks = 1;

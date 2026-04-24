<?php
/**
 * ERP FINCAS - Configuración Principal
 * Adaptada para el entorno real: /home/nano/www/erp-fincas/
 */

// ─── Carga de variables .env ──────────────────────────────────────────────────
// Lee el archivo .env del directorio raíz del proyecto
$envFile = dirname(__DIR__) . '/.env';
if (file_exists($envFile)) {
    foreach (file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (str_starts_with(trim($line), '#')) continue;
        if (!str_contains($line, '=')) continue;
        [$key, $val] = explode('=', $line, 2);
        $key = trim($key);
        $val = trim($val, " \t\n\r\"'");
        if (!getenv($key)) putenv("$key=$val");
    }
}

// ─── Entorno ──────────────────────────────────────────────────────────────────
define('APP_ENV',     getenv('APP_ENV')     ?: 'production');
define('APP_DEBUG',   getenv('APP_DEBUG')   === 'true');
define('APP_VERSION', '1.0.0');
define('APP_NAME',    'ERP Fincas');

// ─── Dominio ──────────────────────────────────────────────────────────────────
define('BASE_DOMAIN',  getenv('BASE_DOMAIN') ?: 'nanoserver.es');
define('ADMIN_DOMAIN', 'admin.' . BASE_DOMAIN);

// ─── Rutas absolutas (adaptadas a /home/nano/www/erp-fincas/) ─────────────────
define('ROOT_PATH',    dirname(__DIR__));                      // /home/nano/www/erp-fincas
define('CONFIG_PATH',  ROOT_PATH . '/config');
define('CORE_PATH',    ROOT_PATH . '/core');
define('MODULES_PATH', ROOT_PATH . '/modules');
define('VIEWS_PATH',   ROOT_PATH . '/views');
define('PUBLIC_PATH',  ROOT_PATH . '/public');
define('UPLOADS_PATH', ROOT_PATH . '/uploads');
define('LOGS_PATH',    '/home/nano/www/logs');   // Logs compartidos con los del VirtualHost
define('CACHE_PATH',   ROOT_PATH . '/cache');

// ─── Base de datos ────────────────────────────────────────────────────────────
define('DB_HOST',    getenv('DB_HOST')  ?: 'localhost');
define('DB_PORT',    getenv('DB_PORT')  ?: '3306');
define('DB_NAME',    getenv('DB_NAME')  ?: 'erp_fincas');
define('DB_USER',    getenv('DB_USER')  ?: 'erp_user');
define('DB_PASS',    getenv('DB_PASS')  ?: '');
define('DB_CHARSET', 'utf8mb4');

// ─── Sesiones ─────────────────────────────────────────────────────────────────
// Cookie de sesión acotada al dominio base para cubrir todos los subdominios
define('SESSION_LIFETIME',  7200);
define('SESSION_NAME',      'ERPFINCAS');
define('SESSION_SECURE',    true);          // Siempre true: el servidor ya usa HTTPS
define('SESSION_DOMAIN',    '.' . BASE_DOMAIN); // Punto inicial = válida en subdominios

// ─── Seguridad ────────────────────────────────────────────────────────────────
define('BCRYPT_COST',          12);
define('CSRF_TOKEN_LENGTH',    32);
define('MAX_LOGIN_ATTEMPTS',   5);
define('LOCKOUT_TIME',         900);        // 15 min
define('ENCRYPTION_KEY',       getenv('ENCRYPTION_KEY') ?: 'CAMBIA_ESTO_EN_PRODUCCION_32!!');

// ─── Email ────────────────────────────────────────────────────────────────────
define('MAIL_HOST',      getenv('MAIL_HOST')      ?: 'smtp.nanoserver.es');
define('MAIL_PORT',      getenv('MAIL_PORT')      ?: 587);
define('MAIL_USERNAME',  getenv('MAIL_USERNAME')  ?: 'noreply@nanoserver.es');
define('MAIL_PASSWORD',  getenv('MAIL_PASSWORD')  ?: '');
define('MAIL_FROM',      getenv('MAIL_FROM')      ?: 'noreply@nanoserver.es');
define('MAIL_FROM_NAME', 'ERP Fincas');

// ─── Timezone ────────────────────────────────────────────────────────────────
define('DEFAULT_TIMEZONE', 'Europe/Madrid');
define('DEFAULT_CURRENCY', 'EUR');

date_default_timezone_set(DEFAULT_TIMEZONE);
mb_internal_encoding('UTF-8');

// ─── Módulos del ERP ──────────────────────────────────────────────────────────
define('MODULES', [
    'admin'         => ['label' => 'Gestión Administrativa', 'icon' => 'fa-clipboard-list', 'color' => '#0ea5e9'],
    'economica'     => ['label' => 'Económica y Contable',   'icon' => 'fa-chart-line',     'color' => '#10b981'],
    'mantenimiento' => ['label' => 'Mantenimiento y Técnica','icon' => 'fa-wrench',          'color' => '#f59e0b'],
    'juridica'      => ['label' => 'Jurídica y Legal',       'icon' => 'fa-balance-scale',   'color' => '#ef4444'],
]);

// ─── Autoloader PSR-4 ────────────────────────────────────────────────────────
spl_autoload_register(function(string $class): void {
    $map = [
        'Core\\'        => CORE_PATH . '/',
        'Controllers\\' => ROOT_PATH . '/controllers/',
        'Api\\'         => ROOT_PATH . '/api/',
        'Module\\'      => MODULES_PATH . '/',
    ];
    foreach ($map as $prefix => $dir) {
        if (str_starts_with($class, $prefix)) {
            $file = $dir . str_replace(['\\', $prefix], ['/', ''], $class) . '.php';
            if (file_exists($file)) { require_once $file; return; }
        }
    }
});

require_once CORE_PATH . '/helpers.php';

// ─── Manejo global de errores ────────────────────────────────────────────────
if (APP_DEBUG) {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
} else {
    error_reporting(0);
    ini_set('display_errors', '0');
    ini_set('log_errors', '1');
    ini_set('error_log', LOGS_PATH . '/erp-php-errors.log');
}

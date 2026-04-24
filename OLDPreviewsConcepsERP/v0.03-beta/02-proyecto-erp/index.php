<?php
declare(strict_types=1);
require_once __DIR__ . '/config/config.php';

use Core\SubdomainResolver;
use Core\Router;

$resolver = new SubdomainResolver();
$router   = new Router();

if ($resolver->isAdmin()) {
    require_once __DIR__ . '/admin/routes.php';
} elseif ($resolver->isRoot()) {
    require_once __DIR__ . '/routes/public.php';
} else {
    require_once __DIR__ . '/routes/app.php';
}

$router->dispatch();

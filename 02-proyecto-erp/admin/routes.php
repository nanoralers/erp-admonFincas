<?php
/**
 * Rutas del panel superadministrador
 * Se carga cuando se accede a admin.nanoserver.es
 */

use Core\Auth;

$auth = new Auth();

// Autenticación del superadmin
$router->get('/login',  ['Admin\AuthController', 'loginForm']);
$router->post('/login', ['Admin\AuthController', 'loginSubmit']);
$router->get('/logout', ['Admin\AuthController', 'logout']);

// Dashboard principal
$router->get('/',         ['Admin\DashboardController', 'index']);
$router->get('/dashboard',['Admin\DashboardController', 'index']);

// Gestoras (tenants)
$router->get('/gestoras',              ['Admin\GestoraController', 'index']);
$router->get('/gestoras/nueva',        ['Admin\GestoraController', 'create']);
$router->post('/gestoras/nueva',       ['Admin\GestoraController', 'store']);
$router->get('/gestoras/{id}',         ['Admin\GestoraController', 'show']);
$router->get('/gestoras/{id}/editar',  ['Admin\GestoraController', 'edit']);
$router->post('/gestoras/{id}/editar', ['Admin\GestoraController', 'update']);
$router->post('/gestoras/{id}/toggle', ['Admin\GestoraController', 'toggle']);

// Planes y módulos
$router->get('/planes',           ['Admin\PlanController', 'index']);
$router->get('/planes/{id}',      ['Admin\PlanController', 'show']);
$router->post('/planes/{id}',     ['Admin\PlanController', 'update']);

// Usuarios globales
$router->get('/usuarios',         ['Admin\UsuarioController', 'index']);
$router->post('/usuarios/{id}/toggle', ['Admin\UsuarioController', 'toggle']);

// Logs y auditoría
$router->get('/logs',             ['Admin\LogController', 'index']);
$router->get('/logs/audit',       ['Admin\LogController', 'audit']);

// Estadísticas globales
$router->get('/stats',            ['Admin\StatsController', 'index']);

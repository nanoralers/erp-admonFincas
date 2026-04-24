<?php
/**
 * Rutas de la aplicación tenant
 * Se carga cuando el subdominio corresponde a una gestora válida
 */

use Core\Auth;

$auth = new Auth();

// ── Autenticación ─────────────────────────────────────────────────────────────
$router->get('/login',  ['Controllers\AuthController', 'loginForm']);
$router->post('/login', ['Controllers\AuthController', 'loginSubmit']);
$router->get('/logout', ['Controllers\AuthController', 'logout']);
$router->get('/recuperar-password',        ['Controllers\AuthController', 'recoverForm']);
$router->post('/recuperar-password',       ['Controllers\AuthController', 'recoverSubmit']);
$router->get('/reset-password/{token}',    ['Controllers\AuthController', 'resetForm']);
$router->post('/reset-password/{token}',   ['Controllers\AuthController', 'resetSubmit']);

// ── Dashboard ─────────────────────────────────────────────────────────────────
$router->get('/',          ['Controllers\DashboardController', 'index']);
$router->get('/dashboard', ['Controllers\DashboardController', 'index']);

// ── Comunidades ───────────────────────────────────────────────────────────────
$router->get('/comunidades',                    ['Controllers\ComunidadController', 'index']);
$router->get('/comunidades/nueva',              ['Controllers\ComunidadController', 'create']);
$router->post('/comunidades/nueva',             ['Controllers\ComunidadController', 'store']);
$router->get('/comunidades/{id}',               ['Controllers\ComunidadController', 'show']);
$router->get('/comunidades/{id}/editar',        ['Controllers\ComunidadController', 'edit']);
$router->post('/comunidades/{id}/editar',       ['Controllers\ComunidadController', 'update']);
$router->post('/comunidades/{id}/eliminar',     ['Controllers\ComunidadController', 'destroy']);

// ── Propietarios ──────────────────────────────────────────────────────────────
$router->get('/propietarios',                   ['Controllers\PropietarioController', 'index']);
$router->get('/propietarios/nuevo',             ['Controllers\PropietarioController', 'create']);
$router->post('/propietarios/nuevo',            ['Controllers\PropietarioController', 'store']);
$router->get('/propietarios/{id}',              ['Controllers\PropietarioController', 'show']);
$router->get('/propietarios/{id}/editar',       ['Controllers\PropietarioController', 'edit']);
$router->post('/propietarios/{id}/editar',      ['Controllers\PropietarioController', 'update']);

// ── MÓDULO ECONÓMICO ──────────────────────────────────────────────────────────
$router->get('/economica',                       ['Controllers\Economica\DashboardController','index']);
$router->get('/economica/presupuestos',          ['Controllers\Economica\PresupuestoController','index']);
$router->get('/economica/presupuestos/{id}',     ['Controllers\Economica\PresupuestoController','show']);
$router->post('/economica/presupuestos',         ['Controllers\Economica\PresupuestoController','store']);
$router->get('/economica/recibos',               ['Controllers\Economica\ReciboController','index']);
$router->get('/economica/recibos/emitir',        ['Controllers\Economica\ReciboController','emitir']);
$router->post('/economica/recibos/emitir',       ['Controllers\Economica\ReciboController','emitirStore']);
$router->get('/economica/recibos/{id}',          ['Controllers\Economica\ReciboController','show']);
$router->post('/economica/recibos/{id}/cobrar',  ['Controllers\Economica\ReciboController','cobrar']);
$router->get('/economica/remesas',               ['Controllers\Economica\RemesaController','index']);
$router->post('/economica/remesas',              ['Controllers\Economica\RemesaController','store']);
$router->get('/economica/remesas/{id}/sepa',     ['Controllers\Economica\RemesaController','descargarSEPA']);
$router->get('/economica/movimientos',           ['Controllers\Economica\MovimientoController','index']);
$router->post('/economica/movimientos',          ['Controllers\Economica\MovimientoController','store']);
$router->get('/economica/liquidaciones',         ['Controllers\Economica\LiquidacionController','index']);
$router->get('/economica/liquidaciones/{id}',    ['Controllers\Economica\LiquidacionController','show']);
$router->get('/economica/liquidaciones/{id}/pdf',['Controllers\Economica\LiquidacionController','pdf']);

// ── MÓDULO MANTENIMIENTO ──────────────────────────────────────────────────────
$router->get('/mantenimiento',                   ['Controllers\Mantenimiento\DashboardController','index']);
$router->get('/mantenimiento/averias',           ['Controllers\Mantenimiento\AveriaController','index']);
$router->get('/mantenimiento/averias/nueva',     ['Controllers\Mantenimiento\AveriaController','create']);
$router->post('/mantenimiento/averias/nueva',    ['Controllers\Mantenimiento\AveriaController','store']);
$router->get('/mantenimiento/averias/{id}',      ['Controllers\Mantenimiento\AveriaController','show']);
$router->post('/mantenimiento/averias/{id}/estado',['Controllers\Mantenimiento\AveriaController','cambiarEstado']);
$router->get('/mantenimiento/proveedores',       ['Controllers\Mantenimiento\ProveedorController','index']);
$router->get('/mantenimiento/proveedores/nuevo', ['Controllers\Mantenimiento\ProveedorController','create']);
$router->post('/mantenimiento/proveedores/nuevo',['Controllers\Mantenimiento\ProveedorController','store']);
$router->get('/mantenimiento/contratos',         ['Controllers\Mantenimiento\ContratoController','index']);
$router->post('/mantenimiento/contratos',        ['Controllers\Mantenimiento\ContratoController','store']);
$router->get('/mantenimiento/obras',             ['Controllers\Mantenimiento\ObraController','index']);
$router->post('/mantenimiento/obras',            ['Controllers\Mantenimiento\ObraController','store']);
$router->get('/mantenimiento/obras/{id}',        ['Controllers\Mantenimiento\ObraController','show']);
$router->get('/mantenimiento/ite-iee',           ['Controllers\Mantenimiento\IteController','index']);
$router->post('/mantenimiento/ite-iee',          ['Controllers\Mantenimiento\IteController','store']);

// ── MÓDULO JURÍDICO ───────────────────────────────────────────────────────────
$router->get('/juridica',                        ['Controllers\Juridica\DashboardController','index']);
$router->get('/juridica/morosos',                ['Controllers\Juridica\MorosoController','index']);
$router->get('/juridica/morosos/nuevo',          ['Controllers\Juridica\MorosoController','create']);
$router->post('/juridica/morosos/nuevo',         ['Controllers\Juridica\MorosoController','store']);
$router->get('/juridica/morosos/{id}',           ['Controllers\Juridica\MorosoController','show']);
$router->post('/juridica/morosos/{id}/actualizar',['Controllers\Juridica\MorosoController','update']);
$router->get('/juridica/siniestros',             ['Controllers\Juridica\SiniestroController','index']);
$router->post('/juridica/siniestros',            ['Controllers\Juridica\SiniestroController','store']);
$router->get('/juridica/siniestros/{id}',        ['Controllers\Juridica\SiniestroController','show']);
$router->get('/juridica/documentos',             ['Controllers\Juridica\DocumentoController','index']);
$router->post('/juridica/documentos',            ['Controllers\Juridica\DocumentoController','upload']);

// ── MÓDULO ADMINISTRATIVO ─────────────────────────────────────────────────────
$router->get('/admin-fincas',                    ['Controllers\Administrativa\DashboardController','index']);
$router->get('/juntas',                          ['Controllers\Administrativa\JuntaController','index']);
$router->get('/juntas/nueva',                    ['Controllers\Administrativa\JuntaController','create']);
$router->post('/juntas/nueva',                   ['Controllers\Administrativa\JuntaController','store']);
$router->get('/juntas/{id}',                     ['Controllers\Administrativa\JuntaController','show']);
$router->get('/juntas/{id}/convocatoria',        ['Controllers\Administrativa\JuntaController','convocatoriaPdf']);
$router->get('/juntas/{id}/acta',                ['Controllers\Administrativa\JuntaController','actaPdf']);
$router->post('/juntas/{id}/acuerdo',            ['Controllers\Administrativa\JuntaController','addAcuerdo']);
$router->get('/actas',                           ['Controllers\Administrativa\ActaController','index']);
$router->get('/actas/{id}',                      ['Controllers\Administrativa\ActaController','show']);
$router->get('/comunicaciones',                  ['Controllers\Administrativa\ComunicacionController','index']);
$router->post('/comunicaciones/enviar',          ['Controllers\Administrativa\ComunicacionController','enviar']);
$router->get('/tareas',                          ['Controllers\Administrativa\TareaController','index']);
$router->post('/tareas',                         ['Controllers\Administrativa\TareaController','store']);
$router->post('/tareas/{id}/completar',          ['Controllers\Administrativa\TareaController','completar']);

// ── Configuración Gestora ─────────────────────────────────────────────────────
$router->get('/configuracion',                   ['Controllers\ConfigController','index']);
$router->post('/configuracion/perfil',           ['Controllers\ConfigController','updatePerfil']);
$router->post('/configuracion/branding',         ['Controllers\ConfigController','updateBranding']);
$router->post('/configuracion/logo',             ['Controllers\ConfigController','uploadLogo']);
$router->get('/usuarios',                        ['Controllers\UsuarioController','index']);
$router->post('/usuarios',                       ['Controllers\UsuarioController','store']);
$router->post('/usuarios/{id}/editar',           ['Controllers\UsuarioController','update']);
$router->post('/usuarios/{id}/eliminar',         ['Controllers\UsuarioController','destroy']);

// ── API interna (JSON) ────────────────────────────────────────────────────────
$router->get('/api/comunidades',                 ['Api\ComunidadApi','list']);
$router->get('/api/propietarios',                ['Api\PropietarioApi','list']);
$router->get('/api/dashboard/stats',             ['Api\DashboardApi','stats']);
$router->get('/api/notificaciones',              ['Api\NotificacionApi','list']);
$router->post('/api/notificaciones/{id}/leer',   ['Api\NotificacionApi','markRead']);

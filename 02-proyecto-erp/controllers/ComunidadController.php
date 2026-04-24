<?php
namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class ComunidadController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $this->gestora   = $resolver->getGestora() ?? [];
        $this->gestoraId = (int)($this->gestora['id'] ?? 0);
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $q      = trim($_GET['q'] ?? '');
        $where  = ['gestora_id = ?', 'activo = 1'];
        $params = [$this->gestoraId];

        if ($q) {
            $where[]  = '(nombre LIKE ? OR direccion LIKE ? OR nif LIKE ?)';
            $like     = "%$q%";
            $params   = array_merge($params, [$like, $like, $like]);
        }

        $paginado = $this->db->paginate(
            'SELECT c.*,
                    (SELECT COUNT(*) FROM inmuebles WHERE comunidad_id = c.id AND activo = 1) as total_inmuebles,
                    (SELECT COUNT(*) FROM recibos WHERE comunidad_id = c.id AND estado = "pendiente") as recibos_pendientes,
                    (SELECT COUNT(*) FROM averias WHERE comunidad_id = c.id AND estado NOT IN ("resuelta","cerrada","cancelada")) as averias_abiertas
             FROM comunidades c
             WHERE ' . implode(' AND ', $where) . '
             ORDER BY nombre ASC',
            $params,
            (int)($_GET['pagina'] ?? 1), 15
        );

        $pageTitle   = 'Comunidades';
        $breadcrumbs = [['label' => 'Comunidades']];

        ob_start();
        require VIEWS_PATH . '/comunidades/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function show(string $id): void
    {
        $comunidad = $this->getComunidadOrFail((int)$id);
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $inmuebles = $this->db->query(
            'SELECT i.*,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    p.moroso
             FROM inmuebles i
             LEFT JOIN propietarios p ON p.id = i.propietario_id
             WHERE i.comunidad_id = ? ORDER BY i.tipo, i.referencia',
            [(int)$id]
        );

        $ejercicio = $this->db->queryOne(
            'SELECT * FROM ejercicios WHERE comunidad_id = ? AND estado = "activo" LIMIT 1',
            [(int)$id]
        );

        $stats = [
            'recibos_pendientes' => $this->db->queryOne('SELECT COUNT(*) as n, COALESCE(SUM(importe_pendiente),0) as total FROM recibos WHERE comunidad_id = ? AND estado = "pendiente"', [(int)$id]),
            'averias_abiertas'   => $this->db->queryOne('SELECT COUNT(*) as n FROM averias WHERE comunidad_id = ? AND estado NOT IN ("resuelta","cerrada","cancelada")', [(int)$id]),
            'morosos'            => $this->db->queryOne('SELECT COUNT(*) as n, COALESCE(SUM(deuda_total),0) as total FROM morosos WHERE comunidad_id = ? AND estado = "activo"', [(int)$id]),
        ];

        $pageTitle   = $comunidad['nombre'];
        $breadcrumbs = [
            ['label' => 'Comunidades', 'url' => '/comunidades'],
            ['label' => $comunidad['nombre']],
        ];

        ob_start();
        require VIEWS_PATH . '/comunidades/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function create(): void
    {
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );
        $pageTitle   = 'Nueva Comunidad';
        $breadcrumbs = [
            ['label' => 'Comunidades', 'url' => '/comunidades'],
            ['label' => 'Nueva'],
        ];

        ob_start();
        require VIEWS_PATH . '/comunidades/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/comunidades/nueva');
        }

        $nombre    = trim($_POST['nombre']    ?? '');
        $direccion = trim($_POST['direccion'] ?? '');
        $tipo      = $_POST['tipo']           ?? 'horizontal';

        if (!$nombre || !$direccion) {
            flash('error', 'El nombre y la dirección son obligatorios.');
            redirect('/comunidades/nueva');
        }

        $id = $this->db->insert(
            'INSERT INTO comunidades
             (gestora_id, nombre, tipo, nif, direccion, ciudad, cp, provincia,
              num_viviendas, num_locales, num_garajes, cuota_mensual_defecto,
              seguro_compania, seguro_poliza, iban_principal, notas)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            [
                $this->gestoraId, $nombre, $tipo,
                trim($_POST['nif']       ?? '') ?: null,
                $direccion,
                trim($_POST['ciudad']    ?? '') ?: null,
                trim($_POST['cp']        ?? '') ?: null,
                trim($_POST['provincia'] ?? '') ?: null,
                (int)($_POST['num_viviendas'] ?? 0),
                (int)($_POST['num_locales']   ?? 0),
                (int)($_POST['num_garajes']   ?? 0),
                (float)($_POST['cuota_mensual_defecto'] ?? 0),
                trim($_POST['seguro_compania'] ?? '') ?: null,
                trim($_POST['seguro_poliza']   ?? '') ?: null,
                trim($_POST['iban_principal']  ?? '') ?: null,
                trim($_POST['notas']           ?? '') ?: null,
            ]
        );

        flash('success', "Comunidad «$nombre» creada correctamente.");
        redirect('/comunidades/' . $id);
    }

    public function edit(string $id): void
    {
        $comunidad   = $this->getComunidadOrFail((int)$id);
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );
        $pageTitle   = 'Editar · ' . $comunidad['nombre'];
        $breadcrumbs = [
            ['label' => 'Comunidades', 'url' => '/comunidades'],
            ['label' => $comunidad['nombre'], 'url' => '/comunidades/' . $id],
            ['label' => 'Editar'],
        ];

        ob_start();
        require VIEWS_PATH . '/comunidades/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function update(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/comunidades/' . $id . '/editar');
        }

        $comunidad = $this->getComunidadOrFail((int)$id);

        $this->db->execute(
            'UPDATE comunidades SET
             nombre = ?, tipo = ?, nif = ?, direccion = ?, ciudad = ?, cp = ?, provincia = ?,
             num_viviendas = ?, num_locales = ?, num_garajes = ?,
             cuota_mensual_defecto = ?, seguro_compania = ?, seguro_poliza = ?,
             seguro_vencimiento = ?, iban_principal = ?, banco_nombre = ?, notas = ?,
             updated_at = NOW()
             WHERE id = ? AND gestora_id = ?',
            [
                trim($_POST['nombre']),
                $_POST['tipo'],
                trim($_POST['nif']        ?? '') ?: null,
                trim($_POST['direccion']),
                trim($_POST['ciudad']     ?? '') ?: null,
                trim($_POST['cp']         ?? '') ?: null,
                trim($_POST['provincia']  ?? '') ?: null,
                (int)($_POST['num_viviendas'] ?? 0),
                (int)($_POST['num_locales']   ?? 0),
                (int)($_POST['num_garajes']   ?? 0),
                (float)($_POST['cuota_mensual_defecto'] ?? 0),
                trim($_POST['seguro_compania']  ?? '') ?: null,
                trim($_POST['seguro_poliza']    ?? '') ?: null,
                $_POST['seguro_vencimiento']    ?? null ?: null,
                trim($_POST['iban_principal']   ?? '') ?: null,
                trim($_POST['banco_nombre']     ?? '') ?: null,
                trim($_POST['notas']            ?? '') ?: null,
                $comunidad['id'], $this->gestoraId,
            ]
        );

        flash('success', 'Comunidad actualizada.');
        redirect('/comunidades/' . $id);
    }

    public function destroy(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/comunidades');
        }
        $comunidad = $this->getComunidadOrFail((int)$id);
        $this->db->execute(
            'UPDATE comunidades SET activo = 0 WHERE id = ? AND gestora_id = ?',
            [$comunidad['id'], $this->gestoraId]
        );
        flash('success', 'Comunidad desactivada.');
        redirect('/comunidades');
    }

    private function getComunidadOrFail(int $id): array
    {
        $c = $this->db->queryOne(
            'SELECT * FROM comunidades WHERE id = ? AND gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$c) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $c;
    }
}

<?php
namespace Controllers\Economica;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class PresupuestoController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireModule('economica');
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

        $ejercicios = $this->db->query(
            'SELECT e.*, c.nombre as comunidad_nombre
             FROM ejercicios e JOIN comunidades c ON c.id = e.comunidad_id
             WHERE c.gestora_id = ? ORDER BY e.anio DESC, c.nombre ASC',
            [$this->gestoraId]
        );

        $pageTitle   = 'Presupuestos Anuales';
        $breadcrumbs = [
            ['label' => 'Económica', 'url' => '/economica'],
            ['label' => 'Presupuestos'],
        ];

        ob_start();
        require VIEWS_PATH . '/economica/presupuestos/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function show(string $id): void
    {
        $ejercicio = $this->db->queryOne(
            'SELECT e.*, c.nombre as comunidad_nombre
             FROM ejercicios e JOIN comunidades c ON c.id = e.comunidad_id
             WHERE e.id = ? AND c.gestora_id = ?',
            [(int)$id, $this->gestoraId]
        );
        if (!$ejercicio) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }

        $partidas = $this->db->query(
            'SELECT p.*, cat.nombre as categoria, cat.tipo
             FROM presupuestos p
             JOIN categorias_contables cat ON cat.id = p.categoria_id
             WHERE p.ejercicio_id = ?
             ORDER BY cat.tipo DESC, cat.nombre ASC',
            [(int)$id]
        );

        $totales = [
            'ingresos_previstos' => array_sum(array_column(array_filter($partidas, fn($r) => $r['tipo'] === 'ingreso'), 'importe_previsto')),
            'gastos_previstos'   => array_sum(array_column(array_filter($partidas, fn($r) => $r['tipo'] === 'gasto'),   'importe_previsto')),
            'ingresos_reales'    => array_sum(array_column(array_filter($partidas, fn($r) => $r['tipo'] === 'ingreso'), 'importe_real')),
            'gastos_reales'      => array_sum(array_column(array_filter($partidas, fn($r) => $r['tipo'] === 'gasto'),   'importe_real')),
        ];
        $totales['superavit_previsto'] = $totales['ingresos_previstos'] - $totales['gastos_previstos'];
        $totales['superavit_real']     = $totales['ingresos_reales']    - $totales['gastos_reales'];

        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Presupuesto ' . $ejercicio['anio'] . ' · ' . $ejercicio['comunidad_nombre'];
        $breadcrumbs = [
            ['label' => 'Económica', 'url' => '/economica'],
            ['label' => 'Presupuestos', 'url' => '/economica/presupuestos'],
            ['label' => $ejercicio['anio'] . ' · ' . $ejercicio['comunidad_nombre']],
        ];

        ob_start();
        require VIEWS_PATH . '/economica/presupuestos/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/economica/presupuestos');
        }

        $comunidadId = (int)($_POST['comunidad_id'] ?? 0);
        $anio        = (int)($_POST['anio'] ?? date('Y'));

        $comunidad = $this->db->queryOne(
            'SELECT id FROM comunidades WHERE id = ? AND gestora_id = ?',
            [$comunidadId, $this->gestoraId]
        );
        if (!$comunidad) { flash('error', 'Comunidad no válida.'); redirect('/economica/presupuestos'); }

        $existe = $this->db->queryOne(
            'SELECT id FROM ejercicios WHERE comunidad_id = ? AND anio = ?',
            [$comunidadId, $anio]
        );
        if ($existe) {
            flash('warning', "Ya existe un ejercicio para el año $anio en esa comunidad.");
            redirect('/economica/presupuestos');
        }

        $id = $this->db->insert(
            'INSERT INTO ejercicios (comunidad_id, anio, fecha_inicio, fecha_fin, estado)
             VALUES (?, ?, ?, ?, "borrador")',
            [$comunidadId, $anio, "$anio-01-01", "$anio-12-31"]
        );

        flash('success', "Ejercicio $anio creado. Añade las partidas presupuestarias.");
        redirect('/economica/presupuestos/' . $id);
    }
}

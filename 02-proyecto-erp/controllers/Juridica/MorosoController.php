<?php
namespace Controllers\Juridica;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class MorosoController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireModule('juridica');
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $this->gestoraId = (int)(($resolver->getGestora() ?? [])['id'] ?? 0);
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $filtros = [
            'estado'       => $_GET['estado']       ?? '',
            'comunidad_id' => (int)($_GET['comunidad_id'] ?? 0),
        ];

        $where  = ['m.gestora_id = ?'];
        $params = [$this->gestoraId];

        if ($filtros['estado'])       { $where[] = 'm.estado = ?';       $params[] = $filtros['estado']; }
        if ($filtros['comunidad_id']) { $where[] = 'm.comunidad_id = ?'; $params[] = $filtros['comunidad_id']; }

        $paginado = $this->db->paginate(
            'SELECT m.*,
                    c.nombre as comunidad_nombre,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    i.referencia as inmueble_ref
             FROM morosos m
             JOIN comunidades c  ON c.id = m.comunidad_id
             JOIN propietarios p ON p.id = m.propietario_id
             JOIN inmuebles i    ON i.id = m.inmueble_id
             WHERE ' . implode(' AND ', $where) . '
             ORDER BY m.deuda_total DESC, m.updated_at DESC',
            $params,
            (int)($_GET['pagina'] ?? 1), 20
        );

        // KPIs
        $kpis = $this->db->queryOne(
            'SELECT COUNT(*) as total,
                    SUM(deuda_total) as deuda_total,
                    COUNT(CASE WHEN estado="judicial" THEN 1 END) as judiciales,
                    COUNT(CASE WHEN estado="acuerdo_pago" THEN 1 END) as acuerdos
             FROM morosos WHERE gestora_id = ? AND estado != "resuelto"',
            [$this->gestoraId]
        );

        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];
        $pageTitle   = 'Gestión de Morosos';
        $breadcrumbs = [
            ['label' => 'Jurídica', 'url' => '/juridica'],
            ['label' => 'Morosos'],
        ];

        ob_start();
        require VIEWS_PATH . '/juridica/morosos/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function create(): void
    {
        $currentUser = $this->auth->user();
        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Nuevo Expediente Moroso';
        $breadcrumbs = [
            ['label' => 'Jurídica', 'url' => '/juridica'],
            ['label' => 'Morosos', 'url' => '/juridica/morosos'],
            ['label' => 'Nuevo'],
        ];

        ob_start();
        require VIEWS_PATH . '/juridica/morosos/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/juridica/morosos/nuevo');
        }

        $comunidadId  = (int)($_POST['comunidad_id']  ?? 0);
        $propietarioId= (int)($_POST['propietario_id'] ?? 0);
        $inmuebleId   = (int)($_POST['inmueble_id']    ?? 0);
        $deuda        = (float)($_POST['deuda_total']  ?? 0);
        $fechaInicio  = $_POST['fecha_inicio'] ?? date('Y-m-d');

        if (!$comunidadId || !$propietarioId || !$inmuebleId || $deuda <= 0) {
            flash('error', 'Completa todos los campos.');
            redirect('/juridica/morosos/nuevo');
        }

        // Marcar propietario como moroso
        $this->db->execute(
            'UPDATE propietarios SET moroso = 1 WHERE id = ? AND gestora_id = ?',
            [$propietarioId, $this->gestoraId]
        );

        $id = $this->db->insert(
            'INSERT INTO morosos (gestora_id, comunidad_id, propietario_id, inmueble_id,
             deuda_total, fecha_inicio_morosidad, estado, notas)
             VALUES (?,?,?,?,?,?,?,?)',
            [
                $this->gestoraId, $comunidadId, $propietarioId, $inmuebleId,
                $deuda, $fechaInicio, 'activo',
                trim($_POST['notas'] ?? ''),
            ]
        );

        flash('success', 'Expediente de morosidad creado.');
        redirect('/juridica/morosos/' . $id);
    }

    public function show(string $id): void
    {
        $moroso = $this->getMorosoOrFail((int)$id);
        $currentUser = $this->auth->user();
        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];

        // Recibos pendientes de este propietario en esta comunidad
        $recibosPendientes = $this->db->query(
            'SELECT * FROM recibos
             WHERE propietario_id = ? AND comunidad_id = ? AND estado IN ("pendiente","devuelto")
             ORDER BY fecha_vencimiento ASC',
            [$moroso['propietario_id'], $moroso['comunidad_id']]
        );
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Expediente Moroso · ' . $moroso['propietario_nombre'];
        $breadcrumbs = [
            ['label' => 'Jurídica', 'url' => '/juridica'],
            ['label' => 'Morosos', 'url' => '/juridica/morosos'],
            ['label' => $moroso['propietario_nombre']],
        ];

        ob_start();
        require VIEWS_PATH . '/juridica/morosos/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function update(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/juridica/morosos/' . $id);
        }

        $moroso = $this->getMorosoOrFail((int)$id);

        $campos = ['estado','abogado_nombre','abogado_email','num_procedimiento',
                   'juzgado','fecha_demanda','sentencia','fecha_sentencia','notas'];
        $sets   = [];
        $params = [];

        foreach ($campos as $c) {
            if (isset($_POST[$c])) {
                $sets[]  = "$c = ?";
                $params[] = $_POST[$c] !== '' ? $_POST[$c] : null;
            }
        }

        if (!empty($_POST['deuda_total'])) {
            $sets[]   = 'deuda_total = ?';
            $params[] = (float)$_POST['deuda_total'];
        }

        if (!empty($sets)) {
            $params[] = $moroso['id'];
            $this->db->execute(
                'UPDATE morosos SET ' . implode(', ', $sets) . ', updated_at = NOW() WHERE id = ?',
                $params
            );
        }

        // Si se resuelve, desmarcar propietario como moroso
        if (($_POST['estado'] ?? '') === 'resuelto') {
            $this->db->execute(
                'UPDATE propietarios SET moroso = 0 WHERE id = ?',
                [$moroso['propietario_id']]
            );
        }

        flash('success', 'Expediente actualizado.');
        redirect('/juridica/morosos/' . $id);
    }

    private function getMorosoOrFail(int $id): array
    {
        $m = $this->db->queryOne(
            'SELECT m.*,
                    c.nombre as comunidad_nombre,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    p.email as propietario_email, p.telefono as propietario_tel,
                    i.referencia as inmueble_ref
             FROM morosos m
             JOIN comunidades c  ON c.id = m.comunidad_id
             JOIN propietarios p ON p.id = m.propietario_id
             JOIN inmuebles i    ON i.id = m.inmueble_id
             WHERE m.id = ? AND m.gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$m) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $m;
    }
}

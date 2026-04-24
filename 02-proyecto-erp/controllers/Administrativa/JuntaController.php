<?php
namespace Controllers\Administrativa;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class JuntaController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireModule('admin');
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

        $filtro_tipo = $_GET['tipo'] ?? '';
        $filtro_com  = (int)($_GET['comunidad_id'] ?? 0);

        $where  = ['j.gestora_id = ?'];
        $params = [$this->gestoraId];
        if ($filtro_tipo) { $where[] = 'j.tipo = ?';         $params[] = $filtro_tipo; }
        if ($filtro_com)  { $where[] = 'j.comunidad_id = ?'; $params[] = $filtro_com; }

        $paginado = $this->db->paginate(
            'SELECT j.*, c.nombre as comunidad_nombre
             FROM juntas j JOIN comunidades c ON c.id = j.comunidad_id
             WHERE ' . implode(' AND ', $where) . '
             ORDER BY j.fecha_primera DESC',
            $params,
            (int)($_GET['pagina'] ?? 1), 20
        );

        $pageTitle   = 'Juntas de Propietarios';
        $breadcrumbs = [['label' => 'Juntas']];

        ob_start();
        require VIEWS_PATH . '/administrativa/juntas/index.php';
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

        $pageTitle   = 'Convocar Junta';
        $breadcrumbs = [
            ['label' => 'Juntas', 'url' => '/juntas'],
            ['label' => 'Nueva Convocatoria'],
        ];

        ob_start();
        require VIEWS_PATH . '/administrativa/juntas/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/juntas/nueva');
        }

        $comunidadId = (int)($_POST['comunidad_id'] ?? 0);
        $titulo      = trim($_POST['titulo']         ?? '');
        $tipo        = $_POST['tipo']                ?? 'ordinaria';
        $fechaPrimera= $_POST['fecha_primera']       ?? '';
        $lugar       = trim($_POST['lugar']          ?? '');
        $modalidad   = $_POST['modalidad']           ?? 'presencial';
        $ordenDia    = trim($_POST['orden_del_dia']  ?? '');

        if (!$comunidadId || !$titulo || !$fechaPrimera) {
            flash('error', 'Completa todos los campos obligatorios.');
            redirect('/juntas/nueva');
        }

        $id = $this->db->insert(
            'INSERT INTO juntas
             (gestora_id, comunidad_id, tipo, titulo, fecha_convocatoria,
              fecha_primera, fecha_segunda, lugar, modalidad, url_reunion,
              orden_del_dia, estado)
             VALUES (?,?,?,?,NOW(),?,?,?,?,?,?,?)',
            [
                $this->gestoraId, $comunidadId, $tipo, $titulo,
                $fechaPrimera,
                $_POST['fecha_segunda'] ?? null,
                $lugar, $modalidad,
                trim($_POST['url_reunion'] ?? '') ?: null,
                $ordenDia, 'convocada',
            ]
        );

        flash('success', 'Junta convocada correctamente.');
        redirect('/juntas/' . $id);
    }

    public function show(string $id): void
    {
        $junta = $this->getJuntaOrFail((int)$id);
        $currentUser = $this->auth->user();

        $acuerdos = $this->db->query(
            'SELECT * FROM acuerdos WHERE junta_id = ? ORDER BY numero_punto ASC',
            [(int)$id]
        );
        $asistentes = $this->db->query(
            'SELECT ja.*, CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    i.referencia as inmueble_ref, ja.coeficiente
             FROM juntas_asistentes ja
             JOIN propietarios p ON p.id = ja.propietario_id
             JOIN inmuebles i    ON i.id = ja.inmueble_id
             WHERE ja.junta_id = ? ORDER BY p.apellidos ASC',
            [(int)$id]
        );

        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = $junta['titulo'];
        $breadcrumbs = [
            ['label' => 'Juntas', 'url' => '/juntas'],
            ['label' => $junta['titulo']],
        ];

        ob_start();
        require VIEWS_PATH . '/administrativa/juntas/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function addAcuerdo(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            json(['ok' => false, 'error' => 'CSRF inválido'], 422);
        }

        $junta = $this->getJuntaOrFail((int)$id);

        $numeroPunto = (int)($_POST['numero_punto'] ?? 1);
        $titulo      = trim($_POST['titulo']         ?? '');
        $descripcion = trim($_POST['descripcion']    ?? '');
        $resultado   = $_POST['resultado']           ?? 'aprobado';
        $tipoMayoria = $_POST['tipo_mayoria']        ?? 'simple';

        if (!$titulo) { json(['ok' => false, 'error' => 'El título es obligatorio'], 422); }

        $acuerdoId = $this->db->insert(
            'INSERT INTO acuerdos
             (junta_id, numero_punto, titulo, descripcion, tipo_mayoria, resultado,
              votos_favor, votos_contra, votos_abstenciones, plazo_ejecucion, responsable)
             VALUES (?,?,?,?,?,?,?,?,?,?,?)',
            [
                $junta['id'], $numeroPunto, $titulo, $descripcion,
                $tipoMayoria, $resultado,
                (int)($_POST['votos_favor']        ?? 0),
                (int)($_POST['votos_contra']       ?? 0),
                (int)($_POST['votos_abstenciones'] ?? 0),
                $_POST['plazo_ejecucion'] ?? null,
                trim($_POST['responsable'] ?? '') ?: null,
            ]
        );

        json(['ok' => true, 'id' => $acuerdoId]);
    }

    public function convocatoriaPdf(string $id): void
    {
        $junta = $this->getJuntaOrFail((int)$id);
        // TODO: Implementar generación de PDF con biblioteca (mPDF o FPDF)
        // Por ahora redirige a la vista de detalle
        flash('warning', 'La generación de PDF estará disponible próximamente.');
        redirect('/juntas/' . $id);
    }

    public function actaPdf(string $id): void
    {
        $junta = $this->getJuntaOrFail((int)$id);
        flash('warning', 'La generación de PDF del acta estará disponible próximamente.');
        redirect('/juntas/' . $id);
    }

    private function getJuntaOrFail(int $id): array
    {
        $j = $this->db->queryOne(
            'SELECT j.*, c.nombre as comunidad_nombre
             FROM juntas j JOIN comunidades c ON c.id = j.comunidad_id
             WHERE j.id = ? AND j.gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$j) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $j;
    }
}

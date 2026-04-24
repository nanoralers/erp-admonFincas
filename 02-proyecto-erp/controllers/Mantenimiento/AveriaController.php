<?php
namespace Controllers\Mantenimiento;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class AveriaController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireModule('mantenimiento');
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

        $filtros = [
            'estado'       => $_GET['estado']       ?? '',
            'urgencia'     => $_GET['urgencia']     ?? '',
            'comunidad_id' => (int)($_GET['comunidad_id'] ?? 0),
            'q'            => trim($_GET['q']        ?? ''),
        ];

        $where  = ['a.gestora_id = ?'];
        $params = [$this->gestoraId];

        if ($filtros['estado'])       { $where[] = 'a.estado = ?';       $params[] = $filtros['estado']; }
        if ($filtros['urgencia'])     { $where[] = 'a.urgencia = ?';     $params[] = $filtros['urgencia']; }
        if ($filtros['comunidad_id']) { $where[] = 'a.comunidad_id = ?'; $params[] = $filtros['comunidad_id']; }
        if ($filtros['q']) {
            $where[]  = '(a.titulo LIKE ? OR a.numero LIKE ?)';
            $like     = '%' . $filtros['q'] . '%';
            $params[] = $like;
            $params[] = $like;
        }

        $sql = 'SELECT a.*, c.nombre as comunidad_nombre,
                       prov.nombre as proveedor_nombre
                FROM averias a
                JOIN comunidades c ON c.id = a.comunidad_id
                LEFT JOIN proveedores prov ON prov.id = a.proveedor_id
                WHERE ' . implode(' AND ', $where) . '
                ORDER BY
                  CASE a.urgencia
                    WHEN "critica" THEN 1 WHEN "alta" THEN 2
                    WHEN "media"   THEN 3 ELSE 4 END,
                  a.fecha_apertura DESC';

        $paginado = $this->db->paginate($sql, $params, (int)($_GET['pagina'] ?? 1), 20);

        $pageTitle   = 'Gestión de Averías';
        $breadcrumbs = [
            ['label' => 'Mantenimiento', 'url' => '/mantenimiento'],
            ['label' => 'Averías'],
        ];

        ob_start();
        require VIEWS_PATH . '/mantenimiento/averias/index.php';
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
        $proveedores = $this->db->query(
            'SELECT id, nombre, categoria FROM proveedores WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Nueva Avería';
        $breadcrumbs = [
            ['label' => 'Mantenimiento', 'url' => '/mantenimiento'],
            ['label' => 'Averías', 'url' => '/mantenimiento/averias'],
            ['label' => 'Nueva'],
        ];

        ob_start();
        require VIEWS_PATH . '/mantenimiento/averias/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/mantenimiento/averias/nueva');
        }

        $comunidadId = (int)($_POST['comunidad_id'] ?? 0);
        $titulo      = trim($_POST['titulo'] ?? '');
        $descripcion = trim($_POST['descripcion'] ?? '');
        $urgencia    = $_POST['urgencia'] ?? 'media';
        $categoria   = trim($_POST['categoria'] ?? '');
        $zona        = trim($_POST['zona'] ?? '');
        $proveedorId = (int)($_POST['proveedor_id'] ?? 0) ?: null;

        if (!$comunidadId || !$titulo || !$descripcion) {
            flash('error', 'Completa los campos obligatorios.');
            redirect('/mantenimiento/averias/nueva');
        }

        // Número de avería secuencial
        $count = $this->db->queryOne(
            'SELECT COUNT(*)+1 as n FROM averias WHERE gestora_id = ?',
            [$this->gestoraId]
        );
        $numero = 'AV-' . date('Y') . '-' . str_pad((string)($count['n'] ?? 1), 5, '0', STR_PAD_LEFT);

        $id = $this->db->insert(
            'INSERT INTO averias
             (gestora_id, comunidad_id, numero, titulo, descripcion, urgencia, categoria,
              zona, proveedor_id, estado, reportado_por)
             VALUES (?,?,?,?,?,?,?,?,?,
               CASE ? WHEN "critica" THEN "asignada" ELSE "abierta" END,
               ?)',
            [
                $this->gestoraId, $comunidadId, $numero, $titulo, $descripcion,
                $urgencia, $categoria, $zona, $proveedorId,
                $urgencia,
                $_SESSION['user_id'],
            ]
        );

        flash('success', "Avería $numero registrada correctamente.");
        redirect('/mantenimiento/averias/' . $id);
    }

    public function show(string $id): void
    {
        $averia = $this->getAveriaOrFail((int)$id);
        $currentUser = $this->auth->user();

        $seguimiento = $this->db->query(
            'SELECT s.*, u.nombre as usuario_nombre
             FROM averia_seguimiento s
             LEFT JOIN usuarios u ON u.id = s.usuario_id
             WHERE s.averia_id = ? ORDER BY s.created_at ASC',
            [(int)$id]
        );
        $proveedores = $this->db->query(
            'SELECT id, nombre, categoria, telefono_urgencias FROM proveedores
             WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Avería ' . $averia['numero'];
        $breadcrumbs = [
            ['label' => 'Mantenimiento', 'url' => '/mantenimiento'],
            ['label' => 'Averías', 'url' => '/mantenimiento/averias'],
            ['label' => $averia['numero']],
        ];

        ob_start();
        require VIEWS_PATH . '/mantenimiento/averias/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function cambiarEstado(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            json(['ok' => false, 'error' => 'CSRF inválido'], 422);
        }

        $averia     = $this->getAveriaOrFail((int)$id);
        $nuevoEstado = $_POST['estado']     ?? '';
        $comentario  = trim($_POST['comentario'] ?? '');
        $proveedorId = (int)($_POST['proveedor_id'] ?? 0) ?: null;

        $estadosValidos = ['abierta','asignada','en_proceso','resuelta','cerrada','cancelada'];
        if (!in_array($nuevoEstado, $estadosValidos, true)) {
            json(['ok' => false, 'error' => 'Estado inválido'], 422);
        }

        $updates = ['estado = ?', 'updated_at = NOW()'];
        $params  = [$nuevoEstado];

        if ($nuevoEstado === 'asignada' && $proveedorId) {
            $updates[] = 'proveedor_id = ?';
            $updates[] = 'fecha_asignacion = NOW()';
            $params[]  = $proveedorId;
        }
        if ($nuevoEstado === 'resuelta') {
            $updates[] = 'fecha_resolucion = NOW()';
        }

        $params[] = $averia['id'];
        $this->db->execute(
            'UPDATE averias SET ' . implode(', ', $updates) . ' WHERE id = ?',
            $params
        );

        $this->db->execute(
            'INSERT INTO averia_seguimiento (averia_id, usuario_id, estado_nuevo, comentario)
             VALUES (?,?,?,?)',
            [$averia['id'], $_SESSION['user_id'], $nuevoEstado, $comentario]
        );

        json(['ok' => true, 'estado' => $nuevoEstado]);
    }

    private function getAveriaOrFail(int $id): array
    {
        $a = $this->db->queryOne(
            'SELECT a.*, c.nombre as comunidad_nombre, p.nombre as proveedor_nombre
             FROM averias a
             JOIN comunidades c ON c.id = a.comunidad_id
             LEFT JOIN proveedores p ON p.id = a.proveedor_id
             WHERE a.id = ? AND a.gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$a) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $a;
    }
}

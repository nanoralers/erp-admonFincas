<?php
namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class PropietarioController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
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

        $q     = trim($_GET['q']            ?? '');
        $comId = (int)($_GET['comunidad_id'] ?? 0);
        $moroso= $_GET['moroso']             ?? '';

        $where  = ['p.gestora_id = ?'];
        $params = [$this->gestoraId];

        if ($q) {
            $where[]  = '(p.nombre LIKE ? OR p.apellidos LIKE ? OR p.email LIKE ? OR p.nif LIKE ?)';
            $like     = "%$q%";
            $params   = array_merge($params, [$like, $like, $like, $like]);
        }
        if ($comId) {
            $where[]  = 'EXISTS (SELECT 1 FROM inmuebles i WHERE i.propietario_id = p.id AND i.comunidad_id = ?)';
            $params[] = $comId;
        }
        if ($moroso !== '') {
            $where[]  = 'p.moroso = ?';
            $params[] = (int)$moroso;
        }

        $paginado = $this->db->paginate(
            'SELECT p.*,
                    COUNT(DISTINCT i.id) as num_inmuebles
             FROM propietarios p
             LEFT JOIN inmuebles i ON i.propietario_id = p.id
             WHERE ' . implode(' AND ', $where) . '
             GROUP BY p.id
             ORDER BY p.apellidos ASC, p.nombre ASC',
            $params,
            (int)($_GET['pagina'] ?? 1), 25
        );

        $pageTitle   = 'Propietarios';
        $breadcrumbs = [['label' => 'Propietarios']];

        $gestora = (new SubdomainResolver())->getGestora() ?? [];
        ob_start();
        require VIEWS_PATH . '/propietarios/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function show(string $id): void
    {
        $propietario = $this->getOrFail((int)$id);
        $currentUser = $this->auth->user();

        $inmuebles = $this->db->query(
            'SELECT i.*, c.nombre as comunidad_nombre
             FROM inmuebles i JOIN comunidades c ON c.id = i.comunidad_id
             WHERE i.propietario_id = ?',
            [(int)$id]
        );
        $recibos = $this->db->query(
            'SELECT r.*, c.nombre as comunidad_nombre
             FROM recibos r JOIN comunidades c ON c.id = r.comunidad_id
             WHERE r.propietario_id = ?
             ORDER BY r.fecha_emision DESC LIMIT 20',
            [(int)$id]
        );

        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );
        $gestora     = (new SubdomainResolver())->getGestora() ?? [];
        $pageTitle   = ($propietario['nombre'] . ' ' . ($propietario['apellidos'] ?? ''));
        $breadcrumbs = [
            ['label' => 'Propietarios', 'url' => '/propietarios'],
            ['label' => $pageTitle],
        ];

        ob_start();
        require VIEWS_PATH . '/propietarios/show.php';
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
        $gestora     = (new SubdomainResolver())->getGestora() ?? [];
        $pageTitle   = 'Nuevo Propietario';
        $breadcrumbs = [
            ['label' => 'Propietarios', 'url' => '/propietarios'],
            ['label' => 'Nuevo'],
        ];

        ob_start();
        require VIEWS_PATH . '/propietarios/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/propietarios/nuevo');
        }

        $nombre = trim($_POST['nombre'] ?? '');
        if (!$nombre) {
            flash('error', 'El nombre es obligatorio.'); redirect('/propietarios/nuevo');
        }

        $id = $this->db->insert(
            'INSERT INTO propietarios
             (gestora_id, tipo, nombre, apellidos, razon_social, nif,
              email, telefono, telefono2, direccion_fiscal, iban, notas)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
            [
                $this->gestoraId,
                $_POST['tipo']           ?? 'propietario',
                $nombre,
                trim($_POST['apellidos']       ?? '') ?: null,
                trim($_POST['razon_social']    ?? '') ?: null,
                trim($_POST['nif']             ?? '') ?: null,
                trim($_POST['email']           ?? '') ?: null,
                trim($_POST['telefono']        ?? '') ?: null,
                trim($_POST['telefono2']       ?? '') ?: null,
                trim($_POST['direccion_fiscal']?? '') ?: null,
                trim($_POST['iban']            ?? '') ?: null,
                trim($_POST['notas']           ?? '') ?: null,
            ]
        );

        flash('success', 'Propietario creado.');
        redirect('/propietarios/' . $id);
    }

    public function edit(string $id): void
    {
        $propietario = $this->getOrFail((int)$id);
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );
        $gestora     = (new SubdomainResolver())->getGestora() ?? [];
        $pageTitle   = 'Editar propietario';
        $breadcrumbs = [
            ['label' => 'Propietarios', 'url' => '/propietarios'],
            ['label' => $propietario['nombre'], 'url' => '/propietarios/' . $id],
            ['label' => 'Editar'],
        ];

        ob_start();
        require VIEWS_PATH . '/propietarios/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    public function update(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/propietarios/' . $id . '/editar');
        }

        $p = $this->getOrFail((int)$id);
        $this->db->execute(
            'UPDATE propietarios SET
             tipo=?,nombre=?,apellidos=?,razon_social=?,nif=?,email=?,
             telefono=?,telefono2=?,direccion_fiscal=?,iban=?,notas=?,updated_at=NOW()
             WHERE id=? AND gestora_id=?',
            [
                $_POST['tipo'],
                trim($_POST['nombre']),
                trim($_POST['apellidos']       ?? '') ?: null,
                trim($_POST['razon_social']    ?? '') ?: null,
                trim($_POST['nif']             ?? '') ?: null,
                trim($_POST['email']           ?? '') ?: null,
                trim($_POST['telefono']        ?? '') ?: null,
                trim($_POST['telefono2']       ?? '') ?: null,
                trim($_POST['direccion_fiscal']?? '') ?: null,
                trim($_POST['iban']            ?? '') ?: null,
                trim($_POST['notas']           ?? '') ?: null,
                $p['id'], $this->gestoraId,
            ]
        );
        flash('success', 'Propietario actualizado.');
        redirect('/propietarios/' . $id);
    }

    private function getOrFail(int $id): array
    {
        $p = $this->db->queryOne(
            'SELECT * FROM propietarios WHERE id = ? AND gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$p) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $p;
    }
}

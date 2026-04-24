<?php
namespace Admin;

use Core\Auth;
use Core\Database;

class DashboardController
{
    private Auth $auth;
    private Database $db;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        // Solo superadmin puede acceder al panel admin
        if (($_SESSION['rol'] ?? '') !== 'superadmin') {
            http_response_code(403);
            require VIEWS_PATH . '/errors/403.php';
            exit;
        }
        $this->db = Database::getInstance();
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();

        $stats = [
            'total_gestoras'    => $this->db->queryOne('SELECT COUNT(*) as n FROM gestoras WHERE activo = 1')['n']  ?? 0,
            'total_usuarios'    => $this->db->queryOne('SELECT COUNT(*) as n FROM usuarios WHERE activo = 1')['n']  ?? 0,
            'total_comunidades' => $this->db->queryOne('SELECT COUNT(*) as n FROM comunidades WHERE activo = 1')['n']?? 0,
            'trial_expiring'    => $this->db->queryOne(
                'SELECT COUNT(*) as n FROM gestoras WHERE trial_hasta BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)'
            )['n'] ?? 0,
            'sub_expiring'      => $this->db->queryOne(
                'SELECT COUNT(*) as n FROM gestoras WHERE suscripcion_hasta BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)'
            )['n'] ?? 0,
        ];

        $gestoras_recientes = $this->db->query(
            'SELECT g.*, p.nombre as plan_nombre, p.color_badge,
                    (SELECT COUNT(*) FROM comunidades WHERE gestora_id = g.id AND activo = 1) as comunidades
             FROM gestoras g JOIN planes p ON p.id = g.plan_id
             ORDER BY g.created_at DESC LIMIT 10'
        );

        $actividad = $this->db->query(
            'SELECT al.*, g.nombre as gestora_nombre, u.email as usuario_email
             FROM audit_log al
             LEFT JOIN gestoras g ON g.id = al.gestora_id
             LEFT JOIN usuarios u ON u.id = al.usuario_id
             ORDER BY al.created_at DESC LIMIT 20'
        );

        $planes = $this->db->query(
            'SELECT p.*,
                    COUNT(g.id) as gestoras_en_plan
             FROM planes p
             LEFT JOIN gestoras g ON g.plan_id = p.id AND g.activo = 1
             GROUP BY p.id ORDER BY p.orden'
        );

        $pageTitle = 'Panel Superadministrador';
        $gestora   = ['nombre_app' => 'ERP Fincas Admin'];
        $comunidades = [];

        ob_start();
        require VIEWS_PATH . '/admin/dashboard.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/admin/layout.php';
    }
}

class GestoraController
{
    private Auth $auth;
    private Database $db;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        if (($_SESSION['rol'] ?? '') !== 'superadmin') {
            http_response_code(403); require VIEWS_PATH . '/errors/403.php'; exit;
        }
        $this->db = Database::getInstance();
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        $q     = trim($_GET['q'] ?? '');
        $where = []; $params = [];

        if ($q) {
            $where[]  = '(g.nombre LIKE ? OR g.subdominio LIKE ? OR g.email_contacto LIKE ?)';
            $like     = "%$q%";
            $params   = [$like, $like, $like];
        }

        $sql = 'SELECT g.*, p.nombre as plan_nombre, p.color_badge,
                       (SELECT COUNT(*) FROM comunidades WHERE gestora_id = g.id AND activo = 1) as comunidades,
                       (SELECT COUNT(*) FROM usuarios WHERE gestora_id = g.id AND activo = 1) as usuarios
                FROM gestoras g JOIN planes p ON p.id = g.plan_id'
            . ($where ? ' WHERE ' . implode(' AND ', $where) : '')
            . ' ORDER BY g.created_at DESC';

        $paginado = $this->db->paginate($sql, $params, (int)($_GET['pagina'] ?? 1), 20);
        $planes   = $this->db->query('SELECT * FROM planes ORDER BY orden');

        $pageTitle   = 'Gestoras';
        $gestora     = ['nombre_app' => 'ERP Fincas Admin'];
        $comunidades = [];

        ob_start();
        require VIEWS_PATH . '/admin/gestoras/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/admin/layout.php';
    }

    public function create(): void
    {
        $currentUser = $this->auth->user();
        $planes      = $this->db->query('SELECT * FROM planes WHERE activo = 1 ORDER BY orden');

        $pageTitle   = 'Nueva Gestora';
        $gestora     = ['nombre_app' => 'ERP Fincas Admin'];
        $comunidades = [];

        ob_start();
        require VIEWS_PATH . '/admin/gestoras/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/admin/layout.php';
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.'); redirect('/gestoras/nueva');
        }

        $subdominio = strtolower(trim($_POST['subdominio'] ?? ''));
        $nombre     = trim($_POST['nombre']         ?? '');
        $email      = trim($_POST['email_contacto'] ?? '');
        $planId     = (int)($_POST['plan_id']       ?? 1);

        // Validaciones
        if (!preg_match('/^[a-z0-9-]{3,30}$/', $subdominio)) {
            flash('error', 'Subdominio inválido (3-30 chars, solo letras, números y guiones).');
            redirect('/gestoras/nueva');
        }
        $existe = $this->db->queryOne('SELECT id FROM gestoras WHERE subdominio = ?', [$subdominio]);
        if ($existe) {
            flash('error', "El subdominio «$subdominio» ya está en uso.");
            redirect('/gestoras/nueva');
        }

        $id = $this->db->insert(
            'INSERT INTO gestoras
             (plan_id, subdominio, nombre, razon_social, nif, email_contacto,
              telefono, color_primario, color_secundario, color_acento, nombre_app,
              suscripcion_desde, suscripcion_hasta, activo)
             VALUES (?,?,?,?,?,?,?,?,?,?,?,CURDATE(),
               DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1)',
            [
                $planId, $subdominio, $nombre,
                trim($_POST['razon_social'] ?? '') ?: null,
                trim($_POST['nif']          ?? '') ?: null,
                $email,
                trim($_POST['telefono']     ?? '') ?: null,
                $_POST['color_primario']    ?? '#1e40af',
                $_POST['color_secundario']  ?? '#0f172a',
                $_POST['color_acento']      ?? '#38bdf8',
                $_POST['nombre_app']        ?? 'ERP Fincas',
            ]
        );

        // Crear usuario admin para la gestora
        $passTemp = bin2hex(random_bytes(6));
        $this->db->insert(
            'INSERT INTO usuarios (gestora_id, rol_id, nombre, apellidos, email, password_hash, activo, email_verified)
             VALUES (?, (SELECT id FROM roles WHERE codigo = "admin_gestora"), ?, ?, ?, ?, 1, 1)',
            [
                $id,
                trim($_POST['admin_nombre']    ?? 'Administrador'),
                trim($_POST['admin_apellidos'] ?? ''),
                $email,
                password_hash($passTemp, PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]),
            ]
        );

        flash('success', "Gestora «$nombre» creada. URL: https://{$subdominio}." . BASE_DOMAIN . " | Pass temporal admin: $passTemp");
        redirect('/gestoras');
    }

    public function show(string $id): void
    {
        $gestoraRow  = $this->getGestoraOrFail((int)$id);
        $currentUser = $this->auth->user();
        $planes      = $this->db->query('SELECT * FROM planes ORDER BY orden');

        $stats = [
            'comunidades' => $this->db->queryOne('SELECT COUNT(*) as n FROM comunidades WHERE gestora_id = ? AND activo = 1', [(int)$id])['n'] ?? 0,
            'usuarios'    => $this->db->queryOne('SELECT COUNT(*) as n FROM usuarios WHERE gestora_id = ? AND activo = 1', [(int)$id])['n'] ?? 0,
            'recibos'     => $this->db->queryOne('SELECT COUNT(*) as n FROM recibos WHERE gestora_id = ?', [(int)$id])['n'] ?? 0,
        ];
        $usuarios     = $this->db->query('SELECT u.*, r.nombre as rol_nombre FROM usuarios u JOIN roles r ON r.id = u.rol_id WHERE u.gestora_id = ? ORDER BY u.nombre', [(int)$id]);

        $pageTitle   = $gestoraRow['nombre'];
        $gestora     = ['nombre_app' => 'ERP Fincas Admin'];
        $comunidades = [];

        ob_start();
        require VIEWS_PATH . '/admin/gestoras/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/admin/layout.php';
    }

    public function edit(string $id): void
    {
        $gestoraRow  = $this->getGestoraOrFail((int)$id);
        $currentUser = $this->auth->user();
        $planes      = $this->db->query('SELECT * FROM planes ORDER BY orden');

        $pageTitle   = 'Editar Gestora · ' . $gestoraRow['nombre'];
        $gestora     = ['nombre_app' => 'ERP Fincas Admin'];
        $comunidades = [];

        ob_start();
        require VIEWS_PATH . '/admin/gestoras/form.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/admin/layout.php';
    }

    public function update(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/gestoras/' . $id . '/editar');
        }
        $gestoraRow = $this->getGestoraOrFail((int)$id);

        $this->db->execute(
            'UPDATE gestoras SET
             nombre = ?, razon_social = ?, nif = ?, email_contacto = ?, telefono = ?,
             plan_id = ?, color_primario = ?, color_secundario = ?, color_acento = ?,
             nombre_app = ?, suscripcion_hasta = ?, activo = ?, updated_at = NOW()
             WHERE id = ?',
            [
                trim($_POST['nombre']),
                trim($_POST['razon_social']  ?? '') ?: null,
                trim($_POST['nif']           ?? '') ?: null,
                trim($_POST['email_contacto']),
                trim($_POST['telefono']      ?? '') ?: null,
                (int)$_POST['plan_id'],
                $_POST['color_primario']    ?? '#1e40af',
                $_POST['color_secundario']  ?? '#0f172a',
                $_POST['color_acento']      ?? '#38bdf8',
                $_POST['nombre_app']        ?? 'ERP Fincas',
                $_POST['suscripcion_hasta'] ?? null,
                isset($_POST['activo']) ? 1 : 0,
                $gestoraRow['id'],
            ]
        );

        flash('success', 'Gestora actualizada.');
        redirect('/gestoras/' . $id);
    }

    public function toggle(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            json(['ok' => false], 422);
        }
        $g = $this->getGestoraOrFail((int)$id);
        $nuevo = $g['activo'] ? 0 : 1;
        $this->db->execute('UPDATE gestoras SET activo = ? WHERE id = ?', [$nuevo, $g['id']]);
        json(['ok' => true, 'activo' => $nuevo]);
    }

    private function getGestoraOrFail(int $id): array
    {
        $g = $this->db->queryOne(
            'SELECT g.*, p.nombre as plan_nombre FROM gestoras g JOIN planes p ON p.id = g.plan_id WHERE g.id = ?',
            [$id]
        );
        if (!$g) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $g;
    }
}

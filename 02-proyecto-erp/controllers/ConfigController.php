<?php
namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class ConfigController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        // Solo admin_gestora o superior
        if (!in_array($_SESSION['rol'] ?? '', ['admin_gestora','superadmin'], true)) {
            http_response_code(403); require VIEWS_PATH . '/errors/403.php'; exit;
        }
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $this->gestora   = $resolver->getGestora() ?? [];
        $this->gestoraId = (int)($this->gestora['id'] ?? 0);
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $plan    = $this->db->queryOne(
            'SELECT p.*, GROUP_CONCAT(m.codigo) as modulos
             FROM planes p
             LEFT JOIN planes_modulos pm ON pm.plan_id = p.id
             LEFT JOIN modulos m ON m.id = pm.modulo_id
             WHERE p.id = ?
             GROUP BY p.id',
            [$this->gestora['plan_id'] ?? 0]
        );
        $usuarios = $this->db->query(
            'SELECT u.*, r.nombre as rol_nombre
             FROM usuarios u JOIN roles r ON r.id = u.rol_id
             WHERE u.gestora_id = ? ORDER BY u.nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Configuración';
        $breadcrumbs = [['label' => 'Configuración']];

        ob_start();
        require VIEWS_PATH . '/config/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    /** Actualiza nombre, email, teléfono, etc. de la gestora */
    public function updatePerfil(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }

        $this->db->execute(
            'UPDATE gestoras SET
             nombre=?, razon_social=?, nif=?, email_contacto=?, telefono=?,
             direccion=?, ciudad=?, cp=?, provincia=?, updated_at=NOW()
             WHERE id=?',
            [
                trim($_POST['nombre']),
                trim($_POST['razon_social']  ?? '') ?: null,
                trim($_POST['nif']           ?? '') ?: null,
                trim($_POST['email_contacto']?? '') ?: null,
                trim($_POST['telefono']      ?? '') ?: null,
                trim($_POST['direccion']     ?? '') ?: null,
                trim($_POST['ciudad']        ?? '') ?: null,
                trim($_POST['cp']            ?? '') ?: null,
                trim($_POST['provincia']     ?? '') ?: null,
                $this->gestoraId,
            ]
        );

        flash('success', 'Perfil actualizado.');
        redirect('/configuracion');
    }

    /** Actualiza colores y nombre de la app (white-label) */
    public function updateBranding(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }

        $color1  = $_POST['color_primario']   ?? '#1e40af';
        $color2  = $_POST['color_secundario'] ?? '#0f172a';
        $color3  = $_POST['color_acento']     ?? '#38bdf8';
        $appName = trim($_POST['nombre_app']  ?? 'ERP Fincas');

        // Validar formato hex
        foreach ([$color1, $color2, $color3] as $c) {
            if (!preg_match('/^#[0-9a-fA-F]{6}$/', $c)) {
                flash('error', "Color inválido: $c"); redirect('/configuracion');
            }
        }

        $this->db->execute(
            'UPDATE gestoras SET color_primario=?,color_secundario=?,color_acento=?,nombre_app=?,updated_at=NOW() WHERE id=?',
            [$color1, $color2, $color3, $appName, $this->gestoraId]
        );

        flash('success', 'Branding actualizado. Los cambios se verán en la próxima carga.');
        redirect('/configuracion');
    }

    /** Sube el logo de la gestora */
    public function uploadLogo(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }

        $file = $_FILES['logo'] ?? null;
        if (!$file || $file['error'] !== UPLOAD_ERR_OK) {
            flash('error', 'Error al subir el archivo.'); redirect('/configuracion');
        }

        $mime = mime_content_type($file['tmp_name']);
        if (!in_array($mime, ['image/jpeg','image/png','image/gif','image/webp','image/svg+xml'])) {
            flash('error', 'Formato no válido. Usa JPG, PNG, WebP o SVG.'); redirect('/configuracion');
        }

        if ($file['size'] > 2 * 1024 * 1024) {
            flash('error', 'El logo no puede superar 2 MB.'); redirect('/configuracion');
        }

        $ext      = pathinfo($file['name'], PATHINFO_EXTENSION);
        $filename = 'gestora_' . $this->gestoraId . '_' . time() . '.' . strtolower($ext);
        $destDir  = UPLOADS_PATH . '/logos/';
        $dest     = $destDir . $filename;

        if (!is_dir($destDir)) mkdir($destDir, 0775, true);

        if (!move_uploaded_file($file['tmp_name'], $dest)) {
            flash('error', 'No se pudo guardar el logo.'); redirect('/configuracion');
        }

        // Borrar logo anterior
        $anterior = $this->gestora['logo_path'] ?? '';
        if ($anterior && file_exists($destDir . $anterior)) {
            unlink($destDir . $anterior);
        }

        $this->db->execute(
            'UPDATE gestoras SET logo_path = ?, updated_at = NOW() WHERE id = ?',
            [$filename, $this->gestoraId]
        );

        flash('success', 'Logo actualizado correctamente.');
        redirect('/configuracion');
    }
}

class UsuarioController
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
        redirect('/configuracion#usuarios');
    }

    public function store(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }

        $email = trim($_POST['email'] ?? '');
        $nombre= trim($_POST['nombre']?? '');
        $rolId = (int)($_POST['rol_id'] ?? 0);
        $pass  = $_POST['password'] ?? bin2hex(random_bytes(6));

        if (!$email || !$nombre) {
            flash('error', 'Email y nombre son obligatorios.'); redirect('/configuracion');
        }

        $existe = $this->db->queryOne(
            'SELECT id FROM usuarios WHERE email = ? AND gestora_id = ?',
            [$email, $this->gestoraId]
        );
        if ($existe) {
            flash('error', 'Ya existe un usuario con ese email.'); redirect('/configuracion');
        }

        $this->db->insert(
            'INSERT INTO usuarios (gestora_id,rol_id,nombre,apellidos,email,password_hash,activo,email_verified)
             VALUES (?,?,?,?,?,?,1,1)',
            [
                $this->gestoraId, $rolId, $nombre,
                trim($_POST['apellidos'] ?? '') ?: null,
                $email,
                password_hash($pass, PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]),
            ]
        );

        flash('success', "Usuario $email creado. Contraseña temporal: $pass");
        redirect('/configuracion');
    }

    public function update(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }

        $fields = ['nombre' => trim($_POST['nombre'] ?? ''),
                   'apellidos' => trim($_POST['apellidos'] ?? '') ?: null,
                   'rol_id' => (int)($_POST['rol_id'] ?? 0)];

        $this->db->execute(
            'UPDATE usuarios SET nombre=?,apellidos=?,rol_id=? WHERE id=? AND gestora_id=?',
            array_merge(array_values($fields), [(int)$id, $this->gestoraId])
        );

        flash('success', 'Usuario actualizado.');
        redirect('/configuracion');
    }

    public function destroy(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'CSRF inválido.'); redirect('/configuracion');
        }
        if ((int)$id === (int)($_SESSION['user_id'] ?? 0)) {
            flash('error', 'No puedes eliminarte a ti mismo.'); redirect('/configuracion');
        }
        $this->db->execute(
            'UPDATE usuarios SET activo = 0 WHERE id = ? AND gestora_id = ?',
            [(int)$id, $this->gestoraId]
        );
        flash('success', 'Usuario desactivado.');
        redirect('/configuracion');
    }
}

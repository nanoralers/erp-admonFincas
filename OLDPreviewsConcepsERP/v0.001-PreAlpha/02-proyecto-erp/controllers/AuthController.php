<?php
namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class AuthController
{
    private Auth $auth;
    private Database $db;
    private array $gestora;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $this->gestora = $resolver->getGestora() ?? [];
    }

    public function loginForm(): void
    {
        if ($this->auth->check()) {
            header('Location: /dashboard');
            exit;
        }

        $data = [
            'gestora' => $this->gestora,
            'auth' => $this->auth,
            'error' => $_SESSION['_flash_error'] ?? null,
            'success' => $_SESSION['_flash_success'] ?? null,
        ];
        unset($_SESSION['_flash_error'], $_SESSION['_flash_success']);

        require VIEWS_PATH . '/login.php';
    }

    public function loginSubmit(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            header('Location: /login');
            exit;
        }

        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            $_SESSION['_flash_error'] = 'Token CSRF inválido. Recarga la página.';
            header('Location: /login');
            exit;
        }

        $email = trim($_POST['email'] ?? '');
        $password = $_POST['password'] ?? '';
        $gestoraId = $this->gestora['id'] ?? 0;

        if (!$email || !$password) {
            $_SESSION['_flash_error'] = 'Completa todos los campos.';
            header('Location: /login');
            exit;
        }

        $result = $this->auth->attempt($email, $password, $gestoraId);

        if (!$result['ok']) {
            $_SESSION['_flash_error'] = $result['error'];
            header('Location: /login');
            exit;
        }

        // Login exitoso
        $redirect = $_POST['redirect'] ?? '/dashboard';
        header('Location: ' . $redirect);
        exit;
    }

    public function logout(): void
    {
        $this->auth->logout();
        header('Location: /login');
        exit;
    }

    public function recoverForm(): void
    {
        $data = [
            'gestora' => $this->gestora,
            'auth' => $this->auth,
        ];
        require VIEWS_PATH . '/auth/recover.php';
    }

    public function recoverSubmit(): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            header('Location: /recuperar-password');
            exit;
        }

        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            $_SESSION['_flash_error'] = 'Token CSRF inválido.';
            header('Location: /recuperar-password');
            exit;
        }

        $email = trim($_POST['email'] ?? '');
        $gestoraId = $this->gestora['id'] ?? 0;

        if (!$email) {
            $_SESSION['_flash_error'] = 'Indica tu email.';
            header('Location: /recuperar-password');
            exit;
        }

        $user = $this->db->queryOne(
            'SELECT id, nombre FROM usuarios WHERE email = ? AND gestora_id = ? AND activo = 1',
            [$email, $gestoraId]
        );

        // Siempre mostramos éxito (no filtrar emails válidos)
        $_SESSION['_flash_success'] = 'Si el email existe, recibirás un enlace de recuperación.';

        if ($user) {
            $token = bin2hex(random_bytes(32));
            $expires = date('Y-m-d H:i:s', time() + 3600); // 1 hora
            
            $this->db->execute(
                'UPDATE usuarios SET token_reset = ?, token_reset_exp = ? WHERE id = ?',
                [$token, $expires, $user['id']]
            );

            // TODO: Enviar email con link /reset-password/{$token}
            // Por ahora lo omitimos, pero aquí iría PHPMailer o similar
        }

        header('Location: /recuperar-password');
        exit;
    }

    public function resetForm(string $token): void
    {
        $user = $this->db->queryOne(
            'SELECT id, nombre FROM usuarios 
             WHERE token_reset = ? AND token_reset_exp > NOW() AND activo = 1',
            [$token]
        );

        if (!$user) {
            $_SESSION['_flash_error'] = 'Enlace inválido o expirado.';
            header('Location: /login');
            exit;
        }

        $data = [
            'gestora' => $this->gestora,
            'auth' => $this->auth,
            'token' => $token,
            'user' => $user,
        ];
        require VIEWS_PATH . '/auth/reset.php';
    }

    public function resetSubmit(string $token): void
    {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            header('Location: /login');
            exit;
        }

        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            $_SESSION['_flash_error'] = 'Token CSRF inválido.';
            header('Location: /reset-password/' . $token);
            exit;
        }

        $password = $_POST['password'] ?? '';
        $confirm = $_POST['password_confirm'] ?? '';

        if (!$password || strlen($password) < 8) {
            $_SESSION['_flash_error'] = 'La contraseña debe tener al menos 8 caracteres.';
            header('Location: /reset-password/' . $token);
            exit;
        }

        if ($password !== $confirm) {
            $_SESSION['_flash_error'] = 'Las contraseñas no coinciden.';
            header('Location: /reset-password/' . $token);
            exit;
        }

        $user = $this->db->queryOne(
            'SELECT id FROM usuarios 
             WHERE token_reset = ? AND token_reset_exp > NOW() AND activo = 1',
            [$token]
        );

        if (!$user) {
            $_SESSION['_flash_error'] = 'Enlace inválido o expirado.';
            header('Location: /login');
            exit;
        }

        $hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]);
        $this->db->execute(
            'UPDATE usuarios SET password_hash = ?, token_reset = NULL, token_reset_exp = NULL WHERE id = ?',
            [$hash, $user['id']]
        );

        $_SESSION['_flash_success'] = 'Contraseña actualizada. Ya puedes acceder.';
        header('Location: /login');
        exit;
    }
}

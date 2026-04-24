<?php
namespace Core;

class Auth
{
    private Database $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
        $this->startSession();
    }

    private function startSession(): void
    {
        if (session_status() === PHP_SESSION_NONE) {
            // La cookie debe funcionar en TODOS los subdominios *.nanoserver.es
            session_name(SESSION_NAME);
            session_set_cookie_params([
                'lifetime' => 0,
                'path'     => '/',
                'domain'   => SESSION_DOMAIN,   // '.nanoserver.es' (punto inicial = wildcard)
                'secure'   => SESSION_SECURE,    // true siempre (HTTPS en producción)
                'httponly' => true,
                'samesite' => 'Lax',
            ]);
            session_start();
        }

        // Regenerar ID de sesión cada 30 min (prevención de session fixation)
        if (!isset($_SESSION['_created'])) {
            $_SESSION['_created'] = time();
        } elseif (time() - $_SESSION['_created'] > 1800) {
            session_regenerate_id(true);
            $_SESSION['_created'] = time();
        }
    }

    public function attempt(string $email, string $password, int $gestoraId): array
    {
        $lockKey     = "login_lock_{$gestoraId}_{$email}";
        $attemptsKey = "login_attempts_{$gestoraId}_{$email}";

        // ¿Cuenta bloqueada?
        if (isset($_SESSION[$lockKey]) && time() < $_SESSION[$lockKey]) {
            $wait = (int)(($_SESSION[$lockKey] - time()) / 60) + 1;
            return ['ok' => false, 'error' => "Cuenta bloqueada. Intenta en $wait min."];
        }

        $user = $this->db->queryOne(
            'SELECT u.*, r.codigo as rol_codigo, r.nivel as rol_nivel
             FROM usuarios u
             JOIN roles r ON r.id = u.rol_id
             WHERE u.email = ? AND u.gestora_id = ? AND u.activo = 1',
            [$email, $gestoraId]
        );

        if (!$user || !password_verify($password, $user['password_hash'])) {
            $_SESSION[$attemptsKey] = ($_SESSION[$attemptsKey] ?? 0) + 1;

            if ($_SESSION[$attemptsKey] >= MAX_LOGIN_ATTEMPTS) {
                $_SESSION[$lockKey] = time() + LOCKOUT_TIME;
                unset($_SESSION[$attemptsKey]);
                return ['ok' => false, 'error' => 'Demasiados intentos. Cuenta bloqueada 15 min.'];
            }

            $restantes = MAX_LOGIN_ATTEMPTS - $_SESSION[$attemptsKey];
            return ['ok' => false, 'error' => "Credenciales incorrectas. Intentos restantes: $restantes."];
        }

        // Login correcto — limpiar intentos y regenerar sesión
        unset($_SESSION[$attemptsKey], $_SESSION[$lockKey]);
        session_regenerate_id(true);

        $_SESSION['user_id']   = $user['id'];
        $_SESSION['gestora_id']= $user['gestora_id'];
        $_SESSION['rol']       = $user['rol_codigo'];
        $_SESSION['rol_nivel'] = $user['rol_nivel'];
        $_SESSION['nombre']    = $user['nombre'];
        $_SESSION['_created']  = time();

        // Actualizar último acceso
        $this->db->execute(
            'UPDATE usuarios SET ultimo_acceso = NOW(), ip_ultimo_acceso = ? WHERE id = ?',
            [$_SERVER['REMOTE_ADDR'] ?? null, $user['id']]
        );

        // Hash upgrade automático si cost ha cambiado
        if (password_needs_rehash($user['password_hash'], PASSWORD_BCRYPT, ['cost' => BCRYPT_COST])) {
            $newHash = password_hash($password, PASSWORD_BCRYPT, ['cost' => BCRYPT_COST]);
            $this->db->execute(
                'UPDATE usuarios SET password_hash = ? WHERE id = ?',
                [$newHash, $user['id']]
            );
        }

        return ['ok' => true, 'user' => $user];
    }

    public function check(): bool
    {
        return !empty($_SESSION['user_id']);
    }

    public function user(): ?array
    {
        if (!$this->check()) return null;
        return $this->db->queryOne(
            'SELECT u.*, r.codigo as rol_codigo, r.nivel as rol_nivel,
                    g.nombre as gestora_nombre, g.subdominio, g.logo_path,
                    g.color_primario, g.color_secundario, g.color_acento,
                    g.nombre_app, g.plan_id
             FROM usuarios u
             JOIN roles r ON r.id = u.rol_id
             LEFT JOIN gestoras g ON g.id = u.gestora_id
             WHERE u.id = ?',
            [$_SESSION['user_id']]
        );
    }

    public function logout(): void
    {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $p = session_get_cookie_params();
            setcookie(
                session_name(), '', time() - 42000,
                $p['path'], $p['domain'], $p['secure'], $p['httponly']
            );
        }
        session_destroy();
    }

    public function can(string $modulo): bool
    {
        if (!$this->check()) return false;
        if ($_SESSION['rol'] === 'superadmin') return true;

        $row = $this->db->queryOne(
            'SELECT 1
             FROM planes_modulos pm
             JOIN planes p  ON p.id  = pm.plan_id
             JOIN modulos m ON m.id  = pm.modulo_id
             JOIN gestoras g ON g.plan_id = p.id
             WHERE g.id = ? AND m.codigo = ? AND g.activo = 1',
            [$_SESSION['gestora_id'], $modulo]
        );
        return $row !== null;
    }

    public function requireAuth(): void
    {
        if (!$this->check()) {
            header('Location: /login?redirect=' . urlencode($_SERVER['REQUEST_URI']));
            exit;
        }
    }

    public function requireModule(string $modulo): void
    {
        $this->requireAuth();
        if (!$this->can($modulo)) {
            http_response_code(403);
            require VIEWS_PATH . '/errors/403.php';
            exit;
        }
    }

    // ── CSRF ──────────────────────────────────────────────────────────────────
    public function csrfToken(): string
    {
        if (empty($_SESSION['_csrf'])) {
            $_SESSION['_csrf'] = bin2hex(random_bytes(CSRF_TOKEN_LENGTH));
        }
        return $_SESSION['_csrf'];
    }

    public function verifyCsrf(?string $token): bool
    {
        return !empty($_SESSION['_csrf'])
            && hash_equals($_SESSION['_csrf'], (string)$token);
    }

    public function csrfField(): string
    {
        return '<input type="hidden" name="_csrf" value="'
            . htmlspecialchars($this->csrfToken()) . '">';
    }
}

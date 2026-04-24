<?php
namespace Api;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

/**
 * API interna — responde JSON a las peticiones AJAX de la UI
 */
class DashboardApi
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

    public function stats(): void
    {
        header('Content-Type: application/json; charset=utf-8');
        $comunidadId = $_SESSION['comunidad_activa'] ?? null;
        $w = $comunidadId ? 'AND comunidad_id = ' . (int)$comunidadId : '';

        json([
            'ok'    => true,
            'stats' => [
                'comunidades'        => $this->db->queryOne("SELECT COUNT(*) as n FROM comunidades WHERE gestora_id = ? AND activo = 1", [$this->gestoraId])['n'] ?? 0,
                'recibos_pendientes' => $this->db->queryOne("SELECT COUNT(*) as n FROM recibos WHERE gestora_id = ? AND estado = 'pendiente' $w", [$this->gestoraId])['n'] ?? 0,
                'averias_abiertas'   => $this->db->queryOne("SELECT COUNT(*) as n FROM averias WHERE gestora_id = ? AND estado NOT IN ('resuelta','cerrada','cancelada') $w", [$this->gestoraId])['n'] ?? 0,
                'morosos'            => $this->db->queryOne("SELECT COUNT(*) as n FROM morosos WHERE gestora_id = ? AND estado = 'activo' $w", [$this->gestoraId])['n'] ?? 0,
            ],
        ]);
    }
}

class NotificacionApi
{
    private Auth $auth;
    private Database $db;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        $this->db = Database::getInstance();
    }

    public function list(): void
    {
        $notifs = $this->db->query(
            'SELECT * FROM notificaciones WHERE usuario_id = ?
             ORDER BY created_at DESC LIMIT 20',
            [$_SESSION['user_id']]
        );
        json(['ok' => true, 'notificaciones' => $notifs]);
    }

    public function count(): void
    {
        $row = $this->db->queryOne(
            'SELECT COUNT(*) as n FROM notificaciones WHERE usuario_id = ? AND leida = 0',
            [$_SESSION['user_id']]
        );
        json(['ok' => true, 'unread' => (int)($row['n'] ?? 0)]);
    }

    public function markRead(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            json(['ok' => false], 422);
        }
        $this->db->execute(
            'UPDATE notificaciones SET leida = 1 WHERE id = ? AND usuario_id = ?',
            [(int)$id, $_SESSION['user_id']]
        );
        json(['ok' => true]);
    }
}

class ComunidadApi
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

    public function list(): void
    {
        $rows = $this->db->query(
            'SELECT id, nombre, tipo, direccion FROM comunidades
             WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );
        json(['ok' => true, 'comunidades' => $rows]);
    }
}

class PropietarioApi
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

    public function list(): void
    {
        $q    = trim($_GET['q'] ?? '');
        $comId= (int)($_GET['comunidad_id'] ?? 0);

        $where  = ['p.gestora_id = ?'];
        $params = [$this->gestoraId];

        if ($q) {
            $where[]  = '(p.nombre LIKE ? OR p.apellidos LIKE ? OR p.email LIKE ?)';
            $like     = "%$q%";
            $params   = array_merge($params, [$like, $like, $like]);
        }
        if ($comId) {
            $where[]  = 'EXISTS (SELECT 1 FROM inmuebles WHERE propietario_id = p.id AND comunidad_id = ?)';
            $params[] = $comId;
        }

        $rows = $this->db->query(
            'SELECT p.id, p.nombre, p.apellidos, p.email, p.telefono, p.moroso
             FROM propietarios p
             WHERE ' . implode(' AND ', $where) . '
             ORDER BY p.apellidos, p.nombre LIMIT 50',
            $params
        );
        json(['ok' => true, 'propietarios' => $rows]);
    }
}

<?php
namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class DashboardController
{
    private Auth $auth;
    private Database $db;
    private array $gestora;
    private int $gestoraId;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireAuth();
        
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $this->gestora = $resolver->getGestora() ?? [];
        $this->gestoraId = $this->gestora['id'] ?? 0;
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        
        // Stats generales
        $stats = $this->getStats();
        
        // Últimas actividades
        $actividades = $this->getRecentActivity(10);
        
        // Tareas pendientes
        $tareas = $this->db->query(
            'SELECT * FROM tareas 
             WHERE gestora_id = ? AND estado IN ("pendiente","en_curso")
             ORDER BY 
               CASE prioridad
                 WHEN "urgente" THEN 1
                 WHEN "alta" THEN 2
                 WHEN "normal" THEN 3
                 ELSE 4
               END,
               fecha_limite ASC
             LIMIT 8',
            [$this->gestoraId]
        );

        // Próximas juntas
        $juntas = $this->db->query(
            'SELECT j.*, c.nombre as comunidad_nombre
             FROM juntas j
             JOIN comunidades c ON c.id = j.comunidad_id
             WHERE j.gestora_id = ? AND j.fecha_primera >= CURDATE()
               AND j.estado = "convocada"
             ORDER BY j.fecha_primera ASC
             LIMIT 5',
            [$this->gestoraId]
        );

        // Avisos importantes
        $avisos = $this->getAvisos();

        // Comunidades
        $comunidades = $this->db->query(
            'SELECT * FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        $data = [
            'pageTitle' => 'Dashboard',
            'breadcrumbs' => [],
            'gestora' => $this->gestora,
            'auth' => $this->auth,
            'currentUser' => $currentUser,
            'comunidades' => $comunidades,
            'stats' => $stats,
            'actividades' => $actividades,
            'tareas' => $tareas,
            'juntas' => $juntas,
            'avisos' => $avisos,
        ];

        ob_start();
        require VIEWS_PATH . '/dashboard/index.php';
        $content = ob_get_clean();

        $data['content'] = $content;
        require VIEWS_PATH . '/layouts/app.php';
    }

    private function getStats(): array
    {
        $comunidadId = $_SESSION['comunidad_activa'] ?? null;
        $whereClause = $comunidadId ? 'AND c.id = ?' : '';
        $params = $comunidadId ? [$this->gestoraId, $comunidadId] : [$this->gestoraId];

        $stats = [];

        // Comunidades
        $row = $this->db->queryOne(
            'SELECT COUNT(*) as total FROM comunidades WHERE gestora_id = ? AND activo = 1',
            [$this->gestoraId]
        );
        $stats['comunidades'] = (int)($row['total'] ?? 0);

        // Propietarios
        $row = $this->db->queryOne(
            'SELECT COUNT(DISTINCT p.id) as total 
             FROM propietarios p
             JOIN inmuebles i ON i.propietario_id = p.id
             JOIN comunidades c ON c.id = i.comunidad_id
             WHERE c.gestora_id = ? AND c.activo = 1 ' . $whereClause,
            $params
        );
        $stats['propietarios'] = (int)($row['total'] ?? 0);

        // Recibos pendientes
        if ($this->auth->can('economica')) {
            $row = $this->db->queryOne(
                'SELECT COUNT(*) as total, COALESCE(SUM(importe_pendiente),0) as importe
                 FROM recibos r
                 JOIN comunidades c ON c.id = r.comunidad_id
                 WHERE r.gestora_id = ? AND r.estado = "pendiente" ' . $whereClause,
                $params
            );
            $stats['recibos_pendientes'] = (int)($row['total'] ?? 0);
            $stats['importe_pendiente'] = (float)($row['importe'] ?? 0);
        }

        // Averías abiertas
        if ($this->auth->can('mantenimiento')) {
            $row = $this->db->queryOne(
                'SELECT COUNT(*) as total 
                 FROM averias a
                 JOIN comunidades c ON c.id = a.comunidad_id
                 WHERE a.gestora_id = ? AND a.estado IN ("abierta","asignada","en_proceso") ' . $whereClause,
                $params
            );
            $stats['averias_abiertas'] = (int)($row['total'] ?? 0);
        }

        // Morosos activos
        if ($this->auth->can('juridica')) {
            $row = $this->db->queryOne(
                'SELECT COUNT(*) as total, COALESCE(SUM(deuda_total),0) as deuda
                 FROM morosos m
                 JOIN comunidades c ON c.id = m.comunidad_id
                 WHERE m.gestora_id = ? AND m.estado = "activo" ' . $whereClause,
                $params
            );
            $stats['morosos'] = (int)($row['total'] ?? 0);
            $stats['deuda_morosos'] = (float)($row['deuda'] ?? 0);
        }

        return $stats;
    }

    private function getRecentActivity(int $limit = 10): array
    {
        $activities = [];
        
        // Últimos movimientos económicos
        if ($this->auth->can('economica')) {
            $movs = $this->db->query(
                'SELECT m.*, c.nombre as comunidad_nombre, cat.nombre as categoria
                 FROM movimientos m
                 JOIN comunidades c ON c.id = m.comunidad_id
                 LEFT JOIN categorias_contables cat ON cat.id = m.categoria_id
                 WHERE m.gestora_id = ?
                 ORDER BY m.fecha DESC, m.created_at DESC
                 LIMIT ' . $limit,
                [$this->gestoraId]
            );
            foreach ($movs as $m) {
                $activities[] = [
                    'tipo' => 'movimiento',
                    'icono' => $m['tipo'] === 'ingreso' ? 'fa-arrow-trend-up' : 'fa-arrow-trend-down',
                    'color' => $m['tipo'] === 'ingreso' ? '#10b981' : '#ef4444',
                    'titulo' => $m['concepto'],
                    'subtitulo' => $m['comunidad_nombre'] . ' · ' . number_format($m['importe'], 2) . ' €',
                    'fecha' => $m['created_at'],
                ];
            }
        }

        // Últimas averías
        if ($this->auth->can('mantenimiento')) {
            $averias = $this->db->query(
                'SELECT a.*, c.nombre as comunidad_nombre
                 FROM averias a
                 JOIN comunidades c ON c.id = a.comunidad_id
                 WHERE a.gestora_id = ?
                 ORDER BY a.created_at DESC
                 LIMIT ' . ($limit / 2),
                [$this->gestoraId]
            );
            foreach ($averias as $av) {
                $activities[] = [
                    'tipo' => 'averia',
                    'icono' => 'fa-triangle-exclamation',
                    'color' => '#f59e0b',
                    'titulo' => $av['titulo'],
                    'subtitulo' => $av['comunidad_nombre'],
                    'fecha' => $av['created_at'],
                ];
            }
        }

        // Ordenar por fecha desc
        usort($activities, fn($a, $b) => strtotime($b['fecha']) <=> strtotime($a['fecha']));

        return array_slice($activities, 0, $limit);
    }

    private function getAvisos(): array
    {
        $avisos = [];

        // ITE/IEE próximas
        if ($this->auth->can('mantenimiento')) {
            $ites = $this->db->query(
                'SELECT c.nombre, i.tipo, i.fecha_vencimiento
                 FROM ite_iee i
                 JOIN comunidades c ON c.id = i.comunidad_id
                 WHERE c.gestora_id = ? AND i.fecha_vencimiento BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 90 DAY)
                 ORDER BY i.fecha_vencimiento ASC
                 LIMIT 3',
                [$this->gestoraId]
            );
            foreach ($ites as $ite) {
                $avisos[] = [
                    'tipo' => 'warning',
                    'icono' => 'fa-clipboard-check',
                    'mensaje' => "Próximo vencimiento {$ite['tipo']} en {$ite['nombre']}",
                    'fecha' => $ite['fecha_vencimiento'],
                ];
            }
        }

        // Seguros próximos a vencer
        $seguros = $this->db->query(
            'SELECT nombre, seguro_vencimiento
             FROM comunidades
             WHERE gestora_id = ? AND seguro_vencimiento BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 60 DAY)
             ORDER BY seguro_vencimiento ASC
             LIMIT 3',
            [$this->gestoraId]
        );
        foreach ($seguros as $s) {
            $avisos[] = [
                'tipo' => 'info',
                'icono' => 'fa-shield-halved',
                'mensaje' => "Renovar seguro de {$s['nombre']}",
                'fecha' => $s['seguro_vencimiento'],
            ];
        }

        return $avisos;
    }
}

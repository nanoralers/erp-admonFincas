<?php
namespace Controllers\Economica;

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
        $this->auth->requireModule('economica');
        $this->db        = Database::getInstance();
        $resolver        = new SubdomainResolver();
        $this->gestora   = $resolver->getGestora() ?? [];
        $this->gestoraId = (int)($this->gestora['id'] ?? 0);
    }

    public function index(): void
    {
        $currentUser = $this->auth->user();
        $comunidades = $this->db->query(
            'SELECT * FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );
        $comunidadId = $_SESSION['comunidad_activa'] ?? null;

        // KPIs económicos
        $kpis = $this->getKpis($comunidadId);

        // Recibos pendientes recientes
        $recibosPendientes = $this->db->query(
            'SELECT r.*, i.referencia as inmueble_ref,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    c.nombre as comunidad_nombre
             FROM recibos r
             JOIN inmuebles i    ON i.id = r.inmueble_id
             JOIN propietarios p ON p.id = r.propietario_id
             JOIN comunidades c  ON c.id = r.comunidad_id
             WHERE r.gestora_id = ? AND r.estado = "pendiente"
             ' . ($comunidadId ? 'AND r.comunidad_id = ?' : '') . '
             ORDER BY r.fecha_vencimiento ASC LIMIT 10',
            $comunidadId ? [$this->gestoraId, $comunidadId] : [$this->gestoraId]
        );

        // Últimos movimientos
        $movimientos = $this->db->query(
            'SELECT m.*, c.nombre as comunidad_nombre, cat.nombre as categoria_nombre
             FROM movimientos m
             JOIN comunidades c ON c.id = m.comunidad_id
             LEFT JOIN categorias_contables cat ON cat.id = m.categoria_id
             WHERE m.gestora_id = ?
             ' . ($comunidadId ? 'AND m.comunidad_id = ?' : '') . '
             ORDER BY m.fecha DESC, m.created_at DESC LIMIT 10',
            $comunidadId ? [$this->gestoraId, $comunidadId] : [$this->gestoraId]
        );

        $pageTitle  = 'Módulo Económico';
        $breadcrumbs = [['label' => 'Económica y Contable']];

        ob_start();
        require VIEWS_PATH . '/economica/dashboard.php';
        $content = ob_get_clean();

        require VIEWS_PATH . '/layouts/app.php';
    }

    private function getKpis(?int $comunidadId): array
    {
        $w = $comunidadId ? 'AND comunidad_id = ?' : '';
        $p = fn($extra = []) => $comunidadId
            ? array_merge([$this->gestoraId], $extra, [$comunidadId])
            : array_merge([$this->gestoraId], $extra);

        $recibos = $this->db->queryOne(
            "SELECT COUNT(*) as total,
                    SUM(CASE WHEN estado='pendiente'  THEN importe_pendiente ELSE 0 END) as importe_pendiente,
                    SUM(CASE WHEN estado='cobrado'    THEN importe ELSE 0 END) as cobrado_mes,
                    COUNT(CASE WHEN estado='pendiente' THEN 1 END) as num_pendientes,
                    COUNT(CASE WHEN estado='devuelto' THEN 1 END) as num_devueltos
             FROM recibos WHERE gestora_id = ? $w",
            $p()
        );

        $ingresos_mes = $this->db->queryOne(
            "SELECT COALESCE(SUM(importe),0) as total
             FROM movimientos
             WHERE gestora_id = ? AND tipo='ingreso'
             AND MONTH(fecha)=MONTH(CURDATE()) AND YEAR(fecha)=YEAR(CURDATE()) $w",
            $p()
        );
        $gastos_mes = $this->db->queryOne(
            "SELECT COALESCE(SUM(importe),0) as total
             FROM movimientos
             WHERE gestora_id = ? AND tipo='gasto'
             AND MONTH(fecha)=MONTH(CURDATE()) AND YEAR(fecha)=YEAR(CURDATE()) $w",
            $p()
        );

        return [
            'importe_pendiente' => (float)($recibos['importe_pendiente'] ?? 0),
            'num_pendientes'    => (int)($recibos['num_pendientes']    ?? 0),
            'num_devueltos'     => (int)($recibos['num_devueltos']     ?? 0),
            'ingresos_mes'      => (float)($ingresos_mes['total']      ?? 0),
            'gastos_mes'        => (float)($gastos_mes['total']        ?? 0),
            'balance_mes'       => (float)($ingresos_mes['total'] ?? 0) - (float)($gastos_mes['total'] ?? 0),
        ];
    }
}

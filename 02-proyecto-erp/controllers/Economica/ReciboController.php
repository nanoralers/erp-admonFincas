<?php
namespace Controllers\Economica;

use Core\Auth;
use Core\Database;
use Core\SubdomainResolver;

class ReciboController
{
    private Auth $auth;
    private Database $db;
    private int $gestoraId;

    public function __construct()
    {
        $this->auth = new Auth();
        $this->auth->requireModule('economica');
        $this->db = Database::getInstance();
        $resolver = new SubdomainResolver();
        $gestora  = $resolver->getGestora() ?? [];
        $this->gestoraId = (int)($gestora['id'] ?? 0);
    }

    /** Listado de recibos con filtros */
    public function index(): void
    {
        $currentUser = $this->auth->user();
        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? AND activo = 1 ORDER BY nombre',
            [$this->gestoraId]
        );

        // Filtros desde GET
        $filtros = [
            'estado'       => $_GET['estado']       ?? '',
            'comunidad_id' => (int)($_GET['comunidad_id'] ?? 0),
            'periodo'      => $_GET['periodo']       ?? '',
            'q'            => trim($_GET['q']        ?? ''),
        ];

        // Query dinámica
        $where  = ['r.gestora_id = ?'];
        $params = [$this->gestoraId];

        if ($filtros['estado'])       { $where[] = 'r.estado = ?';       $params[] = $filtros['estado']; }
        if ($filtros['comunidad_id']) { $where[] = 'r.comunidad_id = ?'; $params[] = $filtros['comunidad_id']; }
        if ($filtros['periodo'])      { $where[] = 'r.periodo = ?';       $params[] = $filtros['periodo']; }
        if ($filtros['q']) {
            $where[]  = '(p.nombre LIKE ? OR p.apellidos LIKE ? OR r.numero LIKE ?)';
            $like     = '%' . $filtros['q'] . '%';
            $params   = array_merge($params, [$like, $like, $like]);
        }

        $sql = 'SELECT r.*,
                       c.nombre as comunidad_nombre,
                       i.referencia as inmueble_ref,
                       CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre
                FROM recibos r
                JOIN comunidades c  ON c.id = r.comunidad_id
                JOIN inmuebles i    ON i.id = r.inmueble_id
                JOIN propietarios p ON p.id = r.propietario_id
                WHERE ' . implode(' AND ', $where) . '
                ORDER BY r.fecha_vencimiento DESC, r.created_at DESC';

        $paginado = $this->db->paginate($sql, $params,
            (int)($_GET['pagina'] ?? 1), 25
        );

        $pageTitle   = 'Recibos y Cobros';
        $breadcrumbs = [
            ['label' => 'Económica', 'url' => '/economica'],
            ['label' => 'Recibos'],
        ];

        ob_start();
        require VIEWS_PATH . '/economica/recibos/index.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    /** Formulario de emisión masiva de recibos */
    public function emitir(): void
    {
        $currentUser = $this->auth->user();
        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];
        $comunidades = $this->db->query(
            'SELECT c.*, e.id as ejercicio_id, e.anio
             FROM comunidades c
             LEFT JOIN ejercicios e ON e.comunidad_id = c.id AND e.estado = "activo"
             WHERE c.gestora_id = ? AND c.activo = 1
             ORDER BY c.nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Emitir Recibos';
        $breadcrumbs = [
            ['label' => 'Económica', 'url' => '/economica'],
            ['label' => 'Recibos', 'url' => '/economica/recibos'],
            ['label' => 'Emitir'],
        ];

        ob_start();
        require VIEWS_PATH . '/economica/recibos/emitir.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    /** Procesar emisión de recibos */
    public function emitirStore(): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            flash('error', 'Token CSRF inválido.');
            redirect('/economica/recibos/emitir');
        }

        $comunidadId = (int)($_POST['comunidad_id'] ?? 0);
        $ejercicioId = (int)($_POST['ejercicio_id'] ?? 0);
        $periodo     = trim($_POST['periodo'] ?? '');
        $concepto    = trim($_POST['concepto'] ?? 'Cuota comunidad');
        $fechaVenc   = $_POST['fecha_vencimiento'] ?? date('Y-m-d', strtotime('+15 days'));

        if (!$comunidadId || !$periodo) {
            flash('error', 'Completa todos los campos obligatorios.');
            redirect('/economica/recibos/emitir');
        }

        // Verificar que la comunidad pertenece a la gestora
        $comunidad = $this->db->queryOne(
            'SELECT * FROM comunidades WHERE id = ? AND gestora_id = ?',
            [$comunidadId, $this->gestoraId]
        );
        if (!$comunidad) { redirect('/economica/recibos'); }

        // Obtener inmuebles activos con propietario y cuota
        $inmuebles = $this->db->query(
            'SELECT i.*, p.id as prop_id, p.iban, p.mandato_sepa,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as prop_nombre
             FROM inmuebles i
             JOIN propietarios p ON p.id = i.propietario_id
             WHERE i.comunidad_id = ? AND i.activo = 1 AND i.cuota_mensual > 0',
            [$comunidadId]
        );

        if (empty($inmuebles)) {
            flash('warning', 'No hay inmuebles con cuota definida en esta comunidad.');
            redirect('/economica/recibos/emitir');
        }

        $this->db->beginTransaction();
        try {
            $emitidos = 0;
            foreach ($inmuebles as $inm) {
                // Evitar duplicados del mismo periodo
                $existe = $this->db->queryOne(
                    'SELECT id FROM recibos WHERE comunidad_id = ? AND inmueble_id = ? AND periodo = ?',
                    [$comunidadId, $inm['id'], $periodo]
                );
                if ($existe) continue;

                $numero = 'REC-' . $comunidadId . '-' . date('Ym') . '-' . str_pad((string)($emitidos + 1), 4, '0', STR_PAD_LEFT);
                $this->db->insert(
                    'INSERT INTO recibos
                     (gestora_id, comunidad_id, ejercicio_id, inmueble_id, propietario_id,
                      numero, concepto, periodo, importe, importe_pendiente,
                      fecha_emision, fecha_vencimiento, estado, metodo_cobro)
                     VALUES (?,?,?,?,?,?,?,?,?,?,CURDATE(),?,?,?)',
                    [
                        $this->gestoraId, $comunidadId, $ejercicioId,
                        $inm['id'], $inm['prop_id'],
                        $numero, $concepto, $periodo,
                        $inm['cuota_mensual'], $inm['cuota_mensual'],
                        $fechaVenc, 'pendiente',
                        $inm['mandato_sepa'] ? 'domiciliacion' : 'transferencia',
                    ]
                );
                $emitidos++;
            }
            $this->db->commit();
            flash('success', "Se emitieron $emitidos recibos correctamente para el periodo $periodo.");
        } catch (\Throwable $e) {
            $this->db->rollBack();
            flash('error', 'Error al emitir recibos: ' . $e->getMessage());
        }

        redirect('/economica/recibos');
    }

    /** Detalle de un recibo */
    public function show(string $id): void
    {
        $recibo = $this->getReciboOrFail((int)$id);
        $currentUser = $this->auth->user();
        $resolver    = new SubdomainResolver();
        $gestora     = $resolver->getGestora() ?? [];
        $comunidades = $this->db->query(
            'SELECT id, nombre FROM comunidades WHERE gestora_id = ? ORDER BY nombre',
            [$this->gestoraId]
        );

        $pageTitle   = 'Recibo ' . $recibo['numero'];
        $breadcrumbs = [
            ['label' => 'Económica', 'url' => '/economica'],
            ['label' => 'Recibos', 'url' => '/economica/recibos'],
            ['label' => $recibo['numero']],
        ];

        ob_start();
        require VIEWS_PATH . '/economica/recibos/show.php';
        $content = ob_get_clean();
        require VIEWS_PATH . '/layouts/app.php';
    }

    /** Marcar recibo como cobrado */
    public function cobrar(string $id): void
    {
        if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
            json(['ok' => false, 'error' => 'CSRF inválido'], 422);
        }

        $recibo = $this->getReciboOrFail((int)$id);

        if (!in_array($recibo['estado'], ['pendiente', 'devuelto'])) {
            json(['ok' => false, 'error' => 'El recibo no está en estado cobrable.'], 422);
        }

        $importe_cobrado = (float)($_POST['importe'] ?? $recibo['importe_pendiente']);
        $metodo          = $_POST['metodo'] ?? 'transferencia';
        $referencia      = trim($_POST['referencia'] ?? '');

        $nuevo_estado   = $importe_cobrado >= $recibo['importe_pendiente'] ? 'cobrado' : 'fraccionado';
        $nuevo_pendiente = max(0, $recibo['importe_pendiente'] - $importe_cobrado);

        $this->db->execute(
            'UPDATE recibos SET estado = ?, importe_pendiente = ?, fecha_cobro = CURDATE(),
             metodo_cobro = ?, referencia_pago = ? WHERE id = ?',
            [$nuevo_estado, $nuevo_pendiente, $metodo, $referencia, $recibo['id']]
        );

        // Registrar movimiento
        $this->db->execute(
            'INSERT INTO movimientos (gestora_id, comunidad_id, ejercicio_id, recibo_id, tipo, fecha, concepto, importe, metodo_cobro)
             VALUES (?,?,?,?,?,CURDATE(),?,?,?)',
            [
                $this->gestoraId, $recibo['comunidad_id'], $recibo['ejercicio_id'],
                $recibo['id'], 'ingreso',
                'Cobro recibo ' . $recibo['numero'] . ' · ' . $recibo['concepto'],
                $importe_cobrado, $metodo,
            ]
        );

        json(['ok' => true, 'estado' => $nuevo_estado]);
    }

    private function getReciboOrFail(int $id): array
    {
        $recibo = $this->db->queryOne(
            'SELECT r.*, c.nombre as comunidad_nombre,
                    CONCAT(p.nombre," ",COALESCE(p.apellidos,"")) as propietario_nombre,
                    i.referencia as inmueble_ref
             FROM recibos r
             JOIN comunidades c  ON c.id = r.comunidad_id
             JOIN propietarios p ON p.id = r.propietario_id
             JOIN inmuebles i    ON i.id = r.inmueble_id
             WHERE r.id = ? AND r.gestora_id = ?',
            [$id, $this->gestoraId]
        );
        if (!$recibo) { http_response_code(404); require VIEWS_PATH . '/errors/404.php'; exit; }
        return $recibo;
    }
}

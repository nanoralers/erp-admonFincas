<?php
namespace Core;

/**
 * Resuelve el tenant (gestora) a partir del subdominio
 * Ej: https://gestionpremium.nanoserver.es → subdominio = 'gestionpremium'
 */
class SubdomainResolver
{
    private Database $db;
    private ?array $gestora = null;

    public function __construct()
    {
        $this->db = Database::getInstance();
        $this->resolve();
    }

    private function resolve(): void
    {
        $host       = strtolower($_SERVER['HTTP_HOST'] ?? '');
        $baseDomain = strtolower(BASE_DOMAIN);

        // Quitar puerto si lo hay
        $host = explode(':', $host)[0];

        // ¿Es exactamente el dominio base o www? → Panel principal / landing
        if ($host === $baseDomain || $host === 'www.' . $baseDomain) {
            $this->gestora = null;
            return;
        }

        // ¿Es el admin global? admin.nanoserver.es
        if ($host === 'admin.' . $baseDomain) {
            $this->gestora = ['_is_admin' => true];
            return;
        }

        // Extraer subdominio
        if (!str_ends_with($host, '.' . $baseDomain)) {
            $this->gestora = null;
            return;
        }

        $sub = substr($host, 0, strlen($host) - strlen('.' . $baseDomain));

        // Sólo un nivel de subdominio permitido
        if (str_contains($sub, '.')) {
            $this->gestora = null;
            return;
        }

        $gestora = $this->db->queryOne(
            'SELECT g.*, p.slug as plan_slug, p.nombre as plan_nombre
             FROM gestoras g JOIN planes p ON p.id = g.plan_id
             WHERE g.subdominio = ? AND g.activo = 1',
            [$sub]
        );

        if (!$gestora) {
            http_response_code(404);
            require VIEWS_PATH . '/errors/404-tenant.php';
            exit;
        }

        // ¿Suscripción vigente?
        if ($gestora['suscripcion_hasta'] && strtotime($gestora['suscripcion_hasta']) < time()) {
            http_response_code(402);
            require VIEWS_PATH . '/errors/expired.php';
            exit;
        }

        $this->gestora = $gestora;

        // Inyectar variables globales de branding para las vistas
        $GLOBALS['_GESTORA'] = $gestora;
    }

    public function getGestora(): ?array { return $this->gestora; }
    public function isAdmin(): bool      { return ($this->gestora['_is_admin'] ?? false) === true; }
    public function isRoot(): bool       { return $this->gestora === null; }
    public function gestoraId(): ?int    { return isset($this->gestora['id']) ? (int)$this->gestora['id'] : null; }
}

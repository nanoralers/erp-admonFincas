<?php
/**
 * Helper functions para las vistas
 */

/**
 * Marca un link como activo si coincide con la ruta actual
 */
function active(string $path): string
{
    $current = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    return ($current === $path || str_starts_with($current, $path . '/')) ? 'active' : '';
}

/**
 * Marca activo si la ruta actual empieza con el prefijo
 */
function activePrefix(string $prefix): string
{
    $current = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    return str_starts_with($current, $prefix) ? 'active' : '';
}

/**
 * Cuenta pendientes por tipo para badges en navegación
 */
function countPendientes(string $tipo): int
{
    $db = Core\Database::getInstance();
    $gestoraId = $_SESSION['gestora_id'] ?? 0;

    switch ($tipo) {
        case 'recibos':
            $row = $db->queryOne(
                'SELECT COUNT(*) as c FROM recibos WHERE gestora_id = ? AND estado = "pendiente"',
                [$gestoraId]
            );
            break;
        case 'averias':
            $row = $db->queryOne(
                'SELECT COUNT(*) as c FROM averias WHERE gestora_id = ? AND estado IN ("abierta","asignada","en_proceso")',
                [$gestoraId]
            );
            break;
        case 'morosos':
            $row = $db->queryOne(
                'SELECT COUNT(*) as c FROM morosos WHERE gestora_id = ? AND estado = "activo"',
                [$gestoraId]
            );
            break;
        default:
            return 0;
    }

    return (int)($row['c'] ?? 0);
}

/**
 * Formatea fecha en español
 */
function formatDate(?string $date, string $format = 'd/m/Y'): string
{
    if (!$date) return '-';
    $ts = strtotime($date);
    if (!$ts) return '-';
    return date($format, $ts);
}

/**
 * Formatea moneda
 */
function formatMoney(float $amount, string $currency = '€'): string
{
    return number_format($amount, 2, ',', '.') . ' ' . $currency;
}

/**
 * Tiempo relativo "hace X"
 */
function timeAgo(string $datetime): string
{
    $now = time();
    $ts = strtotime($datetime);
    if (!$ts) return '-';
    
    $diff = $now - $ts;
    
    if ($diff < 60) return 'Ahora mismo';
    if ($diff < 3600) return 'Hace ' . floor($diff / 60) . ' min';
    if ($diff < 86400) return 'Hace ' . floor($diff / 3600) . ' h';
    if ($diff < 604800) return 'Hace ' . floor($diff / 86400) . ' días';
    
    return formatDate($datetime);
}

/**
 * Escape HTML seguro
 */
function e(?string $str): string
{
    return htmlspecialchars($str ?? '', ENT_QUOTES, 'UTF-8');
}

/**
 * Flash message helper
 */
function flash(string $type, string $message): void
{
    $_SESSION['_flash'][] = ['type' => $type, 'message' => $message];
}

/**
 * Obtiene y limpia flash messages
 */
function getFlash(): array
{
    $flash = $_SESSION['_flash'] ?? [];
    unset($_SESSION['_flash']);
    return $flash;
}

/**
 * Obtiene valor de input antiguo (after validation error)
 */
function old(string $key, string $default = ''): string
{
    return $_SESSION['_old'][$key] ?? $_POST[$key] ?? $default;
}

/**
 * CSRF token shorthand
 */
function csrf(): string
{
    $auth = new Core\Auth();
    return $auth->csrfField();
}

/**
 * Redirect helper
 */
function redirect(string $url, int $code = 302): void
{
    header("Location: $url", true, $code);
    exit;
}

/**
 * JSON response helper
 */
function json(array $data, int $code = 200): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/**
 * Validación simple
 */
function validate(array $rules): array
{
    $errors = [];
    
    foreach ($rules as $field => $ruleSet) {
        $value = $_POST[$field] ?? null;
        $fieldRules = explode('|', $ruleSet);
        
        foreach ($fieldRules as $rule) {
            if ($rule === 'required' && empty($value)) {
                $errors[$field] = "El campo $field es obligatorio.";
                break;
            }
            if ($rule === 'email' && !filter_var($value, FILTER_VALIDATE_EMAIL)) {
                $errors[$field] = "El campo $field debe ser un email válido.";
                break;
            }
            if (str_starts_with($rule, 'min:')) {
                $min = (int)substr($rule, 4);
                if (strlen($value) < $min) {
                    $errors[$field] = "El campo $field debe tener al menos $min caracteres.";
                    break;
                }
            }
            if (str_starts_with($rule, 'max:')) {
                $max = (int)substr($rule, 4);
                if (strlen($value) > $max) {
                    $errors[$field] = "El campo $field no puede tener más de $max caracteres.";
                    break;
                }
            }
        }
    }
    
    return $errors;
}

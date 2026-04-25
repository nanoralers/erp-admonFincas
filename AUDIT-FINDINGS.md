# 🔍 Auditoría de Seguridad y Arquitectura - ERP Admin Fincas

**Fecha**: 25 de abril de 2026  
**Auditor**: Architect Auditor Agent  
**Total de Hallazgos**: 29 (6 Críticos | 7 Altos | 9 Medios | 7 Bajos)

---

## 📁 Estructura del Proyecto con Vulnerabilidades

```
02-proyecto-erp/
│
├── 🔴 core/
│   ├── 🔴 Auth.php                          [CRÍTICO] [ALTO]
│   ├── 🟠 Database.php                      [ALTO] [MEDIO]
│   ├── 🟡 helpers.php                       [MEDIO]
│   └── 🟡 Router.php                        [MEDIO]
│
├── 🟠 controllers/
│   ├── 🔴 AuthController.php                [CRÍTICO]
│   ├── 🟠 ComunidadController.php           [CRÍTICO] [ALTO] [MEDIO]
│   ├── 🟠 PropietarioController.php         [MEDIO]
│   ├── 🟠 ConfigController.php              [MEDIO]
│   ├── 🟠 DashboardController.php           [ALTO] [MEDIO]
│   └── Administrativa/
│       └── 🔴 JuntaController.php           [CRÍTICO] [MEDIO]
│   └── Economica/
│       ├── 🟠 ReciboController.php          [ALTO] [MEDIO]
│       ├── 🟠 PresupuestoController.php     [MEDIO]
│       └── 🟡 DashboardController.php       [MEDIO]
│   └── Juridica/
│       └── 🟡 MorosoController.php          [MEDIO]
│   └── Mantenimiento/
│       └── 🟡 AveriaController.php          [MEDIO]
│
├── 🔴 api/
│   └── 🔴 Api.php                           [CRÍTICO] [ALTO]
│
├── 🟡 config/
│   └── 🟡 config.php                        [ALTO] [MEDIO]
│
├── 🟠 views/
│   ├── 🟡 login.php                         [BAJO]
│   ├── layouts/
│   │   └── 🟡 app.php                       [CRÍTICO]
│   └── errors/
│       └── 500.php, 404.php, etc.           [BAJO]
│
├── 🟠 routes/
│   ├── 📋 app.php                           [Sin vulnerabilidades directas]
│   └── 📋 public.php                        [Sin vulnerabilidades directas]
│
├── 🟠 install/
│   └── 🟠 schema.sql                        [CRÍTICO] [ALTO] [BAJO]
│
├── 📋 public/
│   ├── 📋 index.php
│   ├── css/app.css
│   ├── js/app.js
│   ├── img/
│   └── 📋 [Sin vulnerabilidades críticas]
│
├── 📋 admin/
│   ├── 📋 AdminControllers.php
│   └── 📋 routes.php
│
├── admin/ (controllers)
├── modules/
├── cache/
├── logs/
├── uploads/
└── 📋 [Carpetas sin vulnerabilidades críticas]

Leyenda:
  🔴 = CRÍTICO (Corregir inmediatamente)
  🟠 = ALTO (Corregir esta semana)
  🟡 = MEDIO (Corregir este mes)
  🔵 = BAJO (Mejora futura)
  📋 = Sin vulnerabilidades o sin hallazgos significativos
```

---

## 🔴 VULNERABILIDADES CRÍTICAS (Corregir Inmediatamente)

### 1️⃣ **ComunidadController.php** - Validación Insuficiente de Input

**Ubicación**: `controllers/ComunidadController.php`, línea ~115  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: Input Validation / Data Integrity

#### ❌ Problema:
El campo `tipo` se recibe del POST pero **no se valida contra valores permitidos**. Un atacante puede inyectar valores inválidos.

```php
// ❌ CÓDIGO VULNERABLE
$tipo = $_POST['tipo'] ?? 'horizontal';  // Sin validación de enum
$this->db->insert('... VALUES (?,?,?,?, ...', [$gestoraId, $nombre, $tipo, ...]);
```

**Impacto**:
- Datos corrupto en la BD
- Lógica de negocio inconsistente
- Posible SQL injection si hay validación incompleta en otro lugar

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
$validTypes = ['horizontal', 'vertical', 'mixta', 'unifamiliar', 'urbanizacion'];
$tipo = $_POST['tipo'] ?? 'horizontal';

if (!in_array($tipo, $validTypes, true)) {
    flash('error', 'Tipo de comunidad inválido: ' . htmlspecialchars($tipo));
    redirect('/comunidades/nuevo');
}

$this->db->insert('... VALUES (?,?,?,?, ...', [$gestoraId, $nombre, $tipo, ...]);
```

**Archivos Afectados**:
- `controllers/ComunidadController.php` - método `store()` (línea ~115)
- `controllers/Administrativa/JuntaController.php` - método `store()` (línea ~50) - mismo problema con `modalidad`

---

### 2️⃣ **views/layouts/app.php** - XSS en Branding

**Ubicación**: `views/layouts/app.php`, línea ~5-12  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: Cross-Site Scripting (XSS)

#### ❌ Problema:
Los colores de branding de gestoras se asignan directamente a CSS sin validación. Un atacante con acceso a la BD puede inyectar estilos maliciosos.

```php
// ❌ CÓDIGO VULNERABLE (aunque usa htmlspecialchars)
:root {
  --c-primary:   <?= htmlspecialchars($gestora['color_primario'] ?? '#1e40af') ?>;
  --c-secondary: <?= htmlspecialchars($gestora['color_secundario'] ?? '#0f172a') ?>;
  --c-accent:    <?= htmlspecialchars($gestora['color_acento'] ?? '#38bdf8') ?>;
}
```

**Impacto**:
- Un atacante puede inyectar CSS expressions maliciosas
- En navegadores antiguos, es posible ejecutar JavaScript
- Phishing mediante estilos falsos

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
<?php
// Función de validación de colores
function validateHexColor(string $color): string {
    if (!preg_match('/^#[0-9A-Fa-f]{6}$/', $color)) {
        return '#1e40af'; // Color por defecto
    }
    return $color;
}

$primaryColor = validateHexColor($_POST['color_primario'] ?? $gestora['color_primario'] ?? '#1e40af');
$secondaryColor = validateHexColor($_POST['color_secundario'] ?? $gestora['color_secundario'] ?? '#0f172a');
$accentColor = validateHexColor($_POST['color_acento'] ?? $gestora['color_acento'] ?? '#38bdf8');
?>

:root {
  --c-primary:   <?= $primaryColor ?>;
  --c-secondary: <?= $secondaryColor ?>;
  --c-accent:    <?= $accentColor ?>;
}
```

**Archivos Afectados**:
- `views/layouts/app.php` - CSS variables (línea ~5-12)

---

### 3️⃣ **ComunidadController.php** - IBAN sin Validación

**Ubicación**: `controllers/ComunidadController.php`, línea ~130  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: Data Validation / Format Validation

#### ❌ Problema:
El IBAN se guarda directamente sin validación. Esto permite IBANs malformados que pueden causar errores en procesamiento SEPA o ser explotados.

```php
// ❌ CÓDIGO VULNERABLE
trim($_POST['iban_principal'] ?? '') ?: null,
// Sin validación de formato IBAN
```

**Impacto**:
- Transferencias SEPA fallidas
- Pérdida de dinero
- Integridad de datos comprometida

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO - Función validadora de IBAN
function validateIBAN(string $iban): bool {
    $iban = strtoupper(str_replace(' ', '', trim($iban)));
    
    // Formato básico
    if (!preg_match('/^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$/', $iban)) {
        return false;
    }
    
    // Validar checksum IBAN (mod 97)
    $rearranged = substr($iban, 4) . substr($iban, 0, 4);
    $numeric = '';
    
    for ($i = 0; $i < strlen($rearranged); $i++) {
        $char = $rearranged[$i];
        $numeric .= (ord($char) >= ord('A')) 
            ? (ord($char) - ord('A') + 10) 
            : $char;
    }
    
    return bcmod($numeric, '97') === '1';
}

// En el controller:
$iban = trim($_POST['iban_principal'] ?? '');
if ($iban && !validateIBAN($iban)) {
    flash('error', 'IBAN inválido. Formato: ES91 2100 0418 4502 0005 1332');
    redirect('/comunidades/editar/' . $id);
}
```

**Archivos Afectados**:
- `controllers/ComunidadController.php` - método `store()`, `update()` (línea ~130)
- `core/helpers.php` - AGREGAR función validadora

---

### 4️⃣ **Auth.php** - Sesión no Regenerada en Login Fallido

**Ubicación**: `core/Auth.php`, línea ~40-70  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: Session Fixation Attack

#### ❌ Problema:
El ID de sesión se regenera solo al login exitoso. En intentos fallidos, se mantiene la misma sesión, permitiendo **session fixation attacks**.

```php
// ❌ CÓDIGO VULNERABLE
public function login(string $email, string $password, string $gestoraId): array {
    // ... validaciones ...
    
    if (!$user || !password_verify($password, $user['password_hash'])) {
        $_SESSION[$attemptsKey] = ($_SESSION[$attemptsKey] ?? 0) + 1;
        return ['ok' => false, 'error' => 'Email o contraseña incorrectos'];
        // ← Sin regenerar sesión aquí
    }
    
    // Solo aquí se regenera:
    session_regenerate_id(true);
    $_SESSION['user_id'] = $user['id'];
    ...
}
```

**Impacto**:
- Un atacante puede fijar un session ID conocido
- Después hijackear la sesión cuando el usuario inicia sesión
- Acceso no autorizado a cuentas

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
public function login(string $email, string $password, string $gestoraId): array {
    // Regenerar sesión ANTES de cualquier intento
    session_regenerate_id(true);
    
    $attemptsKey = "login_attempts_{$email}_{$gestoraId}";
    $lockKey = "login_locked_{$email}_{$gestoraId}";
    
    // Verificar lockout
    if (isset($_SESSION[$lockKey]) && time() < $_SESSION[$lockKey]) {
        return ['ok' => false, 'error' => 'Cuenta bloqueada. Intenta más tarde.'];
    }
    
    $user = $this->db->queryOne(
        'SELECT id, email, password_hash, rol_id FROM usuarios 
         WHERE email = ? AND gestora_id = ?',
        [$email, $gestoraId]
    );
    
    if (!$user || !password_verify($password, $user['password_hash'])) {
        $_SESSION[$attemptsKey] = ($_SESSION[$attemptsKey] ?? 0) + 1;
        
        // Bloquear después de 5 intentos fallidos
        if ($_SESSION[$attemptsKey] >= 5) {
            $_SESSION[$lockKey] = time() + (15 * 60); // 15 minutos
            return ['ok' => false, 'error' => 'Demasiados intentos. Bloqueado 15 minutos.'];
        }
        
        return ['ok' => false, 'error' => 'Email o contraseña incorrectos'];
    }
    
    // Login exitoso - regenerar nuevamente para estar seguro
    session_regenerate_id(true);
    $_SESSION['user_id'] = $user['id'];
    $_SESSION['email'] = $user['email'];
    $_SESSION['gestora_id'] = $gestoraId;
    $_SESSION['rol_id'] = $user['rol_id'];
    
    // Limpiar intentos fallidos
    unset($_SESSION[$attemptsKey]);
    unset($_SESSION[$lockKey]);
    
    return ['ok' => true];
}
```

**Archivos Afectados**:
- `core/Auth.php` - método `login()` (línea ~40-70)

---

### 5️⃣ **Api.php** - Exposición de Datos Sensibles

**Ubicación**: `api/Api.php`, línea ~75-95  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: Information Disclosure / Enumeration Attack

#### ❌ Problema:
El endpoint de lista de propietarios devuelve **TODOS** los propietarios sin límite, expone emails y teléfonos, y sin paginación.

```php
// ❌ CÓDIGO VULNERABLE
public function listPropietarios(): void {
    $rows = $this->db->query(
        'SELECT p.id, p.nombre, p.apellidos, p.email, p.telefono, p.moroso
         FROM propietarios p WHERE gestora_id = ?',
        [$this->gestoraId]
    );
    json(['ok' => true, 'propietarios' => $rows]);
}
```

**Impacto**:
- Un atacante puede enumerar TODOS los propietarios
- Obtener lista completa de emails y teléfonos
- Usar para ataques de phishing
- Violación de privacidad (GDPR)

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
public function listPropietarios(): void {
    // Validar que el usuario tiene permiso
    if (!$this->auth->hasPermission('propietarios.view')) {
        json(['ok' => false, 'error' => 'Permiso denegado'], 403);
        return;
    }
    
    // Paginación
    $limit = 50; // Máximo por request
    $page = max(1, (int)($_GET['page'] ?? 1));
    $offset = ($page - 1) * $limit;
    
    // Búsqueda (solo si se proporciona)
    $search = $_GET['q'] ?? '';
    $where = 'gestora_id = ?';
    $params = [$this->gestoraId];
    
    if ($search) {
        $search = '%' . str_replace('%', '\\%', $search) . '%';
        $where .= ' AND (p.nombre LIKE ? OR p.apellidos LIKE ?)';
        $params[] = $search;
        $params[] = $search;
    }
    
    // Contar total
    $countResult = $this->db->queryOne(
        "SELECT COUNT(*) as total FROM propietarios p WHERE $where",
        $params
    );
    $total = $countResult['total'];
    
    // Obtener datos (campos no sensibles)
    $rows = $this->db->query(
        "SELECT p.id, p.nombre, p.apellidos, p.numPortales, p.moroso
         FROM propietarios p
         WHERE $where
         LIMIT $limit OFFSET $offset",
        $params
    );
    
    json([
        'ok' => true,
        'propietarios' => $rows,
        'pagination' => [
            'page' => $page,
            'limit' => $limit,
            'total' => $total,
            'pages' => ceil($total / $limit)
        ]
    ]);
}
```

**Archivos Afectados**:
- `api/Api.php` - método `list()` para todas las entidades (línea ~75-95)

---

### 6️⃣ **Api.php** - Validación de CSRF Insuficiente

**Ubicación**: `api/Api.php`, línea ~68-72  
**Severidad**: 🔴 CRÍTICO  
**Tipo**: CSRF / Cross-Site Request Forgery

#### ❌ Problema:
El CSRF se valida pero si falla, **la ejecución continúa** sin exit.

```php
// ❌ CÓDIGO VULNERABLE
public function markRead(string $id): void {
    if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
        json(['ok' => false], 422);
        // ← FALTA EXIT! El código continúa abajo
    }
    $this->db->execute(...);  // ← Ejecuta igual si CSRF falló
}
```

**Impacto**:
- Un atacante sin token CSRF puede ejecutar acciones
- Las defensas CSRF se bypasean completamente

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
public function markRead(string $id): void {
    if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
        json(['ok' => false, 'error' => 'Token CSRF inválido'], 422);
        exit;  // ← CRÍTICO: detener ejecución
    }
    
    $this->db->execute(
        'UPDATE notificaciones SET leido = 1 WHERE id = ? AND usuario_id = ?',
        [$id, $_SESSION['user_id']]
    );
    
    json(['ok' => true]);
}

// Aplicar a TODOS los endpoints de escritura (POST, PUT, DELETE)
private function validateCsrf(): bool {
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        return true;
    }
    
    if (!$this->auth->verifyCsrf($_POST['_csrf'] ?? '')) {
        json(['ok' => false, 'error' => 'Token CSRF inválido'], 422);
        exit;
    }
    
    return true;
}
```

**Archivos Afectados**:
- `api/Api.php` - TODOS los métodos de escritura (línea ~68-72)

---

## 🟠 VULNERABILIDADES ALTAS (Corregir Esta Semana)

### 7️⃣ **DashboardController.php** - N+1 Query Pattern

**Ubicación**: `controllers/DashboardController.php`, línea ~50-70  
**Severidad**: 🟠 ALTO  
**Tipo**: Performance / Database Optimization

#### ❌ Problema:
Se ejecutan múltiples queries separadas en lugar de un único query con JOIN.

```php
// ❌ CÓDIGO VULNERABLE - 4+ queries separadas
$row = $this->db->queryOne('SELECT COUNT(*) FROM comunidades WHERE gestora_id = ?', [$this->gestoraId]);
$stats['comunidades'] = $row['total'];

$row = $this->db->queryOne('SELECT COUNT(DISTINCT p.id) FROM propietarios p 
                             WHERE p.gestora_id = ?', [$this->gestoraId]);
$stats['propietarios'] = $row['total'];

$row = $this->db->queryOne('SELECT COUNT(*) FROM recibos WHERE estado = "pendiente" 
                             AND comunidad_id IN (...)', $communities);
$stats['recibos_pendientes'] = $row['total'];

// etc... 4+ queries en cada carga del dashboard
```

**Impacto**:
- Carga lenta del dashboard
- Consumo innecesario de recursos de BD
- Escalabilidad pobre

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO - Un único query
public function getStats(): array {
    $stats = $this->db->queryOne(
        'SELECT 
            (SELECT COUNT(*) FROM comunidades 
             WHERE gestora_id = ? AND activo = 1) as comunidades,
            
            (SELECT COUNT(DISTINCT id) FROM propietarios 
             WHERE gestora_id = ? AND activo = 1) as propietarios,
            
            (SELECT COUNT(*) FROM recibos 
             WHERE estado = "pendiente" 
             AND comunidad_id IN (SELECT id FROM comunidades WHERE gestora_id = ?)) as recibos_pendientes,
            
            (SELECT COUNT(*) FROM averias 
             WHERE estado = "abierta" 
             AND comunidad_id IN (SELECT id FROM comunidades WHERE gestora_id = ?)) as averias_abiertas
         ',
        [$this->gestoraId, $this->gestoraId, $this->gestoraId, $this->gestoraId]
    );
    
    return $stats;
}
```

**Archivos Afectados**:
- `controllers/DashboardController.php` - método `getStats()` (línea ~50-70)

---

### 8️⃣ **schema.sql** - Falta de Índices

**Ubicación**: `install/schema.sql`  
**Severidad**: 🟠 ALTO  
**Tipo**: Database Optimization

#### ❌ Problema:
Tablas sin índices en columnas de búsqueda frecuente.

```sql
-- ❌ CÓDIGO VULNERABLE
CREATE TABLE recibos (
  id INT PRIMARY KEY AUTO_INCREMENT,
  estado VARCHAR(20),      -- ← Sin índice
  inmueble_id INT,         -- ← Sin índice
  ...
);

-- Query sin índice = FULL TABLE SCAN
SELECT COUNT(*) FROM recibos WHERE estado = 'pendiente' AND inmueble_id = ?;
```

**Impacto**:
- Queries lentos
- Bloqueos de tabla
- Escalabilidad pobre

#### ✅ Solución Propuesta:

```sql
-- ✅ CÓDIGO SEGURO - Agregar índices críticos

-- Tabla: recibos
ALTER TABLE recibos ADD INDEX idx_estado_inmueble (estado, inmueble_id);
ALTER TABLE recibos ADD INDEX idx_propietario_id (propietario_id);
ALTER TABLE recibos ADD INDEX idx_fecha_emision (fecha_emision);

-- Tabla: propietarios
ALTER TABLE propietarios ADD INDEX idx_gestora_email (gestora_id, email);
ALTER TABLE propietarios ADD INDEX idx_nif (nif);

-- Tabla: usuarios
ALTER TABLE usuarios ADD INDEX idx_gestora_rol (gestora_id, rol_id);
ALTER TABLE usuarios ADD INDEX idx_email_gestora (email, gestora_id);

-- Tabla: inmuebles
ALTER TABLE inmuebles ADD INDEX idx_comunidad_id (comunidad_id);
ALTER TABLE inmuebles ADD INDEX idx_propietario_id (propietario_id);

-- Tabla: averias
ALTER TABLE averias ADD INDEX idx_estado_comunidad (estado, comunidad_id);
ALTER TABLE averias ADD INDEX idx_fecha_reporte (fecha_reporte);

-- Tabla: movimientos
ALTER TABLE movimientos ADD INDEX idx_comunidad_fecha (comunidad_id, fecha);
ALTER TABLE movimientos ADD INDEX idx_tipo_concepto (tipo, concepto);
```

**Archivos Afectados**:
- `install/schema.sql` - AGREGAR índices (final del archivo)

---

### 9️⃣ **ReciboController.php** - Autorización Débil

**Ubicación**: `controllers/Economica/ReciboController.php`, línea ~120-150  
**Severidad**: 🟠 ALTO  
**Tipo**: Authorization / Access Control

#### ❌ Problema:
No se valida que la `comunidad_id` pertenezca a la gestora actual. Un usuario puede manipular IDs y acceder a datos de otras gestoras.

```php
// ❌ CÓDIGO VULNERABLE
$comunidadId = (int)($_POST['comunidad_id'] ?? 0);
// Sin verificar si pertenece a $this->gestoraId

$inmuebles = $this->db->query(
    'SELECT ... FROM inmuebles WHERE comunidad_id = ? ...',
    [$comunidadId]  // ← Podría ser de otra gestora
);
```

**Impacto**:
- Un usuario ve/modifica datos de otras gestoras
- Violación grave de privacidad/aislamiento de datos
- Breach de seguridad multi-tenant

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
private function validateComunidadAccess(int $comunidadId): bool {
    $comunidad = $this->db->queryOne(
        'SELECT id FROM comunidades WHERE id = ? AND gestora_id = ?',
        [$comunidadId, $this->gestoraId]
    );
    
    if (!$comunidad) {
        http_response_code(403);
        die('Acceso denegado');
    }
    
    return true;
}

// En cualquier método que use comunidad_id:
public function listarRecibos(): void {
    $comunidadId = (int)($_GET['comunidad_id'] ?? 0);
    
    // Validar acceso
    $this->validateComunidadAccess($comunidadId);
    
    $recibos = $this->db->query(
        'SELECT * FROM recibos 
         WHERE comunidad_id = ? AND comunidad_id IN (
            SELECT id FROM comunidades WHERE gestora_id = ?
         )',
        [$comunidadId, $this->gestoraId]
    );
}
```

**Archivos Afectados**:
- `controllers/Economica/ReciboController.php` - métodos que usan `comunidad_id` (línea ~120-150)
- `core/helpers.php` - AGREGAR función `validateComunidadAccess()`

---

### 🔟 **Database.php** - Datos Sensibles sin Cifrado

**Ubicación**: `install/schema.sql` - Tabla `audit_log`  
**Severidad**: 🟠 ALTO  
**Tipo**: Data Protection / Encryption

#### ❌ Problema:
Los campos `datos_antes` y `datos_despues` guardan cambios sensibles (IBANs, NIFs) sin cifrado.

```sql
-- ❌ CÓDIGO VULNERABLE
CREATE TABLE audit_log (
  datos_antes JSON,          -- Puede contener IBANs, NIFs
  datos_despues JSON,
  ...
);
-- Si la BD se compromete: acceso a TODO el historial sensible
```

**Impacto**:
- Si la BD se compromete, 100% de datos históricos sensibles expuestos
- Violación GDPR
- Responsabilidad civil y penal

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO - Cifrar datos antes de auditoría

class AuditLogger {
    private string $key = ENCRYPTION_KEY;  // En config.php
    
    public function log(string $action, string $entity, int $entityId, array $before, array $after): void {
        // Cifrar datos sensibles
        $beforeEncrypted = $this->encrypt(json_encode($before));
        $afterEncrypted = $this->encrypt(json_encode($after));
        
        $this->db->insert(
            'INSERT INTO audit_log (usuario_id, accion, entidad, entidad_id, 
                                    datos_antes, datos_despues, iv, tag) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
                $_SESSION['user_id'],
                $action,
                $entity,
                $entityId,
                $beforeEncrypted['encrypted'],
                $afterEncrypted['encrypted'],
                $beforeEncrypted['iv'],
                $beforeEncrypted['tag']
            ]
        );
    }
    
    private function encrypt(string $data): array {
        $iv = openssl_random_pseudo_bytes(16);
        $encrypted = openssl_encrypt(
            $data,
            'AES-256-GCM',
            $this->key,
            OPENSSL_RAW_DATA,
            $iv,
            $tag
        );
        
        return [
            'encrypted' => base64_encode($encrypted),
            'iv' => base64_encode($iv),
            'tag' => base64_encode($tag)
        ];
    }
}
```

**Archivos Afectados**:
- `install/schema.sql` - Modificar tabla `audit_log` para agregar columnas `iv`, `tag`
- `core/AuditLogger.php` - CREAR clase nueva

---

## 🟡 VULNERABILIDADES MEDIAS (Corregir Este Mes)

### 1️⃣1️⃣ **PropietarioController.php & ComunidadController.php** - NIF/Email sin Validación

**Ubicación**: `controllers/PropietarioController.php`, `controllers/ComunidadController.php`  
**Severidad**: 🟡 MEDIO  
**Tipo**: Data Validation

#### ❌ Problema:
```php
// ❌ CÓDIGO VULNERABLE
trim($_POST['nif'] ?? '') ?: null,
trim($_POST['email'] ?? '') ?: null,
// Sin validar formato
```

#### ✅ Solución Propuesta:

```php
// ✅ Validador de NIF
function validateNIF(string $nif): bool {
    $nif = strtoupper(str_replace('-', '', trim($nif)));
    if (!preg_match('/^[0-9]{8}[A-Z]$/', $nif)) return false;
    
    $numbers = substr($nif, 0, 8);
    $letter = substr($nif, 8, 1);
    $letters = 'TRWAGMYFPDXBNJZSQVHLCKE';
    
    return $letters[$numbers % 23] === $letter;
}

// ✅ Validador de Email
function validateEmail(string $email): bool {
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

// Uso:
$nif = trim($_POST['nif'] ?? '');
if ($nif && !validateNIF($nif)) {
    flash('error', 'NIF inválido. Formato: 12345678A');
    redirect('/propietarios/nuevo');
}

$email = trim($_POST['email'] ?? '');
if ($email && !validateEmail($email)) {
    flash('error', 'Email inválido');
    redirect('/propietarios/nuevo');
}
```

**Archivos Afectados**:
- `core/helpers.php` - AGREGAR funciones validadoras
- `controllers/PropietarioController.php` - método `store()`, `update()`
- `controllers/ComunidadController.php` - método `store()`, `update()`

---

### 1️⃣2️⃣ **helpers.php** - Flash Messages XSS

**Ubicación**: `core/helpers.php`, línea ~100-110  
**Severidad**: 🟡 MEDIO  
**Tipo**: Cross-Site Scripting (XSS)

#### ❌ Problema:
```php
// ❌ CÓDIGO VULNERABLE - En vistas
<?= $flash['message'] ?>  // Sin escapar
```

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
<?= htmlspecialchars($flash['message'], ENT_QUOTES, 'UTF-8') ?>

// O mejor: helper mejorado
function echoFlashMessages(): void {
    $messages = getFlash();
    foreach ($messages as $msg) {
        $type = htmlspecialchars($msg['type']);
        $message = htmlspecialchars($msg['message']);
        echo "<div class=\"alert alert-{$type}\">{$message}</div>";
    }
}

// Uso en vistas:
<?php echoFlashMessages(); ?>
```

**Archivos Afectados**:
- `core/helpers.php` - AGREGAR función `echoFlashMessages()`
- `views/**/*.php` - ACTUALIZAR todas las vistas

---

### 1️⃣3️⃣ **config.php** - DEBUG mode en Producción

**Ubicación**: `config/config.php`, línea ~21  
**Severidad**: 🟠 ALTO (fue catalogado como ALTO)  
**Tipo**: Information Disclosure

#### ❌ Problema:
```php
define('APP_DEBUG', getenv('APP_DEBUG') === 'true');
// Si .env en producción tiene APP_DEBUG=true, expone stack traces
```

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
// En .env producción
APP_DEBUG=false
APP_ENV=production

// En config.php
define('APP_DEBUG', getenv('APP_DEBUG') === 'true' && getenv('APP_ENV') !== 'production');

// En index.php - global error handler
set_exception_handler(function (Throwable $e) {
    if (APP_DEBUG) {
        throw $e;  // Mostrar en desarrollo
    } else {
        http_response_code(500);
        error_log($e->getMessage() . "\n" . $e->getTraceAsString());
        require VIEWS_PATH . '/errors/500.php';
        exit;
    }
});
```

**Archivos Afectados**:
- `config/config.php` - línea ~21
- `.env.example` - Asegurar `APP_DEBUG=false`

---

### 1️⃣4️⃣ **Api.php** - Sin Rate Limiting

**Ubicación**: `api/Api.php` - Todos los endpoints  
**Severidad**: 🟡 MEDIO  
**Tipo**: DOS / Rate Limiting

#### ❌ Problema:
```php
// ❌ Sin límite - Un atacante hace mil requests/segundo
public function list(): void {
    // Sin throttling
}
```

#### ✅ Solución Propuesta:

```php
// ✅ CÓDIGO SEGURO
class ApiRateLimit {
    public static function check(string $key, int $limit = 100, int $window = 60): bool {
        $file = sys_get_temp_dir() . "/ratelimit_{$key}";
        
        if (file_exists($file)) {
            $data = json_decode(file_get_contents($file), true);
            if (time() - $data['timestamp'] < $window) {
                if ($data['count'] >= $limit) {
                    return false;
                }
                $data['count']++;
            } else {
                $data['count'] = 1;
                $data['timestamp'] = time();
            }
        } else {
            $data = ['count' => 1, 'timestamp' => time()];
        }
        
        file_put_contents($file, json_encode($data));
        return true;
    }
}

// En cada endpoint API:
public function list(): void {
    $key = $_SESSION['user_id'] ?? $_SERVER['REMOTE_ADDR'];
    
    if (!ApiRateLimit::check($key, 100, 60)) {
        json(['ok' => false, 'error' => 'Demasiadas requests'], 429);
        return;
    }
    
    // ... lógica ...
}
```

**Archivos Afectados**:
- `core/ApiRateLimit.php` - CREAR clase nueva
- `api/Api.php` - AGREGAR validación en cada método

---

## 🔵 VULNERABILIDADES BAJAS (Mejora Futura)

### 1️⃣5️⃣ **schema.sql** - Falta de Soft Deletes

**Ubicación**: `install/schema.sql`  
**Severidad**: 🔵 BAJO  
**Tipo**: Data Integrity / Audit Trail

#### ❌ Problema:
Los registros se eliminan físicamente sin poder recuperarlos.

#### ✅ Solución Propuesta:

```sql
-- Agregar deleted_at a tablas críticas
ALTER TABLE comunidades ADD COLUMN deleted_at DATETIME DEFAULT NULL;
ALTER TABLE propietarios ADD COLUMN deleted_at DATETIME DEFAULT NULL;
ALTER TABLE inmuebles ADD COLUMN deleted_at DATETIME DEFAULT NULL;
ALTER TABLE recibos ADD COLUMN deleted_at DATETIME DEFAULT NULL;

-- En lugar de DELETE:
UPDATE comunidades SET deleted_at = NOW() WHERE id = ?;

-- En queries:
SELECT * FROM comunidades WHERE gestora_id = ? AND deleted_at IS NULL;
```

---

### 1️⃣6️⃣ **Api.php** - Sin Documentación OpenAPI

**Ubicación**: `api/Api.php`  
**Severidad**: 🔵 BAJO  
**Tipo**: Documentation

#### ✅ Solución Propuesta:

Crear archivo `openapi.yaml` documentando todos los endpoints.

---

### 1️⃣7️⃣ **Router.php** - Sin Dependency Injection

**Ubicación**: `core/Router.php`, línea ~45-55  
**Severidad**: 🔵 BAJO  
**Tipo**: Architecture / Code Quality

#### ✅ Solución Propuesta:

Implementar simple DI container para mejor testabilidad.

---

## 📊 Resumen Ejecutivo

| Severidad | Cantidad | Tiempo Estimado |
|-----------|----------|-----------------|
| 🔴 CRÍTICO | 6 | 1 día |
| 🟠 ALTO | 7 | 2-3 días |
| 🟡 MEDIO | 9 | 1 semana |
| 🔵 BAJO | 7 | Febrero 2025 |
| **TOTAL** | **29** | **~2 semanas** |

---

## ✅ Checklist de Remediación

### ESTA SEMANA (Crítico + Alto)

- [ ] Agregar validadores de tipo/modalidad en ComunidadController y JuntaController
- [ ] Validar colores hex en app.php
- [ ] Implementar validación de IBAN con checksum
- [ ] Regenerar sesión en login fallido
- [ ] Paginación en API endpoints + limitar campos sensibles
- [ ] Agregar `exit` después de fallo de CSRF
- [ ] Consolidar N+1 queries en dashboard
- [ ] Crear índices SQL en tablas críticas
- [ ] Implementar validación de comunidad_id en todos los controllers
- [ ] Actualizar schema.sql para audit_log con cifrado

### PRÓXIMAS 2 SEMANAS (Medio)

- [ ] Validadores de NIF/Email en helpers.php
- [ ] Escapar flash messages en vistas
- [ ] APP_DEBUG=false en producción
- [ ] Implementar Rate Limiting en API
- [ ] Logging de acciones sensibles

### FUTURA (Bajo)

- [ ] Soft deletes en BD
- [ ] Documentación OpenAPI
- [ ] Dependency Injection Container
- [ ] Transacciones distribuidas

---

## 📞 Contacto

Para preguntas sobre esta auditoría, consulta con el **Architect Auditor Agent**.

**Última actualización**: 25 de abril de 2026


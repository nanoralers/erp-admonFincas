<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= htmlspecialchars($pageTitle ?? 'Dashboard') ?> — <?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></title>
<meta name="csrf-token" content="<?= $auth->csrfToken() ?>">
<link rel="icon" href="<?= $gestora['favicon_path'] ? '/uploads/'.$gestora['favicon_path'] : '/public/img/favicon.ico' ?>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<link rel="stylesheet" href="/public/css/app.css">
<style>
:root {
  --c-primary:   <?= htmlspecialchars($gestora['color_primario']   ?? '#1e40af') ?>;
  --c-secondary: <?= htmlspecialchars($gestora['color_secundario'] ?? '#0f172a') ?>;
  --c-accent:    <?= htmlspecialchars($gestora['color_acento']     ?? '#38bdf8') ?>;
}
</style>
</head>
<body>

<!-- ─── Overlay móvil ─────────────────────────────────────────────────────── -->
<div class="sidebar-overlay" id="sidebarOverlay"></div>

<!-- ═══════════════════════════════════════════════════════════════════════════
     SIDEBAR
════════════════════════════════════════════════════════════════════════════ -->
<aside class="sidebar" id="sidebar">

  <!-- Logo / Branding -->
  <div class="sidebar-brand">
    <div class="brand-logo">
      <?php if (!empty($gestora['logo_path'])): ?>
        <img src="/uploads/logos/<?= htmlspecialchars($gestora['logo_path']) ?>" alt="Logo" class="brand-img">
      <?php else: ?>
        <div class="brand-icon"><i class="fa-solid fa-building-columns"></i></div>
      <?php endif; ?>
    </div>
    <div class="brand-info">
      <span class="brand-name"><?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></span>
      <span class="brand-sub"><?= htmlspecialchars($gestora['nombre'] ?? '') ?></span>
    </div>
    <button class="sidebar-close" id="sidebarClose"><i class="fa-solid fa-xmark"></i></button>
  </div>

  <!-- Selector de comunidad -->
  <div class="community-selector">
    <div class="community-label">Comunidad activa</div>
    <div class="community-select-wrap">
      <select id="comunidadSelect" class="community-select" onchange="switchComunidad(this.value)">
        <option value="">— Todas las comunidades —</option>
        <?php foreach ($comunidades ?? [] as $c): ?>
          <option value="<?= $c['id'] ?>"
            <?= (($_SESSION['comunidad_activa'] ?? null) == $c['id']) ? 'selected' : '' ?>>
            <?= htmlspecialchars($c['nombre']) ?>
          </option>
        <?php endforeach; ?>
      </select>
      <i class="fa-solid fa-chevron-down community-select-icon"></i>
    </div>
  </div>

  <!-- Navegación principal -->
  <nav class="sidebar-nav">
    <div class="nav-section-label">General</div>
    <a href="/dashboard" class="nav-item <?= active('/dashboard') ?>">
      <i class="fa-solid fa-gauge-high"></i>
      <span>Dashboard</span>
    </a>
    <a href="/comunidades" class="nav-item <?= active('/comunidades') ?>">
      <i class="fa-solid fa-city"></i>
      <span>Comunidades</span>
    </a>
    <a href="/propietarios" class="nav-item <?= active('/propietarios') ?>">
      <i class="fa-solid fa-users"></i>
      <span>Propietarios</span>
    </a>

    <?php if ($auth->can('economica')): ?>
    <div class="nav-section-label" style="color:<?= MODULES['economica']['color'] ?>">Económica</div>
    <a href="/economica" class="nav-item <?= activePrefix('/economica') ?>" style="--mod-color:<?= MODULES['economica']['color'] ?>">
      <i class="fa-solid fa-chart-line"></i><span>Resumen Económico</span>
    </a>
    <a href="/economica/presupuestos" class="nav-item sub <?= active('/economica/presupuestos') ?>">
      <i class="fa-solid fa-file-invoice"></i><span>Presupuestos</span>
    </a>
    <a href="/economica/recibos" class="nav-item sub <?= active('/economica/recibos') ?>">
      <i class="fa-solid fa-receipt"></i><span>Recibos y Cobros</span>
      <?php $pendientes = countPendientes('recibos'); if ($pendientes): ?>
        <span class="nav-badge"><?= $pendientes ?></span>
      <?php endif; ?>
    </a>
    <a href="/economica/remesas" class="nav-item sub <?= active('/economica/remesas') ?>">
      <i class="fa-solid fa-landmark"></i><span>Remesas SEPA</span>
    </a>
    <a href="/economica/movimientos" class="nav-item sub <?= active('/economica/movimientos') ?>">
      <i class="fa-solid fa-arrows-left-right"></i><span>Movimientos</span>
    </a>
    <a href="/economica/liquidaciones" class="nav-item sub <?= active('/economica/liquidaciones') ?>">
      <i class="fa-solid fa-file-chart-pie"></i><span>Liquidaciones</span>
    </a>
    <?php endif; ?>

    <?php if ($auth->can('mantenimiento')): ?>
    <div class="nav-section-label" style="color:<?= MODULES['mantenimiento']['color'] ?>">Mantenimiento</div>
    <a href="/mantenimiento/averias" class="nav-item <?= activePrefix('/mantenimiento/aver') ?>" style="--mod-color:<?= MODULES['mantenimiento']['color'] ?>">
      <i class="fa-solid fa-triangle-exclamation"></i><span>Averías</span>
      <?php $abiertas = countPendientes('averias'); if ($abiertas): ?>
        <span class="nav-badge urgent"><?= $abiertas ?></span>
      <?php endif; ?>
    </a>
    <a href="/mantenimiento/obras" class="nav-item sub <?= activePrefix('/mantenimiento/obras') ?>">
      <i class="fa-solid fa-helmet-safety"></i><span>Obras y Presupuestos</span>
    </a>
    <a href="/mantenimiento/proveedores" class="nav-item sub <?= activePrefix('/mantenimiento/proveedores') ?>">
      <i class="fa-solid fa-truck"></i><span>Proveedores</span>
    </a>
    <a href="/mantenimiento/contratos" class="nav-item sub <?= active('/mantenimiento/contratos') ?>">
      <i class="fa-solid fa-file-signature"></i><span>Contratos de Servicios</span>
    </a>
    <a href="/mantenimiento/ite-iee" class="nav-item sub <?= active('/mantenimiento/ite-iee') ?>">
      <i class="fa-solid fa-clipboard-check"></i><span>ITE / IEE</span>
    </a>
    <?php endif; ?>

    <?php if ($auth->can('juridica')): ?>
    <div class="nav-section-label" style="color:<?= MODULES['juridica']['color'] ?>">Jurídica</div>
    <a href="/juridica/morosos" class="nav-item <?= activePrefix('/juridica/morosos') ?>" style="--mod-color:<?= MODULES['juridica']['color'] ?>">
      <i class="fa-solid fa-gavel"></i><span>Morosos</span>
      <?php $morosos = countPendientes('morosos'); if ($morosos): ?>
        <span class="nav-badge urgent"><?= $morosos ?></span>
      <?php endif; ?>
    </a>
    <a href="/juridica/siniestros" class="nav-item sub <?= activePrefix('/juridica/siniestros') ?>">
      <i class="fa-solid fa-fire-flame-curved"></i><span>Siniestros</span>
    </a>
    <a href="/juridica/documentos" class="nav-item sub <?= active('/juridica/documentos') ?>">
      <i class="fa-solid fa-folder-open"></i><span>Documentación Legal</span>
    </a>
    <?php endif; ?>

    <?php if ($auth->can('admin')): ?>
    <div class="nav-section-label" style="color:<?= MODULES['admin']['color'] ?>">Administrativa</div>
    <a href="/juntas" class="nav-item <?= activePrefix('/juntas') ?>" style="--mod-color:<?= MODULES['admin']['color'] ?>">
      <i class="fa-solid fa-people-group"></i><span>Juntas de Propietarios</span>
    </a>
    <a href="/actas" class="nav-item sub <?= active('/actas') ?>">
      <i class="fa-solid fa-book"></i><span>Libro de Actas</span>
    </a>
    <a href="/comunicaciones" class="nav-item sub <?= active('/comunicaciones') ?>">
      <i class="fa-solid fa-paper-plane"></i><span>Comunicaciones</span>
    </a>
    <a href="/tareas" class="nav-item sub <?= active('/tareas') ?>">
      <i class="fa-solid fa-list-check"></i><span>Tareas</span>
    </a>
    <?php endif; ?>
  </nav>

  <!-- Footer del sidebar -->
  <div class="sidebar-footer">
    <a href="/configuracion" class="nav-item">
      <i class="fa-solid fa-sliders"></i><span>Configuración</span>
    </a>
    <a href="/logout" class="nav-item danger">
      <i class="fa-solid fa-right-from-bracket"></i><span>Cerrar sesión</span>
    </a>
  </div>
</aside>

<!-- ═══════════════════════════════════════════════════════════════════════════
     MAIN CONTENT
════════════════════════════════════════════════════════════════════════════ -->
<div class="main-wrap">

  <!-- Topbar -->
  <header class="topbar">
    <button class="topbar-toggle" id="sidebarToggle" aria-label="Menú">
      <i class="fa-solid fa-bars"></i>
    </button>

    <!-- Breadcrumb -->
    <nav class="breadcrumb" aria-label="Ruta">
      <a href="/dashboard" class="breadcrumb-home"><i class="fa-solid fa-house"></i></a>
      <?php if (!empty($breadcrumbs)): ?>
        <?php foreach ($breadcrumbs as $bc): ?>
          <i class="fa-solid fa-chevron-right bc-sep"></i>
          <?php if (!empty($bc['url'])): ?>
            <a href="<?= htmlspecialchars($bc['url']) ?>" class="breadcrumb-link"><?= htmlspecialchars($bc['label']) ?></a>
          <?php else: ?>
            <span class="breadcrumb-current"><?= htmlspecialchars($bc['label']) ?></span>
          <?php endif; ?>
        <?php endforeach; ?>
      <?php endif; ?>
    </nav>

    <div class="topbar-actions">
      <!-- Búsqueda rápida -->
      <button class="topbar-btn" id="searchBtn" aria-label="Buscar">
        <i class="fa-solid fa-magnifying-glass"></i>
      </button>

      <!-- Notificaciones -->
      <div class="notif-wrap">
        <button class="topbar-btn" id="notifBtn" aria-label="Notificaciones">
          <i class="fa-solid fa-bell"></i>
          <span class="notif-dot" id="notifDot" style="display:none"></span>
        </button>
        <div class="notif-panel" id="notifPanel">
          <div class="notif-header">
            <span>Notificaciones</span>
            <button class="notif-mark-all" onclick="markAllRead()">Marcar todas</button>
          </div>
          <div class="notif-list" id="notifList">
            <div class="notif-empty">Cargando...</div>
          </div>
        </div>
      </div>

      <!-- Avatar usuario -->
      <div class="user-menu-wrap">
        <button class="user-avatar-btn" id="userMenuBtn">
          <div class="user-avatar">
            <?php if (!empty($currentUser['avatar_path'])): ?>
              <img src="/uploads/avatars/<?= htmlspecialchars($currentUser['avatar_path']) ?>" alt="Avatar">
            <?php else: ?>
              <span><?= strtoupper(mb_substr($currentUser['nombre'] ?? 'U', 0, 1)) ?></span>
            <?php endif; ?>
          </div>
          <span class="user-name"><?= htmlspecialchars($currentUser['nombre'] ?? 'Usuario') ?></span>
          <i class="fa-solid fa-chevron-down user-caret"></i>
        </button>
        <div class="user-menu" id="userMenu">
          <div class="user-menu-info">
            <strong><?= htmlspecialchars(trim(($currentUser['nombre'] ?? '') . ' ' . ($currentUser['apellidos'] ?? ''))) ?></strong>
            <small><?= htmlspecialchars($currentUser['email'] ?? '') ?></small>
            <span class="role-tag"><?= htmlspecialchars($currentUser['rol_codigo'] ?? '') ?></span>
          </div>
          <div class="user-menu-divider"></div>
          <a href="/configuracion" class="user-menu-item"><i class="fa-solid fa-user-gear"></i> Mi perfil</a>
          <a href="/configuracion#seguridad" class="user-menu-item"><i class="fa-solid fa-shield-halved"></i> Seguridad</a>
          <div class="user-menu-divider"></div>
          <a href="/logout" class="user-menu-item danger"><i class="fa-solid fa-right-from-bracket"></i> Cerrar sesión</a>
        </div>
      </div>
    </div>
  </header>

  <!-- Mensajes flash -->
  <?php if (!empty($flash)): ?>
    <div class="flash-wrap">
      <?php foreach ($flash as $f): ?>
        <div class="flash flash-<?= htmlspecialchars($f['type']) ?>" role="alert">
          <i class="fa-solid <?= $f['type']==='error'?'fa-circle-exclamation':($f['type']==='success'?'fa-circle-check':'fa-circle-info') ?>"></i>
          <?= htmlspecialchars($f['message']) ?>
          <button class="flash-close" onclick="this.parentElement.remove()"><i class="fa-solid fa-xmark"></i></button>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <!-- Contenido de la página -->
  <main class="page-content">
    <?= $content ?? '' ?>
  </main>

</div><!-- /.main-wrap -->

<!-- ─── Modal búsqueda rápida ─────────────────────────────────────────────── -->
<div class="search-modal" id="searchModal">
  <div class="search-modal-box">
    <div class="search-input-wrap">
      <i class="fa-solid fa-magnifying-glass"></i>
      <input type="text" id="globalSearch" placeholder="Buscar comunidades, propietarios, recibos..." autofocus>
      <kbd>Esc</kbd>
    </div>
    <div class="search-results" id="searchResults">
      <div class="search-hint">Escribe para buscar en todo el sistema</div>
    </div>
  </div>
</div>

<script src="/public/js/app.js"></script>
</body>
</html>

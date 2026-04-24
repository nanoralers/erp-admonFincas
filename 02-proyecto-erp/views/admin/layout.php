<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title><?= htmlspecialchars($pageTitle ?? 'Admin') ?> — ERP Fincas Superadmin</title>
<meta name="csrf-token" content="<?= $auth->csrfToken() ?>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;500;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<style>
:root {
  --c-primary: #6366f1; --c-bg: #0f172a; --c-surface: #1e293b;
  --c-surface2: #273549; --c-border: rgba(255,255,255,.08);
  --c-text: #f1f5f9; --c-muted: #94a3b8; --c-accent: #38bdf8;
  --sidebar-w: 240px; --font: 'Sora', system-ui, sans-serif;
}
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: var(--font); background: var(--c-bg); color: var(--c-text);
       display: flex; min-height: 100vh; font-size: 14px; }
a { color: var(--c-accent); text-decoration: none; }

/* Sidebar */
.sidebar {
  width: var(--sidebar-w); background: var(--c-surface);
  border-right: 1px solid var(--c-border);
  display: flex; flex-direction: column; position: fixed; inset: 0 auto 0 0; z-index: 100;
}
.sidebar-brand {
  padding: 1.25rem 1rem; border-bottom: 1px solid var(--c-border);
  display: flex; align-items: center; gap: .75rem;
}
.brand-icon {
  width: 36px; height: 36px; border-radius: 8px;
  background: linear-gradient(135deg, var(--c-primary), var(--c-accent));
  display: flex; align-items: center; justify-content: center;
  font-size: .9rem; color: #fff; flex-shrink: 0;
}
.brand-text strong { display: block; font-size: .85rem; color: var(--c-text); }
.brand-text span   { font-size: .7rem; color: var(--c-muted); }
.nav-section { padding: .75rem .75rem .25rem; font-size: .65rem; text-transform: uppercase;
               letter-spacing: .08em; color: var(--c-muted); font-weight: 700; }
.nav-item {
  display: flex; align-items: center; gap: .6rem;
  padding: .55rem .85rem; font-size: .82rem; font-weight: 500;
  color: var(--c-muted); transition: all .15s; border-radius: 6px; margin: .1rem .4rem;
  text-decoration: none;
}
.nav-item:hover { background: rgba(255,255,255,.06); color: var(--c-text); }
.nav-item.active { background: rgba(99,102,241,.15); color: var(--c-primary); }
.nav-item i { width: 16px; text-align: center; font-size: .85rem; }
.sidebar-footer { margin-top: auto; border-top: 1px solid var(--c-border); padding: .5rem 0; }
.nav-item.danger { color: #f87171; }
.nav-item.danger:hover { background: rgba(248,113,113,.1); }

/* Main */
.main-wrap { margin-left: var(--sidebar-w); flex: 1; display: flex; flex-direction: column; }
.topbar {
  height: 56px; background: var(--c-surface); border-bottom: 1px solid var(--c-border);
  display: flex; align-items: center; padding: 0 1.5rem; gap: 1rem; position: sticky; top: 0; z-index: 50;
}
.topbar-title { font-size: .95rem; font-weight: 700; }
.topbar-actions { margin-left: auto; display: flex; align-items: center; gap: .5rem; }
.badge-admin {
  padding: .2rem .55rem; border-radius: 5px;
  background: rgba(99,102,241,.2); color: var(--c-primary);
  font-size: .7rem; font-weight: 700; text-transform: uppercase;
}
.page-content { padding: 1.5rem; flex: 1; }

/* Cards */
.card {
  background: var(--c-surface); border: 1px solid var(--c-border);
  border-radius: 12px; overflow: hidden;
}
.card-header {
  padding: 1rem 1.25rem; border-bottom: 1px solid var(--c-border);
  display: flex; align-items: center; justify-content: space-between;
}
.card-title { font-size: .875rem; font-weight: 700; display: flex; align-items: center; gap: .5rem; }
.card-body { padding: 1.25rem; }

/* Tables */
.table { width: 100%; border-collapse: collapse; font-size: .83rem; }
.table th { padding: .6rem 1rem; text-align: left; font-size: .7rem; text-transform: uppercase;
            letter-spacing: .06em; color: var(--c-muted); background: var(--c-surface2);
            border-bottom: 1px solid var(--c-border); }
.table td { padding: .75rem 1rem; border-bottom: 1px solid var(--c-border); vertical-align: middle; }
.table tbody tr:hover td { background: rgba(255,255,255,.02); }
.table-wrap { overflow-x: auto; }

/* Stats grid */
.stats-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px,1fr)); gap: 1rem; margin-bottom: 1.5rem; }
.stat-card {
  background: var(--c-surface); border: 1px solid var(--c-border); border-radius: 10px;
  padding: 1.1rem; display: flex; flex-direction: column; gap: .3rem;
}
.stat-val  { font-size: 2rem; font-weight: 800; color: var(--c-text); line-height: 1; }
.stat-lbl  { font-size: .75rem; color: var(--c-muted); }
.stat-icon { font-size: 1.4rem; margin-bottom: .25rem; }

/* Badges */
.badge { display: inline-flex; align-items: center; gap: .2rem; padding: .15rem .45rem;
         border-radius: 999px; font-size: .7rem; font-weight: 700; }
.badge-active  { background: rgba(16,185,129,.15); color: #10b981; }
.badge-inactive{ background: rgba(248,113,113,.15); color: #f87171; }
.badge-plan    { padding: .15rem .45rem; border-radius: 4px; font-size: .68rem; font-weight: 700; }

/* Buttons */
.btn { display: inline-flex; align-items: center; gap: .4rem; padding: .45rem .9rem;
       border-radius: 7px; font-family: var(--font); font-size: .82rem; font-weight: 600;
       border: 1px solid transparent; cursor: pointer; text-decoration: none; }
.btn-primary { background: var(--c-primary); color: #fff; border-color: var(--c-primary); }
.btn-primary:hover { opacity: .88; }
.btn-secondary { background: var(--c-surface2); color: var(--c-text); border-color: var(--c-border); }
.btn-secondary:hover { border-color: var(--c-primary); }
.btn-sm { padding: .3rem .6rem; font-size: .75rem; }
.btn-danger { background: rgba(248,113,113,.15); color: #f87171; border-color: rgba(248,113,113,.2); }

/* Flash */
.flash-wrap { padding: .75rem 1.5rem 0; }
.flash { display: flex; align-items: center; gap: .5rem; padding: .65rem 1rem;
         border-radius: 8px; font-size: .83rem; margin-bottom: .5rem; }
.flash-success { background: rgba(16,185,129,.1); color: #34d399; border: 1px solid rgba(16,185,129,.2); }
.flash-error   { background: rgba(248,113,113,.1); color: #f87171; border: 1px solid rgba(248,113,113,.2); }
.flash-warning { background: rgba(251,191,36,.1);  color: #fbbf24; border: 1px solid rgba(251,191,36,.2); }
.flash-close   { margin-left: auto; background: none; border: none; cursor: pointer; color: inherit; opacity: .6; }
</style>
</head>
<body>

<aside class="sidebar">
  <div class="sidebar-brand">
    <div class="brand-icon"><i class="fa-solid fa-shield-halved"></i></div>
    <div class="brand-text">
      <strong>ERP Fincas</strong>
      <span>Superadmin</span>
    </div>
  </div>

  <nav style="flex:1;overflow-y:auto;padding:.5rem 0;">
    <div class="nav-section">General</div>
    <a href="/dashboard" class="nav-item <?= active('/dashboard') ?>">
      <i class="fa-solid fa-gauge-high"></i> Dashboard
    </a>

    <div class="nav-section">Clientes</div>
    <a href="/gestoras" class="nav-item <?= activePrefix('/gestoras') ?>">
      <i class="fa-solid fa-building"></i> Gestoras
    </a>
    <a href="/planes" class="nav-item <?= activePrefix('/planes') ?>">
      <i class="fa-solid fa-boxes-stacked"></i> Planes y Módulos
    </a>

    <div class="nav-section">Sistema</div>
    <a href="/usuarios" class="nav-item <?= activePrefix('/usuarios') ?>">
      <i class="fa-solid fa-users-gear"></i> Usuarios
    </a>
    <a href="/stats" class="nav-item <?= active('/stats') ?>">
      <i class="fa-solid fa-chart-bar"></i> Estadísticas
    </a>
    <a href="/logs" class="nav-item <?= activePrefix('/logs') ?>">
      <i class="fa-solid fa-scroll"></i> Auditoría
    </a>
  </nav>

  <div class="sidebar-footer">
    <a href="/logout" class="nav-item danger">
      <i class="fa-solid fa-right-from-bracket"></i> Cerrar sesión
    </a>
  </div>
</aside>

<div class="main-wrap">
  <header class="topbar">
    <span class="topbar-title"><?= htmlspecialchars($pageTitle ?? '') ?></span>
    <div class="topbar-actions">
      <span class="badge-admin">SUPERADMIN</span>
      <span style="font-size:.82rem;color:var(--c-muted);">
        <?= htmlspecialchars($currentUser['nombre'] ?? '') ?>
      </span>
    </div>
  </header>

  <?php if (!empty($flash = getFlash())): ?>
    <div class="flash-wrap">
      <?php foreach ($flash as $f): ?>
        <div class="flash flash-<?= $f['type'] ?>">
          <i class="fa-solid <?= $f['type']==='error'?'fa-circle-exclamation':'fa-circle-check' ?>"></i>
          <?= htmlspecialchars($f['message']) ?>
          <button class="flash-close" onclick="this.parentElement.remove()">×</button>
        </div>
      <?php endforeach; ?>
    </div>
  <?php endif; ?>

  <main class="page-content">
    <?= $content ?? '' ?>
  </main>
</div>

<script>
// CSRF header para fetch
const CSRF = document.querySelector('meta[name="csrf-token"]')?.content;
</script>
</body>
</html>

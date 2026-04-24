<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Acceso — <?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></title>
<link rel="icon" href="<?= $gestora['favicon_path'] ? '/uploads/'.$gestora['favicon_path'] : '/public/img/favicon.ico' ?>">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<style>
/* ─── Variables branding dinámico ─────────────────────────────────────────── */
:root {
  --c-primary:   <?= htmlspecialchars($gestora['color_primario']   ?? '#1e40af') ?>;
  --c-secondary: <?= htmlspecialchars($gestora['color_secundario'] ?? '#0f172a') ?>;
  --c-accent:    <?= htmlspecialchars($gestora['color_acento']     ?? '#38bdf8') ?>;
  --c-bg:        #f0f4f8;
  --c-surface:   #ffffff;
  --c-text:      #0f172a;
  --c-muted:     #64748b;
  --c-border:    #e2e8f0;
  --radius:      14px;
  --shadow-lg:   0 24px 64px rgba(0,0,0,.12), 0 4px 16px rgba(0,0,0,.06);
  --font:        'Sora', system-ui, sans-serif;
  --font-mono:   'JetBrains Mono', monospace;
}

/* ─── Reset ───────────────────────────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; }
body {
  font-family: var(--font);
  background: var(--c-bg);
  color: var(--c-text);
  display: grid;
  place-items: center;
  min-height: 100vh;
  position: relative;
  overflow: hidden;
}

/* ─── Fondo animado ───────────────────────────────────────────────────────── */
.bg-shapes {
  position: fixed; inset: 0; z-index: 0; pointer-events: none;
  overflow: hidden;
}
.bg-shapes span {
  position: absolute; border-radius: 50%;
  opacity: .06; animation: drift 18s ease-in-out infinite alternate;
}
.bg-shapes span:nth-child(1) {
  width: 600px; height: 600px; background: var(--c-primary);
  top: -200px; left: -100px; animation-delay: 0s;
}
.bg-shapes span:nth-child(2) {
  width: 400px; height: 400px; background: var(--c-accent);
  bottom: -100px; right: -80px; animation-delay: -6s;
}
.bg-shapes span:nth-child(3) {
  width: 250px; height: 250px; background: var(--c-primary);
  top: 40%; right: 20%; animation-delay: -3s;
}
@keyframes drift {
  from { transform: translate(0,0) scale(1); }
  to   { transform: translate(30px, 40px) scale(1.08); }
}

/* ─── Tarjeta login ───────────────────────────────────────────────────────── */
.login-wrapper {
  position: relative; z-index: 10;
  width: 100%; max-width: 420px;
  padding: 1.5rem;
  animation: slideUp .5s cubic-bezier(.22,.68,0,1.2) both;
}
@keyframes slideUp {
  from { opacity: 0; transform: translateY(32px); }
  to   { opacity: 1; transform: translateY(0); }
}

.login-card {
  background: var(--c-surface);
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  overflow: hidden;
}

/* Header colorido */
.login-header {
  background: linear-gradient(135deg, var(--c-primary) 0%, var(--c-secondary) 100%);
  padding: 2.5rem 2rem 2rem;
  text-align: center;
  position: relative;
}
.login-header::after {
  content: '';
  position: absolute; bottom: -1px; left: 0; right: 0;
  height: 30px;
  background: var(--c-surface);
  clip-path: ellipse(55% 100% at 50% 100%);
}

.login-logo {
  width: 72px; height: 72px;
  background: rgba(255,255,255,.15);
  border-radius: 18px;
  display: inline-flex; align-items: center; justify-content: center;
  margin-bottom: 1rem;
  border: 2px solid rgba(255,255,255,.3);
  backdrop-filter: blur(4px);
}
.login-logo img { width: 44px; height: 44px; object-fit: contain; }
.login-logo i   { font-size: 2rem; color: #fff; }

.login-header h1 {
  font-size: 1.5rem; font-weight: 700; color: #fff;
  letter-spacing: -.02em;
}
.login-header p {
  font-size: .85rem; color: rgba(255,255,255,.7); margin-top: .25rem;
}

/* Body del form */
.login-body { padding: 2rem; }

.alert {
  padding: .75rem 1rem;
  border-radius: 8px;
  font-size: .875rem;
  margin-bottom: 1.25rem;
  display: flex; align-items: center; gap: .5rem;
}
.alert-error   { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.alert-success { background: #f0fdf4; color: #16a34a; border: 1px solid #bbf7d0; }

.form-group {
  margin-bottom: 1.25rem;
}
.form-label {
  display: block;
  font-size: .8rem; font-weight: 600;
  color: var(--c-muted); text-transform: uppercase;
  letter-spacing: .05em; margin-bottom: .4rem;
}
.input-wrap {
  position: relative;
}
.input-icon {
  position: absolute; left: .9rem; top: 50%; transform: translateY(-50%);
  color: var(--c-muted); font-size: .9rem; pointer-events: none;
}
.form-control {
  width: 100%; padding: .75rem .75rem .75rem 2.5rem;
  border: 1.5px solid var(--c-border);
  border-radius: 10px;
  font-family: var(--font); font-size: .95rem;
  color: var(--c-text); background: #fff;
  transition: border-color .2s, box-shadow .2s;
  outline: none;
}
.form-control:focus {
  border-color: var(--c-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--c-primary) 15%, transparent);
}
.toggle-pass {
  position: absolute; right: .9rem; top: 50%; transform: translateY(-50%);
  background: none; border: none; cursor: pointer;
  color: var(--c-muted); font-size: .9rem;
  transition: color .2s;
}
.toggle-pass:hover { color: var(--c-primary); }

.form-extras {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 1.5rem; font-size: .875rem;
}
.checkbox-wrap {
  display: flex; align-items: center; gap: .4rem; cursor: pointer;
}
.checkbox-wrap input[type=checkbox] { accent-color: var(--c-primary); }
.link-muted {
  color: var(--c-primary); text-decoration: none; font-weight: 500;
  transition: opacity .15s;
}
.link-muted:hover { opacity: .75; }

.btn-login {
  display: flex; align-items: center; justify-content: center; gap: .5rem;
  width: 100%; padding: .9rem;
  background: linear-gradient(135deg, var(--c-primary) 0%, var(--c-secondary) 100%);
  color: #fff; border: none; border-radius: 10px;
  font-family: var(--font); font-size: 1rem; font-weight: 600;
  cursor: pointer; transition: opacity .2s, transform .15s;
}
.btn-login:hover  { opacity: .9; }
.btn-login:active { transform: scale(.98); }
.btn-login .spinner {
  width: 18px; height: 18px; border: 2px solid rgba(255,255,255,.4);
  border-top-color: #fff; border-radius: 50%;
  animation: spin .7s linear infinite; display: none;
}
@keyframes spin { to { transform: rotate(360deg); } }
.btn-login.loading .spinner { display: block; }
.btn-login.loading .btn-text { display: none; }

/* Footer */
.login-footer {
  text-align: center; padding: 1rem 2rem 1.5rem;
  font-size: .78rem; color: var(--c-muted);
  border-top: 1px solid var(--c-border);
}
.login-footer a { color: var(--c-primary); text-decoration: none; }

/* ─── Indicador plan ──────────────────────────────────────────────────────── */
.plan-badge {
  display: inline-flex; align-items: center; gap: .35rem;
  padding: .2rem .6rem; border-radius: 999px;
  font-size: .7rem; font-weight: 600; text-transform: uppercase;
  letter-spacing: .05em;
  background: color-mix(in srgb, var(--c-accent) 20%, transparent);
  color: var(--c-primary);
  margin-top: .5rem;
}

/* ─── Versión ─────────────────────────────────────────────────────────────── */
.version-tag {
  position: fixed; bottom: 1rem; right: 1.25rem;
  font-size: .7rem; color: var(--c-muted);
  font-family: var(--font-mono);
  z-index: 10; opacity: .6;
}
</style>
</head>
<body>

<div class="bg-shapes">
  <span></span><span></span><span></span>
</div>

<div class="login-wrapper">
  <div class="login-card">

    <!-- Header con branding -->
    <div class="login-header">
      <div class="login-logo">
        <?php if (!empty($gestora['logo_path'])): ?>
          <img src="/uploads/logos/<?= htmlspecialchars($gestora['logo_path']) ?>" alt="Logo">
        <?php else: ?>
          <i class="fa-solid fa-building-columns"></i>
        <?php endif; ?>
      </div>
      <h1><?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></h1>
      <p><?= htmlspecialchars($gestora['nombre'] ?? 'Administración de Fincas') ?></p>
      <?php if (!empty($gestora['plan_nombre'])): ?>
        <div class="plan-badge">
          <i class="fa-solid fa-bolt"></i>
          Plan <?= htmlspecialchars($gestora['plan_nombre']) ?>
        </div>
      <?php endif; ?>
    </div>

    <!-- Formulario -->
    <div class="login-body">
      <?php if (!empty($error)): ?>
        <div class="alert alert-error">
          <i class="fa-solid fa-circle-exclamation"></i>
          <?= htmlspecialchars($error) ?>
        </div>
      <?php endif; ?>
      <?php if (!empty($success)): ?>
        <div class="alert alert-success">
          <i class="fa-solid fa-circle-check"></i>
          <?= htmlspecialchars($success) ?>
        </div>
      <?php endif; ?>

      <form id="loginForm" action="/login" method="POST" novalidate>
        <?= $auth->csrfField() ?>
        <input type="hidden" name="redirect" value="<?= htmlspecialchars($_GET['redirect'] ?? '/') ?>">

        <div class="form-group">
          <label class="form-label" for="email">Correo electrónico</label>
          <div class="input-wrap">
            <i class="fa-solid fa-envelope input-icon"></i>
            <input class="form-control" type="email" id="email" name="email"
                   autocomplete="username email"
                   value="<?= htmlspecialchars($_POST['email'] ?? '') ?>"
                   placeholder="usuario@empresa.es" required>
          </div>
        </div>

        <div class="form-group">
          <label class="form-label" for="password">Contraseña</label>
          <div class="input-wrap">
            <i class="fa-solid fa-lock input-icon"></i>
            <input class="form-control" type="password" id="password" name="password"
                   autocomplete="current-password" placeholder="••••••••" required>
            <button type="button" class="toggle-pass" id="togglePass" aria-label="Mostrar contraseña">
              <i class="fa-solid fa-eye" id="eyeIcon"></i>
            </button>
          </div>
        </div>

        <div class="form-extras">
          <label class="checkbox-wrap">
            <input type="checkbox" name="remember" value="1">
            Mantener sesión
          </label>
          <a href="/recuperar-password" class="link-muted">¿Olvidaste la contraseña?</a>
        </div>

        <button class="btn-login" type="submit" id="btnLogin">
          <span class="btn-text"><i class="fa-solid fa-arrow-right-to-bracket"></i> Acceder</span>
          <span class="spinner"></span>
        </button>
      </form>
    </div>

    <div class="login-footer">
      Acceso restringido &middot;
      <a href="mailto:soporte@nanoserver.es">Soporte</a>
    </div>
  </div>
</div>

<div class="version-tag">ERP Fincas v<?= APP_VERSION ?></div>

<script>
// Toggle password visibility
document.getElementById('togglePass').addEventListener('click', function() {
  const inp = document.getElementById('password');
  const ico = document.getElementById('eyeIcon');
  if (inp.type === 'password') {
    inp.type = 'text';
    ico.className = 'fa-solid fa-eye-slash';
  } else {
    inp.type = 'password';
    ico.className = 'fa-solid fa-eye';
  }
});

// Loading state on submit
document.getElementById('loginForm').addEventListener('submit', function() {
  document.getElementById('btnLogin').classList.add('loading');
});
</script>
</body>
</html>

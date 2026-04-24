<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Recuperar contraseña — <?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<style>
:root {
  --c-primary:   <?= htmlspecialchars($gestora['color_primario']   ?? '#1e40af') ?>;
  --c-secondary: <?= htmlspecialchars($gestora['color_secundario'] ?? '#0f172a') ?>;
}
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Sora', sans-serif; background: linear-gradient(135deg, var(--c-primary) 0%, var(--c-secondary) 100%);
       display: grid; place-items: center; min-height: 100vh; padding: 1rem; }
.card {
  background: #fff; border-radius: 16px; width: 100%; max-width: 400px;
  box-shadow: 0 24px 64px rgba(0,0,0,.15); overflow: hidden;
  animation: slideUp .4s cubic-bezier(.22,.68,0,1.2) both;
}
@keyframes slideUp { from { opacity:0; transform:translateY(24px); } to { opacity:1; transform:translateY(0); } }
.card-head { background: linear-gradient(135deg, var(--c-primary), var(--c-secondary));
             padding: 2rem; text-align: center; }
.card-head i { font-size: 2.5rem; color: rgba(255,255,255,.9); }
.card-head h1 { font-size: 1.25rem; color: #fff; margin-top: .75rem; }
.card-head p { font-size: .82rem; color: rgba(255,255,255,.7); margin-top: .25rem; }
.card-body { padding: 1.75rem; }
.alert { padding: .7rem .9rem; border-radius: 8px; font-size: .83rem; margin-bottom: 1rem;
         display: flex; gap: .5rem; }
.alert-success { background: #f0fdf4; color: #16a34a; border: 1px solid #bbf7d0; }
.alert-error   { background: #fef2f2; color: #dc2626; border: 1px solid #fecaca; }
.form-group { margin-bottom: 1.1rem; }
.form-label { display: block; font-size: .78rem; font-weight: 700; text-transform: uppercase;
              letter-spacing: .05em; color: #64748b; margin-bottom: .4rem; }
.form-control {
  width: 100%; padding: .65rem .85rem;
  border: 1.5px solid #e2e8f0; border-radius: 9px;
  font-family: 'Sora', sans-serif; font-size: .9rem; outline: none;
  transition: border-color .15s, box-shadow .15s;
}
.form-control:focus {
  border-color: var(--c-primary);
  box-shadow: 0 0 0 3px color-mix(in srgb, var(--c-primary) 15%, transparent);
}
.btn-submit {
  width: 100%; padding: .85rem; border: none; border-radius: 9px; cursor: pointer;
  background: linear-gradient(135deg, var(--c-primary), var(--c-secondary));
  color: #fff; font-family: 'Sora',sans-serif; font-size: .95rem; font-weight: 700;
  transition: opacity .2s;
}
.btn-submit:hover { opacity: .88; }
.card-footer { padding: .9rem 1.75rem 1.5rem; text-align: center; font-size: .82rem; color: #64748b; }
.card-footer a { color: var(--c-primary); font-weight: 600; }
</style>
</head>
<body>
<div class="card">
  <div class="card-head">
    <i class="fa-solid fa-key"></i>
    <h1>Recuperar contraseña</h1>
    <p>Introduce tu email para recibir el enlace de recuperación</p>
  </div>

  <div class="card-body">
    <?php $flash = getFlash(); foreach ($flash as $f): ?>
      <div class="alert alert-<?= $f['type'] ?>">
        <i class="fa-solid <?= $f['type']==='success'?'fa-circle-check':'fa-circle-exclamation' ?>"></i>
        <?= htmlspecialchars($f['message']) ?>
      </div>
    <?php endforeach; ?>

    <form action="/recuperar-password" method="POST" novalidate>
      <?= $auth->csrfField() ?>
      <div class="form-group">
        <label class="form-label" for="email">Correo electrónico</label>
        <input class="form-control" type="email" id="email" name="email"
               placeholder="usuario@empresa.es" required autofocus>
      </div>
      <button type="submit" class="btn-submit">
        <i class="fa-solid fa-paper-plane"></i> Enviar enlace de recuperación
      </button>
    </form>
  </div>

  <div class="card-footer">
    <a href="/login"><i class="fa-solid fa-arrow-left"></i> Volver al login</a>
  </div>
</div>
</body>
</html>

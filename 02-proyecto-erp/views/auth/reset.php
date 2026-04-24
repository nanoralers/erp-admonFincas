<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Nueva contraseña — <?= htmlspecialchars($gestora['nombre_app'] ?? 'ERP Fincas') ?></title>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
<style>
:root{--c-primary:<?= htmlspecialchars($gestora['color_primario']??'#1e40af') ?>;
      --c-secondary:<?= htmlspecialchars($gestora['color_secundario']??'#0f172a') ?>;}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0;}
body{font-family:'Sora',sans-serif;background:linear-gradient(135deg,var(--c-primary),var(--c-secondary));
     display:grid;place-items:center;min-height:100vh;padding:1rem;}
.card{background:#fff;border-radius:16px;width:100%;max-width:400px;box-shadow:0 24px 64px rgba(0,0,0,.15);overflow:hidden;}
.card-head{background:linear-gradient(135deg,var(--c-primary),var(--c-secondary));padding:2rem;text-align:center;}
.card-head i{font-size:2.5rem;color:rgba(255,255,255,.9);}
.card-head h1{font-size:1.25rem;color:#fff;margin-top:.75rem;}
.card-body{padding:1.75rem;}
.alert{padding:.7rem .9rem;border-radius:8px;font-size:.83rem;margin-bottom:1rem;display:flex;gap:.5rem;}
.alert-error{background:#fef2f2;color:#dc2626;border:1px solid #fecaca;}
.form-group{margin-bottom:1.1rem;}
.form-label{display:block;font-size:.78rem;font-weight:700;text-transform:uppercase;
            letter-spacing:.05em;color:#64748b;margin-bottom:.4rem;}
.form-control{width:100%;padding:.65rem .85rem;border:1.5px solid #e2e8f0;border-radius:9px;
              font-family:'Sora',sans-serif;font-size:.9rem;outline:none;}
.form-control:focus{border-color:var(--c-primary);}
.btn-submit{width:100%;padding:.85rem;border:none;border-radius:9px;cursor:pointer;
            background:linear-gradient(135deg,var(--c-primary),var(--c-secondary));
            color:#fff;font-family:'Sora',sans-serif;font-size:.95rem;font-weight:700;}
.card-footer{padding:.9rem 1.75rem 1.5rem;text-align:center;font-size:.82rem;color:#64748b;}
.card-footer a{color:var(--c-primary);font-weight:600;}
</style>
</head>
<body>
<div class="card">
  <div class="card-head">
    <i class="fa-solid fa-lock"></i>
    <h1>Nueva contraseña</h1>
  </div>
  <div class="card-body">
    <?php $flash = getFlash(); foreach ($flash as $f): ?>
      <div class="alert alert-error"><i class="fa-solid fa-circle-exclamation"></i><?= htmlspecialchars($f['message']) ?></div>
    <?php endforeach; ?>
    <form action="/reset-password/<?= htmlspecialchars($token) ?>" method="POST">
      <?= $auth->csrfField() ?>
      <div class="form-group">
        <label class="form-label">Nueva contraseña (mín. 8 caracteres)</label>
        <input class="form-control" type="password" name="password" required minlength="8" autofocus>
      </div>
      <div class="form-group">
        <label class="form-label">Confirmar contraseña</label>
        <input class="form-control" type="password" name="password_confirm" required>
      </div>
      <button type="submit" class="btn-submit">Establecer nueva contraseña</button>
    </form>
  </div>
  <div class="card-footer"><a href="/login">← Volver al login</a></div>
</div>
</body>
</html>

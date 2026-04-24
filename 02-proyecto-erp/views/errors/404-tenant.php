<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gestora no encontrada</title>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@600;700&display=swap" rel="stylesheet">
<style>*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:'Sora',sans-serif;background:linear-gradient(135deg,#1e40af,#0f172a);
color:#fff;display:grid;place-items:center;min-height:100vh;text-align:center;padding:1.5rem;}
h1{font-size:2rem;margin-bottom:.5rem;}
p{opacity:.8;margin-bottom:2rem;}
code{background:rgba(255,255,255,.1);padding:.25rem .6rem;border-radius:5px;font-family:monospace;}
.btn{display:inline-block;padding:.75rem 2rem;border-radius:10px;
background:rgba(255,255,255,.15);border:1px solid rgba(255,255,255,.3);
color:#fff;text-decoration:none;font-weight:600;}
</style>
</head>
<body>
<div>
  <h1>Gestora no encontrada</h1>
  <p>El subdominio <code><?= htmlspecialchars($_SERVER['HTTP_HOST'] ?? '') ?></code> no corresponde a ninguna gestora activa.</p>
  <a href="https://<?= htmlspecialchars(BASE_DOMAIN ?? 'nanoserver.es') ?>" class="btn">Ir al inicio</a>
</div>
</body>
</html>

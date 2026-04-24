<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>404 - Página no encontrada</title>
<link href="https://fonts.googleapis.com/css2?family=Sora:wght@600;700&display=swap" rel="stylesheet">
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: 'Sora', sans-serif;
  background: linear-gradient(135deg, #1e40af 0%, #0f172a 100%);
  color: #fff; display: grid; place-items: center;
  min-height: 100vh; text-align: center; padding: 1rem;
}
.error-box { max-width: 500px; }
.error-code {
  font-size: 8rem; font-weight: 700; line-height: 1;
  background: linear-gradient(135deg, #38bdf8, #818cf8);
  -webkit-background-clip: text; background-clip: text;
  -webkit-text-fill-color: transparent;
  margin-bottom: 1rem;
}
h1 { font-size: 1.75rem; margin-bottom: .75rem; }
p { opacity: .85; font-size: 1rem; line-height: 1.6; margin-bottom: 2rem; }
.btn {
  display: inline-flex; align-items: center; gap: .5rem;
  padding: .75rem 1.5rem; border-radius: 10px;
  background: rgba(255,255,255,.15); backdrop-filter: blur(10px);
  border: 1px solid rgba(255,255,255,.2);
  color: #fff; text-decoration: none; font-weight: 600;
  transition: all .2s;
}
.btn:hover { background: rgba(255,255,255,.25); transform: translateY(-2px); }
</style>
</head>
<body>
<div class="error-box">
  <div class="error-code">404</div>
  <h1>Página no encontrada</h1>
  <p>La página que buscas no existe o ha sido movida. Verifica la URL o vuelve al inicio.</p>
  <a href="/dashboard" class="btn">
    <svg width="16" height="16" fill="currentColor" viewBox="0 0 16 16">
      <path d="M8 0a8 8 0 1 0 0 16A8 8 0 0 0 8 0zm3.5 7.5a.5.5 0 0 1 0 1H5.707l2.147 2.146a.5.5 0 0 1-.708.708l-3-3a.5.5 0 0 1 0-.708l3-3a.5.5 0 1 1 .708.708L5.707 7.5H11.5z"/>
    </svg>
    Volver al inicio
  </a>
</div>
</body>
</html>

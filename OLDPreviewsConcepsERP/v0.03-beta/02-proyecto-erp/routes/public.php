<?php
/**
 * Rutas públicas - Landing / Marketing
 * Se carga cuando se accede al dominio base (nanoserver.es)
 */

$router->get('/', function() {
    ?>
    <!DOCTYPE html>
    <html lang="es">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ERP Fincas - Administración de Fincas Inteligente</title>
    <link href="https://fonts.googleapis.com/css2?family=Sora:wght@400;600;700&display=swap" rel="stylesheet">
    <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        font-family: 'Sora', sans-serif;
        background: linear-gradient(135deg, #1e40af 0%, #0f172a 100%);
        color: #fff; min-height: 100vh;
        display: grid; place-items: center; text-align: center; padding: 2rem;
    }
    .hero { max-width: 700px; }
    h1 { font-size: 3rem; margin-bottom: 1rem; line-height: 1.2; }
    h1 span { background: linear-gradient(135deg, #38bdf8, #818cf8);
              -webkit-background-clip: text; background-clip: text;
              -webkit-text-fill-color: transparent; }
    p { font-size: 1.15rem; opacity: .9; line-height: 1.6; margin-bottom: 2.5rem; }
    .buttons { display: flex; gap: 1rem; justify-content: center; flex-wrap: wrap; }
    .btn {
        padding: .85rem 2rem; border-radius: 10px; font-weight: 600;
        text-decoration: none; transition: all .2s;
        display: inline-flex; align-items: center; gap: .5rem;
    }
    .btn-primary {
        background: rgba(255,255,255,.95); color: #1e40af;
    }
    .btn-primary:hover { background: #fff; transform: translateY(-2px); }
    .btn-secondary {
        background: rgba(255,255,255,.1); border: 1px solid rgba(255,255,255,.3);
        color: #fff; backdrop-filter: blur(10px);
    }
    .btn-secondary:hover { background: rgba(255,255,255,.2); }
    .features {
        display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
        gap: 1.5rem; margin-top: 3rem;
    }
    .feature { padding: 1.5rem; border-radius: 12px;
               background: rgba(255,255,255,.08); backdrop-filter: blur(10px);
               border: 1px solid rgba(255,255,255,.1); }
    .feature h3 { font-size: 1rem; margin-bottom: .5rem; }
    .feature p { font-size: .85rem; opacity: .75; margin: 0; }
    </style>
    </head>
    <body>
    <div class="hero">
        <h1>Gestiona tus comunidades con <span>ERP Fincas</span></h1>
        <p>La plataforma modular todo-en-uno para administradores de fincas. Económica, mantenimiento, jurídica y gestión administrativa en un solo lugar.</p>
        <div class="buttons">
            <a href="https://admin.<?= BASE_DOMAIN ?>" class="btn btn-primary">
                Acceso Administradores
            </a>
            <a href="#demo" class="btn btn-secondary">
                Ver demo
            </a>
        </div>
        <div class="features">
            <div class="feature">
                <h3>📊 Económica</h3>
                <p>Presupuestos, recibos, remesas SEPA</p>
            </div>
            <div class="feature">
                <h3>🔧 Mantenimiento</h3>
                <p>Averías, obras, contratos</p>
            </div>
            <div class="feature">
                <h3>⚖️ Jurídica</h3>
                <p>Morosos, siniestros, documentación</p>
            </div>
            <div class="feature">
                <h3>📋 Administrativa</h3>
                <p>Juntas, actas, comunicaciones</p>
            </div>
        </div>
    </div>
    </body>
    </html>
    <?php
});

$router->get('/pricing', function() {
    echo '<h1>Planes y Precios</h1>';
    echo '<p>Próximamente...</p>';
});

$router->get('/demo', function() {
    header('Location: https://demo.' . BASE_DOMAIN . '/login');
    exit;
});

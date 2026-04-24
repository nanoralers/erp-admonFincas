<!-- Admin Dashboard -->
<div style="margin-bottom:1.5rem;display:flex;align-items:center;justify-content:space-between;">
  <div>
    <h2 style="font-size:1.25rem;font-weight:700;">Resumen del sistema</h2>
    <p style="color:var(--c-muted);font-size:.83rem;margin-top:.2rem;">
      <?= date('l, d \d\e F \d\e Y', time()) ?>
    </p>
  </div>
  <a href="/gestoras/nueva" class="btn btn-primary">
    <i class="fa-solid fa-plus"></i> Nueva Gestora
  </a>
</div>

<!-- KPIs -->
<div class="stats-grid">
  <div class="stat-card">
    <div class="stat-icon" style="color:#38bdf8;">🏢</div>
    <div class="stat-val"><?= $stats['total_gestoras'] ?></div>
    <div class="stat-lbl">Gestoras activas</div>
  </div>
  <div class="stat-card">
    <div class="stat-icon" style="color:#a78bfa;">👤</div>
    <div class="stat-val"><?= $stats['total_usuarios'] ?></div>
    <div class="stat-lbl">Usuarios totales</div>
  </div>
  <div class="stat-card">
    <div class="stat-icon" style="color:#34d399;">🏘️</div>
    <div class="stat-val"><?= $stats['total_comunidades'] ?></div>
    <div class="stat-lbl">Comunidades</div>
  </div>
  <?php if ($stats['trial_expiring'] > 0): ?>
  <div class="stat-card" style="border-color:rgba(251,191,36,.3);">
    <div class="stat-icon" style="color:#fbbf24;">⚠️</div>
    <div class="stat-val" style="color:#fbbf24;"><?= $stats['trial_expiring'] ?></div>
    <div class="stat-lbl">Trial expiran en 7 días</div>
  </div>
  <?php endif; ?>
  <?php if ($stats['sub_expiring'] > 0): ?>
  <div class="stat-card" style="border-color:rgba(248,113,113,.3);">
    <div class="stat-icon" style="color:#f87171;">🔔</div>
    <div class="stat-val" style="color:#f87171;"><?= $stats['sub_expiring'] ?></div>
    <div class="stat-lbl">Suscripciones expiran en 30 días</div>
  </div>
  <?php endif; ?>
</div>

<!-- Planes en uso -->
<div style="display:grid;grid-template-columns:1fr 1fr;gap:1.25rem;">

  <div class="card">
    <div class="card-header">
      <span class="card-title"><i class="fa-solid fa-boxes-stacked"></i> Distribución por plan</span>
    </div>
    <div style="padding:.5rem 0;">
      <?php foreach ($planes as $plan): ?>
        <div style="display:flex;align-items:center;justify-content:space-between;padding:.6rem 1.25rem;border-bottom:1px solid var(--c-border);">
          <div style="display:flex;align-items:center;gap:.6rem;">
            <span style="width:10px;height:10px;border-radius:50%;background:<?= htmlspecialchars($plan['color_badge']) ?>;display:inline-block;flex-shrink:0;"></span>
            <span style="font-size:.83rem;font-weight:600;"><?= htmlspecialchars($plan['nombre']) ?></span>
            <span style="font-size:.75rem;color:var(--c-muted);">
              <?= $plan['precio_mes'] > 0 ? number_format($plan['precio_mes'],0).'€/mes' : 'Personalizado' ?>
            </span>
          </div>
          <span style="font-size:1.1rem;font-weight:800;"><?= $plan['gestoras_en_plan'] ?></span>
        </div>
      <?php endforeach; ?>
    </div>
  </div>

  <div class="card">
    <div class="card-header">
      <span class="card-title"><i class="fa-solid fa-scroll"></i> Última actividad</span>
      <a href="/logs/audit" class="btn btn-secondary btn-sm">Ver todo</a>
    </div>
    <div style="max-height:280px;overflow-y:auto;">
      <?php if (empty($actividad)): ?>
        <p style="padding:1rem;text-align:center;color:var(--c-muted);font-size:.83rem;">Sin actividad registrada</p>
      <?php else: ?>
        <?php foreach ($actividad as $log): ?>
          <div style="padding:.6rem 1.25rem;border-bottom:1px solid var(--c-border);display:flex;gap:.75rem;">
            <div style="flex:1;min-width:0;">
              <div style="font-size:.8rem;font-weight:600;"><?= htmlspecialchars($log['accion']) ?></div>
              <div style="font-size:.72rem;color:var(--c-muted);">
                <?= htmlspecialchars($log['gestora_nombre'] ?? 'Sistema') ?> ·
                <?= htmlspecialchars($log['usuario_email'] ?? '') ?>
              </div>
            </div>
            <div style="font-size:.7rem;color:var(--c-muted);white-space:nowrap;">
              <?= timeAgo($log['created_at']) ?>
            </div>
          </div>
        <?php endforeach; ?>
      <?php endif; ?>
    </div>
  </div>

</div>

<!-- Gestoras recientes -->
<div class="card" style="margin-top:1.25rem;">
  <div class="card-header">
    <span class="card-title"><i class="fa-solid fa-building"></i> Últimas gestoras registradas</span>
    <a href="/gestoras" class="btn btn-secondary btn-sm">Ver todas</a>
  </div>
  <div class="table-wrap">
    <table class="table">
      <thead><tr>
        <th>Gestora</th><th>Subdominio</th><th>Plan</th>
        <th>Comunidades</th><th>Estado</th><th>Registrada</th>
      </tr></thead>
      <tbody>
        <?php if (empty($gestoras_recientes)): ?>
          <tr><td colspan="6" style="text-align:center;padding:2rem;color:var(--c-muted);">
            Sin gestoras aún — <a href="/gestoras/nueva">Crear la primera</a>
          </td></tr>
        <?php else: ?>
          <?php foreach ($gestoras_recientes as $g): ?>
            <tr onclick="window.location='/gestoras/<?= $g['id'] ?>'" style="cursor:pointer;">
              <td>
                <strong><?= htmlspecialchars($g['nombre']) ?></strong><br>
                <small style="color:var(--c-muted);"><?= htmlspecialchars($g['email_contacto']) ?></small>
              </td>
              <td><code style="background:var(--c-surface2);padding:.1rem .4rem;border-radius:4px;font-size:.78rem;">
                <?= htmlspecialchars($g['subdominio']) ?>.nanoserver.es
              </code></td>
              <td><span class="badge badge-plan" style="background:<?= htmlspecialchars($g['color_badge']) ?>20;color:<?= htmlspecialchars($g['color_badge']) ?>;">
                <?= htmlspecialchars($g['plan_nombre']) ?>
              </span></td>
              <td style="text-align:center;"><?= $g['comunidades'] ?></td>
              <td><span class="badge <?= $g['activo'] ? 'badge-active' : 'badge-inactive' ?>">
                <?= $g['activo'] ? '● Activa' : '○ Inactiva' ?>
              </span></td>
              <td style="font-size:.78rem;color:var(--c-muted);">
                <?= formatDate($g['created_at']) ?>
              </td>
            </tr>
          <?php endforeach; ?>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

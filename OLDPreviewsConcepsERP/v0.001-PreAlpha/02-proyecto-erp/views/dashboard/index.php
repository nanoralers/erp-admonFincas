<!-- Dashboard principal -->
<div class="page-header">
  <div class="page-title-group">
    <h1 class="page-title">Bienvenido, <?= htmlspecialchars($currentUser['nombre']) ?></h1>
    <p class="page-subtitle">
      <?= $stats['comunidades'] ?> comunidades · 
      <?= $stats['propietarios'] ?> propietarios
      <?php if (!empty($_SESSION['comunidad_activa'])): ?>
        · Viendo: <?= htmlspecialchars($comunidades[array_search($_SESSION['comunidad_activa'], array_column($comunidades, 'id'))]['nombre'] ?? 'Todas') ?>
      <?php endif; ?>
    </p>
  </div>
  <div class="page-actions">
    <button class="btn btn-secondary btn-sm" onclick="window.print()">
      <i class="fa-solid fa-print"></i> Imprimir
    </button>
  </div>
</div>

<!-- Avisos importantes -->
<?php if (!empty($avisos)): ?>
<div style="margin-bottom: 1.5rem;">
  <?php foreach (array_slice($avisos, 0, 2) as $aviso): ?>
    <div class="flash flash-<?= $aviso['tipo'] ?? 'info' ?>" role="alert">
      <i class="fa-solid <?= $aviso['icono'] ?? 'fa-circle-info' ?>"></i>
      <?= htmlspecialchars($aviso['mensaje']) ?>
      <span style="margin-left: auto; font-size: .78rem; opacity: .7;">
        <?= date('d/m/Y', strtotime($aviso['fecha'])) ?>
      </span>
    </div>
  <?php endforeach; ?>
</div>
<?php endif; ?>

<!-- KPI Stats Grid -->
<div class="stats-grid">
  <!-- Comunidades -->
  <div class="stat-card" style="--mod-color:#0ea5e9">
    <div class="stat-icon"><i class="fa-solid fa-city"></i></div>
    <div class="stat-info">
      <div class="stat-value"><?= $stats['comunidades'] ?></div>
      <div class="stat-label">Comunidades activas</div>
    </div>
  </div>

  <!-- Propietarios -->
  <div class="stat-card" style="--mod-color:#6366f1">
    <div class="stat-icon"><i class="fa-solid fa-users"></i></div>
    <div class="stat-info">
      <div class="stat-value"><?= $stats['propietarios'] ?></div>
      <div class="stat-label">Propietarios</div>
    </div>
  </div>

  <?php if ($auth->can('economica')): ?>
  <!-- Recibos pendientes -->
  <div class="stat-card" style="--mod-color:#10b981">
    <div class="stat-icon"><i class="fa-solid fa-receipt"></i></div>
    <div class="stat-info">
      <div class="stat-value"><?= $stats['recibos_pendientes'] ?></div>
      <div class="stat-label">Recibos pendientes</div>
      <div class="stat-change down">
        <i class="fa-solid fa-arrow-down"></i>
        <?= number_format($stats['importe_pendiente'] ?? 0, 2) ?> €
      </div>
    </div>
  </div>
  <?php endif; ?>

  <?php if ($auth->can('mantenimiento')): ?>
  <!-- Averías abiertas -->
  <div class="stat-card" style="--mod-color:#f59e0b">
    <div class="stat-icon"><i class="fa-solid fa-triangle-exclamation"></i></div>
    <div class="stat-info">
      <div class="stat-value"><?= $stats['averias_abiertas'] ?? 0 ?></div>
      <div class="stat-label">Averías abiertas</div>
    </div>
  </div>
  <?php endif; ?>

  <?php if ($auth->can('juridica')): ?>
  <!-- Morosos -->
  <div class="stat-card" style="--mod-color:#ef4444">
    <div class="stat-icon"><i class="fa-solid fa-gavel"></i></div>
    <div class="stat-info">
      <div class="stat-value"><?= $stats['morosos'] ?? 0 ?></div>
      <div class="stat-label">Morosos activos</div>
      <div class="stat-change down">
        <i class="fa-solid fa-euro-sign"></i>
        <?= number_format($stats['deuda_morosos'] ?? 0, 0) ?>
      </div>
    </div>
  </div>
  <?php endif; ?>
</div>

<!-- Grid principal -->
<div class="grid-2" style="margin-top: 2rem;">
  
  <!-- Actividad reciente -->
  <div class="card">
    <div class="card-header">
      <h3 class="card-title">
        <i class="fa-solid fa-clock-rotate-left"></i>
        Actividad reciente
      </h3>
    </div>
    <div class="card-body" style="padding: 0;">
      <?php if (empty($actividades)): ?>
        <div class="empty-state">
          <div class="empty-state-icon"><i class="fa-solid fa-inbox"></i></div>
          <p>No hay actividad reciente</p>
        </div>
      <?php else: ?>
        <div class="timeline">
          <?php foreach ($actividades as $act): ?>
            <div class="timeline-item">
              <div class="timeline-dot" style="border-color: <?= $act['color'] ?>; color: <?= $act['color'] ?>;">
                <i class="fa-solid <?= $act['icono'] ?>"></i>
              </div>
              <div class="timeline-content">
                <div class="timeline-title"><?= htmlspecialchars($act['titulo']) ?></div>
                <div class="timeline-time"><?= htmlspecialchars($act['subtitulo']) ?></div>
                <div class="timeline-time"><?= timeAgo($act['fecha']) ?></div>
              </div>
            </div>
          <?php endforeach; ?>
        </div>
      <?php endif; ?>
    </div>
  </div>

  <!-- Tareas pendientes -->
  <div class="card">
    <div class="card-header">
      <h3 class="card-title">
        <i class="fa-solid fa-list-check"></i>
        Tareas pendientes
      </h3>
      <a href="/tareas" class="btn btn-ghost btn-sm">Ver todas</a>
    </div>
    <div class="card-body" style="padding: 0;">
      <?php if (empty($tareas)): ?>
        <div class="empty-state">
          <div class="empty-state-icon"><i class="fa-solid fa-check"></i></div>
          <h3>Todo al día</h3>
          <p>No hay tareas pendientes</p>
        </div>
      <?php else: ?>
        <div class="table-wrap">
          <table class="table">
            <tbody>
              <?php foreach ($tareas as $t): ?>
                <tr>
                  <td style="width: 32px;">
                    <input type="checkbox" onchange="completarTarea(<?= $t['id'] ?>)">
                  </td>
                  <td>
                    <strong><?= htmlspecialchars($t['titulo']) ?></strong>
                    <?php if ($t['descripcion']): ?>
                      <br><small style="color: var(--c-muted);"><?= htmlspecialchars(mb_substr($t['descripcion'], 0, 60)) ?></small>
                    <?php endif; ?>
                  </td>
                  <td style="width: 100px;">
                    <?php
                    $prioColors = ['baja'=>'muted','normal'=>'info','alta'=>'warning','urgente'=>'danger'];
                    $color = $prioColors[$t['prioridad']] ?? 'muted';
                    ?>
                    <span class="badge badge-<?= $color ?>"><?= $t['prioridad'] ?></span>
                  </td>
                  <td style="width: 100px; text-align: right;">
                    <?php if ($t['fecha_limite']): ?>
                      <small style="color: var(--c-muted);">
                        <?= date('d/m/Y', strtotime($t['fecha_limite'])) ?>
                      </small>
                    <?php endif; ?>
                  </td>
                </tr>
              <?php endforeach; ?>
            </tbody>
          </table>
        </div>
      <?php endif; ?>
    </div>
  </div>

  <!-- Próximas juntas -->
  <?php if ($auth->can('admin') && !empty($juntas)): ?>
  <div class="card">
    <div class="card-header">
      <h3 class="card-title">
        <i class="fa-solid fa-people-group"></i>
        Próximas juntas
      </h3>
      <a href="/juntas" class="btn btn-ghost btn-sm">Ver todas</a>
    </div>
    <div class="card-body" style="padding: 0;">
      <div class="table-wrap">
        <table class="table">
          <tbody>
            <?php foreach ($juntas as $j): ?>
              <tr onclick="window.location='/juntas/<?= $j['id'] ?>'" style="cursor: pointer;">
                <td>
                  <strong><?= htmlspecialchars($j['titulo']) ?></strong><br>
                  <small style="color: var(--c-muted);"><?= htmlspecialchars($j['comunidad_nombre']) ?></small>
                </td>
                <td style="width: 140px; text-align: right;">
                  <div style="font-size: .83rem;">
                    <?= date('d M Y', strtotime($j['fecha_primera'])) ?><br>
                    <small style="color: var(--c-muted);"><?= date('H:i', strtotime($j['fecha_primera'])) ?>h</small>
                  </div>
                </td>
                <td style="width: 40px;">
                  <i class="fa-solid fa-chevron-right" style="color: var(--c-muted); font-size: .8rem;"></i>
                </td>
              </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
  <?php endif; ?>

</div>

<script>
function completarTarea(id) {
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
  fetch(`/tareas/${id}/completar`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrf
    }
  }).then(() => window.location.reload());
}

function timeAgo(dateStr) {
  const now = new Date();
  const date = new Date(dateStr);
  const diff = Math.floor((now - date) / 1000);
  if (diff < 60) return 'Ahora mismo';
  if (diff < 3600) return `Hace ${Math.floor(diff / 60)} min`;
  if (diff < 86400) return `Hace ${Math.floor(diff / 3600)} h`;
  if (diff < 604800) return `Hace ${Math.floor(diff / 86400)} días`;
  return date.toLocaleDateString('es-ES');
}
</script>

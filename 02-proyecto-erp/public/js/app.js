/**
 * ERP FINCAS - Main JavaScript
 */

(function() {
  'use strict';

  // ═══════════════════════════════════════════════════════════════════════
  //  SIDEBAR & MOBILE MENU
  // ═══════════════════════════════════════════════════════════════════════
  const sidebar = document.getElementById('sidebar');
  const sidebarToggle = document.getElementById('sidebarToggle');
  const sidebarClose = document.getElementById('sidebarClose');
  const sidebarOverlay = document.getElementById('sidebarOverlay');

  function openSidebar() {
    sidebar?.classList.add('open');
    sidebarOverlay?.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  function closeSidebar() {
    sidebar?.classList.remove('open');
    sidebarOverlay?.classList.remove('active');
    document.body.style.overflow = '';
  }

  sidebarToggle?.addEventListener('click', openSidebar);
  sidebarClose?.addEventListener('click', closeSidebar);
  sidebarOverlay?.addEventListener('click', closeSidebar);

  // ═══════════════════════════════════════════════════════════════════════
  //  USER MENU DROPDOWN
  // ═══════════════════════════════════════════════════════════════════════
  const userMenuBtn = document.getElementById('userMenuBtn');
  const userMenu = document.getElementById('userMenu');

  userMenuBtn?.addEventListener('click', (e) => {
    e.stopPropagation();
    userMenu?.classList.toggle('open');
    notifPanel?.classList.remove('open');
  });

  document.addEventListener('click', (e) => {
    if (userMenu && !userMenu.contains(e.target) && e.target !== userMenuBtn) {
      userMenu.classList.remove('open');
    }
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════
  const notifBtn = document.getElementById('notifBtn');
  const notifPanel = document.getElementById('notifPanel');
  const notifDot = document.getElementById('notifDot');
  const notifList = document.getElementById('notifList');

  notifBtn?.addEventListener('click', (e) => {
    e.stopPropagation();
    notifPanel?.classList.toggle('open');
    userMenu?.classList.remove('open');
    if (notifPanel?.classList.contains('open')) {
      loadNotifications();
    }
  });

  document.addEventListener('click', (e) => {
    if (notifPanel && !notifPanel.contains(e.target) && e.target !== notifBtn) {
      notifPanel.classList.remove('open');
    }
  });

  async function loadNotifications() {
    if (!notifList) return;
    notifList.innerHTML = '<div class="notif-empty">Cargando...</div>';
    
    try {
      const res = await fetch('/api/notificaciones', {
        headers: { 'X-Requested-With': 'XMLHttpRequest' }
      });
      const data = await res.json();
      
      if (!data.ok || !data.notificaciones?.length) {
        notifList.innerHTML = '<div class="notif-empty">No hay notificaciones</div>';
        notifDot.style.display = 'none';
        return;
      }

      const unread = data.notificaciones.filter(n => !n.leida).length;
      notifDot.style.display = unread > 0 ? 'block' : 'none';

      notifList.innerHTML = data.notificaciones.map(n => `
        <div class="notif-item ${n.leida ? '' : 'unread'}" onclick="markNotifRead(${n.id}, '${n.url || '#'}')">
          <div class="notif-item-icon">
            <i class="fa-solid ${getNotifIcon(n.tipo)}"></i>
          </div>
          <div class="notif-item-body">
            <div class="notif-item-title">${escapeHtml(n.titulo)}</div>
            <div class="notif-item-text">${escapeHtml(n.mensaje || '')}</div>
            <div class="notif-item-time">${timeAgo(n.created_at)}</div>
          </div>
        </div>
      `).join('');
    } catch (err) {
      console.error('Error loading notifications:', err);
      notifList.innerHTML = '<div class="notif-empty">Error al cargar</div>';
    }
  }

  window.markNotifRead = async function(id, url) {
    try {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
      await fetch(`/api/notificaciones/${id}/leer`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      if (url && url !== '#') {
        window.location.href = url;
      } else {
        loadNotifications();
      }
    } catch (err) {
      console.error('Error marking notification as read:', err);
    }
  };

  window.markAllRead = async function() {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
    try {
      await fetch('/api/notificaciones/marcar-todas', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrf,
          'X-Requested-With': 'XMLHttpRequest'
        }
      });
      loadNotifications();
    } catch (err) {
      console.error('Error marking all as read:', err);
    }
  };

  function getNotifIcon(tipo) {
    const icons = {
      recibo: 'fa-receipt',
      averia: 'fa-triangle-exclamation',
      junta: 'fa-people-group',
      moroso: 'fa-gavel',
      obra: 'fa-helmet-safety',
      default: 'fa-bell'
    };
    return icons[tipo] || icons.default;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  GLOBAL SEARCH
  // ═══════════════════════════════════════════════════════════════════════
  const searchBtn = document.getElementById('searchBtn');
  const searchModal = document.getElementById('searchModal');
  const globalSearch = document.getElementById('globalSearch');
  const searchResults = document.getElementById('searchResults');

  searchBtn?.addEventListener('click', () => {
    searchModal?.classList.add('open');
    setTimeout(() => globalSearch?.focus(), 100);
  });

  document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault();
      searchModal?.classList.add('open');
      setTimeout(() => globalSearch?.focus(), 100);
    }
    if (e.key === 'Escape' && searchModal?.classList.contains('open')) {
      searchModal.classList.remove('open');
      globalSearch.value = '';
      searchResults.innerHTML = '<div class="search-hint">Escribe para buscar en todo el sistema</div>';
    }
  });

  searchModal?.addEventListener('click', (e) => {
    if (e.target === searchModal) {
      searchModal.classList.remove('open');
      globalSearch.value = '';
      searchResults.innerHTML = '<div class="search-hint">Escribe para buscar en todo el sistema</div>';
    }
  });

  let searchTimeout;
  globalSearch?.addEventListener('input', (e) => {
    clearTimeout(searchTimeout);
    const query = e.target.value.trim();
    
    if (query.length < 2) {
      searchResults.innerHTML = '<div class="search-hint">Escribe al menos 2 caracteres</div>';
      return;
    }

    searchResults.innerHTML = '<div class="search-hint">Buscando...</div>';

    searchTimeout = setTimeout(async () => {
      try {
        const res = await fetch(`/api/buscar?q=${encodeURIComponent(query)}`, {
          headers: { 'X-Requested-With': 'XMLHttpRequest' }
        });
        const data = await res.json();
        
        if (!data.ok || !data.resultados?.length) {
          searchResults.innerHTML = '<div class="search-hint">No se encontraron resultados</div>';
          return;
        }

        // Group by type
        const grouped = {};
        data.resultados.forEach(r => {
          if (!grouped[r.tipo]) grouped[r.tipo] = [];
          grouped[r.tipo].push(r);
        });

        const labels = {
          comunidad: 'Comunidades',
          propietario: 'Propietarios',
          recibo: 'Recibos',
          averia: 'Averías',
          moroso: 'Morosos'
        };

        searchResults.innerHTML = Object.entries(grouped).map(([tipo, items]) => `
          <div class="search-group-label">${labels[tipo] || tipo}</div>
          ${items.map(item => `
            <a href="${escapeHtml(item.url)}" class="search-result-item">
              <div class="search-result-icon" style="background:${item.color || '#e2e8f0'};">
                <i class="fa-solid ${item.icon}" style="color:${item.iconColor || '#64748b'};"></i>
              </div>
              <div class="search-result-body">
                <div class="search-result-title">${highlight(escapeHtml(item.titulo), query)}</div>
                <div class="search-result-sub">${escapeHtml(item.subtitulo || '')}</div>
              </div>
            </a>
          `).join('')}
        `).join('');
      } catch (err) {
        console.error('Search error:', err);
        searchResults.innerHTML = '<div class="search-hint">Error en la búsqueda</div>';
      }
    }, 300);
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  COMUNIDAD SWITCHER
  // ═══════════════════════════════════════════════════════════════════════
  window.switchComunidad = function(id) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content;
    fetch('/api/cambiar-comunidad', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrf,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({ comunidad_id: id })
    }).then(() => {
      window.location.reload();
    });
  };

  // ═══════════════════════════════════════════════════════════════════════
  //  MODALS
  // ═══════════════════════════════════════════════════════════════════════
  window.openModal = function(id) {
    const modal = document.getElementById(id);
    modal?.classList.add('open');
    document.body.style.overflow = 'hidden';
  };

  window.closeModal = function(id) {
    const modal = document.getElementById(id);
    modal?.classList.remove('open');
    document.body.style.overflow = '';
  };

  document.querySelectorAll('.modal-overlay').forEach(overlay => {
    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) {
        overlay.classList.remove('open');
        document.body.style.overflow = '';
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  TABS
  // ═══════════════════════════════════════════════════════════════════════
  window.switchTab = function(groupName, tabId) {
    document.querySelectorAll(`[data-tab-group="${groupName}"]`).forEach(btn => {
      btn.classList.remove('active');
    });
    document.querySelectorAll(`[data-panel-group="${groupName}"]`).forEach(panel => {
      panel.classList.remove('active');
    });
    
    document.querySelector(`[data-tab-id="${tabId}"]`)?.classList.add('active');
    document.getElementById(tabId)?.classList.add('active');
  };

  // ═══════════════════════════════════════════════════════════════════════
  //  UTILS
  // ═══════════════════════════════════════════════════════════════════════
  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function highlight(text, query) {
    if (!query) return text;
    const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
    return text.replace(regex, '<mark style="background:#fef08a;font-weight:600;">$1</mark>');
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

  // ═══════════════════════════════════════════════════════════════════════
  //  CONFIRMATIONS
  // ═══════════════════════════════════════════════════════════════════════
  window.confirmAction = function(message, callback) {
    if (confirm(message)) {
      callback();
    }
  };

  // ═══════════════════════════════════════════════════════════════════════
  //  AUTO-REFRESH NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════
  if (notifBtn) {
    setInterval(() => {
      fetch('/api/notificaciones/count', {
        headers: { 'X-Requested-With': 'XMLHttpRequest' }
      })
      .then(r => r.json())
      .then(data => {
        if (data.ok && data.unread > 0) {
          notifDot.style.display = 'block';
        } else {
          notifDot.style.display = 'none';
        }
      })
      .catch(() => {});
    }, 30000); // cada 30 segundos
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  FORM VALIDATION HINTS
  // ═══════════════════════════════════════════════════════════════════════
  document.querySelectorAll('form[novalidate]').forEach(form => {
    form.addEventListener('submit', (e) => {
      const invalids = form.querySelectorAll(':invalid');
      if (invalids.length > 0) {
        e.preventDefault();
        invalids[0].focus();
        invalids[0].reportValidity();
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  //  DATATABLES HELPER (if using any)
  // ═══════════════════════════════════════════════════════════════════════
  window.initDataTable = function(tableId, options = {}) {
    // Placeholder for future DataTables.js integration
    console.log('DataTable init:', tableId, options);
  };

  // ═══════════════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════════════
  console.log('✓ ERP Fincas JS loaded');

})();

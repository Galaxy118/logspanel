// Mise à jour des statuts via le module centralisé ServerSync
function updateServerStatusFromData(servers) {
  Object.keys(servers).forEach(serverId => {
    const serverData = servers[serverId];
    const statusBadge = document.querySelector(`[data-server-id="${serverId}"] .status-badge`);
    if (statusBadge) {
      statusBadge.className = `status-badge ${serverData.status === 'online' ? 'status-online' : 'status-offline'}`;
      statusBadge.innerHTML = `<i class="fas fa-circle me-1"></i>${serverData.status === 'online' ? 'Online' : 'Offline'}`;
    }
  });
}

// Fallback pour quand ServerSync n'est pas disponible
function updateServerStatusLegacy() {
  fetch('/api/servers/status')
    .then(response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.json();
    })
    .then(data => updateServerStatusFromData(data))
    .catch(error => console.error('Erreur lors de la mise à jour du statut:', error));
}

// SÉCURITÉ: Récupère le token CSRF depuis le formulaire ou les meta tags
function getCsrfToken() {
  const csrfInput = document.querySelector('input[name="csrf_token"]');
  if (csrfInput) return csrfInput.value;
  const csrfMeta = document.querySelector('meta[name="csrf-token"]');
  if (csrfMeta) return csrfMeta.content;
  return '';
}

// Gestion du formulaire de création de serveur
document.addEventListener('DOMContentLoaded', function() {
  // Utiliser ServerSync si disponible
  if (typeof ServerSync !== 'undefined') {
    ServerSync.subscribe(function(servers) {
      updateServerStatusFromData(servers);
    });
    console.log('[admin_servers] Utilisation de ServerSync pour la synchronisation');
  } else {
    // Fallback: mode legacy
    console.warn('[admin_servers] ServerSync non disponible, mode legacy activé');
    setInterval(updateServerStatusLegacy, 30000);
    setTimeout(updateServerStatusLegacy, 1000);
  }

  const createServerForm = document.getElementById('createServerForm');
  if (createServerForm) {
    createServerForm.addEventListener('submit', function(e) {
      e.preventDefault();
      
      const formData = new FormData(this);
      
      fetch('/admin/servers/create', {
        method: 'POST',
        headers: {
          'X-CSRFToken': getCsrfToken()
        },
        body: formData
      })
      .then(response => response.json())
      .then(async result => {
        if (result.success) {
          // Forcer un rafraîchissement complet après création
          if (typeof ServerSync !== 'undefined') {
            await ServerSync.forceRefresh();
          }
          await showSuccess('Serveur créé avec succès!', '✅ Création réussie');
          location.reload();
        } else {
          await showError(result.error, '❌ Erreur de création');
        }
      })
      .catch(async error => {
        console.error('Erreur:', error);
        await showError('Erreur lors de la création du serveur', '❌ Erreur réseau');
      });
    });
  }

  // Gestion de la suppression de serveur
  let serverToDelete = null;
  
  window.confirmDeleteServer = function(serverId, serverName) {
    serverToDelete = serverId;
    document.getElementById('deleteServerName').textContent = serverName;
    const deleteModal = new bootstrap.Modal(document.getElementById('deleteServerModal'));
    deleteModal.show();
  };
  
  const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
  if (confirmDeleteBtn) {
    confirmDeleteBtn.addEventListener('click', function() {
      if (serverToDelete) {
        fetch(`/admin/servers/${serverToDelete}/delete`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': getCsrfToken()
          }
        })
        .then(response => response.json())
        .then(async result => {
          if (result.success) {
            // Forcer un rafraîchissement complet après suppression
            if (typeof ServerSync !== 'undefined') {
              await ServerSync.forceRefresh();
            }
            await showSuccess('Serveur supprimé avec succès!', '✅ Suppression réussie');
            location.reload();
          } else {
            await showError(result.error, '❌ Erreur de suppression');
          }
        })
        .catch(async error => {
          console.error('Erreur:', error);
          await showError('Erreur lors de la suppression du serveur', '❌ Erreur réseau');
        });
      }
    });
  }
});
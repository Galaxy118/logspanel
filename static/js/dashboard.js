document.addEventListener('DOMContentLoaded', () => {
  const trigger = document.getElementById('category-trigger');
  const popup = document.getElementById('category-popup');
  const searchInput = document.getElementById('category-search');
  const categoryList = document.getElementById('category-list');
  const form = document.getElementById('filter-form');
  const dataEl = document.getElementById('dashboard-data');
  const logoutBtn = document.getElementById('logout-btn');

  let categories = [];
  try {
    if (dataEl && dataEl.dataset.categories) {
      categories = JSON.parse(dataEl.dataset.categories);
    }
  } catch (e) {
    categories = [];
  }

  // Gestion de la déconnexion
  if (logoutBtn && dataEl && dataEl.dataset.logoutUrl) {
    logoutBtn.addEventListener('click', () => {
      if (confirm('Êtes-vous sûr de vouloir vous déconnecter ?')) {
        window.location.href = dataEl.dataset.logoutUrl;
      }
    });
  }

  // Gestion des catégories si les éléments existent
  if (trigger && popup && searchInput && categoryList && form) {
    function renderCategories(filter = "") {
      categoryList.innerHTML = '';
      categories.forEach(cat => {
        if (cat.toLowerCase().includes(filter.toLowerCase())) {
          const item = document.createElement('div');
          item.textContent = cat;
          item.classList.add('category-item');
          item.addEventListener('click', () => {
            trigger.textContent = cat;
            popup.style.display = 'none';
            trigger.classList.remove('open');

            let input = form.querySelector('input[name="type"]');
            if (!input) {
              input = document.createElement('input');
              input.type = 'hidden';
              input.name = 'type';
              form.appendChild(input);
            }

            input.value = (cat === 'Tous') ? '' : cat;
            form.submit();
          });
          categoryList.appendChild(item);
        }
      });
    }

    trigger.addEventListener('click', () => {
      const isOpen = popup.style.display === 'block';
      popup.style.display = isOpen ? 'none' : 'block';
      trigger.classList.toggle('open', !isOpen);
      if (!isOpen) {
        searchInput.value = '';
        renderCategories();
        searchInput.focus();
      }
    });

    searchInput.addEventListener('input', () => {
      renderCategories(searchInput.value);
    });

    document.addEventListener('click', (e) => {
      if (!popup.contains(e.target) && !trigger.contains(e.target)) {
        popup.style.display = 'none';
        trigger.classList.remove('open');
      }
    });

    const urlParams = new URLSearchParams(window.location.search);
    let selectedCat = urlParams.get('type');
    selectedCat = selectedCat ? selectedCat.trim() : 'Tous';

    const matchedCategory = categories.find(cat => cat.toLowerCase() === selectedCat.toLowerCase());
    trigger.textContent = matchedCategory || 'Tous';
  }

  // Sidebar: clic sur types de logs
  const logTypeItems = document.querySelectorAll('.log-type-item');
  const currentParams = new URLSearchParams(window.location.search);
  const currentType = currentParams.get('type');

  logTypeItems.forEach(function(item) {
    const itemType = item.getAttribute('data-type');
    if ((currentType && itemType === currentType) || (!currentType && itemType === 'all')) {
      item.classList.add('active');
    }
    item.style.cursor = 'pointer';
    item.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      const logType = item.getAttribute('data-type');
      if (logType) {
        const params = new URLSearchParams(window.location.search);
        if (logType === 'all') {
          params.delete('type');
        } else {
          params.set('type', logType);
        }
        params.delete('page');
        window.location.href = window.location.pathname + '?' + params.toString();
      }
    });
  });

  // Barre de recherche des types de logs
  const logTypeSearchInput = document.getElementById('logTypeSearch');
  const logTypeNoResults = document.querySelector('.log-type-no-results');

  if (logTypeSearchInput) {
    logTypeSearchInput.addEventListener('input', function() {
      const searchTerm = this.value.toLowerCase().trim();
      let visibleCount = 0;

      logTypeItems.forEach(function(item) {
        const typeName = item.querySelector('.log-type-name');
        const typeText = typeName ? typeName.textContent.toLowerCase() : '';
        const dataType = item.getAttribute('data-type') || '';
        
        // Le type "all" (Tous) est toujours visible si le terme est vide
        if (dataType === 'all' && searchTerm === '') {
          item.classList.remove('hidden');
          visibleCount++;
        } else if (typeText.includes(searchTerm) || dataType.toLowerCase().includes(searchTerm)) {
          item.classList.remove('hidden');
          visibleCount++;
        } else {
          item.classList.add('hidden');
        }
      });

      // Afficher le message "Aucun résultat" si nécessaire
      if (logTypeNoResults) {
        if (visibleCount === 0) {
          logTypeNoResults.classList.add('visible');
        } else {
          logTypeNoResults.classList.remove('visible');
        }
      }
    });

    // Permettre de vider la recherche avec Escape
    logTypeSearchInput.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') {
        this.value = '';
        this.dispatchEvent(new Event('input'));
      }
    });
  }
});
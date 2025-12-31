# 🎨 Système de Modales Personnalisées

Remplace les `alert()` et `confirm()` natifs par des modales stylées au thème du site.

## 📦 Installation

Inclure dans votre HTML :

```html
<link rel="stylesheet" href="{{ url_for('static', filename='css/modal.css') }}?v={{ ASSET_VERSION }}">
<script src="{{ url_for('static', filename='js/modal.js') }}?v={{ ASSET_VERSION }}"></script>
```

## 🚀 Utilisation

### Alerte Simple

```javascript
await showAlert('Message', 'Titre', 'info');
// Types: 'success', 'error', 'warning', 'info'
```

### Confirmation

```javascript
const confirmed = await showConfirm(
    'Voulez-vous continuer ?',
    'Confirmation',
    {
        type: 'warning',
        confirmText: 'Oui',
        cancelText: 'Non',
        danger: false // true pour bouton rouge
    }
);

if (confirmed) {
    // L'utilisateur a confirmé
}
```

### Raccourcis

```javascript
// Succès (vert)
await showSuccess('Opération réussie !', 'Succès');

// Erreur (rouge)
await showError('Une erreur est survenue', 'Erreur');

// Avertissement (orange)
await showWarning('Attention !', 'Avertissement');
```

## 🎨 Personnalisation

Les modales utilisent les variables CSS du thème :
- `--bg-color`: Fond principal
- `--accent-color`: Couleur d'accent (#8D12AB)
- `--text-color`: Couleur du texte

## 📝 Exemples Complets

### Création avec confirmation de succès

```javascript
try {
    const response = await fetch('/api/create', {
        method: 'POST',
        body: formData
    });
    
    const data = await response.json();
    
    if (data.success) {
        await showSuccess('Élément créé avec succès !', '✅ Création réussie');
        location.reload();
    } else {
        await showError(data.error || 'Erreur inconnue', '❌ Erreur');
    }
} catch (error) {
    await showError('Erreur de connexion', '❌ Erreur réseau');
}
```

### Suppression avec double confirmation

```javascript
async function deleteItem(id, name) {
    const confirmed = await showConfirm(
        `Voulez-vous vraiment supprimer "${name}" ?`,
        '⚠️ Attention',
        { type: 'warning', danger: true }
    );
    
    if (!confirmed) return;
    
    const doubleConfirm = await showConfirm(
        'Cette action est irréversible.',
        '🗑️ Confirmation finale',
        { 
            type: 'error',
            confirmText: 'Supprimer',
            danger: true
        }
    );
    
    if (doubleConfirm) {
        // Effectuer la suppression
    }
}
```

## 🎯 Fonctionnalités

- ✅ Fermeture avec Échap
- ✅ Animations fluides
- ✅ Responsive mobile
- ✅ Thème cohérent avec le site
- ✅ Promesses natives (async/await)
- ✅ Prévention XSS automatique

## 🔒 Sécurité

Le texte est automatiquement échappé pour éviter les injections XSS :

```javascript
await showAlert('<script>alert("hack")</script>', 'Test');
// Affiche littéralement le texte, ne l'exécute pas
```

/**
 * SYSTÈME DE MODALES PERSONNALISÉES
 * Remplace les alert() et confirm() natifs par des modales stylées
 */

class CustomModal {
    constructor() {
        this.overlay = null;
        this.modal = null;
        this.resolvePromise = null;
    }

    /**
     * Crée la structure HTML de la modale
     */
    createModal() {
        // Supprimer toute modale existante
        this.destroy();

        // Créer l'overlay
        this.overlay = document.createElement('div');
        this.overlay.className = 'custom-modal-overlay';

        // Créer la modale
        this.modal = document.createElement('div');
        this.modal.className = 'custom-modal';

        this.overlay.appendChild(this.modal);
        document.body.appendChild(this.overlay);

        // Fermer avec Échap
        document.addEventListener('keydown', this.handleEscape.bind(this));
    }

    /**
     * Gère la touche Échap
     */
    handleEscape(e) {
        if (e.key === 'Escape' && this.overlay) {
            this.close(false);
        }
    }

    /**
     * Affiche une alerte (remplace alert())
     */
    async alert(message, title = 'Information', type = 'info') {
        return new Promise((resolve) => {
            this.resolvePromise = resolve;
            this.createModal();

            const iconClass = this.getIconClass(type);
            const iconSymbol = this.getIconSymbol(type);

            this.modal.innerHTML = `
                <div class="custom-modal-header">
                    <div class="custom-modal-icon ${type}">
                        <i class="fas ${iconSymbol}"></i>
                    </div>
                    <h3 class="custom-modal-title">${this.escapeHtml(title)}</h3>
                </div>
                <div class="custom-modal-body">
                    ${this.escapeHtml(message).replace(/\n/g, '<br>')}
                </div>
                <div class="custom-modal-footer">
                    <button class="custom-modal-btn custom-modal-btn-primary" data-action="ok">
                        <i class="fas fa-check me-1"></i> OK
                    </button>
                </div>
            `;

            // Ajouter les event listeners
            this.modal.querySelector('[data-action="ok"]').addEventListener('click', () => {
                this.close(true);
            });

            // Clic sur l'overlay pour fermer
            this.overlay.addEventListener('click', (e) => {
                if (e.target === this.overlay) {
                    this.close(true);
                }
            });

            // Afficher la modale
            setTimeout(() => this.overlay.classList.add('active'), 10);
        });
    }

    /**
     * Affiche une confirmation (remplace confirm())
     */
    async confirm(message, title = 'Confirmation', options = {}) {
        return new Promise((resolve) => {
            this.resolvePromise = resolve;
            this.createModal();

            const {
                type = 'warning',
                confirmText = 'Confirmer',
                cancelText = 'Annuler',
                confirmClass = 'custom-modal-btn-primary',
                danger = false
            } = options;

            const iconSymbol = this.getIconSymbol(type);
            const confirmButtonClass = danger ? 'custom-modal-btn-danger' : confirmClass;

            this.modal.innerHTML = `
                <div class="custom-modal-header">
                    <div class="custom-modal-icon ${type}">
                        <i class="fas ${iconSymbol}"></i>
                    </div>
                    <h3 class="custom-modal-title">${this.escapeHtml(title)}</h3>
                </div>
                <div class="custom-modal-body">
                    ${this.escapeHtml(message).replace(/\n/g, '<br>')}
                </div>
                <div class="custom-modal-footer">
                    <button class="custom-modal-btn custom-modal-btn-secondary" data-action="cancel">
                        <i class="fas fa-times me-1"></i> ${this.escapeHtml(cancelText)}
                    </button>
                    <button class="custom-modal-btn ${confirmButtonClass}" data-action="confirm">
                        <i class="fas fa-check me-1"></i> ${this.escapeHtml(confirmText)}
                    </button>
                </div>
            `;

            // Ajouter les event listeners
            this.modal.querySelector('[data-action="confirm"]').addEventListener('click', () => {
                this.close(true);
            });

            this.modal.querySelector('[data-action="cancel"]').addEventListener('click', () => {
                this.close(false);
            });

            // Clic sur l'overlay pour annuler
            this.overlay.addEventListener('click', (e) => {
                if (e.target === this.overlay) {
                    this.close(false);
                }
            });

            // Afficher la modale
            setTimeout(() => this.overlay.classList.add('active'), 10);
        });
    }

    /**
     * Affiche un succès
     */
    async success(message, title = 'Succès') {
        return this.alert(message, title, 'success');
    }

    /**
     * Affiche une erreur
     */
    async error(message, title = 'Erreur') {
        return this.alert(message, title, 'error');
    }

    /**
     * Affiche un avertissement
     */
    async warning(message, title = 'Attention') {
        return this.alert(message, title, 'warning');
    }

    /**
     * Ferme la modale avec animation
     */
    close(result) {
        if (!this.overlay) return;

        // Animation de fermeture
        this.overlay.classList.add('closing');

        setTimeout(() => {
            this.destroy();
            if (this.resolvePromise) {
                this.resolvePromise(result);
                this.resolvePromise = null;
            }
        }, 200);
    }

    /**
     * Détruit complètement la modale
     */
    destroy() {
        if (this.overlay && this.overlay.parentNode) {
            this.overlay.parentNode.removeChild(this.overlay);
        }
        this.overlay = null;
        this.modal = null;
        document.removeEventListener('keydown', this.handleEscape.bind(this));
    }

    /**
     * Obtient la classe d'icône selon le type
     */
    getIconClass(type) {
        const classes = {
            success: 'fa-check-circle',
            error: 'fa-times-circle',
            warning: 'fa-exclamation-triangle',
            info: 'fa-info-circle'
        };
        return classes[type] || classes.info;
    }

    /**
     * Obtient le symbole d'icône selon le type
     */
    getIconSymbol(type) {
        const symbols = {
            success: 'fa-check-circle',
            error: 'fa-times-circle',
            warning: 'fa-exclamation-triangle',
            info: 'fa-info-circle'
        };
        return symbols[type] || symbols.info;
    }

    /**
     * Échappe le HTML pour éviter les injections
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Instance globale
const modal = new CustomModal();

// Fonctions globales pour faciliter l'utilisation
window.showAlert = (message, title, type) => modal.alert(message, title, type);
window.showConfirm = (message, title, options) => modal.confirm(message, title, options);
window.showSuccess = (message, title) => modal.success(message, title);
window.showError = (message, title) => modal.error(message, title);
window.showWarning = (message, title) => modal.warning(message, title);

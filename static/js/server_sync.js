/**
 * Module de synchronisation centralisé des statuts de serveurs
 * Ce module gère un état global partagé entre toutes les pages
 * pour éviter les problèmes de désynchronisation.
 */

const ServerSync = (function() {
    'use strict';

    // Configuration
    const CONFIG = {
        REFRESH_INTERVAL: 30000,        // 30 secondes - intervalle de rafraîchissement unifié
        STORAGE_KEY: 'serverStatusCache',
        CACHE_TTL: 25000,               // 25 secondes - légèrement inférieur au refresh pour éviter les données périmées
        API_ENDPOINT: '/api/servers/status'
    };

    // État global
    let state = {
        servers: {},
        lastUpdate: 0,
        lastConfigUpdate: 0,
        isUpdating: false,
        listeners: [],
        refreshTimer: null
    };

    /**
     * Charge l'état depuis le localStorage
     */
    function loadFromStorage() {
        try {
            const stored = localStorage.getItem(CONFIG.STORAGE_KEY);
            if (stored) {
                const parsed = JSON.parse(stored);
                // Vérifier si le cache est encore valide
                if (Date.now() - parsed.timestamp < CONFIG.CACHE_TTL) {
                    state.servers = parsed.servers || {};
                    state.lastUpdate = parsed.timestamp || 0;
                    return true;
                }
            }
        } catch (e) {
            console.warn('[ServerSync] Erreur lecture localStorage:', e);
        }
        return false;
    }

    /**
     * Sauvegarde l'état dans le localStorage
     */
    function saveToStorage() {
        try {
            localStorage.setItem(CONFIG.STORAGE_KEY, JSON.stringify({
                servers: state.servers,
                timestamp: state.lastUpdate
            }));
        } catch (e) {
            console.warn('[ServerSync] Erreur écriture localStorage:', e);
        }
    }

    /**
     * Notifie tous les listeners d'un changement
     */
    function notifyListeners(changedServers) {
        state.listeners.forEach(listener => {
            try {
                listener(state.servers, changedServers);
            } catch (e) {
                console.error('[ServerSync] Erreur dans listener:', e);
            }
        });
    }

    /**
     * Compare deux états et retourne les serveurs modifiés
     */
    function getChangedServers(oldState, newState) {
        const changed = {};
        const allServerIds = new Set([...Object.keys(oldState), ...Object.keys(newState)]);
        
        allServerIds.forEach(serverId => {
            const oldServer = oldState[serverId];
            const newServer = newState[serverId];
            
            // Nouveau serveur ou serveur supprimé
            if (!oldServer || !newServer) {
                changed[serverId] = { type: !newServer ? 'removed' : 'added', data: newServer };
                return;
            }
            
            // Vérifier les changements de statut
            if (oldServer.status !== newServer.status || 
                oldServer.db_accessible !== newServer.db_accessible) {
                changed[serverId] = { 
                    type: 'status_changed', 
                    data: newServer,
                    previousStatus: oldServer.status,
                    newStatus: newServer.status
                };
            }
        });
        
        return changed;
    }

    /**
     * Rafraîchit les statuts depuis l'API
     */
    async function refresh(forceRefresh = false) {
        if (state.isUpdating) {
            console.log('[ServerSync] Mise à jour déjà en cours, ignoré');
            return state.servers;
        }

        // Vérifier si un refresh est nécessaire
        const timeSinceLastUpdate = Date.now() - state.lastUpdate;
        if (!forceRefresh && timeSinceLastUpdate < CONFIG.CACHE_TTL) {
            console.log('[ServerSync] Cache encore valide, pas de refresh');
            return state.servers;
        }

        state.isUpdating = true;

        try {
            const url = forceRefresh 
                ? `${CONFIG.API_ENDPOINT}?force=true&t=${Date.now()}` 
                : `${CONFIG.API_ENDPOINT}?t=${Date.now()}`;
            
            const response = await fetch(url, {
                method: 'GET',
                headers: {
                    'Cache-Control': 'no-cache',
                    'Pragma': 'no-cache'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const responseData = await response.json();
            
            // Support du nouveau format avec métadonnées ou ancien format direct
            const newServers = responseData.servers || responseData;
            const serverTimestamp = responseData.timestamp || Date.now();
            const lastConfigUpdate = responseData.last_config_update || 0;
            
            const oldServers = { ...state.servers };
            
            // Vérifier si la config a changé (nouveau serveur créé/supprimé)
            if (lastConfigUpdate > state.lastConfigUpdate) {
                console.log('[ServerSync] Configuration serveur mise à jour, rafraîchissement forcé');
                state.lastConfigUpdate = lastConfigUpdate;
            }
            
            // Mettre à jour l'état
            state.servers = newServers;
            state.lastUpdate = Date.now();
            
            // Sauvegarder dans le localStorage
            saveToStorage();
            
            // Identifier les changements
            const changedServers = getChangedServers(oldServers, newServers);
            
            // Notifier si des changements
            if (Object.keys(changedServers).length > 0) {
                console.log('[ServerSync] Changements détectés:', changedServers);
                notifyListeners(changedServers);
            }
            
            // Émettre un événement custom pour les autres scripts
            window.dispatchEvent(new CustomEvent('serversync:updated', {
                detail: { servers: newServers, changed: changedServers, timestamp: serverTimestamp }
            }));
            
            return state.servers;

        } catch (error) {
            console.error('[ServerSync] Erreur lors du refresh:', error);
            return state.servers;
        } finally {
            state.isUpdating = false;
        }
    }

    /**
     * Démarre le rafraîchissement automatique
     */
    function startAutoRefresh() {
        if (state.refreshTimer) {
            clearInterval(state.refreshTimer);
        }
        
        state.refreshTimer = setInterval(() => {
            refresh();
        }, CONFIG.REFRESH_INTERVAL);
        
        console.log(`[ServerSync] Auto-refresh démarré (intervalle: ${CONFIG.REFRESH_INTERVAL}ms)`);
    }

    /**
     * Arrête le rafraîchissement automatique
     */
    function stopAutoRefresh() {
        if (state.refreshTimer) {
            clearInterval(state.refreshTimer);
            state.refreshTimer = null;
            console.log('[ServerSync] Auto-refresh arrêté');
        }
    }

    /**
     * S'abonne aux mises à jour
     */
    function subscribe(callback) {
        if (typeof callback === 'function') {
            state.listeners.push(callback);
            // Appeler immédiatement avec l'état actuel
            callback(state.servers, {});
        }
        return () => {
            state.listeners = state.listeners.filter(l => l !== callback);
        };
    }

    /**
     * Obtient le statut d'un serveur spécifique
     */
    function getServerStatus(serverId) {
        return state.servers[serverId] || null;
    }

    /**
     * Obtient tous les serveurs
     */
    function getAllServers() {
        return { ...state.servers };
    }

    /**
     * Force une invalidation complète et un rafraîchissement
     */
    async function forceRefresh() {
        localStorage.removeItem(CONFIG.STORAGE_KEY);
        state.lastUpdate = 0;
        return await refresh(true);
    }

    /**
     * Initialise le module
     */
    function init() {
        // Charger l'état depuis le localStorage
        loadFromStorage();
        
        // Premier rafraîchissement immédiat
        refresh();
        
        // Démarrer l'auto-refresh
        startAutoRefresh();
        
        // Écouter les changements de visibilité de la page
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                // Page en arrière-plan, réduire la fréquence
                stopAutoRefresh();
            } else {
                // Page visible, rafraîchir et reprendre l'auto-refresh
                refresh();
                startAutoRefresh();
            }
        });
        
        // Écouter les changements de focus
        window.addEventListener('focus', () => {
            // Forcer un rafraîchissement quand l'utilisateur revient sur la page
            const timeSinceLastUpdate = Date.now() - state.lastUpdate;
            if (timeSinceLastUpdate > 10000) { // Plus de 10 secondes
                refresh();
            }
        });
        
        // Écouter les demandes de synchronisation d'autres fenêtres
        window.addEventListener('storage', (e) => {
            if (e.key === CONFIG.STORAGE_KEY && e.newValue) {
                try {
                    const newData = JSON.parse(e.newValue);
                    // Mettre à jour si les données sont plus récentes
                    if (newData.timestamp > state.lastUpdate) {
                        const oldServers = { ...state.servers };
                        state.servers = newData.servers;
                        state.lastUpdate = newData.timestamp;
                        
                        const changedServers = getChangedServers(oldServers, newData.servers);
                        if (Object.keys(changedServers).length > 0) {
                            notifyListeners(changedServers);
                        }
                    }
                } catch (e) {
                    // Ignorer les erreurs de parsing
                }
            }
        });
        
        console.log('[ServerSync] Module initialisé');
    }

    // API publique
    return {
        init,
        refresh,
        forceRefresh,
        subscribe,
        getServerStatus,
        getAllServers,
        startAutoRefresh,
        stopAutoRefresh,
        // Exposer la config pour les autres scripts qui voudraient l'utiliser
        CONFIG
    };
})();

// Auto-initialisation au chargement du DOM
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', ServerSync.init);
} else {
    ServerSync.init();
}

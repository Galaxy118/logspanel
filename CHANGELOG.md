# 📝 Changelog

Toutes les modifications notables du projet sont documentées dans ce fichier.

---

## [1.1.0] - 2024-12-27

### ✨ Nouvelles Fonctionnalités

#### Panel Client
- **Création de serveur par les clients** - Les utilisateurs avec un rôle Discord spécifique peuvent créer leur propre serveur
- **Limitation à 1 serveur** - Les clients ne peuvent créer qu'un seul serveur
- **Gestion depuis la page Mon Compte** - Interface dédiée dans `/account` au lieu de `/admin`
- **Badge propriétaire** - Affichage du badge "Propriétaire" sur les serveurs créés par les clients
- **Configuration via variables d'environnement** :
  - `CLIENT_DISCORD_GUILD_ID` - ID du serveur Discord où vérifier le rôle
  - `CLIENT_DISCORD_ROLE_ID` - ID du rôle qui permet de créer des serveurs

#### Mode Debug
- **Système de debug configurable** - Variable `DEBUG_MODE` dans `.env`
- **Logs détaillés** - Logs avec emojis pour meilleure lisibilité
- **Niveaux de log** - DEBUG, INFO, WARNING, ERROR
- **Debug ciblé** :
  - Authentification et vérification des rôles Discord
  - Permissions utilisateur
  - Création/modification/suppression de serveurs
  - Sauvegarde de configuration

### 🚀 Optimisations de Performance

- **Parallélisation des requêtes** - Utilisation de `ThreadPoolExecutor`
  - Vérification des statuts serveurs en parallèle (4 serveurs : 30s → 3s)
  - Récupération des icônes Discord en parallèle
- **Réduction des timeouts** :
  - Connexion MySQL : 10s → 3s
  - Pool MySQL : 10s → 5s
  - API Discord (icônes) : 5s → 2s
  - API Discord (rôles) : 10s → 5s
- **Augmentation des caches** :
  - Cache statut serveurs : 30s → 120s
  - Cache icônes Discord : 1h → 24h
- **Temps de chargement page d'accueil réduit de 80-90%**

### 🔧 Corrections de Bugs

- **Fix système de fichiers en lecture seule** :
  - Ajout retry automatique (3 tentatives)
  - Remontage automatique en RW avant chaque sauvegarde
  - Écriture atomique via fichier temporaire `.tmp`
  - Service de surveillance `keepfs-rw` pour maintenir le système en RW
  - Diagnostic détaillé avec permissions, UID/GID, état du mount

- **Fix permissions serveur** :
  - Chemin absolu forcé pour `servers_config.json`
  - Service systemd avec `ReadWritePaths` configuré
  - Script de correction automatique `fix-readonly-fs.sh`

- **Fix ownership** :
  - Ajout du champ `owner_id` dans la configuration serveur
  - Liaison automatique client → serveur lors de la création
  - Permissions de suppression basées sur `owner_id`

### 📚 Documentation

- **Réorganisation complète** - Tous les fichiers `.md` regroupés dans `docs/`
- **Nouveaux guides** :
  - `docs/INSTALLATION.md` - Installation pas à pas
  - `docs/CONFIGURATION.md` - Configuration détaillée
  - `docs/SECURITY.md` - Guide de sécurité complet
  - `docs/MAINTENANCE.md` - Gestion, debug et monitoring
  - `docs/TROUBLESHOOTING.md` - Solutions aux problèmes courants
  - `docs/README.md` - Index de la documentation
- **README.md amélioré** - Vue d'ensemble moderne avec badges
- **Suppression des doublons** - `DEBUG_MODE.md`, `SECURITY.md` (racine), `FIREWALL_SYNC_README.md` intégrés

### 🛠️ Scripts et Outils

- **`deploy/fix-readonly-fs.sh`** - Script de correction automatique du problème RO
- **`deploy/keepfs-rw.service`** - Service systemd de surveillance filesystem
- **Script de mise à jour** - Commande `update-panel` pour déploiement simplifié

### 🎨 Interface Utilisateur

- **Section Espace Client** dans la page Mon Compte :
  - Formulaire de création de serveur complet
  - Carte de gestion du serveur existant avec statut
  - Boutons "Voir les logs" et "Configurer"
- **Badge "Client"** dans le profil utilisateur
- **Badge "Propriétaire"** sur les serveurs créés par l'utilisateur
- **Redirection automatique** - Les clients sans serveur sont redirigés vers `/account`

---

## [1.0.0] - 2024-12-26

### 🎉 Version Initiale

- Application Flask multi-serveurs pour logs FiveM
- Authentification Discord OAuth2
- Gestion des permissions par rôles Discord
- Dashboard avec recherche et filtres
- Support MySQL/MariaDB par serveur
- Cloudflare Tunnel pour accès sécurisé
- Protection CSRF, Rate Limiting, Headers de sécurité
- Cloudflare Turnstile (captcha optionnel)
- Synchronisation automatique UFW pour connexions MySQL
- Interface responsive Bootstrap 5

---

## Format

Ce changelog suit le format [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

### Types de changements

- **Ajouté** pour les nouvelles fonctionnalités
- **Modifié** pour les changements aux fonctionnalités existantes
- **Déprécié** pour les fonctionnalités qui seront bientôt supprimées
- **Supprimé** pour les fonctionnalités supprimées
- **Corrigé** pour les corrections de bugs
- **Sécurité** en cas de vulnérabilités

# 🚀 Panel Logs Galaxy

Panel de gestion des logs multi-serveurs pour FiveM avec authentification Discord.

[![Made with Python](https://img.shields.io/badge/Made%20with-Python-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-2.0+-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Fonctionnalités

### 🔐 Authentification & Autorisations
- **Discord OAuth2** - Connexion via Discord
- **Gestion des rôles sans bot** - Vérification des rôles Discord via OAuth2 (scope `guilds.members.read`)
- **Panel Client** - Les clients peuvent créer et gérer leur propre serveur
- **Super Admin** - Accès complet à tous les serveurs
- **Bot Discord optionnel** - Fonctionne sans ajouter de bot aux serveurs Discord

### 📊 Gestion des Logs
- **Multi-serveurs** - Gérez plusieurs serveurs FiveM depuis une seule interface
- **Recherche avancée** - Filtrage par type, joueur, date, etc.
- **Statistiques** - Vue d'ensemble des logs par type
- **Export** - Téléchargement des logs

### 🛡️ Sécurité
- **Cloudflare Tunnel** - Aucun port ouvert, protection DDoS
- **CSRF Protection** - Tokens anti-CSRF sur tous les formulaires
- **Rate Limiting** - Protection contre les attaques par force brute
- **Headers de sécurité** - CSP, HSTS, X-Frame-Options, etc.
- **Captcha Turnstile** - Protection bot optionnelle

### 🔧 Administration
- **Interface intuitive** - Dashboard moderne et responsive
- **Gestion des serveurs** - Créer, modifier, supprimer des serveurs
- **Configuration Discord** - Intégration Discord par serveur
- **Firewall automatique** - Synchronisation UFW pour les connexions MySQL

---

## 📖 Documentation

### 🚀 Démarrage Rapide
- **[Installation](docs/INSTALLATION.md)** - Guide d'installation pas à pas
- **[Configuration](docs/CONFIGURATION.md)** - Configuration des fichiers `.env` et `servers_config.json`

### 🔒 Sécurité & Production
- **[Sécurité](docs/SECURITY.md)** - Mesures de sécurité et bonnes pratiques
- **[Maintenance](docs/MAINTENANCE.md)** - Gestion, debug, mise à jour

### 🆘 Aide
- **[Dépannage](docs/TROUBLESHOOTING.md)** - Solutions aux problèmes courants

---

## ⚡ Installation en 2 minutes

### Prérequis
- Ubuntu 24.04 LTS (recommandé)
- Accès root ou sudo
- Compte Cloudflare (gratuit)
- Application Discord

### Commande d'installation

```bash
# 1. Cloner le projet
git clone <votre-repo> /var/www/logspanel
cd /var/www/logspanel

# 2. Lancer l'installation automatique
sudo chmod +x deploy/install.sh
sudo ./deploy/install.sh

# 3. Configurer .env et servers_config.json
cp env.example .env
nano .env

# 4. Démarrer
sudo systemctl start logspanel
```

**Consultez [docs/INSTALLATION.md](docs/INSTALLATION.md) pour les détails complets.**

---

## 📁 Structure du Projet

```
panellogs/
├── main.py                      # Application Flask principale
├── models.py                    # Modèles SQLAlchemy et gestion BDD
├── gunicorn_config.py           # Configuration Gunicorn
├── requirements.txt             # Dépendances Python
├── .env                         # Variables d'environnement (non versionné)
├── servers_config.json          # Configuration serveurs (non versionné)
├── env.example                  # Template .env
├── servers_config.json.example  # Template servers_config.json
│
├── docs/                        # 📚 Documentation
│   ├── INSTALLATION.md          # Guide d'installation
│   ├── CONFIGURATION.md         # Configuration détaillée
│   ├── SECURITY.md              # Guide de sécurité
│   ├── MAINTENANCE.md           # Gestion et maintenance
│   └── TROUBLESHOOTING.md       # Dépannage
│
├── static/                      # Assets statiques
│   ├── css/                     # Feuilles de style
│   ├── js/                      # Scripts JavaScript
│   └── html/                    # Templates Jinja2
│
├── deploy/                      # 🚀 Scripts de déploiement
│   ├── install.sh               # Installation complète
│   ├── logspanel.service        # Service systemd
│   └── allow_db_egress.sh       # Synchronisation firewall MySQL
│
└── instance/                    # Bases de données SQLite locales
```

---

## 🎯 Fonctionnalités Clés

### Panel Client

Les utilisateurs avec un rôle Discord spécifique peuvent :
- Créer **un serveur unique**
- Configurer leur base de données MySQL
- Gérer les rôles Discord (staff/admin)
- Visualiser les logs de leur serveur

### Multi-Serveurs

Gérez plusieurs serveurs FiveM :
- Une base de données par serveur
- Permissions Discord par serveur
- Dashboard dédié par serveur
- Statistiques indépendantes

### Recherche Avancée

Filtrez les logs par :
- Type de log (kill, admin, connexion, etc.)
- Nom du joueur ou identifiant
- Plage de dates
- Contenu du message

---

## 🛠️ Technologies Utilisées

- **Backend** : Flask 3.0, SQLAlchemy, Gunicorn
- **Authentification** : Discord OAuth2, JWT
- **Base de données** : MySQL/MariaDB (multi-serveurs)
- **Sécurité** : Flask-WTF (CSRF), Flask-Limiter (rate limiting), Cloudflare
- **Déploiement** : Systemd, Cloudflare Tunnel, Ubuntu 24.04
- **Frontend** : Bootstrap 5, Font Awesome, Animate.css

---

## 🚦 Commandes Rapides

```bash
# Démarrer le panel
sudo systemctl start logspanel

# Arrêter le panel
sudo systemctl stop logspanel

# Redémarrer le panel
sudo systemctl restart logspanel

# Voir les logs
sudo journalctl -u logspanel -f

# Statut
sudo systemctl status logspanel

# Activer le mode debug
echo "DEBUG_MODE=true" >> .env
sudo systemctl restart logspanel
```

---

## 📊 Captures d'écran

### Dashboard Multi-Serveurs
Interface d'administration avec vue d'ensemble de tous les serveurs configurés.

### Page Mon Compte
Espace utilisateur avec accès aux serveurs autorisés et gestion du serveur client.

### Recherche de Logs
Filtres avancés pour trouver rapidement les logs spécifiques.

---

## 🔐 Sécurité

Ce projet implémente de nombreuses mesures de sécurité :

- ✅ **Aucun port ouvert** - Cloudflare Tunnel uniquement
- ✅ **Protection CSRF** - Tokens sur tous les formulaires
- ✅ **Rate Limiting** - Limite les requêtes par IP
- ✅ **Headers de sécurité** - CSP, HSTS, X-Frame-Options
- ✅ **Sanitisation SQL** - Protection injection SQL
- ✅ **JWT Secure** - Tokens HttpOnly, Secure, SameSite
- ✅ **Captcha Turnstile** - Protection bot Cloudflare

**Consultez [docs/SECURITY.md](docs/SECURITY.md) pour plus de détails.**

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Merci de :

1. Fork le projet
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Commit vos changements (`git commit -m 'Ajout fonctionnalité'`)
4. Push vers la branche (`git push origin feature/amelioration`)
5. Ouvrir une Pull Request

---

## 📝 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

## 🔧 Dépannage

### ❌ Erreur "Read-only file system"

**Symptôme** : Impossible de sauvegarder la configuration, erreur dans les logs :
```
[ERROR] ❌ Erreur système lors de la sauvegarde: [Errno 30] Read-only file system
```

**Cause** : La directive `ProtectSystem=strict` dans le service systemd protège le système en lecture seule.

**Solution rapide** :
```bash
# Corriger immédiatement
sudo mount -o remount,rw /

# Appliquer le correctif permanent
cd /var/www/logspanel/deploy
sudo ./fix-readonly-fs.sh
```

**Solution manuelle** :
```bash
# 1. Remonter en lecture-écriture
sudo mount -o remount,rw /

# 2. Installer le service de surveillance
sudo cp deploy/keepfs-rw.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now keepfs-rw

# 3. Mettre à jour logspanel.service
sudo cp deploy/logspanel.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart logspanel

# 4. Vérifier
sudo journalctl -u logspanel -u keepfs-rw -f
```

---

## 📞 Support

- 📖 **Documentation** : [docs/](docs/)
- 🐛 **Issues** : [GitHub Issues](votre-repo/issues)
- 💬 **Discord** : [Votre serveur Discord]

---

## ✅ Checklist de Déploiement

- [ ] Ubuntu 24.04 installé
- [ ] Projet cloné dans `/var/www/logspanel`
- [ ] `sudo ./deploy/install.sh` exécuté
- [ ] `.env` configuré avec vos secrets
- [ ] `servers_config.json` configuré
- [ ] Cloudflare Tunnel créé
- [ ] DNS configuré
- [ ] Services démarrés
- [ ] Test d'accès réussi
- [ ] Mode debug désactivé en production

---

**Made with ❤️ by Galaxy**

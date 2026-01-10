# ⚙️ Guide de Configuration

Guide complet pour configurer Panel Logs Galaxy.

---

## Table des Matières

1. [Fichier .env](#-fichier-env)
2. [Fichier servers_config.json](#-fichier-servers_configjson)
3. [Panel Client](#-panel-client)
4. [Cloudflare Turnstile](#-cloudflare-turnstile)
5. [Variables Avancées](#-variables-avancées)

---

## 🔐 Fichier `.env`

Le fichier `.env` contient toutes les variables d'environnement sensibles.

### Créer le fichier

```bash
cd /var/www/logspanel
sudo cp env.example .env
sudo nano .env
```

### Variables Obligatoires

#### 1. Clés Secrètes

```env
# Génération de clés uniques
# NE JAMAIS réutiliser ces exemples en production !
FLASK_SECRET_KEY=votre_cle_secrete_unique_32_caracteres
JWT_SECRET_KEY=autre_cle_secrete_unique_32_caracteres
```

**Générer des clés sécurisées :**

```bash
# Méthode 1 : Python
python3 -c "import secrets; print(secrets.token_hex(32))"

# Méthode 2 : OpenSSL
openssl rand -hex 32
```

#### 2. Discord OAuth2

```env
# Application Discord - https://discord.com/developers/applications
DISCORD_CLIENT_ID=votre_application_id
DISCORD_CLIENT_SECRET=votre_client_secret

# Token du bot Discord (OPTIONNEL)
# Le système fonctionne SANS bot grâce à OAuth2 avec le scope guilds.members.read
# Si configuré : notifications Discord + vérification rôles plus rapide
# Si non configuré : système plus simple, pas besoin d'ajouter un bot aux serveurs
DISCORD_BOT_TOKEN=

# URL de redirection après connexion
GLOBAL_REDIRECT_URI=https://votre-domaine.com/callback
```

**Obtenir les credentials Discord :**

1. Aller sur [Discord Developer Portal](https://discord.com/developers/applications)
2. Créer une nouvelle application
3. Onglet **OAuth2** :
   - Copier **Client ID**
   - Copier **Client Secret**
   - Ajouter Redirect : `https://votre-domaine.com/callback`
   - **IMPORTANT** : Les scopes requis sont `identify`, `guilds` et `guilds.members.read`
4. Onglet **Bot** (OPTIONNEL - pour notifications Discord) :
   - Créer un bot
   - Activer **Server Members Intent**
   - Copier le **Token**
   - Ajouter le bot aux serveurs Discord où vous voulez des notifications

> **💡 Mode simplifié (sans bot)** : Si vous ne configurez pas `DISCORD_BOT_TOKEN`, le système utilisera uniquement OAuth2. Les utilisateurs n'auront pas besoin d'ajouter de bot à leurs serveurs Discord. La vérification des rôles se fera via leur connexion Discord.

#### 3. Super Administrateurs

```env
# IDs Discord des super admins (séparés par des virgules ou espaces)
SUPER_ADMIN_DISCORD_IDS=123456789012345678,987654321098765432
```

**Obtenir votre ID Discord :**
1. Activer le Mode Développeur dans Discord : Paramètres > Avancés > Mode développeur
2. Clic droit sur votre nom > Copier l'ID

### Variables Optionnelles

#### Cloudflare Turnstile (Captcha)

```env
# Activer le captcha Turnstile - https://www.cloudflare.com/products/turnstile/
TURNSTILE_SITE_KEY=0x4AAAAAAA...
TURNSTILE_SECRET_KEY=0x4AAAAAAA...

# Durée de validité du captcha (secondes)
TURNSTILE_SESSION_TTL=600
ENTRY_CAPTCHA_TTL=86400
```

#### Panel Client

```env
# Permet aux clients de créer leur propre serveur
CLIENT_DISCORD_GUILD_ID=1381418967306080307
CLIENT_DISCORD_ROLE_ID=1381418967306080309
```

#### Configuration Globale

```env
# Nom du site
GLOBAL_SITE_NAME=Panel Logs Galaxy

# Version des assets (cache busting)
ASSET_VERSION=1.0.0

# Mode debug (false en production !)
DEBUG_MODE=false
```

### Sécuriser le fichier

```bash
# Permissions strictes
sudo chmod 600 /var/www/logspanel/.env
sudo chown www-data:www-data /var/www/logspanel/.env
```

---

## 📂 Fichier `servers_config.json`

Configure les serveurs de logs et leurs bases de données.

### Créer le fichier

```bash
cd /var/www/logspanel
sudo cp servers_config.json.example servers_config.json
sudo nano servers_config.json
```

### Structure du Fichier

```json
{
  "servers": {
    "monserveur": {
      "display_name": "Mon Serveur RP",
      "description": "Serveur FiveM Roleplay",
      "database_uri": "mysql+pymysql://user:password@host:3306/database",
      "discord": {
        "guild_id": "123456789012345678",
        "role_id_staff": "123456789012345678",
        "role_id_admin": "987654321098765432",
        "channel_id": "111222333444555666"
      },
      "owner_id": ""
    }
  }
}
```

### Configuration d'un Serveur

#### Champs Obligatoires

| Champ | Type | Description | Exemple |
|-------|------|-------------|---------|
| `display_name` | String | Nom affiché du serveur | `"Mon Serveur RP"` |
| `description` | String | Description du serveur | `"Serveur FiveM..."` |
| `database_uri` | String | URI de connexion MySQL | `"mysql+pymysql://..."` |

#### Configuration Discord (Optionnelle)

| Champ | Type | Description |
|-------|------|-------------|
| `guild_id` | String | ID du serveur Discord |
| `role_id_staff` | String | Rôle pouvant voir les logs |
| `role_id_admin` | String | Rôle pouvant administrer |
| `channel_id` | String | Salon pour les notifications |

#### Champ Système

| Champ | Type | Description |
|-------|------|-------------|
| `owner_id` | String | ID Discord du propriétaire (clients) |

### URI de Base de Données

#### Format MySQL/MariaDB

```
mysql+pymysql://utilisateur:motdepasse@hote:port/base_de_donnees
```

**Exemples :**

```python
# Serveur local
"mysql+pymysql://root:password@localhost:3306/fivem_logs"

# Serveur distant
"mysql+pymysql://user:pass@192.168.1.100:3306/logs"

# Serveur avec nom de domaine
"mysql+pymysql://dbuser:dbpass@mysql.example.com:3306/fivem_db"
```

#### Caractères Spéciaux

Si votre mot de passe contient des caractères spéciaux, encodez-les :

```python
# Mot de passe : p@ssw0rd!#
# Encodé : p%40ssw0rd%21%23
"mysql+pymysql://user:p%40ssw0rd%21%23@host:3306/db"
```

**Encodage des caractères :**
- `@` → `%40`
- `!` → `%21`
- `#` → `%23`
- `$` → `%24`
- `%` → `%25`

### Exemple Complet Multi-Serveurs

```json
{
  "servers": {
    "galaxy-rp": {
      "display_name": "Galaxy RP",
      "description": "Serveur Roleplay Galaxy",
      "database_uri": "mysql+pymysql://logs_user:SecurePass123@db1.example.com:3306/galaxy_logs",
      "discord": {
        "guild_id": "123456789012345678",
        "role_id_staff": "111111111111111111",
        "role_id_admin": "222222222222222222",
        "channel_id": "333333333333333333"
      }
    },
    "galaxy-rp-test": {
      "display_name": "Galaxy RP - Test",
      "description": "Serveur de test",
      "database_uri": "mysql+pymysql://logs_user:TestPass456@db2.example.com:3306/galaxy_test_logs",
      "discord": {
        "guild_id": "123456789012345678",
        "role_id_staff": "444444444444444444",
        "role_id_admin": "555555555555555555",
        "channel_id": "666666666666666666"
      }
    },
    "client-server": {
      "display_name": "Serveur Client",
      "description": "Serveur créé par un client",
      "database_uri": "mysql+pymysql://client:ClientPass789@mysql.host.com:3306/client_logs",
      "discord": {
        "guild_id": "987654321098765432",
        "role_id_staff": "777777777777777777",
        "role_id_admin": "888888888888888888",
        "channel_id": "999999999999999999"
      },
      "owner_id": "841996278010740736"
    }
  }
}
```

### Sécuriser le Fichier

```bash
# Permissions
sudo chmod 664 /var/www/logspanel/servers_config.json
sudo chown www-data:www-data /var/www/logspanel/servers_config.json
```

### Recharger la Configuration

Après modification du fichier :

```bash
# Redémarrer le panel
sudo systemctl restart logspanel

# Synchroniser le firewall (connexions MySQL)
sudo /var/www/logspanel/deploy/allow_db_egress.sh --auto
```

---

## 🏪 Panel Client

Permet aux utilisateurs avec un rôle Discord spécifique de créer leur propre serveur.

### Configuration

#### 1. Créer un rôle "Client" sur Discord

Dans les paramètres de votre serveur Discord :
1. Créer un rôle "Client"
2. Copier l'ID du rôle (clic droit > Copier l'ID)

#### 2. Configurer .env

```env
# ID du serveur Discord où vérifier le rôle
CLIENT_DISCORD_GUILD_ID=1381418967306080307

# ID du rôle qui permet de créer des serveurs
CLIENT_DISCORD_ROLE_ID=1381418967306080309
```

#### 3. Redémarrer

```bash
sudo systemctl restart logspanel
```

### Fonctionnement

Les utilisateurs avec le rôle client peuvent :
- ✅ Créer **un seul serveur**
- ✅ Le configurer depuis leur page "Mon Compte"
- ✅ Gérer leur serveur
- ✅ Voir les logs de leur serveur
- ❌ Accéder aux autres serveurs
- ❌ Créer plus d'un serveur

Le serveur créé est automatiquement lié à l'ID Discord du client (`owner_id`).

---

## 🤖 Cloudflare Turnstile

Protection bot Cloudflare (alternative gratuite à reCAPTCHA).

### Activer Turnstile

#### 1. Créer un Site Turnstile

1. Aller sur [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. **Turnstile** > **Add Site**
3. Nom du site : `Panel Logs`
4. Domaine : `votre-domaine.com`
5. Mode : **Managed** (recommandé)

#### 2. Copier les Clés

Cloudflare affiche :
- **Site Key** (clé publique)
- **Secret Key** (clé privée)

#### 3. Configurer .env

```env
TURNSTILE_SITE_KEY=0x4AAAAAAA...
TURNSTILE_SECRET_KEY=0x4AAAAAAA...
```

#### 4. Redémarrer

```bash
sudo systemctl restart logspanel
```

### Configuration Avancée

```env
# Durée de validité après succès (10 minutes)
TURNSTILE_SESSION_TTL=600

# Durée de validité du captcha d'entrée (24 heures)
ENTRY_CAPTCHA_TTL=86400
```

### Désactiver Turnstile

Laissez les champs vides dans `.env` :

```env
TURNSTILE_SITE_KEY=
TURNSTILE_SECRET_KEY=
```

---

## 🔧 Variables Avancées

### Configuration Globale

```env
# Nom affiché dans l'interface
GLOBAL_SITE_NAME=Panel Logs Galaxy

# Version des assets (cache busting)
ASSET_VERSION=1.0.0

# Mode debug (logs détaillés)
DEBUG_MODE=false
```

### Mode Debug

Activer pour diagnostiquer les problèmes :

```env
DEBUG_MODE=true
```

**Attention** : Mode debug à **désactiver en production** !

Voir [MAINTENANCE.md](MAINTENANCE.md) pour plus de détails.

---

## ✅ Checklist de Configuration

- [ ] `.env` créé depuis `env.example`
- [ ] Clés secrètes générées (uniques !)
- [ ] Discord OAuth2 configuré
- [ ] Redirect URI correct dans Discord
- [ ] Super Admin IDs configurés
- [ ] `servers_config.json` créé depuis l'example
- [ ] Base de données MySQL accessible
- [ ] Connexion testée manuellement
- [ ] Firewall synchronisé (allow_db_egress.sh)
- [ ] Permissions des fichiers correctes (600 pour .env, 664 pour json)
- [ ] Service redémarré
- [ ] Test de connexion réussi

---

## 🔄 Mise à Jour de la Configuration

### Modifier .env

```bash
sudo nano /var/www/logspanel/.env
sudo systemctl restart logspanel
```

### Modifier servers_config.json

```bash
sudo nano /var/www/logspanel/servers_config.json
sudo systemctl restart logspanel
sudo /var/www/logspanel/deploy/allow_db_egress.sh --auto
```

### Via l'Interface Web

Les Super Admins peuvent modifier `servers_config.json` via l'interface :
- Page **Administration** > **Serveurs**
- Cliquer sur **⚙️ Configurer**
- Le firewall se synchronise automatiquement

---

## ➡️ Étape Suivante

Une fois la configuration terminée, consultez :
- **[SECURITY.md](SECURITY.md)** - Sécuriser votre installation
- **[MAINTENANCE.md](MAINTENANCE.md)** - Gérer et maintenir le panel

---

**Besoin d'aide ?** Consultez [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

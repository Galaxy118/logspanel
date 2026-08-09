from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import OperationalError
from sqlalchemy import create_engine, text, func
from sqlalchemy.orm import sessionmaker
import json
import os
import time
from datetime import datetime
import threading
import logging
import sys

db = SQLAlchemy()

# Configurer le logger pour models.py
logger = logging.getLogger(__name__)

# Cache pour les connexions de base de données par serveur
server_db_connections = {}
server_db_sessions = {}
server_db_uris = {}  # Stocke l'URI utilisée pour chaque connexion
_db_lock = threading.Lock()

# JSON parsing accéléré avec fallback
try:
    import orjson as _fastjson
    def parse_json_fast(data):
        try:
            return _fastjson.loads(data)
        except Exception:
            return {}
except Exception:
    def parse_json_fast(data):
        try:
            return json.loads(data)
        except Exception:
            return {}

class ServerLogModel(db.Model):
    __tablename__ = 'server_logs'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    server_id = db.Column(db.String(100), index=True, nullable=False)
    type = db.Column(db.Text, nullable=False)
    data = db.Column(db.Text, nullable=False)
    date = db.Column(db.DateTime, nullable=False, default=db.func.current_timestamp(), index=True)
    
    def __repr__(self):
        return f'<ServerLogModel {self.id}: {self.type}>'
    
    def get_data_json(self):
        """Retourne les données JSON parsées"""
        return parse_json_fast(self.data)

class ServerConfigModel(db.Model):
    __tablename__ = 'server_configs'
    id = db.Column(db.String(100), primary_key=True)
    config_data = db.Column(db.Text, nullable=False)

class GlobalConfigModel(db.Model):
    __tablename__ = 'global_configs'
    id = db.Column(db.String(50), primary_key=True)
    config_data = db.Column(db.Text, nullable=False)

class ServerConfig:
    """Classe pour gérer la configuration des serveurs (via SQLAlchemy)"""
    
    def __init__(self):
        pass
    
    def load_config(self):
        """Obsolète : la configuration est gérée dynamiquement par la base de données SQLite."""
        pass
    
    def get_servers(self):
        """Retourne la liste des serveurs configurés"""
        servers = ServerConfigModel.query.all()
        return {s.id: parse_json_fast(s.config_data) for s in servers}
    
    def get_server(self, server_id):
        """Retourne la configuration d'un serveur spécifique"""
        server = ServerConfigModel.query.get(server_id)
        if server:
            return parse_json_fast(server.config_data)
        return None
    
    def is_valid_server(self, server_id):
        """Vérifie si un serveur existe dans la configuration"""
        return db.session.query(ServerConfigModel.id).filter_by(id=server_id).first() is not None
    
    def get_server_list(self):
        """Retourne la liste des IDs de serveurs"""
        servers = db.session.query(ServerConfigModel.id).all()
        return [s.id for s in servers]
        """Retourne une liste simplifiée des serveurs (ID, Nom, Description, Propriétaire)"""
        servers = self.get_servers()
        return [{
            'id': sid, 
            'name': conf.get('display_name', sid), 
            'description': conf.get('description', ''),
            'owner_id': conf.get('owner_id', '')
        } for sid, conf in servers.items()]
        
    def get_global_config(self):
        """Retourne la configuration globale"""
        global_config = GlobalConfigModel.query.get('global')
        if global_config:
            return parse_json_fast(global_config.config_data)
        return {}
        
    def update_global_config(self, data):
        """Met à jour la configuration globale"""
        global_config = GlobalConfigModel.query.get('global')
        if global_config:
            global_config.config_data = json.dumps(data, ensure_ascii=False)
        else:
            global_config = GlobalConfigModel(id='global', config_data=json.dumps(data, ensure_ascii=False))
            db.session.add(global_config)
        db.session.commit()
        return True
    
    def load_config(self):
        """Obsolète : la configuration est gérée dynamiquement par la base de données SQLite."""
        pass
    
    def save_config(self):
        """Obsolète : La sauvegarde est effectuée par db.session.commit() directement"""
        pass
    
    def update_server_config(self, server_id, config_data):
        """Met à jour la configuration d'un serveur"""
        server = ServerConfigModel.query.get(server_id)
        if not server:
            raise ValueError(f"Serveur {server_id} non trouvé")
        
        current_config = parse_json_fast(server.config_data)
        current_config.update(config_data)
        server.config_data = json.dumps(current_config, ensure_ascii=False)
        db.session.commit()
        
        return True
    
    def delete_server(self, server_id):
        """Supprime un serveur de la configuration"""
        server = ServerConfigModel.query.get(server_id)
        if server:
            # Supprimer aussi les logs associés
            ServerLogModel.query.filter_by(server_id=server_id).delete()
            db.session.delete(server)
            db.session.commit()
            return True
        return False
    
    def create_server(self, server_id, config_data):
        """Crée un nouveau serveur avec sa configuration"""
        import secrets
        if self.is_valid_server(server_id):
            raise ValueError(f"Le serveur {server_id} existe déjà")
        
        default_config = {
            'display_name': config_data.get('display_name', server_id),
            'description': config_data.get('description', ''),
            'logo': config_data.get('logo', f'/static/logos/{server_id}.png'),
            'status': 'offline',
            'api_token': secrets.token_urlsafe(32), # Jeton API généré
            'owner_id': config_data.get('owner_id', ''),
            'discord': {
                'client_id': config_data.get('discord', {}).get('client_id', ''),
                'client_secret': config_data.get('discord', {}).get('client_secret', ''),
                'bot_token': config_data.get('discord', {}).get('bot_token', ''),
                'guild_id': config_data.get('discord', {}).get('guild_id', ''),
                'role_id_client': config_data.get('discord', {}).get('role_id_client', ''),
                'role_id_staff': config_data.get('discord', {}).get('role_id_staff', ''),
                'role_id_admin': config_data.get('discord', {}).get('role_id_admin', ''),
            }
        }
        
        server = ServerConfigModel(id=server_id, config_data=json.dumps(default_config, ensure_ascii=False))
        db.session.add(server)
        db.session.commit()
        
        return True

# Instance globale
server_config = ServerConfig()

def migrate_config_to_db(app):
    """Fonction de migration à exécuter une fois au démarrage"""
    import secrets
    with app.app_context():
        # S'assurer que le dossier instance existe
        os.makedirs(app.instance_path, exist_ok=True)
        db.create_all()

    config_file = os.path.join(app.root_path, 'servers_config.json')
    
    if not os.path.exists(config_file):
        return
        
    try:
        with open(config_file, 'r', encoding='utf-8') as f:
            old_config = json.load(f)
            
        with app.app_context():
            
            # Vérifier si la migration a déjà été faite
            if ServerConfigModel.query.first() is not None or GlobalConfigModel.query.first() is not None:
                return
                
            # Migrer global_config
            if 'global_config' in old_config:
                global_data = old_config['global_config']
                global_model = GlobalConfigModel(id='global', config_data=json.dumps(global_data, ensure_ascii=False))
                db.session.add(global_model)
                
            # Migrer servers
            if 'servers' in old_config:
                for server_id, server_data in old_config['servers'].items():
                    # Ajouter l'api_token si manquant
                    if 'api_token' not in server_data:
                        server_data['api_token'] = secrets.token_urlsafe(32)
                    
                    server_model = ServerConfigModel(id=server_id, config_data=json.dumps(server_data, ensure_ascii=False))
                    db.session.add(server_model)
                    
            db.session.commit()
            print("✅ Migration de la configuration vers SQLite terminée.")
            
    except Exception as e:
        logger.error(f"❌ Erreur lors de la migration: {e}")

# =====================================================================
# Système de Cache Optimisé
# =====================================================================
class SimpleCache:
    def __init__(self, ttl=60):
        self.cache = {}
        self.ttl = ttl
        self.lock = threading.Lock()
        
    def get(self, key, *args):
        """Récupère une valeur du cache si elle n'a pas expiré"""
        if args:
            import hashlib
            args_str = json.dumps(args, sort_keys=True)
            key = f"{key}_{hashlib.md5(args_str.encode()).hexdigest()}"
            
        with self.lock:
            if key in self.cache:
                timestamp, data = self.cache[key]
                if time.time() - timestamp < self.ttl:
                    return data
                else:
                    del self.cache[key]
        return None
        
    def set(self, key, data, *args):
        """Stocke une valeur dans le cache"""
        if args:
            import hashlib
            args_str = json.dumps(args, sort_keys=True)
            key = f"{key}_{hashlib.md5(args_str.encode()).hexdigest()}"
            
        with self.lock:
            self.cache[key] = (time.time(), data)
            
    def invalidate(self, prefix=None):
        """Invalide tout le cache ou les clés avec un préfixe donné"""
        with self.lock:
            if prefix:
                keys_to_remove = [k for k in self.cache.keys() if k.startswith(prefix)]
                for key in keys_to_remove:
                    del self.cache[key]
            else:
                self.cache.clear()
    
    def cleanup_expired(self):
        """Nettoie les entrées expirées du cache"""
        current_time = time.time()
        with self.lock:
            expired_keys = [
                key for key, (timestamp, _) in self.cache.items()
                if current_time - timestamp >= self.ttl
            ]
            for key in expired_keys:
                del self.cache[key]

# Instanciation des caches
status_cache = SimpleCache(ttl=15)
log_types_cache = SimpleCache(ttl=300)
log_stats_cache = SimpleCache(ttl=30)
server_config_cache = SimpleCache(ttl=300)
admin_role_cache = SimpleCache(ttl=300)
log_counts_cache = SimpleCache(ttl=60)

def check_db_connection():
    """Obsolète : ne fait rien. La vérification SQLite se fait automatiquement."""
    pass

def _sanitize_like_input(value):
    """
    Échappe les caractères spéciaux SQL LIKE pour prévenir les injections.
    """
    if not value:
        return ''
    value = str(value)
    value = value.replace('\\', '\\\\')
    value = value.replace('%', '\\%')
    value = value.replace('_', '\\_')
    return value[:500]

def _apply_filters(query, filters):
    """
    Applique les filtres sur la requête ServerLogModel.
    """
    if not filters:
        return query

    if filters.get('name'):
        safe_name = _sanitize_like_input(filters['name'])
        query = query.filter(ServerLogModel.data.like(f'%"name":"%{safe_name}%"%', escape='\\'))
    
    if filters.get('idunique'):
        safe_idunique = _sanitize_like_input(filters['idunique'])
        query = query.filter(ServerLogModel.data.like(f'%"idunique":%{safe_idunique}%', escape='\\'))
    
    if filters.get('message'):
        safe_message = _sanitize_like_input(filters['message'])
        query = query.filter(ServerLogModel.data.like(f'%"logs_message":"%{safe_message}%"%', escape='\\'))
    
    if filters.get('title'):
        safe_title = _sanitize_like_input(filters['title'])
        query = query.filter(ServerLogModel.data.like(f'%"logs_title":"%{safe_title}%"%', escape='\\'))
    
    if filters.get('author_id'):
        safe_author = _sanitize_like_input(filters['author_id'])
        query = query.filter(ServerLogModel.data.like(f'%"discord_id"%{safe_author}%', escape='\\'))
        
    if filters.get('date_start'):
        try:
            dt = datetime.fromisoformat(filters['date_start'].replace('Z', '+00:00'))
            query = query.filter(ServerLogModel.date >= dt)
        except ValueError:
            pass
            
    if filters.get('date_end'):
        try:
            dt = datetime.fromisoformat(filters['date_end'].replace('Z', '+00:00'))
            query = query.filter(ServerLogModel.date <= dt)
        except ValueError:
            pass
            
    if filters.get('type') and filters['type'] != 'all':
        query = query.filter(ServerLogModel.type == filters['type'])
        
    return query

def get_server_logs(server_id, page=1, filters=None, rows_per_page=10):
    """
    Récupère les logs d'un serveur depuis la base SQLite du Panel
    """
    # Valider l'existence du serveur
    if not server_config.is_valid_server(server_id):
        raise ValueError(f"Serveur {server_id} non valide")

    try:
        # Requête de base pour ce serveur
        base_query = ServerLogModel.query.filter_by(server_id=server_id)
        
        # Appliquer les filtres
        filtered_query = _apply_filters(base_query, filters)
        
        # Compter le total (optimisé)
        total_logs = filtered_query.count()
        
        if total_logs == 0:
            return [], 0
            
        # Récupérer les logs de la page
        logs = filtered_query.order_by(ServerLogModel.date.desc()).offset((page - 1) * rows_per_page).limit(rows_per_page).all()
        
        # Parser le JSON
        for log in logs:
            try:
                log.parsed_data = parse_json_fast(log.data)
            except Exception as e:
                logger.error(f"Erreur de parsing JSON pour le log {log.id}: {e}")
                log.parsed_data = {}
                
        return logs, total_logs
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des logs: {e}")
        raise

def check_server_db_status(server_id, use_cache=True):
    """Vérifie si un serveur existe et a configuré ses logs (maintenant toujours True s'il existe)"""
    if use_cache:
        cached_status = status_cache.get(server_id)
        if cached_status is not None:
            return cached_status
            
    server_conf = server_config.get_server(server_id)
    status = server_conf is not None
    
    # Mise en cache
    if use_cache:
        status_cache.set(server_id, status)
    
    return status


def get_log_type_counts(server_id):
    """
    Récupère les statistiques et les types de logs disponibles
    """
    cached = log_counts_cache.get(server_id)
    if cached:
        return cached
        
    try:
        # Extraire les types uniques et le comptage pour ce serveur
        rows = db.session.query(
            ServerLogModel.type, 
            func.count(ServerLogModel.id)
        ).filter(
            ServerLogModel.server_id == server_id,
            ServerLogModel.type != None
        ).group_by(ServerLogModel.type).all()
        
        types = []
        counts = {}
        for log_type, count in rows:
            if log_type:
                types.append(log_type)
                counts[log_type] = count
                
        types.sort()
        result = {'types': types, 'counts': counts}
        log_counts_cache.set(server_id, result)
        return result
    except Exception as e:
        logger.error(f"Erreur get_log_type_counts: {e}")
        return {'types': [], 'counts': {}}

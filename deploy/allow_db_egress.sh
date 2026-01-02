#!/bin/bash
# =============================================================================
# Script d'autorisation des connexions sortantes MySQL
# Lit servers_config.json et autorise les connexions vers les bases de données
# =============================================================================

# Ne pas utiliser set -e car certaines commandes (grep, ufw status) peuvent retourner 
# des codes d'erreur non-zéro sans que ce soit une vraie erreur
# set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Chemin par défaut
SERVERS_CONFIG="/var/www/logspanel/servers_config.json"
AUTO_MODE=false

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            SERVERS_CONFIG="$2"
            shift 2
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config PATH    Chemin vers servers_config.json (défaut: /var/www/logspanel/servers_config.json)"
            echo "  --auto           Mode automatique, sans confirmation"
            echo "  --help           Afficher cette aide"
            echo ""
            echo "Ce script autorise automatiquement les connexions sortantes (EGRESS)"
            echo "vers tous les serveurs MySQL configurés dans servers_config.json"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header() {
    echo ""
    printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}    ${BLUE}🔓 Configuration Firewall MySQL (EGRESS)${NC}                  ${CYAN}║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
    echo ""
}

print_success() {
    printf "${GREEN}  ✓ $1${NC}\n"
}

print_error() {
    printf "${RED}  ✗ $1${NC}\n"
}

print_info() {
    printf "${CYAN}  ℹ $1${NC}\n"
}

print_warning() {
    printf "${YELLOW}  ⚠ $1${NC}\n"
}

# Vérification root
if [[ $EUID -ne 0 ]]; then
    print_error "Ce script doit être exécuté en tant que root"
    echo "Utilisez: sudo $0"
    exit 1
fi

print_header

# Vérifier si le fichier existe
if [[ ! -f "$SERVERS_CONFIG" ]]; then
    print_error "Fichier non trouvé: $SERVERS_CONFIG"
    exit 1
fi

print_info "Lecture de: $SERVERS_CONFIG"

# Vérifier si python3 est installé
if ! command -v python3 &> /dev/null; then
    print_error "python3 n'est pas installé"
    exit 1
fi

# Extraire les hôtes et ports MySQL avec Python
DB_HOSTS=$(python3 <<PYTHON_SCRIPT
import json
import re
import sys

config_file = '${SERVERS_CONFIG}'

try:
    with open(config_file, 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    servers = config.get('servers', {})
    db_connections = []
    
    # Pattern pour parser les URIs MySQL
    # Format: mysql://user:password@host:port/database
    pattern = r'mysql(?:\+\w+)?://[^@]+@([^:/]+):(\d+)/'
    
    for server_name, server_config in servers.items():
        db_uri = server_config.get('database_uri', '')
        
        if not db_uri or db_uri.startswith('sqlite'):
            continue
        
        match = re.search(pattern, db_uri)
        if match:
            host = match.group(1)
            port = match.group(2)
            db_connections.append(f"{host}:{port}")
    
    # Dédupliquer
    db_connections = list(set(db_connections))
    
    # Afficher au format: host:port (un par ligne)
    for conn in sorted(db_connections):
        print(conn)
        
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
)

if [[ -z "$DB_HOSTS" ]]; then
    print_warning "Aucun serveur MySQL trouvé dans la configuration"
    exit 0
fi

echo ""
printf "${BLUE}Serveurs MySQL détectés:${NC}\n"
echo "$DB_HOSTS" | while read line; do
    if [[ -n "$line" ]]; then
        printf "  • $line\n"
    fi
done

echo ""

if [[ "$AUTO_MODE" == false ]]; then
    read -p "Autoriser ces connexions sortantes dans UFW? (o/n) [o]: " CONFIRM
    CONFIRM=${CONFIRM:-o}
    
    if [[ "$CONFIRM" != "o" && "$CONFIRM" != "O" ]]; then
        print_info "Opération annulée"
        exit 0
    fi
else
    print_info "Mode automatique activé"
fi

echo ""
print_info "Configuration des règles UFW..."

# Compteurs
ADDED=0
SKIPPED=0
FAILED=0

# Traiter chaque hôte
while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        continue
    fi
    
    HOST=$(echo "$line" | cut -d':' -f1)
    PORT=$(echo "$line" | cut -d':' -f2)
    
    # Vérifier si c'est une IP ou un hostname
    if [[ "$HOST" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # C'est une IP - Ajouter directement
        if ufw status 2>/dev/null | grep -q "$HOST.*$PORT" 2>/dev/null; then
            print_warning "Règle déjà existante pour $HOST:$PORT"
            ((SKIPPED++))
        else
            if ufw allow out to "$HOST" port "$PORT" proto tcp comment "MySQL $HOST" > /dev/null 2>&1; then
                print_success "Autorisé: $HOST:$PORT"
                ((ADDED++))
            else
                print_error "Échec: $HOST:$PORT"
                ((FAILED++))
            fi
        fi
    else
        # C'est un hostname - Résoudre en IP d'abord
        print_info "Résolution de $HOST..."
        RESOLVED_IP=$(host "$HOST" 2>/dev/null | grep "has address" | head -1 | awk '{print $4}')
        
        if [[ -n "$RESOLVED_IP" ]]; then
            print_success "  → $HOST résolu en $RESOLVED_IP"
            
            # Ajouter règle avec l'IP
            if ! ufw status 2>/dev/null | grep -q "$RESOLVED_IP.*$PORT" 2>/dev/null; then
                if ufw allow out to "$RESOLVED_IP" port "$PORT" proto tcp comment "MySQL $HOST (IP)" > /dev/null 2>&1; then
                    print_success "  → Règle IP ajoutée: $RESOLVED_IP:$PORT"
                    ((ADDED++))
                else
                    print_error "  → Échec règle IP: $RESOLVED_IP:$PORT"
                    ((FAILED++))
                fi
            else
                print_warning "  → Règle IP déjà existante"
                ((SKIPPED++))
            fi
            
            # Ajouter aussi règle avec hostname (au cas où l'IP change)
            if ! ufw status 2>/dev/null | grep -q "$HOST.*$PORT" 2>/dev/null; then
                if ufw allow out to "$HOST" port "$PORT" proto tcp comment "MySQL $HOST (hostname)" > /dev/null 2>&1; then
                    print_success "  → Règle hostname ajoutée: $HOST:$PORT"
                else
                    print_warning "  → Règle hostname non ajoutée (peut-être non supportée)"
                fi
            fi
        else
            # Impossible de résoudre - Essayer quand même avec le hostname
            print_warning "Impossible de résoudre $HOST, tentative avec hostname..."
            if ! ufw status 2>/dev/null | grep -q "$HOST.*$PORT" 2>/dev/null; then
                if ufw allow out to "$HOST" port "$PORT" proto tcp comment "MySQL $HOST" > /dev/null 2>&1; then
                    print_success "Autorisé: $HOST:$PORT"
                    ((ADDED++))
                else
                    print_error "Échec: $HOST:$PORT"
                    ((FAILED++))
                fi
            else
                print_warning "Règle déjà existante pour $HOST:$PORT"
                ((SKIPPED++))
            fi
        fi
    fi
done <<< "$DB_HOSTS"

# Recharger UFW
print_info "Rechargement de UFW..."
if ufw reload > /dev/null 2>&1; then
    print_success "UFW rechargé avec succès"
else
    print_warning "Impossible de recharger UFW (peut nécessiter une intervention manuelle)"
fi

echo ""
printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}\n"
printf "${CYAN}║${NC}    ${GREEN}✓ Configuration terminée${NC}                                   ${CYAN}║${NC}\n"
printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
echo ""

print_success "Règles ajoutées: $ADDED"
[[ $SKIPPED -gt 0 ]] && print_warning "Règles ignorées: $SKIPPED"
[[ $FAILED -gt 0 ]] && print_error "Règles échouées: $FAILED"

echo ""
print_info "Vérification des règles UFW:"
ufw status 2>/dev/null | grep -E "^[0-9]+.*ALLOW OUT" | head -10 || echo "Aucune règle ALLOW OUT trouvée"

echo ""
print_warning "N'oubliez pas de configurer les règles INGRESS sur les serveurs MySQL"
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "non disponible")
print_info "IP publique de ce serveur: $PUBLIC_IP"
echo ""

# Sortir avec succès même s'il y a eu des échecs (le service systemd considérera cela comme un succès)
exit 0

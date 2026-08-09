#!/bin/bash
# =============================================================================
# Script d'installation - Panel Logs Galaxy
# Ubuntu 24.04 + Cloudflare Tunnels
# =============================================================================
#
# Usage:
#   sudo ./install.sh                  # Installation interactive
#   sudo ./install.sh --auto           # Installation automatique
#   sudo ./install.sh --skip-tunnel    # Ignorer la config Cloudflare Tunnel
#   sudo ./install.sh --path /chemin   # Chemin d'installation personnalisé
#   sudo ./install.sh --user www-data  # Utilisateur du service
#
# Le script détecte automatiquement si un Cloudflare Tunnel est déjà
# configuré et en cours d'exécution. Dans ce cas, il propose de le conserver.
#
# =============================================================================

set -e

# Trap pour afficher les erreurs
trap 'echo "ERREUR à la ligne $LINENO: commande \"$BASH_COMMAND\" a échoué avec le code $?"' ERR

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables par défaut
DEPLOY_PATH="/var/www/logspanel"
SERVICE_USER="www-data"
PORT="3001"
AUTO_MODE=false
SKIP_TUNNEL=false
TUNNEL_ALREADY_RUNNING=false

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --path)
            DEPLOY_PATH="$2"
            shift 2
            ;;
        --user)
            SERVICE_USER="$2"
            shift 2
            ;;
        --skip-tunnel)
            SKIP_TUNNEL=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Fonctions d'affichage
print_banner() {
    echo ""
    printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}    ${BLUE}🚀 Panel Logs Galaxy - Installation${NC}                          ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}    ${BLUE}Ubuntu 24.04 + Cloudflare Tunnels${NC}                            ${CYAN}║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
    echo ""
}

print_step() {
    printf "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${BLUE}▶ $1${NC}\n"
    printf "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    printf "${GREEN}  ✓ $1${NC}\n"
}

print_error() {
    printf "${RED}  ✗ $1${NC}\n"
}

print_warning() {
    printf "${YELLOW}  ⚠ $1${NC}\n"
}

print_info() {
    printf "${CYAN}  ℹ $1${NC}\n"
}

# Vérification root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

# Installation du binaire cloudflared uniquement
# (défini ici car utilisé par detect_existing_tunnel)
install_cloudflared_binary() {
    # Détection de l'architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            CF_ARCH="amd64"
            ;;
        aarch64|arm64)
            CF_ARCH="arm64"
            ;;
        armv7l)
            CF_ARCH="arm"
            ;;
        *)
            print_error "Architecture non supportée: $ARCH"
            return 1
            ;;
    esac
    
    # Téléchargement
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$CF_ARCH"
    curl -sL "$CF_URL" -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    
    print_success "cloudflared mis à jour: $(cloudflared --version 2>&1 | head -1)"
}

# Détection d'un tunnel Cloudflare existant
detect_existing_tunnel() {
    print_step "Détection de Cloudflare Tunnel existant"
    
    local tunnel_detected=false
    local tunnel_running=false
    local tunnel_name=""
    local tunnel_hostname=""
    
    # Vérifier si cloudflared est installé
    if command -v cloudflared &>/dev/null; then
        print_info "cloudflared installé: $(cloudflared --version 2>&1 | head -1)"
        tunnel_detected=true
    else
        print_info "cloudflared non installé"
        return 0
    fi
    
    # Vérifier si le service cloudflared est actif
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        tunnel_running=true
        print_success "Service cloudflared actif"
    fi
    
    # Vérifier si une configuration existe
    if [[ -f /etc/cloudflared/config.yml ]]; then
        print_success "Configuration trouvée: /etc/cloudflared/config.yml"
        
        # Extraire le hostname depuis la config
        tunnel_hostname=$(grep -E "^\s*-?\s*hostname:" /etc/cloudflared/config.yml 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "")
        if [[ -n "$tunnel_hostname" ]]; then
            print_info "Domaine configuré: $tunnel_hostname"
        fi
        
        # Extraire le tunnel ID
        tunnel_id=$(grep -E "^tunnel:" /etc/cloudflared/config.yml 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
        if [[ -n "$tunnel_id" && "$tunnel_id" != "VOTRE_TUNNEL_ID" ]]; then
            print_info "Tunnel ID: $tunnel_id"
        fi
    fi
    
    # Vérifier si les credentials existent
    if [[ -f /etc/cloudflared/credentials.json ]]; then
        print_success "Fichier credentials présent"
    fi
    
    # Si un tunnel est détecté et fonctionne
    if [[ "$tunnel_detected" == true ]]; then
        echo ""
        
        if [[ "$tunnel_running" == true ]]; then
            printf "${GREEN}  ✓ Un tunnel Cloudflare est déjà actif et fonctionnel !${NC}\n"
            TUNNEL_ALREADY_RUNNING=true
            
            # Tester la connexion au tunnel
            if [[ -n "$tunnel_hostname" ]]; then
                echo ""
                print_info "Test de connexion au tunnel..."
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$tunnel_hostname" 2>/dev/null || echo "000")
                if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "503" ]]; then
                    print_success "Tunnel accessible via https://$tunnel_hostname"
                else
                    print_warning "Tunnel configuré mais non accessible (HTTP $HTTP_CODE)"
                fi
            fi
        fi
        
        echo ""
        if [[ "$AUTO_MODE" == false && "$SKIP_TUNNEL" == false ]]; then
            printf "${YELLOW}  Que voulez-vous faire ?${NC}\n"
            echo "  1. Conserver le tunnel existant (recommandé)"
            echo "  2. Reconfigurer le tunnel"
            echo "  3. Mettre à jour cloudflared uniquement"
            echo ""
            read -p "Choix [1]: " TUNNEL_CHOICE
            TUNNEL_CHOICE=${TUNNEL_CHOICE:-1}
            
            case $TUNNEL_CHOICE in
                1)
                    SKIP_TUNNEL=true
                    print_info "Conservation du tunnel existant"
                    ;;
                2)
                    SKIP_TUNNEL=false
                    print_info "Le tunnel sera reconfiguré"
                    ;;
                3)
                    SKIP_TUNNEL=true
                    # Forcer la mise à jour de cloudflared
                    install_cloudflared_binary
                    ;;
            esac
        elif [[ "$TUNNEL_ALREADY_RUNNING" == true ]]; then
            # En mode auto, conserver le tunnel existant s'il fonctionne
            SKIP_TUNNEL=true
            print_info "Mode auto: conservation du tunnel existant"
        fi
    fi
}

# Vérification Ubuntu 24.04
check_ubuntu() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]] || [[ ! "$VERSION_ID" =~ ^24 ]]; then
            print_warning "Ce script est optimisé pour Ubuntu 24.04"
            print_warning "Système détecté: $PRETTY_NAME"
            if [[ "$AUTO_MODE" == false ]]; then
                read -p "Continuer quand même? (o/n) [n]: " CONTINUE
                if [[ "$CONTINUE" != "o" && "$CONTINUE" != "O" ]]; then
                    exit 1
                fi
            fi
        fi
    fi
}

# Configuration interactive
configure_installation() {
    if [[ "$AUTO_MODE" == false ]]; then
        print_step "Configuration de l'installation"
        
        read -p "Chemin d'installation [$DEPLOY_PATH]: " input
        DEPLOY_PATH="${input:-$DEPLOY_PATH}"
        
        read -p "Utilisateur du service [$SERVICE_USER]: " input
        SERVICE_USER="${input:-$SERVICE_USER}"
        
        read -p "Port de l'application [$PORT]: " input
        PORT="${input:-$PORT}"
        
        echo ""
        print_info "Configuration:"
        echo "  • Chemin: $DEPLOY_PATH"
        echo "  • Utilisateur: $SERVICE_USER"
        echo "  • Port: $PORT"
        echo ""
        
        read -p "Confirmer? (o/n) [o]: " CONFIRM
        if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
            exit 0
        fi
    fi
}

# Installation des dépendances système
install_dependencies() {
    print_step "Installation des dépendances système"
    
    apt update -qq
    print_success "Liste des paquets mise à jour"
    
    apt install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        pkg-config \
        default-libmysqlclient-dev \
        curl \
        git \
        > /dev/null 2>&1
    
    print_success "Dépendances Python installées"
}

# Installation de cloudflared
install_cloudflared() {
    # Si on doit sauter l'installation du tunnel
    if [[ "$SKIP_TUNNEL" == true ]]; then
        print_step "Cloudflare Tunnel (conservation de l'existant)"
        print_info "Le tunnel existant sera conservé"
        return 0
    fi
    
    print_step "Installation de Cloudflare Tunnel (cloudflared)"
    
    if command -v cloudflared &> /dev/null; then
        CURRENT_VERSION=$(cloudflared --version 2>&1 | head -1)
        print_info "cloudflared déjà installé: $CURRENT_VERSION"
        
        if [[ "$AUTO_MODE" == false ]]; then
            read -p "Mettre à jour le binaire? (o/n) [n]: " UPDATE_CF
            if [[ "$UPDATE_CF" == "o" || "$UPDATE_CF" == "O" ]]; then
                install_cloudflared_binary
            fi
            return 0
        else
            return 0
        fi
    fi
    
    install_cloudflared_binary
}

# Création de l'utilisateur système
create_user() {
    print_step "Configuration de l'utilisateur $SERVICE_USER"
    
    if id "$SERVICE_USER" &>/dev/null; then
        print_info "L'utilisateur $SERVICE_USER existe déjà"
    else
        useradd -r -s /bin/false "$SERVICE_USER"
        print_success "Utilisateur $SERVICE_USER créé"
    fi
}

# Copie des fichiers du projet
deploy_files() {
    print_step "Déploiement des fichiers"
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    
    # Créer le répertoire de destination
    mkdir -p "$DEPLOY_PATH"
    
    # Copier les fichiers (sauf deploy/ et venv/)
    rsync -av --exclude='deploy' --exclude='venv' --exclude='.git' \
        --exclude='__pycache__' --exclude='*.pyc' --exclude='instance/*.db' \
        "$PROJECT_DIR/" "$DEPLOY_PATH/"
    
    print_success "Fichiers copiés vers $DEPLOY_PATH"
}

# Configuration de l'environnement Python
setup_python_env() {
    print_step "Configuration de l'environnement Python"
    
    cd "$DEPLOY_PATH"
    
    # Supprimer l'ancien venv si présent
    [[ -d "venv" ]] && rm -rf venv
    
    # Créer le nouvel environnement
    python3 -m venv venv
    print_success "Environnement virtuel créé"
    
    # Activer et installer les dépendances
    source venv/bin/activate
    pip install --upgrade pip setuptools wheel -q
    pip install -r requirements.txt -q
    
    print_success "Dépendances Python installées"
    
    deactivate
}

# Configuration des permissions
set_permissions() {
    print_step "Configuration des permissions"
    
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_PATH"
    
    # Permissions des répertoires
    find "$DEPLOY_PATH" -type d -exec chmod 755 {} \;
    
    # Permissions des fichiers
    find "$DEPLOY_PATH" -type f -exec chmod 644 {} \;
    
    # Scripts exécutables
    find "$DEPLOY_PATH" -name "*.sh" -exec chmod 755 {} \;
    chmod +x "$DEPLOY_PATH/venv/bin/"*
    
    # Fichiers sensibles
    [[ -f "$DEPLOY_PATH/.env" ]] && chmod 600 "$DEPLOY_PATH/.env"
    
    # Répertoire instance (écriture pour la DB)
    mkdir -p "$DEPLOY_PATH/instance"
    chmod 755 "$DEPLOY_PATH/instance"
    
    print_success "Permissions configurées"
}

# Installation du service systemd
install_service() {
    print_step "Installation du service systemd"
    
    # Créer le fichier de service
    cat > /etc/systemd/system/logspanel.service << EOF
[Unit]
Description=Panel Logs Galaxy - Flask/Gunicorn
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
NotifyAccess=all
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$DEPLOY_PATH

Environment="PATH=$DEPLOY_PATH/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PORT=$PORT"
Environment="PYTHONUNBUFFERED=1"
EnvironmentFile=-$DEPLOY_PATH/.env

ExecStart=$DEPLOY_PATH/venv/bin/gunicorn --config $DEPLOY_PATH/gunicorn_config.py main:app
ExecStop=/bin/kill -s TERM \$MAINPID
TimeoutStopSec=30

Restart=always
RestartSec=10

LimitNOFILE=65535
LimitNPROC=4096

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$DEPLOY_PATH/instance
ReadWritePaths=/tmp

StandardOutput=journal
StandardError=journal
SyslogIdentifier=logspanel

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable logspanel
    
    print_success "Service logspanel installé"
}

# Configuration de Cloudflare Tunnel
setup_cloudflare_tunnel() {
    # Si le tunnel existe déjà et fonctionne, on saute cette étape
    if [[ "$SKIP_TUNNEL" == true ]]; then
        print_step "Configuration de Cloudflare Tunnel (existant)"
        
        if [[ "$TUNNEL_ALREADY_RUNNING" == true ]]; then
            print_success "Tunnel existant conservé et fonctionnel"
            
            # Afficher les infos du tunnel existant
            if [[ -f /etc/cloudflared/config.yml ]]; then
                tunnel_hostname=$(grep -E "^\s*-?\s*hostname:" /etc/cloudflared/config.yml 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "")
                if [[ -n "$tunnel_hostname" ]]; then
                    print_info "Domaine: https://$tunnel_hostname"
                fi
            fi
        else
            print_info "Configuration du tunnel conservée"
        fi
        return 0
    fi
    
    print_step "Configuration de Cloudflare Tunnel"
    
    print_info "Le tunnel Cloudflare nécessite une configuration manuelle."
    echo ""
    printf "${YELLOW}  Étapes à suivre :${NC}\n"
    echo "  1. Authentifiez-vous:    cloudflared tunnel login"
    echo "  2. Créez le tunnel:      cloudflared tunnel create logspanel"
    echo "  3. Copiez l'ID du tunnel affiché"
    echo "  4. Configurez le DNS:    cloudflared tunnel route dns logspanel votre-domaine.com"
    echo ""
    
    # Créer le répertoire de configuration
    mkdir -p /etc/cloudflared
    
    # Copier le template de configuration
    if [[ -f "$DEPLOY_PATH/deploy/cloudflared.yml" ]]; then
        cp "$DEPLOY_PATH/deploy/cloudflared.yml" /etc/cloudflared/config.yml.template
        print_info "Template de configuration copié vers /etc/cloudflared/config.yml.template"
    fi
    
    echo ""
    printf "${YELLOW}  Après avoir créé le tunnel, exécutez :${NC}\n"
    echo "  1. Éditez /etc/cloudflared/config.yml avec votre TUNNEL_ID"
    echo "  2. Copiez le fichier credentials: "
    echo "     cp ~/.cloudflared/<TUNNEL_ID>.json /etc/cloudflared/credentials.json"
    echo "  3. Installez le service: cloudflared service install"
    echo ""
}

# Configuration du firewall
setup_firewall() {
    print_step "Configuration du firewall (UFW)"
    
    if ! command -v ufw &> /dev/null; then
        apt install -y -qq ufw
    fi
    
    # Configurer les règles
    ufw --force reset > /dev/null 2>&1
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    
    # NE PAS ouvrir le port de l'application - Cloudflare Tunnel y accède en local
    # ufw allow $PORT  # SURTOUT PAS !
    
    ufw --force enable
    
    print_success "Firewall configuré"
    print_info "Seul SSH est accessible depuis l'extérieur"
    print_info "Le panel est accessible uniquement via Cloudflare Tunnel"
}

# Vérification de la configuration
verify_installation() {
    print_step "Vérification de l'installation"
    
    local errors=0
    
    # Vérifier les fichiers
    if [[ -f "$DEPLOY_PATH/main.py" ]]; then
        print_success "Fichiers du projet présents"
    else
        print_error "main.py non trouvé"
        ((errors++))
    fi
    
    # Vérifier l'environnement Python
    if [[ -f "$DEPLOY_PATH/venv/bin/python" ]]; then
        print_success "Environnement Python configuré"
    else
        print_error "Environnement Python manquant"
        ((errors++))
    fi
    
    # Vérifier le service
    if systemctl is-enabled logspanel &>/dev/null; then
        print_success "Service logspanel activé"
    else
        print_error "Service logspanel non activé"
        ((errors++))
    fi
    
    # Vérifier cloudflared
    if command -v cloudflared &>/dev/null; then
        print_success "cloudflared installé"
    else
        print_warning "cloudflared non installé"
    fi
    
    # Vérifier le fichier .env
    if [[ -f "$DEPLOY_PATH/.env" ]]; then
        print_success "Fichier .env présent"
    else
        print_warning "Fichier .env manquant - copiez env.example vers .env"
    fi
    
    return $errors
}

# Démarrage du service
start_service() {
    print_step "Démarrage du service"
    
    systemctl start logspanel
    sleep 3
    
    if systemctl is-active --quiet logspanel; then
        print_success "Service logspanel démarré"
        
        # Test local
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" | grep -q "200\|302"; then
            print_success "Le panel répond sur localhost:$PORT"
        else
            print_warning "Le panel ne répond pas encore (peut prendre quelques secondes)"
        fi
    else
        print_error "Le service n'a pas démarré"
        print_info "Vérifiez les logs: journalctl -u logspanel -n 50"
    fi
}

# Résumé final
print_summary() {
    echo ""
    printf "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}    ${GREEN}✓ Installation terminée !${NC}                                   ${CYAN}║${NC}\n"
    printf "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}\n"
    echo ""
    
    printf "${BLUE}📁 Emplacement :${NC} $DEPLOY_PATH\n"
    printf "${BLUE}🔌 Port local :${NC} $PORT\n"
    printf "${BLUE}👤 Utilisateur :${NC} $SERVICE_USER\n"
    
    # Afficher l'URL si le tunnel est actif
    if [[ "$TUNNEL_ALREADY_RUNNING" == true ]]; then
        if [[ -f /etc/cloudflared/config.yml ]]; then
            tunnel_hostname=$(grep -E "^\s*-?\s*hostname:" /etc/cloudflared/config.yml 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || echo "")
            if [[ -n "$tunnel_hostname" ]]; then
                printf "${BLUE}🌐 URL :${NC} https://$tunnel_hostname\n"
            fi
        fi
        printf "${GREEN}🚀 Tunnel :${NC} Actif et fonctionnel\n"
    fi
    echo ""
    
    printf "${YELLOW}📋 Prochaines étapes :${NC}\n"
    echo ""
    
    # Étape 1: Configuration .env
    if [[ ! -f "$DEPLOY_PATH/.env" ]]; then
        echo "  1. Configurez votre fichier .env :"
        echo "     cp $DEPLOY_PATH/env.example $DEPLOY_PATH/.env"
        echo "     nano $DEPLOY_PATH/.env"
        echo ""
    else
        echo "  1. ✓ Fichier .env déjà présent"
        echo ""
    fi
    
    # Étape 2: Cloudflare Tunnel (seulement si pas déjà configuré)
    if [[ "$TUNNEL_ALREADY_RUNNING" == true ]]; then
        echo "  2. ✓ Cloudflare Tunnel déjà configuré et actif"
        echo ""
    elif [[ "$SKIP_TUNNEL" == true ]]; then
        echo "  3. ✓ Configuration Cloudflare Tunnel conservée"
        echo "     Vérifiez que le service est actif : systemctl status cloudflared"
        echo ""
    else
        echo "  3. Configurez Cloudflare Tunnel :"
        echo "     cloudflared tunnel login"
        echo "     cloudflared tunnel create logspanel"
        echo "     # Éditez /etc/cloudflared/config.yml"
        echo "     cloudflared service install"
        echo ""
    fi
    
    # Étape 4: Redémarrage
    echo "  4. Redémarrez le panel (si vous avez modifié la config) :"
    echo "     sudo systemctl restart logspanel"
    echo ""
    
    printf "${BLUE}🔧 Commandes utiles :${NC}\n"
    echo "  • Statut:     sudo systemctl status logspanel"
    echo "  • Logs:       sudo journalctl -u logspanel -f"
    echo "  • Redémarrer: sudo systemctl restart logspanel"
    echo "  • Tunnel:     sudo journalctl -u cloudflared -f"
    echo "  • Gestion:    sudo $DEPLOY_PATH/manage.sh"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

check_root
print_banner
check_ubuntu
configure_installation

# Détecter si un tunnel existe déjà AVANT d'installer quoi que ce soit
detect_existing_tunnel

install_dependencies
install_cloudflared
create_user
deploy_files
setup_python_env
set_permissions
install_service
setup_cloudflare_tunnel
setup_firewall
verify_installation
start_service
print_summary

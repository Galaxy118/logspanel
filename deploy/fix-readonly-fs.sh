#!/bin/bash

# Script de correction du problème "Read-only file system"
# Ce script résout le problème de ProtectSystem=strict dans systemd

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Correction du problème de système de fichiers en lecture seule..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Étape 1 : Remonter le système en RW
echo "📁 Étape 1/4 - Remontage du système de fichiers en lecture-écriture"
if mount | grep " / " | grep -q "(ro"; then
    echo "⚠️  Système en lecture seule, remontage..."
    mount -o remount,rw /
    echo "✅ Système remonté en lecture-écriture"
else
    echo "✅ Système déjà en lecture-écriture"
fi
echo ""

# Étape 2 : Installer le service de surveillance keepfs-rw
echo "📋 Étape 2/4 - Installation du service de surveillance keepfs-rw"
if [ -f "/etc/systemd/system/keepfs-rw.service" ]; then
    echo "ℹ️  Service déjà installé, mise à jour..."
fi

cat > /etc/systemd/system/keepfs-rw.service << 'EOF'
[Unit]
Description=Keep Filesystem Read-Write
After=multi-user.target
Documentation=https://github.com/votre-repo/panellogs

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do if mount | grep " / " | grep -q "(ro"; then mount -o remount,rw / && logger "KeepFS-RW: Remounted / as RW"; fi; sleep 5; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable keepfs-rw
systemctl restart keepfs-rw

if systemctl is-active --quiet keepfs-rw; then
    echo "✅ Service keepfs-rw installé et démarré"
else
    echo "⚠️  Attention : Le service keepfs-rw n'a pas démarré correctement"
fi
echo ""

# Étape 3 : Mettre à jour logspanel.service
echo "⚙️  Étape 3/4 - Mise à jour du service logspanel"
if [ -f "/var/www/logspanel/deploy/logspanel.service" ]; then
    cp /var/www/logspanel/deploy/logspanel.service /etc/systemd/system/
    systemctl daemon-reload
    echo "✅ Service logspanel.service mis à jour"
else
    echo "⚠️  Fichier deploy/logspanel.service non trouvé, skip..."
fi
echo ""

# Étape 4 : Vérifier les permissions et redémarrer
echo "🔐 Étape 4/4 - Permissions et redémarrage"
chown -R www-data:www-data /var/www/logspanel
chmod 664 /var/www/logspanel/servers_config.json
chmod 600 /var/www/logspanel/.env
echo "✅ Permissions corrigées"

systemctl restart logspanel
sleep 2

if systemctl is-active --quiet logspanel; then
    echo "✅ Panel redémarré avec succès"
else
    echo "❌ Erreur : Le panel n'a pas démarré correctement"
    echo "Vérifiez les logs : journalctl -u logspanel -n 50"
    exit 1
fi
echo ""

# Résumé
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Correction terminée avec succès !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Statut des services :"
systemctl status keepfs-rw logspanel --no-pager | grep -E "Active:|Main PID:"
echo ""
echo "🔍 Pour surveiller les logs :"
echo "   sudo journalctl -u logspanel -u keepfs-rw -f"
echo ""
echo "🧪 Testez maintenant la création/modification d'un serveur via l'interface web"
echo ""

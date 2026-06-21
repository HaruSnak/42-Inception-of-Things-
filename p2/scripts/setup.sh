#!/bin/bash

# Mise à jour et installation des dépendances (curl est indispensable)
sudo apt-get update -y
sudo apt-get install -y curl

# Installation de K3s en mode Server
# On fixe l'IP à 192.168.56.110 comme demandé
# --write-kubeconfig-mode 644 permet d'utiliser kubectl sans sudo
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --write-kubeconfig-mode 644" sh -

# Attente que le nœud soit prêt
# Attente active plutôt qu'un sleep fixe : le temps de démarrage de K3s varie
# selon les ressources disponibles. Un sleep fixe risque de lancer kubectl apply
# avant que l'API server soit prêt, ce qui fait échouer le déploiement silencieusement.
echo "Attente du démarrage de K3s..."
until kubectl get nodes 2>/dev/null | grep -q " Ready"; do sleep 5; done

# Déploiement des applications
# On applique tous les fichiers YAML (apps + ingress) d'un coup 
if [ -d "/vagrant/confs" ]; then
	echo "Déploiement des manifestes Kubernetes depuis /confs..."
	kubectl apply -f /vagrant/confs/
else
	echo "Erreur : Le dossier /vagrant/confs est introuvable."
	exit 1
fi


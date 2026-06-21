#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

# 1. Installation de K3s en mode server (Controller)
# On force l'IP sur l'interface réseau privée et on donne les droits de lecture au Kubeconfig
# --write-kubeconfig-mode 644 : K3s crée /etc/rancher/k3s/k3s.yaml en 600 (root seul) par défaut.
# Sans ce flag, kubectl échoue pour l'utilisateur vagrant sans sudo.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --write-kubeconfig-mode 644" sh -

# 2. Partage du token via le dossier synchronisé de Vagrant
# On attend que le fichier soit généré par K3s
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
	sleep 2
done
sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/confs/token

# 3. Installation de kubectl (souvent déjà inclus avec K3s)
# On s'assure qu'il est accessible sans sudo pour l'utilisateur vagrant
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
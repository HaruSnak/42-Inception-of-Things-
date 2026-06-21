#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y curl

# Attente du token généré par le serveur.
# Pas de timeout : Vagrant provisionne les machines séquentiellement (Server puis Worker),
# donc le token est forcément présent quand ce script démarre — la boucle est une sécurité
# contre le délai d'écriture disque sur le dossier partagé.
echo "Attente du token du serveur dans /vagrant/token..."
while [ ! -f /vagrant/confs/token ]; do
	sleep 2
done

# 2. Récupération du token
TOKEN=$(cat /vagrant/confs/token)

# 3. Installation de K3s en mode Agent
# On pointe vers l'IP du serveur (192.168.56.110) avec le token récupéré
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$TOKEN sh -s - agent --node-ip=192.168.56.111
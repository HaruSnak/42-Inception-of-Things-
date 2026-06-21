#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Installation de Docker (si absent)
if ! command -v docker &> /dev/null; then
	echo -e "${GREEN}Installation de Docker...${NC}"
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Installation de K3d (si absent)
if ! command -v k3d &> /dev/null; then
	echo -e "${GREEN}Installation de K3d...${NC}"
	curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG=v5.6.0 bash
fi

# Installation de Kubectl (si absent)
if ! command -v kubectl &> /dev/null; then
	echo -e "${GREEN}Installation de Kubectl...${NC}"
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
	sudo install -m 0755 kubectl /usr/local/bin/kubectl
	rm kubectl
fi

# Création du Cluster K3d
echo -e "${GREEN}Création du cluster K3d...${NC}"
# On mappe le port 8888 pour l'application de Wil
k3d cluster create mycluster --port 8080:80@loadbalancer --port 8888:8888@loadbalancer --wait

# Configuration des Namespaces et Argo CD
echo -e "${GREEN}Configuration de Kubernetes...${NC}"
kubectl create namespace argocd
kubectl create namespace dev

# Installation d'Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Sans cette attente, kubectl apply -f - échoue avec "no matches for kind Application" :
# le CRD est créé par le manifeste Argo CD mais l'API server met plusieurs secondes
# à l'enregistrer, même si les pods ne sont pas encore Running.
echo -e "${GREEN}Attente des CRDs Argo CD...${NC}"
kubectl wait --for=condition=established crd/applications.argoproj.io --timeout=120s

# Liaison avec le dépôt GitHub
echo -e "${GREEN}Liaison du dépôt GitHub avec Argo CD...${NC}"

# Liaison entre Argo CD et le dépôt GitHub
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: harusnaks-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/HaruSnak/42-shmorenos-iot'
    targetRevision: HEAD
    path: confs
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo -e "\n${BLUE}===================================================================${NC}"
echo -e "${BLUE}                   RÉCAP POUR L'ÉVAL         					     ${NC}"
echo -e "${BLUE}=====================================================================${NC}"

# 1. Accès à l'Interface Argo CD [cite: 501]
echo -e "${GREEN}1. ACCÉDER À L'INTERFACE ARGO CD:${NC}"
PASS=\$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "   - URL     : https://localhost:8081"
echo -e "   - User    : admin"
echo -e "   - Password: \$PASS"
echo -e "   - Commande pour le tunnel (à lancer dans un autre terminal):"
echo -e "     kubectl port-forward svc/argocd-server -n argocd 8081:443"

echo -e "\n${GREEN}2. VÉRIFICATION DES NAMESPACES[cite: 460]:${NC}"
echo -e "   kubectl get ns"

echo -e "\n${GREEN}3. TEST DE L'APPLICATION (Port 8888 ):${NC}"
echo -e "   - Version actuelle (v1):"
echo -e "     curl http://localhost:8888/"
echo -e "   - Surveiller le changement de pod lors du push v2:"
echo -e "     kubectl get pods -n dev -w"

echo -e "\n${BLUE}==================================================================${NC}"
echo -e "Check du déploiement des composants --> (kubectl get pods -A)"
#!/bin/bash

# Configuration des couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}      INSTALLATION FINALE : GITLAB + ARGO CD        ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Nettoyage initial pour mes multiples soucis durant mes tests
echo -e "${GREEN}Nettoyage...${NC}"
pkill -f "port-forward" || true
k3d cluster delete bonus-cluster 2>/dev/null

# Création du Cluster
echo -e "${GREEN}Création du cluster K3d...${NC}"
k3d cluster create bonus-cluster \
	-p "80:80@loadbalancer" \
	-p "8888:80@loadbalancer" \
	--agents 2 --wait

# Namespaces
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

# Installation GitLab (Optimisé anti-422)
echo -e "${GREEN}Installation de GitLab (Helm)...${NC}"
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null
helm repo update
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --set global.hosts.domain=127.0.0.1 \
  --set global.hosts.externalIP=127.0.0.1 \
  --set global.hosts.https=false \
  --set global.edition=ce \
  --set gitlab.kas.install=false \
  --set gitlab.gitlab-runner.install=false \
  --set gitlab.prometheus.install=false \
  --set global.ingress.configureCertmanager=false \
  --set postgresql.image.tag=16.4.0 \
  --set redis.image.tag=7.2.5 \
  --set gitlab.webservice.resources.requests.memory=768Mi \
  --timeout 600s

# Installation Argo CD
echo -e "${GREEN}Installation d'Argo CD...${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Attentes Critiques
echo -e "${BLUE}Attente des définitions d'objets Argo CD...${NC}"
kubectl wait --for=condition=established crd/applications.argoproj.io --timeout=60s

echo -e "${BLUE}Attente que GitLab soit prêt (~5 min)...${NC}"
kubectl wait --for=condition=ready pod -l app=webservice -n gitlab --timeout=600s

# Extraction et Encodage de l'Authentification
echo -e "${GREEN}Configuration de l'accès GitOps...${NC}"
GITLAB_PASS=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode)
# GitLab génère un mot de passe avec des caractères spéciaux (@, #, !, etc.).
# Intégrés tels quels dans une URL Git, ils cassent le parsing de l'URL.
# L'encodage URL (%-encoding) est obligatoire pour qu'Argo CD puisse cloner le repo.
ENCODED_PASS=$(echo -n "$GITLAB_PASS" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))")

# Création de l'Application Argo CD (Version Authentifiée)
echo -e "${GREEN}Déploiement de l'Application bonus-app...${NC}"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bonus-app
  namespace: argocd
spec:
  project: default
  source:
    # On injecte root:mot_de_passe@ directement pour éviter les erreurs de droits
    repoURL: 'http://root:${ENCODED_PASS}@gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot-project.git'
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

# Tunnels et Affichage des Accès
echo -e "${GREEN}Lancement des tunnels réseau...${NC}"
kubectl port-forward -n gitlab svc/gitlab-webservice-default 8080:8181 > /dev/null 2>&1 &
kubectl port-forward -n argocd svc/argocd-server 8081:443 > /dev/null 2>&1 &
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}INSTALLATION PROPRE TERMINÉE !${NC}"
echo -e "\n${BLUE}LES ACCÈS :${NC}"
echo -e "  GITLAB : http://127.0.0.1:8080 (Login: root / Pass: ${GITLAB_PASS})"
echo -e "  ARGO CD: https://localhost:8081 (Login: admin / Pass: ${ARGO_PASS})"
echo -e "\n${RED}DERNIÈRE ÉTAPE :${NC}"
echo -e "  1. Créez le projet 'iot-project' en PUBLIC sur GitLab."
echo -e "  2. Poussez les YAML dans un dossier nommé 'confs'."
echo -e "${BLUE}====================================================${NC}"

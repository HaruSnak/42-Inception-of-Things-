# Couleurs
GREEN   = \033[0;32m
RED     = \033[0;31m
RESET   = \033[0m

.PHONY: all clean re status

all:
	@echo "$(GREEN)Lancement de la Partie 1 (Vagrant up)...$(RESET)"
	@vagrant up

parallel:
	@echo "$(GREEN)Lancement de la Partie 1 en Vagrant parallel...$(RESET)" 
	@vagrant up --parallel

status:
	@echo "$(GREEN)Statut des machines de la Partie 1 :$(RESET)"
	@vagrant status

clean:
	@echo "$(RED)Destruction des machines de la Partie 1...$(RESET)"
	@vagrant destroy -f
	@echo "$(RED)Suppression du token partagé...$(RESET)"
	@rm -f confs/token

re: clean all

# Pour vérifier si les noeuds sont bien "Ready" sans entrer dans la VM
check-nodes:
	@echo "$(GREEN)Vérification des noeuds du cluster K3s :$(RESET)"
	@vagrant ssh $${USER}S -c "kubectl get nodes -o wide"
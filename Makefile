.PHONY:  deploy help
SSH_USER ?= $${USER}


help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deploy: ## Triggers deployment to prod
	ANSIBLE_CONFIG="deploy/ansible.cfg" \
	  ansible-playbook \
	  -e ansible_user=$(SSH_USER) \
	  --inventory deploy/ansible/inventory.linode.yml \
	  deploy/ansible/playbook.yml

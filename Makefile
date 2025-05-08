SHELL=/bin/bash

# get digitalocean token
DO_TOKEN := $(shell secret-tool lookup token digitalocean)

tf-init:
	@ terraform init

tf-fmt:
	terraform fmt .

tf-validate:
	terraform validate .

tf-plan:
	@ terraform plan -var "do_token=$(DO_TOKEN)"

tf-apply:
	@ terraform apply -var "do_token=$(DO_TOKEN)"

tf-destroy:
	@ terraform apply -destroy -var "do_token=$(DO_TOKEN)"

tf-refresh:
	@ terraform refresh -var "do_token=$(DO_TOKEN)"

# display output again
tf-output:
	@ terraform output

# show status
tf-show:
	@ terraform show

##
## ansible commands
##

# ssh keys
root_ssh_key := ~/.ssh/do_test
ansibleuser_ssh_key := ssh/ansible_user

# nginx servers
ip_www_server_01 := xxx.xxx.xxx.xxx
ip_www_server_02 := yyy.yyy.yyy.yyy
ip_www_server_03 := zzz.zzz.zzz.zzz

# directory for ansibleuser ssh key
ssh-dir := ssh

# ssh for root uses ssh-key uploaded to digitalocean
ssh-root-01:
	ssh -o "IdentitiesOnly=yes" -i ${root_ssh_key} root@${ip_www_server_01}

ssh-root-02:
	ssh -o "IdentitiesOnly=yes" -i ${root_ssh_key} root@${ip_www_server_02}

ssh-root-03:
	ssh -o "IdentitiesOnly=yes" -i ${root_ssh_key} root@${ip_www_server_03}

# ssh for ansibleuser
$(ssh-dir):
	@echo "Directory 'ssh' does not exist; creating dir and key"
	mkdir ssh
	ssh-keygen -t rsa -b 4096 -f ${ansibleuser_ssh_key}

ssh-ansibleuser-01: | $(ssh-dir)
	ssh -o "IdentitiesOnly=yes" -i ${ansibleuser_ssh_key} ansibleuser@${ip_www_server_01}

ssh-ansibleuser-02: | $(ssh-dir)
	ssh -o "IdentitiesOnly=yes" -i ${ansibleuser_ssh_key} ansibleuser@${ip_www_server_02}

ssh-ansibleuser-03: | $(ssh-dir)
	ssh -o "IdentitiesOnly=yes" -i ${ansibleuser_ssh_key} ansibleuser@${ip_www_server_03}

# server-setup using root account
server-setup: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "setup" \
		-e "ansible_user=root ansible_ssh_private_key_file=$(root_ssh_key)"

server-update: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "update"

nginx-setup: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "nginx_setup"

web-rsync: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "web_rsync"

# targets for new server setup before being added to lb droplets and firewall
new-server-setup: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "setup" --limit "new_servers"\
		-e "ansible_user=root ansible_ssh_private_key_file=~$(root_ssh_key)"  

new-nginx-setup: | $(ssh-dir)
	ansible-playbook -i inventory.ini playbook.yml --tags "nginx_setup" --limit "new_servers"


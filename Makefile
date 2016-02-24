SHELL = /bin/bash
.PHONY: all update plan apply destroy provision

include *.mk

all: update plan apply provision

update:
	-git rev-parse @{upstream} && git pull

ifneq ($(wildcard platform-ansible),)
	cd platform-ansible && git pull origin ${PLATFORM_ANSIBLE_BRANCH}
else
	git clone -b ${PLATFORM_ANSIBLE_BRANCH} ${PLATFORM_ANSIBLE_REPOSITORY} platform-ansible
endif

plan:
	terraform get -update
	terraform plan -module-depth=-1 -var-file terraform.tfvars -out terraform.tfplan

apply:
	./platform-ansible/bin/install_unzip.sh
	./platform-ansible/bin/download_jdk.sh
	./platform-ansible/bin/download_jce.sh
	terraform apply -var-file terraform.tfvars

destroy:
	terraform plan -destroy -var-file terraform.tfvars -out terraform.tfplan
	terraform apply terraform.tfplan

clean:
	rm -f terraform.tfplan
	rm -f terraform.tfstate
	rm -fR .terraform/
	rm -fr platform-ansible
	rm -f ./cf-install/cf_hybrid_override.tf ./cdh/cdh_hybrid_override.tf \
	   ./cdh/consul/consul_hybrid_override.tf ./hybrid_override.tf

provision:
	pushd cf-install; export STATE_FILE="../terraform.tfstate"; make provision; popd

hybrid:
	cp ./cf-install/cf_hybrid_override.tf.hybrid ./cf-install/cf_hybrid_override.tf
	cp ./cdh/cdh_hybrid_override.tf.hybrid ./cdh/cdh_hybrid_override.tf
	cp ./cdh/consul/consul_hybrid_override.tf.hybrid ./cdh/consul/consul_hybrid_override.tf
	cp ./hybrid_override.tf.hybrid ./hybrid_override.tf
	sed -i 's/^exec/#exec/'  platform-ansible/bin/run_ansible.sh 
	sed -i 's/\(worker\|master\)_size=[0-9]/\1_size=0/' terraform.tfvars

route:
	./bin/hybrid-route


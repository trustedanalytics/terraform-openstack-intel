# Copyright (c) 2015 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

provider "openstack" {
  auth_url = "${var.auth_url}"
  tenant_name = "${var.tenant_name}"
  user_name = "${var.username}"
  password = "${var.password}"
}

module "cf-install" {
  source = "./cf-install"
  network = "${var.network}"
  auth_url = "${var.auth_url}"
  tenant_name = "${var.tenant_name}"
  tenant_id = "${var.tenant_id}"
  username = "${var.username}"
  password = "${var.password}"
  public_key_path = "${var.jumpbox_public_key_path}"
  key_path = "${var.jumpbox_key_path}"
  floating_ip_pool = "${var.floating_ip_pool}"
  region = "${var.region}"
  network_external_id = "${var.network_external_id}"
  cf_admin_pass = "${var.cf_admin_pass}"
  cf_client_pass = "${var.cf_client_pass}"
  image_name="${var.ubuntu_image_name}"
  centos_image_name="${var.centos_image_name}"
  install_docker_services="${var.install_docker_services}"
  install_logsearch="${var.install_logsearch}"
  http_proxy="${var.http_proxy}"
  https_proxy="${var.https_proxy}"
  deployment_size="${var.deployment_size}"
  cf_release_version="${var.cf_release_version}"
  debug = "${var.debug}"
  private_cf_domains="${var.private_cf_domains}"
  backbone_resource_pool        = "${var.backbone_resource_pool}"
  data_resource_pool            = "${var.data_resource_pool}"
  public_haproxy_resource_pool  = "${var.public_haproxy_resource_pool}"
  private_haproxy_resource_pool = "${var.private_haproxy_resource_pool}"
  api_resource_pool             = "${var.api_resource_pool}"
  services_resource_pool        = "${var.services_resource_pool}"
  health_resource_pool          = "${var.health_resource_pool}"
  runner_resource_pool          = "${var.runner_resource_pool}"
  install_logsearch             = "${var.install_logsearch}"
  dns1                          = "${var.dns1}"
  dns2                          = "${var.dns2}"
  os_timeout                    = "${var.os_timeout}"
  additional_cf_sg_allow_1="${module.cloudera.cdh_cidr}"
  offline_java_buildpack = "${var.offline_java_buildpack}"
  ntp_servers = "${var.ntp_servers}"
  cf_boshworkspace_repository = "${var.cf_boshworkspace_repository}"
  cf_boshworkspace_branch = "${var.cf_boshworkspace_branch}"
  docker_services_boshworkspace_repository = "${var.docker_services_boshworkspace_repository}"
  docker_services_boshworkspace_branch = "${var.docker_services_boshworkspace_branch}"
  logsearch_workspace_repository = "${var.logsearch_workspace_repository}"
  logsearch_workspace_branch = "${var.logsearch_workspace_branch}"
}

module "cloudera" {
  source = "./cdh"
  network = "${var.network}"
  network = "${var.network}"
  auth_url = "${var.auth_url}"
  tenant_name = "${var.tenant_name}"
  tenant_id = "${var.tenant_id}"
  username = "${var.username}"
  password = "${var.password}"
  floating_ip_pool = "${var.floating_ip_pool}"
  region = "${var.region}"
  jumpbox_public_key_path = "${var.jumpbox_public_key_path}"
  jumpbox_key_path = "${var.jumpbox_key_path}"
  cdh_public_key_path = "${var.cdh_public_key_path}"
  cdh_key_path = "${var.cdh_key_path}"
  ansible_repo_path = "${var.ansible_repo_path}"
  worker_size="${var.worker_size}"
  master_size="${var.master_size}"
  cf_sg_id="${module.cf-install.cf_sg_id}"
  router_id="${module.cf-install.router_id}"
  cf_fp = "${module.cf-install.cf_fp_address}"
  image_name="${var.centos_image_name}"
  http_proxy="${var.http_proxy}"
  https_proxy="${var.https_proxy}"
  dns1="${var.dns1}"
  dns2="${var.dns2}"
  ntp_servers = "${var.ntp_servers}"
  nginx_ip = "${module.cf-install.nginx_ip}"
}


output "cf_api" {
  value = "${module.cf-install.cf_api}"
}

output "bastion_ip" {
  value = "${module.cf-install.bastion_ip}"
}

output "username" {
  value = "${module.cf-install.username}"
}
output "password" {
  value = "${module.cf-install.password}"
}
output "tenant_name" {
  value = "${module.cf-install.tenant_name}"
}
output "auth_url" {
  value = "${module.cf-install.auth_url}"
}
output "region" {
  value = "${module.cf-install.region}"
}
output "internal_network_id" {
  value = "${module.cf-install.internal_network_id}"
}
output "network" {
  value = "${module.cf-install.network}"
}
output "cf_fp_address" {
  value = "${module.cf-install.cf_fp_address}"
}
output "cf_size" {
  value = "${module.cf-install.cf_size}"
}
output "cf_sg" {
  value = "${module.cf-install.cf_sg}"
}
output "cf_domain" {
  value = "${module.cf-install.cf_domain}"
}
output "cf_subnet_cidr" {
  value = "${module.cf-install.cf_subnet_cidr}"
}
output "docker_subnet" {
  value = "${module.cf-install.docker_subnet}"
}
output "docker_subnet_cidr" {
  value = "${module.cf-install.docker_subnet_cidr}"
}
output "install_docker_services" {
  value = "${module.cf-install.install_docker_services}"
}

output "key_path" {
  value = "${module.cf-install.key_path}"
}

output "lb_subnet" {
  value = "${module.cf-install.lb_subnet}"
}

output "lb_net" {
  value = "${module.cf-install.lb_net}"
}

output "lb_subnet_cidr" {
  value = "${module.cf-install.lb_subnet_cidr}"
}

output "cf_release_version" {
	value = "${var.cf_release_version}"
}

output "http_proxy" {
  value = "${var.http_proxy}"
}

output "https_proxy" {
  value = "${var.https_proxy}"
}

output "debug" {
  value = "${var.debug}"
}

output "logsearch_subnet" {
  value = "${module.cf-install.logsearch_subnet}"
}

output "install_logsearch" {
  value = "${module.cf-install.install_logsearch}"
}

output "backbone_z1_count" { value = "${module.cf-install.backbone_z1_count}" }
output "api_z1_count"      { value = "${module.cf-install.api_z1_count}" }
output "services_z1_count" { value = "${module.cf-install.services_z1_count}" }
output "health_z1_count"   { value = "${module.cf-install.health_z1_count}" }
output "runner_z1_count"   { value = "${module.cf-install.runner_z1_count}" }
output "backbone_z2_count" { value = "${module.cf-install.backbone_z2_count}" }
output "api_z2_count"      { value = "${module.cf-install.api_z2_count}" }
output "services_z2_count" { value = "${module.cf-install.services_z2_count}" }
output "health_z2_count"   { value = "${module.cf-install.health_z2_count}" }
output "runner_z2_count"   { value = "${module.cf-install.runner_z2_count}" }

output "private_cf_domains" {
  value = "${module.cf-install.private_cf_domains}"
}

output "additional_cf_sg_allows" {
  value = "${module.cf-install.additional_cf_sg_allows}"
}

output "backbone_resource_pool"        { value = "${module.cf-install.backbone_resource_pool}" }
output "data_resource_pool"            { value = "${module.cf-install.data_resource_pool}" }
output "public_haproxy_resource_pool"  { value = "${module.cf-install.public_haproxy_resource_pool}" }
output "private_haproxy_resource_pool" { value = "${module.cf-install.private_haproxy_resource_pool}" }
output "api_resource_pool"             { value = "${module.cf-install.api_resource_pool}" }
output "services_resource_pool"        { value = "${module.cf-install.services_resource_pool}" }
output "health_resource_pool"          { value = "${module.cf-install.health_resource_pool}" }
output "runner_resource_pool"          { value = "${module.cf-install.runner_resource_pool}" }

output "dns1" {
  value = "${module.cf-install.dns1}"
}
output "dns2" {
  value = "${module.cf-install.dns2}"
}

output "os_timeout" {
  value = "${module.cf-install.os_timeout}"
}

output "offline_java_buildpack" {
  value = "${module.cf-install.offline_java_buildpack}"
}

output "consul_masters" {
  value = "${module.cloudera.consul_masters}"
}

output "cf_admin_pass" {
  value = "${var.cf_admin_pass}"
}

output "cf_client_pass" {
  value = "${var.cf_client_pass}"
}

output "ntp_servers" {
  value = "${var.ntp_servers}"
}

output "cf_boshworkspace_repository" {
  value = "${module.cf-install.cf_boshworkspace_repository}"
}

output "cf_boshworkspace_branch" {
  value = "${module.cf-install.cf_boshworkspace_branch}"
}

output "docker_services_boshworkspace_repository" {
  value = "${module.cf-install.docker_services_boshworkspace_repository}"
}

output "docker_services_boshworkspace_branch" {
  value = "${module.cf-install.docker_services_boshworkspace_branch}"
}

output "logsearch_workspace_repository" {
  value = "${module.cf-install.logsearch_workspace_repository}"
}

output "logsearch_workspace_branch" {
  value = "${module.cf-install.logsearch_workspace_branch}"
}

output "quay_username" {
  value = "${var.quay_username}"
}

output "quay_pass" {
  value = "${var.quay_pass}"
}

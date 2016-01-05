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

variable "auth_url" {}
variable "tenant_name" {}
variable "tenant_id" {}
variable "username" {}
variable "password" {}
variable "jumpbox_key_path" {}
variable "jumpbox_public_key_path" {}
variable "cdh_key_path" {}
variable "cdh_public_key_path" {}
variable "floating_ip_pool" {}
variable "network_external_id" {}
variable "ansible_repo_path" {}

variable "ntp_servers" {
  default = "0.pool.ntp.org,1.pool.ntp.org"
}

variable "cf_admin_pass" {
  default = "c1oudc0w"
}

variable "cf_client_pass" {
  default = "c1oudc0w"
}

variable "region" {

  default = "RegionOne"
}

variable "network" {
	default = "192.168"
}

variable "install_docker_services" {
  default = "true"
}

variable "cf_domain" {
  default = "XIP"
}

variable "docker_boshworkspace_version" {
  default = "master"
}

variable "cf_boshworkspace_version" {
  default = "cf-207"
}

variable "cf_size" {
  default = "tiny"
}

variable "http_proxy" {
  default = ""
}
variable "https_proxy" {
  default = ""
}

variable "deployment_size" {
  default = "small"
}

variable "cf_boshworkspace_version" {
  default = "cf-207"
}

variable "cf_release_version" {
  default = "207"
}
variable "ubuntu_image_name" {
  default = "ubuntu-14.04"
}

variable "centos_image_name" {
  default = "centos65-disk"
}

variable "flavor_name" {
  default = "m1.medium"
}

variable "vol_size" {
  default = 75
}

variable "master_size" {
  default = 3
}

variable "worker_size" {
  default = 3
}

variable "private_cf_domains" {
  default = ""
}

variable "dns1" {}
variable "dns2" {}

variable install_logsearch {
    default = "true"
}

variable "backbone_resource_pool"        { default = "large" }
variable "data_resource_pool"            { default = "large" }
variable "public_haproxy_resource_pool"  { default = "small" }
variable "private_haproxy_resource_pool" { default = "small" }
variable "api_resource_pool"             { default = "medium" }
variable "services_resource_pool"        { default = "medium" }
variable "health_resource_pool"          { default = "medium" }
variable "runner_resource_pool"          { default = "runner" }
variable "debug" { default = "false" }
variable "os_timeout" { default = "1200" }

variable "debug" {
  default = "false"
}

variable "offline_java_buildpack" {
  default = "true"
}

variable "git_account_url" {
        default = "github.com/trustedanalytics"
}
variable "gh_auth" {
 default = ""
}

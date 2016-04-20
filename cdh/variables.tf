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

variable "dns1" {}
variable "dns2" {}
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
variable "ansible_repo_path" {}
variable "cf_sg_id" {}
variable "nginx_sg_id" {}
variable "router_id" {}

variable "ntp_servers" {
  default = "0.pool.ntp.org,1.pool.ntp.org"
}

variable "network" {
  default = "192.168"
}

variable "security_group" {
  default = "default"
}
variable "master_size" {
  default = 3
}
variable "worker_size" {
  default = 3
}
variable "region" {
  default = "RegionOne"
}
variable "image_name" {
  default = "centos65-disk"
}

variable "flavor_name" {
  default = "m1.large"
}

variable "http_proxy" {
  default = ""
}

variable "https_proxy" {
  default = ""
}

variable "cf_fp" {}
variable "nginx_ip" {}

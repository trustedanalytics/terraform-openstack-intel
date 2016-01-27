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

resource "openstack_compute_instance_v2" "consul-master" {
  count = "3"
  name = "consul-master-${count.index}"
  image_name = "${var.image_name}"
  flavor_name = "m1.small"
  region = "${var.region}"

  key_pair = "${var.key_pair}"
  security_groups = [ "${var.security_group}" ]
  config_drive = true

  network {
    uuid = "${var.net_id}"
  }
}

output "consul_masters" {
  value = "${join(",", openstack_compute_instance_v2.consul-master.*.access_ip_v4)}"
}

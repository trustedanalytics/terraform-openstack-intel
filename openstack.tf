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


resource "openstack_networking_network_v2" "cdh-net" {
  region = "${var.region}"
  name = "cdh-net"
  admin_state_up = "true"
  tenant_id = "${var.tenant_id}"
}

resource "openstack_networking_subnet_v2" "cdh-subnet" {
  name = "cdh-subnet"
  region = "${var.region}"
  network_id = "${openstack_networking_network_v2.cdh-net.id}"
  cidr = "${var.network}.6.0/24"
  ip_version = 4
  tenant_id = "${var.tenant_id}"
  enable_dhcp = "true"
  dns_nameservers = ["${var.dns1}","${var.dns2}"]
}

resource "openstack_networking_router_interface_v2" "cdh-ext-interface" {
  region = "${var.region}"
  router_id = "${var.router_id}"
  subnet_id = "${openstack_networking_subnet_v2.cdh-subnet.id}"

}

resource "openstack_compute_secgroup_v2" "cdh-sg" {
  name = "CDH-${var.tenant_name}"
  description = "CDH Security groups"
  region = "${var.region}"

  rule {
    ip_protocol = "tcp"
    from_port = "22"
    to_port = "22"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

  rule {
    ip_protocol = "udp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    from_group_id = "${var.cf_sg_id}"
  }

  rule {
    ip_protocol = "udp"
    from_port = "1"
    to_port = "65535"
    from_group_id = "${var.cf_sg_id}"
  }

}

resource "openstack_networking_floatingip_v2" "cdh-launcher-fp" {
  region = "${var.region}"
  pool = "${var.floating_ip_pool}"
}

resource "openstack_blockstorage_volume_v1" "cdh-manager-vol" {
  region = "RegionOne"
  name = "cdh-manager-vol"
  description = "cdh manager volume"
  size = "${var.vol_size}"
}

resource "openstack_blockstorage_volume_v1" "cdh-master-vol-0" {
  count = "${var.master_size}"
  region = "RegionOne"
  name = "cdh master ${count.index} vol-0"
  description = "cdh master ${count.index} volume"
  size = "${var.vol_size}"
}

resource "openstack_blockstorage_volume_v1" "cdh-master-vol-1" {
  count = "${var.master_size}"
  region = "RegionOne"
  name = "cdh master ${count.index} vol-1"
  description = "cdh master ${count.index} volume"
  size = "${var.vol_size}"
}

resource "openstack_blockstorage_volume_v1" "cdh-worker-vol-0" {
  count = "${var.worker_size}"
  region = "RegionOne"
  name = "cdh worker ${count.index} vol-0"
  description = "cdh worker ${count.index} volume"
  size = "${var.vol_size}"
}

resource "openstack_blockstorage_volume_v1" "cdh-worker-vol-1" {
  count = "${var.worker_size}"
  region = "RegionOne"
  name = "cdh worker ${count.index} vol-1"
  description = "cdh worker ${count.index} volume"
  size = "${var.vol_size}"
}

resource "openstack_compute_keypair_v2" "jumpbox-keypair" {
  name = "cdh-jumpbox-keypair-${var.tenant_name}"
  public_key = "${file(var.jumpbox_public_key_path)}"
  region = "${var.region}"
}

resource "openstack_compute_keypair_v2" "cdh-keypair" {
  name = "cdh-keypair-${var.tenant_name}"
  public_key = "${file(var.cdh_public_key_path)}"
  region = "${var.region}"
}

module "consul" {
  source = "git::git@github.com:trustedanalytics/terraform-openstack-consul.git"

  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"

  key_pair = "${openstack_compute_keypair_v2.cdh-keypair.name}"
  security_group = "${openstack_compute_secgroup_v2.cdh-sg.name}"
  net_id = "${openstack_networking_network_v2.cdh-net.id}"
}          

resource "openstack_compute_instance_v2" "cdh-manager" {
  name = "cdh-manager"
  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"
  key_pair = "${openstack_compute_keypair_v2.cdh-keypair.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.cdh-sg.name}" ]
  config_drive = true

  volume {
    volume_id = "${openstack_blockstorage_volume_v1.cdh-manager-vol.id}"
    device = "/dev/vdb"
  }

  network {
    uuid = "${openstack_networking_network_v2.cdh-net.id}"
  }

}

resource "openstack_compute_instance_v2" "cdh-master" {
  count = "${var.master_size}"
  name = "cdh-master-${count.index}"
  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"
  key_pair = "${openstack_compute_keypair_v2.cdh-keypair.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.cdh-sg.name}" ]
  config_drive = true

  volume {
    volume_id = "${element(openstack_blockstorage_volume_v1.cdh-master-vol-0.*.id, count.index)}"
    device = "/dev/vdb"
  }

  volume {
    volume_id = "${element(openstack_blockstorage_volume_v1.cdh-master-vol-1.*.id, count.index)}"
    device = "/dev/vdc"
  }


  network {
    uuid = "${openstack_networking_network_v2.cdh-net.id}"
  }
}

resource "openstack_compute_instance_v2" "cdh-worker" {
  count = "${var.worker_size}"
  name = "cdh-worker-${count.index}"
  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"
  key_pair = "${openstack_compute_keypair_v2.cdh-keypair.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.cdh-sg.name}" ]
  config_drive = true

  volume {
    volume_id = "${element(openstack_blockstorage_volume_v1.cdh-worker-vol-0.*.id, count.index)}"
    device = "/dev/vdb"
  }

  volume {
    volume_id = "${element(openstack_blockstorage_volume_v1.cdh-worker-vol-1.*.id, count.index)}"
    device = "/dev/vdc"
  }

  network {
    uuid = "${openstack_networking_network_v2.cdh-net.id}"
  }
}


resource "openstack_compute_instance_v2" "cdh-launcher" {
  name = "cdh-launcher"
  image_name = "${var.image_name}"
  flavor_name = "${var.flavor_name}"
  region = "${var.region}"
  key_pair = "${openstack_compute_keypair_v2.jumpbox-keypair.name}"
  security_groups = [ "${openstack_compute_secgroup_v2.cdh-sg.name}" ]
  config_drive = true
  floating_ip = "${openstack_networking_floatingip_v2.cdh-launcher-fp.address}"


  network {
    uuid = "${openstack_networking_network_v2.cdh-net.id}"
  }

  connection {
    user = "centos"
    key_file = "${var.jumpbox_key_path}"
    host = "${openstack_networking_floatingip_v2.cdh-launcher-fp.address}"
  }

  provisioner "file" {
    source = "${var.cdh_key_path}"
    destination = "/home/centos/.ssh/id_rsa"
  }

  provisioner "file" {
    source = "${var.ansible_repo_path}"
    destination = "/home/centos/ansible-cdh"
  }

  provisioner "file" {
    source = "${path.module}/provision.sh"
    destination = "/home/centos/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /home/centos/provision.sh",
        "/home/centos/provision.sh ${openstack_compute_instance_v2.cdh-manager.access_ip_v4} ${join(",", openstack_compute_instance_v2.cdh-master.*.access_ip_v4)} ${join(",", openstack_compute_instance_v2.cdh-worker.*.access_ip_v4)} ${module.consul.consul_masters} ${var.ntp_servers} ${var.http_proxy} ${var.https_proxy}"
    ]
  }
}

output "cdh_cidr" {
  value = "${openstack_networking_subnet_v2.cdh-subnet.cidr}"
}

output "consul_masters" {
  value = "${module.consul.consul_masters}"
}

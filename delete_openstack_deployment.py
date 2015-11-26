#!/usr/bin/env python

#
# Copyright (c) 2015 Intel Corporation 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


from os import environ as env
import argparse
import time
import novaclient.client as nova_client
import neutronclient.v2_0.client as neutron_client
import cinderclient.v2.client as cinder_client


def create_nova_client(auth_url, username, password, tenant_name, region_name):
    nova = nova_client.Client(auth_url=auth_url,
                              username=username,
                              api_key=password,
                              project_id=tenant_name,
                              version='2',
                              region_name=region_name)
    return nova


def create_neutron_client(auth_url, username, password, tenant_name, region_name):
    neutron = neutron_client.Client(auth_url=auth_url,
                                    username=username,
                                    password=password,
                                    tenant_name=tenant_name,
                                    region_name=region_name)
    return neutron


def create_cinder_client(auth_url, username, password, tenant_name, region_name):
    cinder = cinder_client.Client(auth_url=auth_url,
                                  username=username,
                                  api_key=password,
                                  project_id=tenant_name,
                                  region_name=region_name)
    return cinder


def detach_volumes(nova):
    print("\nDetaching volumes:")
    for server in nova.servers.list():
        for volume in nova.volumes.get_server_volumes(server.id):
            print ("\tDetaching volume {0} from server {1}".format(volume, server))
            nova.volumes.delete_server_volume(server.id, volume.id)


def delete_servers(nova):
    print("\nDeleting servers:")
    for server in nova.servers.list():
        print ("\t Deleting server {0}".format(server))
        nova.servers.delete(server.id)


def delete_volumes(cinder):
    print("\nDeleting volumes:")
    for volume in cinder.volumes.list():
        if volume.status == 'error_deleting':
            print("\t Skipping deletion of volume in error_deleting state: {0}".format(volume))
        else:
            print ("\t Deleting volume {0}".format(volume))
            start_time = time.time()
            detached = False
            while time.time() - start_time < TIMEOUT:
                if not volume._info.get('attachments'):
                    detached = True
                    break
                else:
                    time.sleep(5)
                    continue

            if detached:
                cinder.volumes.delete(volume.id)
            else:
                print("\t\t Volume {0} still has active attachments after timeout threshold ({1} seconds):\n{2}"
                      "\nAborting environment deletion.".format(volume, TIMEOUT, volume._info.get('attachments')))
                exit(1)


def delete_bosh_images(nova):
    print("\nDeleting bosh images:")
    for image in nova.images.list():
        if "bosh" in image.human_id:
            print ("\t Deleting images {0}".format(image.human_id))
            nova.images.delete(image.id)


def delete_networks(neutron):
    print("\nDeleting networks:")
    networks = neutron.list_networks()
    for network in networks['networks']:
        if network['name'] != 'net04_ext':
            print ("\t Deleting network {0}".format(network['id']))
            neutron.delete_network(network['id'])


def delete_network_components(neutron):
    try:
        router = neutron.list_routers()['routers'][0]

        print("\nDeleting router interfaces and subnets:")
        for subnet in neutron.list_subnets()['subnets']:
            print ("\t Deleting interface and subnet {0}".format(subnet['id']))
            neutron.remove_interface_router(router['id'], {'subnet_id': subnet['id']})
            neutron.delete_subnet(subnet['id'])

        print("\nDeleting router: {0}".format(router['id']))
        neutron.delete_router(router['id'])

        delete_networks(neutron)

    except IndexError:
        print("Router not found, skipping router interfaces, subnets and router deletion.")


def delete_key_pairs(nova):
    print("\nDeleting key pairs:")
    for keypair in nova.keypairs.list():
        print ("\t Deleting key pair {0}".format(keypair))
        nova.keypairs.delete(keypair.id)


def delete_security_groups(nova):
    print("\nDeleting security groups:")
    for security_group in nova.security_groups.list():
        if security_group.name != 'default':
            print ("\t Deleting security group {0}".format(security_group))
            nova.security_groups.delete(security_group.id)

def delete_floating_ips(nova):
    print("\nDeleting floating IPs:")
    for floating_ip in nova.floating_ips.list():
        print ("\t Deleting floating IP {0}".format(floating_ip))
        nova.floating_ips.delete(floating_ip.id)


def add_auth_url_to_no_proxy_env(domain):
    env["no_proxy"] = "{0}, {1}".format(env.get("no_proxy"), domain)
    env["NO_PROXY"] = "{0}, {1}".format(env.get("NO_PROXY"), domain)


def parse_args():
    parser = argparse.ArgumentParser(description="Deletes all volumes, instances, Bosh images, networks, subnetworks,"
                                                 "key pairs, elastic IPs and security groups"
                                                 " from given Openstack tenant.")
    parser.add_argument("-a", "--auth-url", required=True, help="Set authorization URL.")
    parser.add_argument("-u", "--username", required=True, help="Set Openstack username.")
    parser.add_argument("-p", "--password", required=True, help="Set Openstack user password.")
    parser.add_argument("-t", "--tenant-name", required=True, help="Set Tenant name.")
    parser.add_argument("-r", "--region-name", required=True, help="Set Region name.")
    parser.add_argument("-n", "--no-proxy-domain",
                        help="Optionally set domain that will be added to no_proxy & NO_PROXY environmental variables.")
    parser.add_argument("--timeout",
                        help="Set volumes detachment timeout in seconds (timeout is set to 120 seconds by default).")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    if args.no_proxy_domain:
        add_auth_url_to_no_proxy_env(args.no_proxy_domain)
    if args.timeout:
        TIMEOUT = args.timeout
    else:
        TIMEOUT = 120

    nova_cl = create_nova_client(args.auth_url, args.username, args.password, args.tenant_name, args.region_name)
    neutron_cl = create_neutron_client(args.auth_url, args.username, args.password, args.tenant_name, args.region_name)
    cinder_cl = create_cinder_client(args.auth_url, args.username, args.password, args.tenant_name, args.region_name)

    # ================= Delete computation components  =================
    detach_volumes(nova_cl)

    delete_servers(nova_cl)

    delete_volumes(cinder_cl)

    delete_bosh_images(nova_cl)

    # ================= Delete network components  =================

    delete_network_components(neutron_cl)

    # ================= Delete access and security components  =================

    delete_key_pairs(nova_cl)

    delete_security_groups(nova_cl)

    delete_floating_ips(nova_cl)

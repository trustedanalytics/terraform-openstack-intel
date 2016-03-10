#!/bin/bash
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

function add_to_etc_hosts {
sudo su - <<ENDCOMMANDS
  echo "${1} ${2}" >> /etc/hosts
ENDCOMMANDS
}

echo "$*"
cdhManager=$1
cdhMasterArray=$2
cdhWorkerArray=$3
nginxMaster=$4
ntpServers=$5
cfFp=$6
dns1=$7
dns2=$8

# These variables must be defined at the end
httpProxy=$9
httpsProxy=${10}

declare -a machineIPs

if [[ -n "${httpProxy}" && -n "${httpsProxy}" ]]; then
  echo "#!/bin/sh" | sudo tee /etc/profile.d/proxy.sh
  echo "export http_proxy=${httpProxy}" | sudo tee -a /etc/profile.d/proxy.sh
  echo "export https_proxy=${httpsProxy}" | sudo tee -a /etc/profile.d/proxy.sh
  sudo chmod +x /etc/profile.d/proxy.sh
  source /etc/profile.d/proxy.sh

  echo "proxy=${httpProxy}" | sudo tee -a /etc/yum.conf
fi

sudo sed -i -e 's@^mirrorlist@#mirrorlist@' /etc/yum.repos.d/epel*.repo
sudo sed -i -e 's@^#baseurl.*/epel@baseurl=http://dl.fedoraproject.org/pub/epel@' /etc/yum.repos.d/epel*.repo
sudo yum clean all
sudo yum install ansible-1.9*.el6 tmux vim -y
chmod 600 $HOME/.ssh/id_rsa

pushd $HOME/ansible-cdh/platform-ansible

envName=$(awk '/env_name/ { print $2 }' defaults/env.yml)
useCustomDns=$(awk '/use_custom_dns/ { print $2 }' defaults/env.yml)
echo "openstack_addr: $cfFp" >> defaults/env.yml
echo "openstack_dns1: $dns1" >> defaults/env.yml
echo "openstack_dns2: $dns2" >> defaults/env.yml

if [[ $useCustomDns == 'true' ]]; then
  prefix=".node.${envName}.consul"
else
  prefix=''
fi

pushd inventory

FILE="cdh"
rm $FILE

machineIPs+=($masterIP)
masterIP=${nginxMaster}
masterHost="nginx-master"
echo "[nginx-master]" >> $FILE
echo "${masterHost}${prefix} ansible_ssh_host=${masterIP}" >> $FILE

if [[ $useCustomDns == 'false' ]]; then
  add_to_etc_hosts ${masterIP} ${masterHost}
fi

machineIPs+=($masterIP)

managerIP=${cdhManager}
managerHost="cdh-manager"
echo "[cdh-manager]" >> $FILE
echo "${managerHost}${prefix} ansible_ssh_host=${managerIP}" >> $FILE

if [[ $useCustomDns == 'false' ]]; then
  add_to_etc_hosts ${managerIP} ${managerHost}
fi

machineIPs+=($managerIP)


masterCount=0
echo "[cdh-master]" >> $FILE
masterList=($(echo ${cdhMasterArray//,/ }))
for master in ${masterList[@]}
do
  masterIP=${master}
  masterHost="cdh-master-"${masterCount}
  echo "${masterHost}${prefix} ansible_ssh_host=${masterIP}" >> $FILE

  if [[ $useCustomDns == 'false' ]]; then
    add_to_etc_hosts ${masterIP} ${masterHost}
  fi

  machineIPs+=($masterIP)
  masterCount=$((masterCount + 1))
done

workerCount=0
echo "[cdh-worker]" >> $FILE
workerList=($(echo ${cdhWorkerArray//,/ }))
for worker in ${workerList[@]}
do
  workerIP=${worker}
  workerHost="cdh-worker-"${workerCount}
  echo "${workerHost}${prefix} ansible_ssh_host=${workerIP}" >> $FILE

  if [[ $useCustomDns == 'false' ]]; then
    add_to_etc_hosts ${workerIP} ${workerHost}
  fi

  machineIPs+=($workerIP)
  workerCount=$((workerCount + 1))
done

echo -e "[cdh-all-nodes:children]\ncdh-master\ncdh-worker" >> $FILE
echo -e "[cdh-all:children]\ncdh-all-nodes\ncdh-manager" >> $FILE

popd

if [[ $useCustomDns == 'false' ]]; then
  cp /etc/hosts hosts
fi

for machineIP in ${machineIPs[@]}
do
  if [[ -n "${httpProxy}" && -n "${httpsProxy}" ]]; then
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/profile.d/proxy.sh centos@${machineIP}:/home/centos/proxy.sh
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/yum.conf centos@${machineIP}:/home/centos/yum.conf
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/proxy.sh /etc/profile.d/proxy.sh
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/yum.conf /etc/yum.conf
  fi

  if [[ $useCustomDns == 'false' ]]; then
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no hosts centos@${machineIP}:/home/centos/hosts
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/hosts /etc/hosts
  fi
done

mkdir -p group_vars
echo "ntp_servers: [$ntpServers]" > group_vars/cdh-all

exec bash bin/run_ansible.sh

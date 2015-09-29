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
httpProxy=$4
httpsProxy=$5
consulMasterArray=$6

declare -a machineIPs

echo "#!/bin/sh" | sudo tee /etc/profile.d/proxy.sh
echo "export http_proxy=${httpProxy}" | sudo tee -a /etc/profile.d/proxy.sh
echo "export https_proxy=${httpsProxy}" | sudo tee -a /etc/profile.d/proxy.sh
sudo chmod +x /etc/profile.d/proxy.sh
source /etc/profile.d/proxy.sh

echo "proxy=${httpProxy}" | sudo tee -a /etc/yum.conf

sudo yum install ansible tmux vim -y
chmod 600 $HOME/.ssh/id_rsa

pushd $HOME/ansible-cdh/platform-ansible

envName=$(awk '/env_name/ { print $2 }' defaults/env.yml)
useCustomDns=$(awk '/use_custom_dns/ { print $2 }' defaults/env.yml)

if [[ $useCustomDns == 'true' ]]; then
  prefix=".node.${envName}.consul"
else
  prefix=''
fi

pushd inventory

FILE="cdh"
rm $FILE


managerIP=${1}
managerHost="cdh-manager"
echo "[cdh-manager]" >> $FILE
echo "${managerHost}${prefix} ansible_ssh_host=${managerIP}" >> $FILE

if [[ $useCustomDns == 'true' ]]; then
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

  if [[ $useCustomDns == 'true' ]]; then
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

  if [[ $useCustomDns == 'true' ]]; then
    add_to_etc_hosts ${workerIP} ${workerHost}
  fi

  machineIPs+=($workerIP)
  workerCount=$((workerCount + 1))
done

echo -e "[cdh-all-nodes:children]\ncdh-master\ncdh-worker" >> $FILE
echo -e "[cdh-all:children]\ncdh-all-nodes\ncdh-manager" >> $FILE

consulMasterList=($(echo ${consulMasterArray//,/ }))
consulMasterCount=0

echo '[consul-master]' >> $FILE
for master in ${consulMasterList[@]}
do
  consulMasterIP=${master}
  consulMasterHost="consul-master-${consulMasterCount}"
  echo "${consulMasterHost}${prefix} ansible_ssh_host=${consulMasterIP}" >> $FILE

  if [[ $useCustomDns == 'true' ]]; then
    add_to_etc_hosts ${consulMasterIP} ${consulMasterHost}
  fi

  machineIPs+=($consulMasterIP)
  consulMasterCount=$((consulMasterCount + 1))
done

popd

if [[ $useCustomDns == 'true' ]]; then
  cp /etc/hosts hosts
fi

for machineIP in ${machineIPs[@]}
do
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/profile.d/proxy.sh centos@${machineIP}:/home/centos/proxy.sh
  scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/yum.conf centos@${machineIP}:/home/centos/yum.conf
  ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/proxy.sh /etc/profile.d/proxy.sh
  ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/yum.conf /etc/yum.conf

  if [[ $useCustomDns == 'true' ]]; then
    scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no hosts centos@${machineIP}:/home/centos/hosts
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no centos@${machineIP} sudo cp /home/centos/hosts /etc/hosts
  fi
done

exec bash bin/run_ansible.sh

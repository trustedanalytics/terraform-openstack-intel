#!/bin/bash

# fail immediately on error
set -e

# echo "$0 $*" > ~/provision.log

fail() {
  echo "$*" >&2
  exit 1
}

# Variables passed in from terraform, see openstack-cf-install.tf, the "remote-exec" provisioner
OS_USERNAME=${1}
OS_API_KEY=${2}
OS_TENANT=${3}
OS_AUTH_URL=${4}
OS_REGION=${5}
CF_SUBNET1=${6}
IPMASK=${7}
CF_IP=${8}
CF_SIZE=${9}
CF_DOMAIN=${10}
DOCKER_SUBNET=${11}
INSTALL_DOCKER=${12}
LB_SUBNET1=${13}
CF_SG=${14}
CF_RELEASE_VERSION=${15}
QUAY_USERNAME=${16}
QUAY_PASS=${17}

HTTP_PROXY=${18}
HTTPS_PROXY=${19}

host_regexp="([a-zA-Z0-9\-]*[.]){1,}[a-zA-Z0-9\-]*";
OPENSTACK_IP=$(echo $OS_AUTH_URL | sed -E "s#https?://($host_regexp).*#\1#")
LB_WHITELIST="$(echo LB_WHITELIST_IPS | sed 's/ /,/g')"
CF_WHITELIST="$(echo CF_WHITELIST_IPS | sed 's/ /,/g')"
DK_WHITELIST="$(echo DK_WHITELIST_IPS | sed 's/ /,/g')"
NO_PROXY="LOCALHOST_WHITELIST,$LB_WHITELIST,$CF_WHITELIST,$DK_WHITELIST,$OPENSTACK_IP"

DEBUG=${20}

PRIVATE_DOMAINS=${21}

INSTALL_LOGSEARCH=${22}
LS1_SUBNET=${23}
CF_SG_ALLOWS=${24}

DNS1=${25}
DNS2=${26}

OS_TIMEOUT=${27}

OFFLINE_JAVA_BUILDPACK=${28}

CONSUL_MASTERS=${29}

CF_ADMIN_PASS=${30}
CF_CLIENT_PASS=${31}

NTP_SERVERS=${32}

CF_BOSHWORKSPACE_REPOSITORY=${33}
CF_BOSHWORKSPACE_BRANCH=${34}
DOCKER_SERVICES_BOSHWORKSPACE_REPOSITORY=${35}
DOCKER_SERVICES_BOSHWORKSPACE_BRANCH=${36}
LOGSEARCH_WORKSPACE_REPOSITORY=${37}
LOGSEARCH_WORKSPACE_BRANCH=${38}

DOCKER_IP_HYBRID=${39}

BACKBONE_Z1_COUNT=COUNT
API_Z1_COUNT=COUNT
SERVICES_Z1_COUNT=COUNT
HEALTH_Z1_COUNT=COUNT
RUNNER_Z1_COUNT=COUNT
BACKBONE_Z2_COUNT=COUNT
API_Z2_COUNT=COUNT
SERVICES_Z2_COUNT=COUNT
HEALTH_Z2_COUNT=COUNT
RUNNER_Z2_COUNT=COUNT

BACKBONE_POOL=POOL
DATA_POOL=POOL
PUBLIC_HAPROXY_POOL=POOL
PRIVATE_HAPROXY_POOL=POOL
API_POOL=POOL
SERVICES_POOL=POOL
HEALTH_POOL=POOL
RUNNER_POOL=POOL

SKIP_SSL_VALIDATION=false

boshDirectorHost="${IPMASK}.2.5"

logsearch_syslog="${IPMASK}.7.7"
logsearch_es_ip="${IPMASK}.7.6"

STEMCELL_VERSION='3104'

if [[ $DEBUG == "true" ]]; then
  set -x
fi

cd $HOME
(("$?" == "0")) || fail "Could not find HOME folder, terminating install."

# Setup proxy
if [[ $HTTP_PROXY != "" || $HTTPS_PROXY != "" ]]; then
  echo '#!/bin/sh' | sudo tee /etc/profile.d/proxy.sh
  echo "export http_proxy=${HTTP_PROXY}" | sudo tee -a /etc/profile.d/proxy.sh
  echo "export https_proxy=${HTTPS_PROXY}" | sudo tee -a /etc/profile.d/proxy.sh
  echo "export no_proxy=${NO_PROXY}" | sudo tee -a /etc/profile.d/proxy.sh
  sudo chmod +x /etc/profile.d/proxy.sh
  source /etc/profile.d/proxy.sh

  echo "Acquire::http::Proxy \"${HTTP_PROXY}\";" | sudo tee /etc/apt/apt.conf.d/01proxy
  echo "Acquire::https::Proxy \"${HTTPS_PROXY}\";" | sudo tee -a /etc/apt/apt.conf.d/01proxy
fi

# Generate the key that will be used to ssh between the bastion and the
# microbosh machine
if [[ ! -f ~/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

# Prepare the jumpbox to be able to install ruby and git-based bosh and cf repos

sudo apt-get -qy update
sudo apt-get -qy install build-essential vim-nox git unzip tree libxslt-dev \
  libxslt1.1 libxslt1-dev libxml2 libxml2-dev libpq-dev libmysqlclient-dev \
  libsqlite3-dev g++ gcc make libc6-dev libreadline6-dev zlib1g-dev libssl-dev \
  libyaml-dev libsqlite3-dev sqlite3 autoconf libgdbm-dev libncurses5-dev \
  automake libtool bison pkg-config libffi-dev cmake libcurl4-openssl-dev ntp \
  docker.io jq

sudo sed -i -e '/^server/d' /etc/ntp.conf

ntp_servers=$(echo $NTP_SERVERS | tr ',' "\n")

for ntp_server in $ntp_servers; do
  echo "server ${ntp_server}" | sudo tee -a /etc/ntp.conf
done

sudo service ntp restart

cd $HOME

# Install RVM

if [[ ! -d "$HOME/.rvm" ]]; then
  cd $HOME
  gpg --list-keys
  gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
  curl -sSL https://get.rvm.io | bash -s stable
fi

cd $HOME

if [[ ! "$(ls -A $HOME/.rvm/environments)" ]]; then
  ~/.rvm/bin/rvm install ruby-2.1.5
fi

if [[ ! -d "$HOME/.rvm/environments/default" ]]; then
  ~/.rvm/bin/rvm alias create default ruby-2.1.5
fi

source ~/.rvm/environments/default
source ~/.rvm/scripts/rvm

gem install bundler --no-ri --no-rdoc --quiet

# Use Bundler to install the gem environment for correct dependency resolution
cat <<EOF > Gemfile
source 'https://rubygems.org'

gem 'bosh-bootstrap'
EOF
bundle install

# bosh-bootstrap handles provisioning the microbosh machine and installing bosh
# on it. This is very nice of bosh-bootstrap. Everyone make sure to thank bosh-bootstrap
mkdir -p {bin,workspace/deployments/microbosh,workspace/tools}
pushd workspace/deployments

# TODO: Use this stemcell in BOSH workspaces
STEMCELL=~/bosh-stemcell-${STEMCELL_VERSION}-openstack-kvm-ubuntu-trusty-go_agent.tgz
test -e ${STEMCELL} || wget -O ${STEMCELL} https://bosh.io/d/stemcells/bosh-openstack-kvm-ubuntu-trusty-go_agent?v=${STEMCELL_VERSION}

pushd microbosh
create_settings_yml() {
cat <<EOF > settings.yml
---
bosh:
  name: bosh-${OS_TENANT}
  stemcell_path: ${STEMCELL}
provider:
  name: openstack
  credentials:
    openstack_username: ${OS_USERNAME}
    openstack_api_key: ${OS_API_KEY}
    openstack_tenant: ${OS_TENANT}
    openstack_auth_url: ${OS_AUTH_URL}
    openstack_region: ${OS_REGION}
  options:
    boot_from_volume: false
  state_timeout: ${OS_TIMEOUT}
address:
  subnet_id: ${CF_SUBNET1}
  ip: ${boshDirectorHost}
EOF
}

if [[ ! -f "$HOME/workspace/deployments/microbosh/settings.yml" ]]; then
  create_settings_yml
fi

if [[ $HTTP_PROXY != ""  || $HTTPS_PROXY != ""  ]]; then
  cat <<EOF >> settings.yml
proxy:
  http_proxy: ${HTTP_PROXY}
  https_proxy: ${HTTPS_PROXY}
  no_proxy: ${NO_PROXY}
EOF
fi

if [[ $NTP_SERVERS != "" ]]; then
    cat <<EOF >> settings.yml
ntp: ${NTP_SERVERS}
EOF
fi

if [[ ! -d "$HOME/workspace/deployments/microbosh/deployments" ]]; then
  bosh bootstrap deploy
fi

rebuild_micro_bosh_easy() {
  echo "Retry deploying the micro bosh, attempting bosh bootstrap delete..."
  bosh bootstrap delete || rebuild_micro_bosh_hard
  bosh bootstrap deploy
  bosh -n target https://${boshDirectorHost}:25555
  bosh login admin admin
}

rebuild_micro_bosh_hard() {
  echo "Retry deploying the micro bosh, attempting bosh bootstrap delete..."
  rm -rf "$HOME/workspace/deployments/microbosh/deployments"
  rm -rf "$HOME/workspace/deployments/microbosh/ssh"
  create_settings_yml
}

# We've hardcoded the IP of the microbosh machine, because convenience
bosh -n target https://${boshDirectorHost}:25555
bosh login admin admin

if [[ ! "$?" == 0 ]]; then
  #wipe the ~/workspace/deployments/microbosh folder contents and try again
  echo "Retry deploying the micro bosh..."
fi
popd

if [[ ! -d 'cf-boshworkspace' ]]; then
  git clone --branch ${CF_BOSHWORKSPACE_BRANCH} ${CF_BOSHWORKSPACE_REPOSITORY} cf-boshworkspace
fi

pushd cf-boshworkspace
mkdir -p ssh
gem install bundler
bundle install

# Pull out the UUID of the director - bosh_cli needs it in the deployment to
# know it's hitting the right microbosh instance
DIRECTOR_UUID=$(bosh status | grep UUID | awk '{print $2}')

# If CF_DOMAIN is set to XIP, then use XIP.IO. Otherwise, use the variable
if [ $CF_DOMAIN == "XIP" ]; then
  CF_DOMAIN="${CF_IP}.xip.io"
  SKIP_SSL_VALIDATION="true"
fi

echo "Install Traveling CF"
if [[ "$(cat $HOME/.bashrc | grep 'export PATH=$PATH:$HOME/bin/traveling-cf-admin')" == "" ]]; then
  curl -s https://raw.githubusercontent.com/trustedanalytics/traveling-cf-admin/master/scripts/installer | bash
  echo 'export PATH=$PATH:$HOME/bin/traveling-cf-admin' >> $HOME/.bashrc
  source $HOME/.bashrc
fi

if [[ ! -f "/usr/local/bin/spiff" ]]; then
  curl -sOL https://github.com/cloudfoundry-incubator/spiff/releases/download/v1.0.3/spiff_linux_amd64.zip
  unzip spiff_linux_amd64.zip
  sudo mv ./spiff /usr/local/bin/spiff
  rm spiff_linux_amd64.zip
fi

# This is some hackwork to get the configs right. Could be changed in the future
/bin/sed -i \
  -e "s/CF_SUBNET1/${CF_SUBNET1}/g" \
  -e "s/LB_SUBNET1/${LB_SUBNET1}/g" \
  -e "s|OS_AUTHURL|${OS_AUTH_URL}|g" \
  -e "s/OS_TENANT/${OS_TENANT}/g" \
  -e "s/OS_APIKEY/${OS_API_KEY}/g" \
  -e "s/OS_USERNAME/${OS_USERNAME}/g" \
  -e "s/OS_TENANT/${OS_TENANT}/g" \
  -e "s/CF_ELASTIC_IP/${CF_IP}/g" \
  -e "s/CF_DOMAIN/${CF_DOMAIN}/g" \
  -e "s/CF_SG/${CF_SG}/g" \
  -e "s/DIRECTOR_UUID/${DIRECTOR_UUID}/g" \
  -e "s/version: \+[0-9]\+ \+# DEFAULT_CF_RELEASE_VERSION/version: ${CF_RELEASE_VERSION}/g" \
  -e "s/backbone_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/backbone_z1:\1${BACKBONE_Z1_COUNT}\2/" \
  -e "s/api_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/api_z1:\1${API_Z1_COUNT}\2/" \
  -e "s/services_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/services_z1:\1${SERVICES_Z1_COUNT}\2/" \
  -e "s/health_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/health_z1:\1${HEALTH_Z1_COUNT}\2/" \
  -e "s/runner_z1:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/runner_z1:\1${RUNNER_Z1_COUNT}\2/" \
  -e "s/backbone_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/backbone_z2:\1${BACKBONE_Z2_COUNT}\2/" \
  -e "s/api_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/api_z2:\1${API_Z2_COUNT}\2/" \
  -e "s/services_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/services_z2:\1${SERVICES_Z2_COUNT}\2/" \
  -e "s/health_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/health_z2:\1${HEALTH_Z2_COUNT}\2/" \
  -e "s/runner_z2:\( \+\)[0-9\.]\+\(.*# MARKER_FOR_PROVISION.*\)/runner_z2:\1${RUNNER_Z2_COUNT}\2/" \
  -e "s|~ # HTTP_PROXY|${HTTP_PROXY}|" \
  -e "s|~ # HTTPS_PROXY|${HTTPS_PROXY}|" \
  -e "s/~ # NO_PROXY/${NO_PROXY}/" \
  -e "s/backbone:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/backbone:\1${BACKBONE_POOL}\2/" \
  -e "s/data:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/data:\1${DATA_POOL}\2/" \
  -e "s/public_haproxy:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/public_haproxy:\1${PUBLIC_HAPROXY_POOL}\2/" \
  -e "s/private_haproxy:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/private_haproxy:\1${PRIVATE_HAPROXY_POOL}\2/" \
  -e "s/api:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/api:\1${API_POOL}\2/" \
  -e "s/services:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/services:\1${SERVICES_POOL}\2/" \
  -e "s/health:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/health:\1${HEALTH_POOL}\2/" \
  -e "s/runner:\( \+\)[a-z\-\_A-Z0-1]\+\(.*# MARKER_FOR_POOL_PROVISION.*\)/runner:\1${RUNNER_POOL}\2/" \
  -e "/8.8.8.8/d" \
  -e "/8.8.4.4/d" \
  -e "s|\(dns:\).*|\1 [${CONSUL_MASTERS}]|" \
  -e "s/CF_ADMIN_PASS/${CF_ADMIN_PASS}/g" \
  -e "s/CF_CLIENT_PASS/${CF_CLIENT_PASS}/g" \
  deployments/cf-openstack-${CF_SIZE}.yml

if [[ $OFFLINE_JAVA_BUILDPACK == "true" ]]; then
  sed -i\
    -e "s/^#  - offline-java-buildpack.yml$/  - offline-java-buildpack.yml/" \
    deployments/cf-openstack-${CF_SIZE}.yml
fi

if [[ -n "$PRIVATE_DOMAINS" ]]; then
  for domain in $(echo $PRIVATE_DOMAINS | tr "," "\n"); do
    sed -i -e "s/^\(\s\+\)- PRIVATE_DOMAIN_PLACEHOLDER/\1- $domain\n\1- PRIVATE_DOMAIN_PLACEHOLDER/" deployments/cf-openstack-${CF_SIZE}.yml
  done
  sed -i -e "s/^\s\+- PRIVATE_DOMAIN_PLACEHOLDER//" deployments/cf-openstack-${CF_SIZE}.yml
else
  sed -i -e "s/^\(\s\+\)internal_only_domains:\$/\1internal_only_domains: []/" deployments/cf-openstack-${CF_SIZE}.yml
  sed -i -e "s/^\s\+- PRIVATE_DOMAIN_PLACEHOLDER//" deployments/cf-openstack-${CF_SIZE}.yml
fi

# generate UAA certificate pair
if grep -q UAAC deployments/cf-openstack-${CF_SIZE}.yml; then
  openssl genrsa -out /tmp/uaac_prv.pem 2048
  openssl rsa -pubout -in /tmp/uaac_prv.pem -out /tmp/uaac_pub.pem
  sed -i -e "s/UAAC_PRV_KEY/$(</tmp/uaac_prv.pem sed -e 's/[\&/]/\\&/g' -e 's/$/\\n    /' | tr -d '\n')/g" deployments/cf-openstack-${CF_SIZE}.yml
  sed -i -e "s/UAAC_PUB_KEY/$(</tmp/uaac_pub.pem sed -e 's/[\&/]/\\&/g' -e 's/$/\\n    /' | tr -d '\n')/g" deployments/cf-openstack-${CF_SIZE}.yml
  rm -f /tmp/uaac_prv.pem /tmp/uaac_pub.pem
fi

if [[ -n "$CF_SG_ALLOWS" ]]; then
  replacement_text=""
  for cidr in $(echo $CF_SG_ALLOWS | tr "," "\n"); do
    if [[ -n "$cidr" ]]; then
      replacement_text="${replacement_text}{\"protocol\":\"all\",\"destination\":\"${cidr}\"},"
    fi
  done
  if [[ -n "$replacement_text" ]]; then
    replacement_text=$(echo $replacement_text | sed 's/,$//')
    sed -i -e "s|^\(\s\+additional_security_group_rules:\s\+\).*|\1[$replacement_text]|" deployments/cf-openstack-${CF_SIZE}.yml
  fi
fi

if [[ $INSTALL_LOGSEARCH == "true" ]]; then
    if [[ $(grep -v syslog deployments/cf-openstack-${CF_SIZE}.yml)  ]]; then
        INSERT_AT=$(grep -n cf-networking.yml deployments/cf-openstack-${CF_SIZE}.yml  | cut -d : -f 1)
        sed -i "${INSERT_AT}i\ \ - cf-syslog.yml" deployments/cf-openstack-${CF_SIZE}.yml

        cat <<EOF >> deployments/cf-openstack-${CF_SIZE}.yml

  syslog_daemon_config:
    address: ${logsearch_syslog}
    port: 5515
EOF
    fi
fi

RELEASE=~/cf-release-${CF_RELEASE_VERSION}.tgz
test -e ${RELEASE} || wget -O ${RELEASE} https://bosh.io/d/github.com/cloudfoundry/cf-release?v=${CF_RELEASE_VERSION}
bosh upload release --skip-if-exists ${RELEASE}
bosh deployment cf-openstack-${CF_SIZE}
bosh prepare deployment || bosh prepare deployment  #Seems to always fail on the first run...

# We locally commit the changes to the repo, so that errant git checkouts don't
# cause havok
currentGitUser="$(git config user.name || /bin/true )"
currentGitEmail="$(git config user.email || /bin/true )"
if [[ "${currentGitUser}" == "" || "${currentGitEmail}" == "" ]]; then
  git config --global user.email "${USER}@${HOSTNAME}"
  git config --global user.name "${USER}"
  echo "blarg"
fi

gitDiff="$(git diff)"
if [[ ! "${gitDiff}" == "" ]]; then
  git commit -am 'commit of the local deployment configs'
fi


# Keep trying until there is a successful BOSH deploy.
# for i in {0..2}
#do bosh -n deploy
#done
bosh -n deploy

# Run smoke tests
# FIXME: Re-enable smoke tests after they become reliable (experiencing intermittent failures)
#bosh run errand smoke_tests_runner

# Now deploy docker services if requested
if [[ $INSTALL_DOCKER == "true" ]]; then

  cd ~/workspace/deployments

  if [[ ! -d 'docker-services-boshworkspace' ]]; then
    git clone -b ${DOCKER_SERVICES_BOSHWORKSPACE_BRANCH} ${DOCKER_SERVICES_BOSHWORKSPACE_REPOSITORY} docker-services-boshworkspace
  fi

  echo "Update the docker-aws-vpc.yml with cf-boshworkspace parameters"
  /home/ubuntu/workspace/deployments/docker-services-boshworkspace/shell/populate-docker-openstack
  dockerDeploymentManifest="/home/ubuntu/workspace/deployments/docker-services-boshworkspace/deployments/docker-openstack.yml"
  /bin/sed -i \
    -e "s/SUBNET_ID/${DOCKER_SUBNET}/g" \
    -e "s/DOCKER_SG/${CF_SG}/g" \
    -e "/8.8.8.8/d" \
    -e "/8.8.4.4/d" \
    -e "s|\(dns_servers:\).*|\1 [${DNS1},${DNS2}]|" \
    "${dockerDeploymentManifest}"

  if [[ -n ${HTTP_PROXY} || -n ${HTTPS_PROXY} ]]; then
    /bin/sed -i \
      -e "s|~ # HTTP_PROXY|${HTTP_PROXY}|" \
      -e "s|~ # HTTPS_PROXY|${HTTPS_PROXY}|" \
      -e "s|~ # NO_PROXY|${NO_PROXY}|" \
      "${dockerDeploymentManifest}"
  fi

  if [[ -n ${DOCKER_IP_HYBRID} ]]; then
    /bin/sed -i \
      -e "s|^- docker-jobs.yml|- docker-jobs-hybrid.yml|" \
      -e "s|^- docker-openstack.yml|- docker-openstack-hybrid.yml|" \
      "${dockerDeploymentManifest}"
    /bin/sed -i \
      -e "s|DOCKER_IP_HYBRID|${DOCKER_IP_HYBRID}|" \
      /home/ubuntu/workspace/deployments/docker-services-boshworkspace/templates/docker-jobs-hybrid.yml
  fi
  cd ~/workspace/deployments/docker-services-boshworkspace
  bundle install
  bosh deployment docker-openstack
  bosh prepare deployment

  set +e
  bosh -n deploy
  set -e

  DOCKER_IP=$(bosh vms 2>&1| awk '/docker\/0/ { print $8 }')
  #list all images, convert to JSON, get the container image and tag with JQ
  DOCKER_IMAGES=$(cat templates/docker-properties.yml | ruby -ryaml -rjson -e "print JSON.dump(YAML.load(ARGF))" |\
    jq -r ".properties.broker.services[].plans[].container | [.image, .tag] | @sh" | sed "s/' '/:/;s/'//g")
  #list all images in the jobs file
  DOCKER_JOBS_IMAGES=$(cat templates/docker-jobs.yml | ruby -ryaml -rjson -e "print JSON.dump(YAML.load(ARGF))" | jq -r ".jobs[].properties.containers[].image | @sh" | sed "s/'//g")


  #log in to quay when the username is provided
  if [[ -n "$QUAY_USERNAME" ]]; then
    docker -H "tcp://${DOCKER_IP}:4243" login -u $QUAY_USERNAME -p $QUAY_PASS -e test@test quay.io
  fi

  #pull all public images. private ones will fail when not logged in
  set +e
  for image in $DOCKER_IMAGES $DOCKER_JOBS_IMAGES; do
    docker -H "tcp://${DOCKER_IP}:4243" pull $image
  done
  set -e

  # Keep trying until there is a successful BOSH deploy.
  for i in {0..2}
  do bosh -n deploy
  done

fi

# Now deploy logsearch if requested
if [[ $INSTALL_LOGSEARCH == "true" ]]; then

    cd ~/workspace/deployments

    if [[ ! -d 'logsearch-workspace' ]]; then
        git clone -b ${LOGSEARCH_WORKSPACE_BRANCH} ${LOGSEARCH_WORKSPACE_REPOSITORY} logsearch-workspace
    fi

    cd logsearch-workspace

    /bin/sed -i \
             -e "s/DIRECTOR_UUID/${DIRECTOR_UUID}/g" \
             -e "s/IPMASK/${IPMASK}/g" \
             -e "s/CF_DOMAIN/run.${CF_DOMAIN}/g" \
             -e "s/CF_ADMIN_PASS/${CF_ADMIN_PASS}/g" \
             -e "s/CF_CLIENT_PASS/${CF_CLIENT_PASS}/g" \
             -e "s/CLOUDFOUNDRY_SG/${CF_SG}/g" \
             -e "s/LS1_SUBNET/${LS1_SUBNET}/g" \
             -e "s/skip-ssl-validation: false/skip-ssl-validation: ${SKIP_SSL_VALIDATION}/g"\
             deployments/logsearch-openstack.yml

    bundle install
    bosh deployment logsearch-openstack
    bosh prepare deployment

    # Keep trying until there is a successful BOSH deploy.
    for i in {0..2}
    do bosh -n deploy
    done

    # Install kibana dashboard
    cat .releases/logsearch-for-cloudfoundry/target/kibana4-dashboards.json \
        | curl --data-binary @- http://${logsearch_es_ip}:9200/_bulk

    # Fix Tile Map visualization # http://git.io/vLYabb
    if [[ $(curl -s http://${logsearch_es_ip}:9200/_template/ | grep -v geo_pointt) ]]; then
        echo "installing default elasticsarch index template"
        curl -XPUT http://${logsearch_es_ip}:9200/_template/logstash -d \
             '{"template":"logstash-*","order":10,"settings":{"number_of_shards":4,"number_of_replicas":1,"index":{"query":{"default_field":"@message"},"store":{"compress":{"stored":true,"tv":true}}}},"mappings":{"_default_":{"_all":{"enabled":false},"_source":{"compress":true},"_ttl":{"enabled":true,"default":"2592000000"},"dynamic_templates":[{"string_template":{"match":"*","mapping":{"type":"string","index":"not_analyzed"},"match_mapping_type":"string"}}],"properties":{"@message":{"type":"string","index":"analyzed"},"@tags":{"type":"string","index":"not_analyzed"},"@timestamp":{"type":"date","index":"not_analyzed"},"@type":{"type":"string","index":"not_analyzed"},"message":{"type":"string","index":"analyzed"},"message_data":{"type":"object","properties":{"Message":{"type":"string","index":"analyzed"}}},"geoip":{"properties":{"location":{"type":"geo_point"}}}}}}}'

        echo "deleting all indexes since installed template only applies to new indexes"
        curl -XDELETE http://${logsearch_es_ip}:9200/logstash-*
    fi
fi


echo "Provision script completed..."
exit 0

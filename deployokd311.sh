#!/bin/bash
#
ARGS=$(getopt -o a:b:c: -l "masternode_public_dns:, masternode_private_dns:, workernodes_private_dns:" -- "$@");
echo $ARGS;
eval set -- "$ARGS";

while true
do
  case "$1" in
  -a | --masternode_public_dns)
  shift;
  if [ -n "$1" ];then
    masternode_public_dns=$1;
   shift;
  fi
  ;;
  -b | --masternode_private_dns)
  shift;
  if [ -n "$1" ];then
    masternode_private_dns=$1;
   shift;
  fi
  ;;
  -c | --workernodes_private_dns)
  shift;
  if [ -n "$1" ];then
    workernodes_private_dns=$1;
   shift;
  fi
  ;;
  --)
  shift;
  break;
  ;;
  esac
done


sudo yum -y update
sudo yum -y install git expect

rm -rf okd-requirements
git clone https://github.com/corestackdev/okd-requirements.git
cp okd-requirements/*.yaml .
cp okd-requirements/*.expect .
chmod +x *.expect
sed -i "s/private_hostname_master_node/$masternode_private_dns/g" inventory.yaml
sed -i "s/public_hostname_master_node/$masternode_public_dns/g" inventory.yaml
sed -i "s/YOUR_PASSWORD/corecent123/g" login.expect
sudo sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' /etc/ssh/ssh_config

cat /dev/zero | ssh-keygen -q -N ""

for node in $workernodes_private_dns
do
    echo "$node openshift_node_group_name='node-config-compute' ansible_ssh_common_args='-o StrictHostKeyChecking=no'" >> inventory.yaml
    ./login.expect centos@$node
done

cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

sudo yum -y install epel-release
sudo yum -y install ansible

git clone https://github.com/openshift/openshift-ansible -b release-3.11
ansible-playbook prepare.yaml -i inventory.yaml
ansible-playbook openshift-ansible/playbooks/prerequisites.yml -i inventory.yaml

ansible-playbook openshift-ansible/playbooks/deploy_cluster.yml -i inventory.yaml

for node in $workernodes_private_dns
do
    ssh $node "sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config; sudo service sshd restart"
done
sudo sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/no/yes/' /etc/ssh/ssh_config

exit 0

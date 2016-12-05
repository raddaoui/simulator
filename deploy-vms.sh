#!/usr/bin/env bash
set -eu
# Copyright [2016] [Kevin Carter]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Load all functions and variables
source functions.rc
source vars.rc

# Reset the ssh-agent service to remove potential key issues
ssh_agent_reset


# Create VM Basic Configuration files
for node in $(get_all_nodes_host); do
  node_ip=${node##*','}
  node_type=${node%%','*}
  temp=${node%','*}
  node_name=${temp#*','}
  for vm_name in $(virsh list --all --name | grep "$node_name"); do
    virsh destroy "${vm_name}" || true
    virsh undefine "${vm_name}" || true
  done
  cp -v "/opt/templates/vmnode-config/${node_type}.openstackci.local.xml" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__NODE__|$node_name|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_PXE__|`ip_2_mac 52:54: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_MGMT__|`ip_2_mac 52:55: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_FLAT__|`ip_2_mac 52:56: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_VLAN__|`ip_2_mac 52:57: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_VXLAN__|`ip_2_mac 52:58: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__MAC_STORAGE__|`ip_2_mac 52:59: $node_ip`|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
  sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g" /etc/libvirt/qemu/$node_name.openstackci.local.xml
done

## Populate network configurations based on node type
#for node_type in $(get_all_types); do
#  for node in $(get_host_type ${node_type}); do
#    sed "s/__COUNT__/${node#*":"}/g" "/opt/templates/network-interfaces/vm.openstackci.local-bonded-bridges.cfg" > "/var/www/html/osa-${node%%":"*}.openstackci.local-bridges.cfg"
#  done
#done

# Kick all of the VMs to run the cloud
#  !!!THIS TASK WILL DESTROY ALL OF THE ROOT DISKS IF THEY ALREADY EXIST!!!
rekick_vms

# Wait here for all nodes to be booted and ready with SSH
wait_ping


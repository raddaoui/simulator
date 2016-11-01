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

# Load all functions
source functions.rc

# Make the rekick function part of the main general shell
declare -f rekick_vms | tee /root/.functions.rc
declare -f ssh_agent_reset | tee -a /root/.functions.rc

if ! grep -q 'source /root/.functions.rc' /root/.bashrc; then
  echo 'source /root/.functions.rc' | tee -a /root/.bashrc
fi

# Reset the ssh-agent service to remove potential key issues
ssh_agent_reset


# Install basic packages known to be needed
apt-get update && apt-get install -y software-properties-common bridge-utils ifenslave libvirt-bin lvm2 openssh-server python2.7 qemu-kvm vim virtinst virt-manager vlan

if ! grep "^source.*cfg$" /etc/network/interfaces; then
  echo 'source /etc/network/interfaces.d/*.cfg' | tee -a /etc/network/interfaces
fi

# Clean up stale NTP processes. This is because of BUG https://bugs.launchpad.net/ubuntu/+source/ntp/+bug/1125726
pkill lockfile-create || true

# Set the forward rule
if ! grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf; then
  sysctl -w net.ipv4.ip_forward=1 | tee -a /etc/sysctl.conf
fi

cat > /etc/apt/sources.list <<EOF
# Faster likely unsigned repo
deb [arch=amd64] http://mirror.rackspace.com/ubuntu trusty main universe
deb [arch=amd64] http://mirror.rackspace.com/ubuntu trusty-updates main universe
deb [arch=amd64] http://mirror.rackspace.com/ubuntu trusty-backports main universe
deb [arch=amd64] http://mirror.rackspace.com/ubuntu trusty-security main universe

# i386 comes from the global known repo. This is slower and so it is only used for i386 packages
deb [arch=i386] http://archive.ubuntu.com/ubuntu trusty main universe
deb [arch=i386] http://archive.ubuntu.com/ubuntu trusty-updates main universe
deb [arch=i386] http://archive.ubuntu.com/ubuntu trusty-backports main universe
deb [arch=i386] http://archive.ubuntu.com/ubuntu trusty-security main universe
EOF

# Allow apt repos to be UnAuthenticated
cat > /etc/apt/apt.conf.d/00-nokey <<EOF
APT { Get { AllowUnauthenticated "1"; }; };
EOF

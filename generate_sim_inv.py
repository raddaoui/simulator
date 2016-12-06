#!/usr/bin/env python

import os
from os import path
import sys
import yaml
import netaddr
import json

LIB_DIR = path.join(os.getcwd(), 'lib')
sys.path.append(LIB_DIR)

import ip

USED_IPS = set()

def set_used_ips(user_defined_config):
    """Set all of the used ips into a global list.
    :param user_defined_config: ``dict`` User defined configuration
    """
    used_ips = user_defined_config.get('used_ips')
    if isinstance(used_ips, list):
        for ip in used_ips:
            split_ip = ip.split(',')
            if len(split_ip) >= 2:
                ip_range = list(
                    netaddr.iter_iprange(
                        split_ip[0],
                        split_ip[-1]
                    )
                )
                USED_IPS.update([str(i) for i in ip_range])
            else:
                logger.debug("IP %s set as used", split_ip[0])
                USED_IPS.add(split_ip[0])


def load_user_configuration(config_path):
    """Create a user configuration dictionary from config files

    :param config_path: ``str`` path where the configuration files are kept
    """

    user_defined_config = dict()

    # Load the user defined configuration file
    if os.path.isfile(config_path):
        with open(config_path, 'rb') as f:
            user_defined_config.update(yaml.safe_load(f.read()) or {})


    # Exit if no user_config was found and loaded
    if not user_defined_config:
        raise SystemExit(
            'No user config loaded\n'
        )
    return user_defined_config



def get_sim_hosts(user_defined_config):
    return user_defined_config.get('simulator_hosts').keys()


def generate_inv(sim_hosts, manager, vms_per_host, nodes_index):
    inv = {}
    for host in sim_hosts:
      inv[host] = {}
      inv[host]["nova_compute"] ={}
      for i in range(vms_per_host):
        inv[host]["nova_compute"]["compute" + str(nodes_index) ] = {}
        inv[host]["nova_compute"]["compute" + str(nodes_index)]["ansible_pxe_host"] = manager.get('pxe')
        inv[host]["nova_compute"]["compute" + str(nodes_index)]["ansible_mgmt_host"] = manager.get('mgmt')
        inv[host]["nova_compute"]["compute" + str(nodes_index)]["ansible_tunnel_host"] = manager.get('tunnel')
        inv[host]["nova_compute"]["compute" + str(nodes_index)]["ansible_storage_host"] = manager.get('storage')
        inv[host]["nova_compute"]["compute" + str(nodes_index)]["ansible_flat_host"] = manager.get('flat')
        nodes_index = nodes_index + 1
    return inv
    

def main():
    "main function"

    config_file = "sim_user_config.yml"
    user_defined_config = load_user_configuration(config_file)

    # get hosts that will be used by simulator
    sim_hosts = get_sim_hosts(user_defined_config)
    vms_per_host = int(user_defined_config.get('vms_per_host'))
    nodes_index = int(user_defined_config.get('nodes_index'))

    # get cidr_networks
    cidr_networks = user_defined_config.get('cidr_networks')
    if not cidr_networks:
        raise SystemExit('No nodes CIDR specified in user config')
    try: 
        pxe_cidr = cidr_networks['pxe']
        mgmt_cidr = cidr_networks['mgmt']
        tunnel_cidr = cidr_networks['tunnel']
        storage_cidr = cidr_networks['storage']
        flat_cidr = cidr_networks['flat']
    except Exception as e:
        raise SystemExit('one of pxe, mgmt, tunnel, flat or storage network is not'
                         'specified in user config.')

    # Load all of the IP addresses that we know are used
    set_used_ips(user_defined_config)
    # exclude broadcast and network ips for each cidr
    base_exclude = []
    for cidr in [pxe_cidr, mgmt_cidr, tunnel_cidr, storage_cidr, flat_cidr]:
        base_exclude.append(str(netaddr.IPNetwork(cidr).network))
        base_exclude.append(str(netaddr.IPNetwork(cidr).broadcast))
    USED_IPS.update(base_exclude)

    # set the queues
    manager = ip.IPManager(queues={'pxe': pxe_cidr, 'mgmt': mgmt_cidr, 'tunnel': tunnel_cidr, 'storage': storage_cidr, 'flat': flat_cidr},
                             used_ips=USED_IPS)
    # generate inventory
    inv = generate_inv(sim_hosts, manager, vms_per_host, nodes_index)
    # save inventory
    with open('sim_inv.json', 'w') as outfile:
      json.dump(inv, outfile)
    # generate osa inventory
    with open('compute_vms.yml', 'w') as f:
      f.write('---\n')
      f.write('compute_vms:\n')
      for (k,v) in inv.items():
        for(kk,vv) in v.items():
          for (kkk,vvv) in vv.items():
            f.write('  ' + kkk + ':\n')
            f.write('    ip: ' + vvv['ansible_mgmt_host'] + '\n')
      f.close()
    # generate static inventory
    with open('compute_vms_static_inv.yml', 'w') as f:
      f.write('[compute_vms]\n')
      for (k,v) in inv.items():
        for(kk,vv) in v.items():
          for (kkk,vvv) in vv.items():
            f.write(kkk + '  ansible_ssh_host=' + vvv['ansible_mgmt_host'] + '\n')
      f.close()

if __name__ == "__main__":

    main()

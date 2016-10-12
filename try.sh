#!/bin/bash
source vars.rc
echo $cobbler_ip
echo $cobbler_ip1
sed -i "s/subnet 10.0.0.0 netmask 255.255.255.0/subnet $pxe_subnet netmask $pxe_mask/g" dhcp.template
sed -i "s/routers             10.0.0.200/routers             $pxe_gateway/g" dhcp.template
sed -i "s/option subnet-mask         255.255.255.0/option subnet-mask         $pxe_mask/g" dhcp.template
sed -i "s/dynamic-bootp        10.0.0.1 10.0.0.50/dynamic-bootp        ${dhcp_range%','*} ${dhcp_range#*','}/g" dhcp.template




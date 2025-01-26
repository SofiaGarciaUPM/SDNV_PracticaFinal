#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# VACC: "pod_id" or "deploy/deployment_id" of the access vnf
# VCPE: "pod_id" or "deploy/deployment_id" of the cpe vnf
# CUSTUNIP: the ip address for the customer side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $KUBECTL
: $SDWNS
: $NETNUM
: $VACC
: $VCPE
: $CUSTUNIP
: $CUSTPREFIX
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW

if [[ ! $VACC =~ "-accesschart"  ]]; then
   echo ""       
   echo "ERROR: incorrect <access_deployment_id>: $VACC"
   exit 1
fi

if [[ ! $VCPE =~ "-cpechart"  ]]; then
   echo ""       
   echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
   exit 1
fi

ACC_EXEC="$KUBECTL exec -n $SDWNS $VACC --"
CPE_EXEC="$KUBECTL exec -n $SDWNS $VCPE --"

# IP privada por defecto para el vCPE
VCPEPRIVIP="192.168.255.254"
# IP privada por defecto para el router del cliente
CUSTGW="192.168.255.253"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs de las VNFs
echo "## 1. Obtener IPs de las VNFs"
IPACCESS=`$ACC_EXEC hostname -I | awk '{print $1}'`
echo "IPACCESS = $IPACCESS"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF:
echo "## 2. Iniciar el Servicio OpenVirtualSwitch en cada VNF"
$ACC_EXEC service openvswitch-switch start
$CPE_EXEC service openvswitch-switch start

## 3. En VNF:access agregar un bridge y configurar IPs y rutas
echo "## 3. En VNF:access agregar un bridge y configurar IPs y rutas"
$ACC_EXEC ovs-vsctl add-br brint
$ACC_EXEC ifconfig net$NETNUM $VNFTUNIP/24
$ACC_EXEC ip link add vxlan2 type vxlan id 2 remote $CUSTUNIP dstport 8742 dev net$NETNUM
$ACC_EXEC ip link add axscpe type vxlan id 4 remote $IPCPE dstport 8742 dev eth0
$ACC_EXEC ovs-vsctl add-port brint vxlan2
$ACC_EXEC ovs-vsctl add-port brint axscpe
$ACC_EXEC ifconfig vxlan2 up
$ACC_EXEC ifconfig axscpe up

## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas
echo "## 4. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ovs-vsctl add-br brint
$CPE_EXEC ifconfig brint $VCPEPRIVIP/24
$CPE_EXEC ip link add axscpe type vxlan id 4 remote $IPACCESS dstport 8742 dev eth0
$CPE_EXEC ovs-vsctl add-port brint axscpe
$CPE_EXEC ifconfig axscpe up
$CPE_EXEC ifconfig brint mtu 1400
$CPE_EXEC ifconfig net$NETNUM $VCPEPUBIP/24
$CPE_EXEC ip route add $IPACCESS/32 via $K8SGW
$CPE_EXEC ip route del 0.0.0.0/0 via $K8SGW
$CPE_EXEC ip route add 0.0.0.0/0 via $VCPEGW
$CPE_EXEC ip route add $CUSTPREFIX via $CUSTGW

## 5. En VNF:cpe activar NAT para dar salida a Internet
echo "## 5. En VNF:cpe activar NAT para dar salida a Internet"
$CPE_EXEC /vnx_config_nat brint net$NETNUM

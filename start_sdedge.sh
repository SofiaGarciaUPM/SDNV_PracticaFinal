#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# VACC: "pod_id" or "deploy/deployment_id" of the access vnf
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
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
: $VWAN
: $VCTRL
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

if [[ ! $VWAN =~ "-wanchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
    exit 1
fi

if [[ ! $VCTRL =~ "-ctrlchart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <ctrl_deployment_id>: $VCTRL"
    exit 1
fi

ACC_EXEC="$KUBECTL exec -n $SDWNS $VACC --"
CPE_EXEC="$KUBECTL exec -n $SDWNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $SDWNS $VWAN --"
CTRL_EXEC="$KUBECTL exec -n $SDWNS $VCTRL --"

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

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

IPCTRL=`$CTRL_EXEC hostname -I | awk '{print $1}'`
echo "IPCTRL = $IPCTRL"

## 2. Iniciar el Servicio OpenVirtualSwitch en wan VNF:
echo "## 2. Iniciar el Servicio OpenVirtualSwitch en wan VNF"
$WAN_EXEC service openvswitch-switch start
$CTRL_EXEC service openvswitch-switch start

## 3. En VNF:access agregar un bridge y sus vxlans
echo "## 3. En VNF:access agregar un bridge y sus vxlan"
$ACC_EXEC ovs-vsctl add-br brwan
$ACC_EXEC ip link add vxlan1 type vxlan id 1 remote $CUSTUNIP dstport 4789 dev net$NETNUM
$ACC_EXEC ip link add axswan type vxlan id 3 remote $IPWAN dstport 4788 dev eth0
$ACC_EXEC ovs-vsctl add-port brwan vxlan1
$ACC_EXEC ovs-vsctl add-port brwan axswan
$ACC_EXEC ifconfig vxlan1 up
$ACC_EXEC ifconfig axswan up

## 4. En VNF:wan agregar el conmutador y su vxlan
echo "## 4. En VNF:wan agregar el conmutador y su vxlan"
$WAN_EXEC ovs-vsctl add-br brwan
$WAN_EXEC ip link add axswan type vxlan id 3 remote $IPACCESS dstport 4788 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan axswan
#in the following, it should be net1 (only one MplsNet)
$WAN_EXEC ovs-vsctl add-port brwan net1
$WAN_EXEC ifconfig axswan up

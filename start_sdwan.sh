#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site

set -u # to verify variables are defined
: $KUBECTL
: $SDWNS
: $NETNUM
: $VCPE
: $VWAN
: $VACC
: $VCTRL
: $REMOTESITE

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

CPE_EXEC="$KUBECTL exec -n $SDWNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $SDWNS $VWAN --"
ACC_EXEC="$KUBECTL exec -n $SDWNS $VACC --"
CTRL_EXEC="$KUBECTL exec -n $SDWNS $VCTRL --"
CTRL_SERV="${VCTRL/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

IPCTRL=`$CTRL_EXEC hostname -I | awk '{print $1}'`
echo "IPCTRL = $IPCTRL"

IPACC=`$ACC_EXEC hostname -I | awk '{print $1}'`
echo "IPACC = $IPACC"

PORTCTRL=`$KUBECTL get -n $SDWNS -o jsonpath="{.spec.ports[0].nodePort}" service $CTRL_SERV`
echo "PORTCTRL = $PORTCTRL"

#PORTWAN=`$KUBECTL get -n $SDWNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
#echo "PORTWAN = $PORTWAN"

## 2. En VNF:ctrl arrancar controlador SDN"
echo "## 2.En VNF:ctrl arrancar controlador SDN"
$CTRL_EXEC /usr/local/bin/ryu-manager flowmanager/flowmanager.py ryu.app.ofctl_rest ryu.app.rest_qos ryu.app.rest_conf_switch qos_simple_switch_13.py 2>&1 | tee ryu.log &
 
echo "[DEBUG] Ryu se está ejecutando"


## 3. En VNF:wan activar el modo SDN del conmutador y crear vxlan
echo "## 3. En VNF:wan activar el modo SDN del conmutador y crear vxlan"
$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$WAN_EXEC ovs-vsctl set-manager ptcp:6632

$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up


## 4. En VNF:cpe agregar un bridge, sus vxlan y activar el modo SDN
echo "## 4. En VNF:cpe agregar un bridge, configurar IPs, rutas y activar el modo SDN"
$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan

$CPE_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$CPE_EXEC ovs-vsctl set-fail-mode brwan secure
$CPE_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$CPE_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$CPE_EXEC ovs-vsctl set-manager ptcp:6632

$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 remote $REMOTESITE dstport 8742 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up


## 5. Activar el modo SDN en VNF:access
echo "## 5. Activar el modo SDN en VNF:access"
$ACC_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brwan secure
$ACC_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000003
$ACC_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633
$ACC_EXEC ovs-vsctl set-manager ptcp:6632


## 6. Aplica las reglas de la sdwan con ryu
echo "## 6. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL="http://localhost:$PORTCTRL/stats/flowentry/add"
curl -X POST -d @json/from-cpe.json $RYU_ADD_URL
curl -X POST -d @json/to-cpe.json $RYU_ADD_URL
curl -X POST -d @json/broadcast-from-axs.json $RYU_ADD_URL
curl -X POST -d @json/from-mpls.json $RYU_ADD_URL
curl -X POST -d @json/to-voip-gw.json $RYU_ADD_URL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL

## 7. Aplica las reglas de QoS
## *******************************************************************************************
## | Grupo |        Sentido                  |Global(Mbps) | Puerto dst = 5005 (mínimo, Kbps)|
## | G16   | Subida: Sede remota --> voip-gw |     3,4     |                1800             |
## *******************************************************************************************

echo "## 7. Aplica las reglas de QoS"
$CTRL_EXEC chmod 666 /var/run/openvswitch/db.sock
sudo chmod 666 /var/run/openvswitch/db.sock
CONF_OVSDB="http://$IPCTRL:8080/v1.0/conf/switches/0000000000000003/ovsdb_addr"

curl -X PUT -d "\"tcp:$IPACC:6632\"" $CONF_OVSDB
curl -X POST -d @json_qos/rules.json http://$IPCTRL:8080/qos/rules/0000000000000003
curl -X POST -d @json_qos/queue.json http://$IPCTRL:8080/qos/queue/0000000000000003


echo "--"
echo "sdedge$NETNUM: Abrir Firefox para ver sus flujos Openflow:"
echo "firefox http://localhost:$PORTCTRL/home/ &"
echo "firefox http://$IPCTRL:8080/qos/queue/0000000000000003 &"
echo "firefox http://$IPCTRL:8080/qos/rules/0000000000000003 &"

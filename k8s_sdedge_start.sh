#!/bin/bash
  
# Requires the following variables
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# CUSTUNIP: the ip address for the customer side of the tunnel
# VNFTUNIP: the ip address for the vnf side of the tunnel
# VCPEPUBIP: the public ip address for the vcpe
# VCPEGW: the default gateway for the vcpe

set -u # to verify variables are defined
: $SDWNS
: $NETNUM
: $CUSTUNIP
: $VNFTUNIP
: $VCPEPUBIP
: $VCPEGW

export KUBECTL="microk8s kubectl"

## 0. Instalación
echo "## 0. Instalación de las vnfs"

echo "### 0.1 Limpieza (ignorar errores)"

for vnf in access cpe wan ryu
do
  helm -n $SDWNS uninstall $vnf$NETNUM 
done

for i in {1..15}; do echo -n "."; sleep 1; done
echo ''

echo "### 0.2 Creación de contenedores"

chart_suffix="chart-0.1.0.tgz"
for vnf in access cpe wan ryu
do
  echo '#### $vnf$NETNUM'
  helm -n $SDWNS install $vnf$NETNUM http://127.0.0.1:8080/$vnf$chart_suffix
done

for i in {1..40}; do echo -n "."; sleep 1; done
echo ''

export VACC="deploy/access$NETNUM-accesschart"
export VCPE="deploy/cpe$NETNUM-cpechart"
export VWAN="deploy/wan$NETNUM-wanchart"
export VRYU="deploy/ryu$NETNUM-ryuchart"

./start_corpcpe.sh
./start_sdedge.sh

echo "--"
echo "$(basename "$0")"
echo "K8s deployments para la red $NETNUM:"
echo $VACC
echo $VCPE
echo $VWAN
echo $VRYU

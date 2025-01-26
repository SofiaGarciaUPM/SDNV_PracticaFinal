#!/bin/bash
  
# Requires the following variables
# SDWNS: cluster namespace in the cluster vim
# SIID: id of the service instance
# NETNUM: used to select external networks
# REMOTESITE: the public IP of the remote site vCPE

set -u # to verify variables are defined
: $SDWNS
: $SIID
: $NETNUM
: $REMOTESITE

export KUBECTL="microk8s kubectl"

export VACC="deploy/access$NETNUM-accesschart"
export VCPE="deploy/cpe$NETNUM-cpechart"
export VWAN="deploy/wan$NETNUM-wanchart"
export VRYU="deploy/ryu$NETNUM-ryuchart"

./start_sdwan.sh


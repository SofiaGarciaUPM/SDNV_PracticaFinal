#!/bin/bash
export SDWNS  # needs to be defined in calling shell
export SIID="$NSID2" # $NSID2, for OSM, to be defined in calling shell

export NETNUM=2 # used to select external networks

export REMOTESITE="10.100.1.1"

# HELM SECTION
./k8s_sdwan_start.sh
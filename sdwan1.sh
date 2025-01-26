#!/bin/bash
export SDWNS  # needs to be defined in calling shell
export SIID="$NSID1" # $NSID1, for OSM, to be defined in calling shell

export NETNUM=1 # used to select external networks

export REMOTESITE="10.100.2.1"

# HELM SECTION
./k8s_sdwan_start.sh
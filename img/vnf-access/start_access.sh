#! /bin/bash

# fucntion to calculate the next IP address
nextip(){
    IP=$1
    IP_HEX=$(printf '%.2X%.2X%.2X%.2X\n' `echo $IP | sed -e 's/\./ /g'`)
    NEXT_IP_HEX=$(printf %.8X `echo $(( 0x$IP_HEX + 1 ))`)
    NEXT_IP=$(printf '%d.%d.%d.%d\n' `echo $NEXT_IP_HEX | sed -r 's/(..)/0x\1 /g'`)
    echo "$NEXT_IP"
}

echo "Access container started"
PORT="access0"
# actual port to find out X in port name access0-X
ACTUAL_PORT=`ifconfig | grep $PORT | awk '{print $1}'`

IP=`hostname -I | awk '{printf "%s\n", $1}{print $2}' | grep 192.168.100`

# assume cpe is assigned next IP address
IPCPE=$(nextip $IP)
# assume wan is assigned next IP address to CPE
IPWAN=$(nextip $IPCPE)

echo "Start ovs"
service openvswitch-switch start

echo "Create bridges"
ovs-vsctl add-br brint
ovs-vsctl add-br brwan

echo "Create vxlan tunnel to cpe vnf"
ovs-vsctl add-port brint axscpe -- set interface axscpe type=vxlan options:remote_ip=$IPCPE options:key=inet options:dst_port=8742

echo "Create vxlan tunnel to wan vnf"
ovs-vsctl add-port brwan axswan -- set interface axswan type=vxlan options:remote_ip=$IPWAN


echo "Configure uplink bandwidth limit for VXLAN (UDP) traffic to cpe"
tc qdisc add dev $ACTUAL_PORT root  handle 1: htb default 1
tc class add dev $ACTUAL_PORT parent 1: classid 1:10 htb rate 20Mbit ceil 20Mbit
tc filter add dev $ACTUAL_PORT protocol ip u32 match ip protocol 0x11 0xff match ip dport 8742 0xffff flowid 1:10

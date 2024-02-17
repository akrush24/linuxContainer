#!/bin/bash
set -ex

CONTAINER_IP=172.17.0.10
HOST_GW=172.17.0.1
PUBLIC_PORT=8080
HOST_PUBLIC_PORT=8088
CONTAINER_ID=001

echo "Show all interfaces"
ip link show
echo "Show all network NS"
ip netns list

echo "Add new network NS"
ip netns | grep cont${CONTAINER_ID} || ip netns add cont${CONTAINER_ID}
ip link show veth${CONTAINER_ID} || (ip link add veth${CONTAINER_ID} type veth peer name cveth${CONTAINER_ID} && \
ip link set cveth${CONTAINER_ID} netns cont${CONTAINER_ID})

echo "Add linux bridge"
ip link show br0 || ip link add br0 type bridge
ip link set br${CONTAINER_ID} up
ip link set veth${CONTAINER_ID} master br0

nsenter --net=/run/netns/cont${CONTAINER_ID} ip -br link list
nsenter --net=/run/netns/cont${CONTAINER_ID} ip link set up lo
nsenter --net=/run/netns/cont${CONTAINER_ID} ip link set up cveth${CONTAINER_ID}
nsenter --net=/run/netns/cont${CONTAINER_ID} ip addr add ${CONTAINER_IP}/24 dev cveth${CONTAINER_ID}
nsenter --net=/run/netns/cont${CONTAINER_ID} ip route show
ip link set veth${CONTAINER_ID} up
ip addr add ${HOST_GW}/24 dev veth${CONTAINER_ID}
ip addr show -br veth${CONTAINER_ID}
# Add NAT
iptables -t nat -A POSTROUTING -s 172.17.0.0/24 ! -o veth${CONTAINER_ID} -j MASQUERADE

# public port 
iptables -t nat -A PREROUTING -d ${CONTAINER_IP} -p tcp -m tcp --dport 5000 \
    -j DNAT --to-destination ${CONTAINER_IP}:${PUBLIC_PORT}

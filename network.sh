#!/bin/bash

CONTAINER_IP=172.17.0.10
PUBLIC_PORT=8080
HOST_PUBLIC_PORT=8088

CONTAINER_ID=001

ip link show
echo "Show all network NS"
ip netns list

echo "Add new network NS"
ip netns | grep cont${CONTAINER_ID} || ip netns add cont${CONTAINER_ID}
ip link show veth0 || (ip link add veth${CONTAINER_ID} type veth peer name cveth${CONTAINER_ID} && \
ip link set cveth0 netns cont${CONTAINER_ID})
nsenter --net=/run/netns/cont${CONTAINER_ID} ip -br l l
nsenter --net=/run/netns/cont${CONTAINER_ID} ip link set up lo
nsenter --net=/run/netns/cont${CONTAINER_ID} ip link set up cveth0
nsenter --net=/run/netns/cont${CONTAINER_ID} ip addr add ${CONTAINER_IP}/24 dev cveth0
nsenter --net=/run/netns/cont${CONTAINER_ID} ip route show
ip link set veth0 up
ip addr add 172.17.0.1/24 dev veth0
ip addr show -br veth0
# Add NAT
iptables -t nat -A POSTROUTING -s 172.17.0.0/24 ! -o veth0 -j MASQUERADE

# public port 
iptables -t nat -A PREROUTING -d ${CONTAINER_IP} -p tcp -m tcp --dport 5000 \
    -j DNAT --to-destination ${CONTAINER_IP}:5000

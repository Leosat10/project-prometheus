#!/bin/bash
set -e

echo "### Destroying any existing lab..."
sudo containerlab destroy -t phase1.clab.yml --cleanup || true

echo "### Deploying fresh lab..."
sudo containerlab deploy -t phase1.clab.yml

echo "### Waiting 10 seconds for containers to boot..."
sleep 10

echo "### Configuring Spine1 underlay..."
docker exec clab-phase1-spine1 vtysh -c "
configure terminal
interface eth1
 ip address 10.0.1.1/30
 no shutdown
!
interface eth2
 ip address 10.0.2.1/30
 no shutdown
!
interface lo
 ip address 1.1.1.1/32
!
router bgp 65000
 bgp router-id 1.1.1.1
 neighbor 10.0.1.2 remote-as 65001
 neighbor 10.0.2.2 remote-as 65002
 address-family ipv4 unicast
  network 1.1.1.1/32
  neighbor 10.0.1.2 activate
  neighbor 10.0.2.2 activate
 exit-address-family
!
end
write memory
"

echo "### Configuring Spine2 underlay..."
docker exec clab-phase1-spine2 vtysh -c "
configure terminal
interface eth1
 ip address 10.0.3.1/30
 no shutdown
!
interface eth2
 ip address 10.0.4.1/30
 no shutdown
!
interface lo
 ip address 2.2.2.2/32
!
router bgp 65000
 bgp router-id 2.2.2.2
 neighbor 10.0.3.2 remote-as 65001
 neighbor 10.0.4.2 remote-as 65002
 address-family ipv4 unicast
  network 2.2.2.2/32
  neighbor 10.0.3.2 activate
  neighbor 10.0.4.2 activate
 exit-address-family
!
end
write memory
"

echo "### Configuring Leaf1 underlay..."
docker exec clab-phase1-leaf1 vtysh -c "
configure terminal
interface eth1
 ip address 10.0.1.2/30
 no shutdown
!
interface eth2
 ip address 10.0.3.2/30
 no shutdown
!
interface lo
 ip address 3.3.3.3/32
!
router bgp 65001
 bgp router-id 3.3.3.3
 neighbor 10.0.1.1 remote-as 65000
 neighbor 10.0.3.1 remote-as 65000
 address-family ipv4 unicast
  network 3.3.3.3/32
  neighbor 10.0.1.1 activate
  neighbor 10.0.3.1 activate
 exit-address-family
!
end
write memory
"

echo "### Configuring Leaf2 underlay..."
docker exec clab-phase1-leaf2 vtysh -c "
configure terminal
interface eth1
 ip address 10.0.2.2/30
 no shutdown
!
interface eth2
 ip address 10.0.4.2/30
 no shutdown
!
interface lo
 ip address 4.4.4.4/32
!
router bgp 65002
 bgp router-id 4.4.4.4
 neighbor 10.0.2.1 remote-as 65000
 neighbor 10.0.4.1 remote-as 65000
 address-family ipv4 unicast
  network 4.4.4.4/32
  neighbor 10.0.2.1 activate
  neighbor 10.0.4.1 activate
 exit-address-family
!
end
write memory
"

echo "### Waiting 10 seconds for BGP to converge..."
sleep 10

echo "### Setting up VXLAN overlay on Leaf1..."
docker exec clab-phase1-leaf1 bash -c "
ip link add vxlan10 type vxlan id 10010 local 3.3.3.3 remote 4.4.4.4 dstport 4789
ip link set vxlan10 up
ip link add br10 type bridge
ip link set br10 up
ip link set eth3 master br10
ip link set vxlan10 master br10
"

echo "### Setting up VXLAN overlay on Leaf2..."
docker exec clab-phase1-leaf2 bash -c "
ip link add vxlan10 type vxlan id 10010 local 4.4.4.4 remote 3.3.3.3 dstport 4789
ip link set vxlan10 up
ip link add br10 type bridge
ip link set br10 up
ip link set eth3 master br10
ip link set vxlan10 master br10
"

echo "### Testing connectivity from client1 to client2..."
docker exec clab-phase1-client1 ping -c 3 192.168.10.20

echo "### All done!"


# Project Prometheus

A **self-healing, intent-based autonomous network fabric** built from scratch using open-source tools — designed to mirror the architecture of hyperscale data centers (AWS, Azure, Google).

> **Goal:** Build a production-grade, multi-tenant, EVPN/VXLAN data center fabric with intent-based provisioning, closed-loop automation, and real-time observability — using only open-source software and commodity hardware.

---

## Architecture Overview
+-------------------------------------------------------------+
| PHASE 1 & 2 (Foundation) |
| |
| +----------+ +----------+ |
| | Spine1 |<---- eBGP ----> | Spine2 | |
| | 1.1.1.1 | | 2.2.2.2 | |
| | AS 65000 | | AS 65000 | |
| +----+-----+ +-----+----+ |
| | | |
| +----+-----+ +-----+----+ |
| | Leaf1 |<--- EVPN/VXLAN --> | Leaf2 | |
| | 3.3.3.3 | | 4.4.4.4 | |
| | AS 65001 | | AS 65002 | |
| +----+-----+ +-----+----+ |
| | | |
| +----+-----+ +-----+----+ |
| | Client1 | | Client2 | |
| |.10.10/24 | |.10.20/24 | |
| +----------+ +----------+ |
| |
| Underlay: eBGP Overlay: VXLAN + EVPN |
| VLAN 10 -> VNI 10010 Anycast GW: 192.168.10.1 |
+-------------------------------------------------------------+

text

**Tech stack:** Containerlab | FRRouting | Docker | Linux bridges | VXLAN | EVPN | BGP | Alpine Linux

---

## Project Structure
project-prometheus/
├── README.md <- You are here
├── .gitignore
├── phase1/ <- BGP underlay + static VXLAN overlay
│ ├── README.md
│ ├── phase1.clab.yml
│ ├── setup_phase1.sh
│ ├── spine1/ spine2/ leaf1/ leaf2/
│ └── evidence/
├── phase2/ <- EVPN dynamic control plane
│ ├── README.md
│ ├── phase2.clab.yml
│ ├── spine1/ spine2/ leaf1/ leaf2/
│ └── evidence/
└── (future) phase3/ phase4/ ...

text

---

## Phase-by-Phase Breakdown

### PHASE 1 - Leaf-Spine Fabric with BGP Underlay + Static VXLAN Overlay

**Objective:** Build the physical + logical foundation of a data center fabric.

**What was built:**
- Leaf-Spine topology - 2 spines, 2 leaves, full-mesh interconnection
- eBGP underlay - AS 65000 (spines), AS 65001/65002 (leaves)
- Loopback peering - each device uses a /32 loopback as its stable router-ID
- VXLAN overlay (VNI 10010) - L2 extension across the L3 fabric
- Linux bridges - bind VXLAN tunnel (vxlan10) to client access port (eth3)
- Static VTEP mapping - remote 4.4.4.4 configured manually on each leaf

**Technologies:**
- eBGP (External BGP) for underlay routing
- VXLAN (Virtual Extensible LAN) for L2-over-L3 encapsulation
- VNI (VXLAN Network Identifier) 10010 mapped to VLAN 10
- Linux bridge (br10) as the L2 forwarding domain
- Docker containers + Containerlab for topology-as-code

**Key commands:**
```bash
sudo containerlab deploy -t phase1.clab.yml
docker exec clab-phase1-leaf1 vtysh -c "show ip bgp summary"
docker exec clab-phase1-client1 ping 192.168.10.20
Outcome: Clients on different leaf switches communicate over a VXLAN tunnel.

Limitation: VTEPs are statically configured - does not scale beyond a few leafs.

PHASE 2 - EVPN Dynamic Control Plane with Anycast Gateway
Objective: Replace static VXLAN with a dynamic, scalable EVPN control plane.

What was built:

EVPN address-family (l2vpn evpn) enabled on all four devices

Spines as BGP Route Reflectors - reflect EVPN routes between leaves

EVPN Type 2 routes - MAC/IP Advertisement (control-plane MAC learning)

EVPN Type 3 routes - Inclusive Multicast Ethernet Tag (dynamic VTEP discovery)

advertise-all-vni - automatic VNI advertisement from leaves

nolearning VXLAN - kernel does NOT learn MACs from data plane; BGP programs them

Anycast gateway - both leaves own 192.168.10.1/24 (active-active SVI)

ARP suppression - leafs answer ARP locally, reducing BUM traffic

no bgp ebgp-requires-policy - FRR policy fix to allow route exchange

Technologies:

EVPN (Ethernet VPN) - RFC 7432

BGP Route Reflection for EVPN address-family

VXLAN with nolearning flag (control-plane learning only)

Anycast SVI (same gateway IP on all leafs)

Dynamic VTEP discovery via Type 3 routes

MAC mobility handled by BGP

Key commands:

bash
docker exec clab-phase2-leaf1 vtysh -c "show bgp l2vpn evpn"
docker exec clab-phase2-leaf1 vtysh -c "show evpn mac vni 10010"
docker exec clab-phase2-leaf1 bridge fdb show dev vxlan10
Outcome: MACs and VTEPs are learned automatically via BGP - no static remote config. Fabric is now scalable to hundreds of leafs.

Why this matters: This is the exact architecture used by Cisco ACI, VMware NSX, and every hyperscaler SDN.

PHASE 3 (PLANNED) - Multi-Tenancy with VRFs + Source of Truth (NetBox)
Planned:

VRF Blue / VRF Red - isolated routing tables on the same physical fabric

L3 VNI + L2 VNI - full EVPN multi-tenancy (RFC 8365)

NetBox - single source of truth for IPAM, DCIM, and VLAN definitions

Intent-based provisioning - define intent in NetBox, auto-generate device configs

Jinja2 templates + Nornir - Python-driven config generation

NETCONF/RESTCONF - programmatic device management

PHASE 4 (PLANNED) - Observability & Telemetry
Planned:

Prometheus + gNMIc - streaming telemetry from FRR

Grafana dashboards - BGP peer state, EVPN route counts, MAC churn, tunnel health

ELK stack - syslog aggregation and analysis

Alertmanager - threshold-based alerts (e.g., BGP session down)

Custom fabric health score - single metric for overall state

PHASE 5 (PLANNED) - Closed-Loop Automation (Self-Healing)
Planned:

StackStorm - event-driven automation engine

Runbooks - auto-remediation of common failures

ChatOps - Slack/Teams approval workflows for high-risk actions

Confidence thresholds - auto-apply fixes with historical success rates

Full GitOps CI/CD - every config change flows through a pipeline with validation

Full Technology Stack
Layer	Technology	Purpose
Topology	Containerlab	Network topology as code
Containers	Docker	Lightweight network functions
Routing OS	FRRouting (FRR)	BGP/EVPN/VXLAN control plane
Underlay	eBGP	Reachability between loopbacks
Overlay	VXLAN	L2-over-L3 tunneling
Control Plane	EVPN (RFC 7432)	Dynamic VTEP + MAC learning
Route Reflection	BGP RR	EVPN route distribution
L2 Forwarding	Linux bridges	Bridge VXLAN to access ports
Clients	Alpine Linux	Simulated endpoints
Automation	Python, Nornir, Jinja2	Config generation (Phase 3+)
Source of Truth	NetBox	IPAM/DCIM (Phase 3+)
Telemetry	Prometheus, Grafana	Observability (Phase 4+)
Automation Engine	StackStorm	Closed-loop healing (Phase 5+)
How to Run
Prerequisites
Ubuntu 22.04 (or WSL2 on Windows)

Docker installed

Containerlab installed (bash -c "$(curl -sL https://containerlab.dev/install)")

Phase 1
bash
cd phase1
sudo containerlab deploy -t phase1.clab.yml
./setup_phase1.sh
docker exec clab-phase1-client1 ping -c 5 192.168.10.20
Phase 2
bash
cd phase2
sudo containerlab deploy -t phase2.clab.yml
# ... configure via vtysh (see phase2/README.md) ...
docker exec clab-phase2-client1 ping -c 5 192.168.10.20
Teardown
bash
sudo containerlab destroy -t phase1.clab.yml
sudo containerlab destroy -t phase2.clab.yml
Verification Checklist
Phase 1:

☑ All 4 BGP sessions Established
☑ Loopbacks reachable across fabric
☑ VXLAN tunnel up with static remote
☑ Clients ping across fabric (0% loss)
Phase 2:

☑ EVPN address-family Established on all devices
☑ Type 2 (MAC) and Type 3 (IMET) EVPN routes exchanged
☑ EVPN MAC table shows remote MAC via 4.4.4.4
☑ VXLAN FDB populated dynamically (no static remote)
☑ Anycast gateway responds on both leafs
☑ Clients ping across EVPN fabric (0% loss)
Skills Demonstrated
Data center network design - leaf-spine, spine-leaf fabric

BGP - eBGP, route reflection, address-families

VXLAN - VNI mapping, VTEPs, nolearning, Linux kernel networking

EVPN - Type 2/3 routes, MAC learning, anycast gateway

Linux networking - bridges, veth pairs, network namespaces

Containerlab - topology-as-code, containerized network functions

FRRouting - vtysh, daemon configuration, route-maps, policy

Debugging - layer-by-layer troubleshooting, BGP policy issues

Documentation - architecture diagrams, reproducible setups, evidence capture

References
RFC 7432 - BGP MPLS-Based Ethernet VPN (EVPN): https://datatracker.ietf.org/doc/html/rfc7432

RFC 8365 - A Network Virtualization Overlay Solution Using EVPN: https://datatracker.ietf.org/doc/html/rfc8365

RFC 7348 - VXLAN: https://datatracker.ietf.org/doc/html/rfc7348

Containerlab Documentation: https://containerlab.dev/

FRRouting Documentation: https://docs.frrouting.org/

Author
Leosat - Network Engineering Enthusiast
Building a self-healing, intent-based autonomous network fabric from scratch.

GitHub: https://github.com/Leosat10

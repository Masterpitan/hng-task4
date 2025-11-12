# VPC Control Tool (vpcctl)

A Linux-based Virtual Private Cloud implementation using native networking primitives for HNG Internship Task 4.

## Important Notes

📖 **For better understanding**: A manual setup walkthrough is highly recommended to understand the underlying networking concepts. See [minimal-manual-setup.md](minimal-manual-setup.md) for step-by-step manual configuration.

📝 **Documentation**: Complete project documentation and technical details are available in [blog-post.md](blog-post.md). The published version can be accessed at: https://dev.to/masterpitan/building-a-production-ready-vpc-implementation-on-linux-hng-internship-task-4-complete-vpc-control-3h9j

## Overview

This tool recreates VPC functionality using Linux network namespaces, veth pairs, bridges, routing tables, and iptables to provide:

- Virtual Private Clouds with isolated subnets
- Public/Private subnet types with NAT gateway functionality
- VPC peering for controlled inter-VPC communication
- Security groups via iptables rules
- Application deployment and testing capabilities

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host System                          │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │   VPC-1         │              │   VPC-2         │      │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │      │
│  │ │vpc-demo     │ │   Peering    │ │vpc-demo2    │ │      │
│  │ │(Bridge)     │◄┼──────────────┤►│(Bridge)     │ │      │
│  │ └─────────────┘ │              │ └─────────────┘ │      │
│  │       │         │              │       │         │      │
│  │   ┌───▼───┐ ┌───▼───┐          │   ┌───▼───┐     │      │
│  │   │Public │ │Private│          │   │Public │     │      │
│  │   │Subnet │ │Subnet │          │   │Subnet │     │      │
│  │   │(NS)   │ │(NS)   │          │   │(NS)   │     │      │
│  │   └───────┘ └───────┘          │   └───────┘     │      │
│  └─────────────────┐               └─────────────────┐      │
│                    │                                 │      │
│              ┌─────▼─────┐                          │      │
│              │    NAT    │                          │      │
│              │ (iptables)│                          │      │
│              └─────┬─────┘                          │      │
│                    │                                 │      │
│              ┌─────▼─────┐                          │      │
│              │ Internet  │                          │      │
│              │Interface  │                          │      │
│              └───────────┘                          │      │
└─────────────────────────────────────────────────────────────┘
```

## Requirements

- Linux system with root privileges
- Python 3.6+
- iproute2 package (`ip` command)
- iptables
- bridge-utils (optional)

## Installation

```bash
# Clone or download the project
cd hng-task4

# Check dependencies
make install

# Make scripts executable (Linux/WSL)
chmod +x vpcctl test-demo.sh cleanup.sh
```

## Quick Start

### 1. Create a VPC

```bash
sudo python3 vpcctl create-vpc demo-vpc 10.0.0.0/16
```

### 2. Add Subnets

```bash
# Public subnet (with internet access)
sudo python3 vpcctl add-subnet demo-vpc public-subnet 10.0.1.0/24 --type public

# Private subnet (no internet access)
sudo python3 vpcctl add-subnet demo-vpc private-subnet 10.0.2.0/24 --type private
```

### 3. List VPCs

```bash
sudo python3 vpcctl list
```

### 4. Deploy Applications

```bash
# Deploy web server in public subnet
sudo python3 vpcctl deploy-app demo-vpc public-subnet --type python --port 8080

# Deploy web server in private subnet
sudo python3 vpcctl deploy-app demo-vpc private-subnet --type python --port 8081
```

### 5. Test Connectivity

```bash
# Test internal connectivity
sudo python3 vpcctl test demo-vpc public-subnet 10.0.2.1

# Test internet connectivity
sudo python3 vpcctl test demo-vpc public-subnet 8.8.8.8
```

## Full Demo

Run the complete demonstration:

```bash
sudo make demo
```

This will:
1. Create VPCs with public/private subnets
2. Deploy test applications
3. Test connectivity and isolation
4. Demonstrate VPC peering
5. Apply security policies

## Security Policies

Create JSON policy files to define firewall rules:

```json
{
  "subnet": "10.0.1.0/24",
  "ingress": [
    {"port": 80, "protocol": "tcp", "action": "allow"},
    {"port": 443, "protocol": "tcp", "action": "allow"},
    {"port": 22, "protocol": "tcp", "action": "deny"}
  ]
}
```

Apply the policy:

```bash
sudo python3 vpcctl apply-policy demo-vpc policy.json
```

## VPC Peering

Connect two VPCs for controlled communication:

```bash
# Create second VPC
sudo python3 vpcctl create-vpc vpc2 172.16.0.0/16
sudo python3 vpcctl add-subnet vpc2 subnet2 172.16.1.0/24 --type public

# Create peering connection
sudo python3 vpcctl peer-vpcs demo-vpc vpc2
```

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `create-vpc` | Create new VPC | `vpcctl create-vpc myVPC 10.0.0.0/16` |
| `add-subnet` | Add subnet to VPC | `vpcctl add-subnet myVPC subnet1 10.0.1.0/24 --type public` |
| `list` | List all VPCs | `vpcctl list` |
| `deploy-app` | Deploy test app | `vpcctl deploy-app myVPC subnet1 --type python --port 8080` |
| `test` | Test connectivity | `vpcctl test myVPC subnet1 8.8.8.8` |
| `apply-policy` | Apply security rules | `vpcctl apply-policy myVPC policy.json` |
| `peer-vpcs` | Create VPC peering | `vpcctl peer-vpcs vpc1 vpc2` |
| `delete-vpc` | Delete VPC | `vpcctl delete-vpc myVPC` |

## Testing Scenarios

### 1. Subnet Communication
- ✅ Subnets within same VPC can communicate
- ✅ Public subnet has internet access
- ✅ Private subnet blocked from internet

### 2. VPC Isolation
- ✅ Different VPCs cannot communicate by default
- ✅ VPC peering enables controlled communication

### 3. Security Groups
- ✅ Port-based access control
- ✅ Protocol filtering
- ✅ Allow/deny rules

### 4. NAT Gateway
- ✅ Public subnets have outbound internet access
- ✅ Private subnets remain internal-only

## Cleanup

Remove all VPC resources:

```bash
sudo make cleanup
# or
sudo bash cleanup.sh
```

## Troubleshooting

### Permission Issues
- Ensure running with `sudo` or as root
- Check that user has network administration privileges

### Network Conflicts
- Ensure CIDR blocks don't overlap with existing networks
- Check for conflicting bridge or namespace names

### Connectivity Issues
- Verify IP forwarding is enabled: `cat /proc/sys/net/ipv4/ip_forward`
- Check iptables rules: `iptables -L -n -v`
- Verify routing tables: `ip route show`

## Implementation Details

### Network Namespaces
Each subnet is implemented as a Linux network namespace, providing complete network isolation.

### veth Pairs
Virtual Ethernet pairs connect namespaces to the VPC bridge, enabling communication.

### Bridge Networks
Linux bridges act as VPC routers, forwarding traffic between subnets.

### NAT Implementation
iptables MASQUERADE rules provide NAT functionality for public subnets.

### Security Groups
iptables rules within namespaces implement port and protocol filtering.

## Files Structure

```
hng-task4/
├── vpcctl                    # Main CLI tool
├── test-demo.sh             # Demonstration script
├── cleanup.sh               # Cleanup script
├── Makefile                 # Build automation
├── example-security-policy.json  # Sample policy
└── README.md               # This file
```

## License

This project is created for HNG Internship Task 4 educational purposes.
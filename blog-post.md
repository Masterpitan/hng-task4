# Building a Production-Ready VPC Implementation on Linux

*HNG Internship Task 4: Complete VPC Control System with Networking Primitives*

## Project Overview

This project implements a complete Virtual Private Cloud (VPC) management system using Linux networking primitives. Built as part of the HNG Internship program, it demonstrates advanced networking concepts including network namespaces, bridges, NAT, routing, and security policies.

## Features Implemented

✅ **VPC Management**: Create and manage multiple isolated VPCs with custom CIDR ranges  
✅ **Subnet Types**: Public subnets with NAT gateway and private subnets with no internet access  
✅ **VPC Isolation**: Complete network isolation between VPCs by default  
✅ **VPC Peering**: Controlled communication between VPCs with proper routing  
✅ **Security Policies**: JSON-based security group rules using iptables  
✅ **Application Deployment**: Deploy and test applications within subnets  
✅ **Comprehensive Logging**: All operations logged with timestamps and details  
✅ **Cleanup Automation**: Complete resource cleanup and management  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Host System                             │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │     VPC1        │   Peering    │     VPC2        │      │
│  │ ┌─────────────┐ │ ◄──────────► │ ┌─────────────┐ │      │
│  │ │br-vpc1      │ │              │ │br-vpc2      │ │      │
│  │ │(10.0.0.0/16)│ │              │ │(172.16.0.0/ │ │      │
│  │ └─────────────┘ │              │ │16)          │ │      │
│  │       │         │              │ └─────────────┘ │      │
│  │   ┌───▼───┐ ┌───▼───┐          │       │         │      │
│  │   │Public │ │Private│          │   ┌───▼───┐     │      │
│  │   │Subnet │ │Subnet │          │   │Public │     │      │
│  │   │(NS)   │ │(NS)   │          │   │Subnet │     │      │
│  │   └───────┘ └───────┘          │   │(NS)   │     │      │
│  └─────────────────┐               │   └───────┘     │      │
│                    │               └─────────────────┐      │
│              ┌─────▼─────┐                          │      │
│              │    NAT    │                          │      │
│              │(iptables) │                          │      │
│              └─────┬─────┘                          │      │
│                    │                                 │      │
│              ┌─────▼─────┐                          │      │
│              │ Internet  │                          │      │
│              └───────────┘                          │      │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
hng-task4/
├── vpcctl.py              # Main VPC control tool
├── demo-complete.sh       # Complete demonstration script
├── cleanup.sh            # Resource cleanup script
├── example-security-policy.json  # Security policy template
├── blog-post.md          # This documentation
├── logs/                 # Operation logs directory
│   ├── vpc-operations.log
│   └── demo-run-YYYYMMDD-HHMMSS.log
└── README.md            # Project README
```

## Core Implementation

### VPC Creation with Bridges

Each VPC is implemented as a Linux bridge with proper CIDR management:

```python
def create_vpc(self, vpc_name, cidr_block):
    """Create a new VPC with specified CIDR"""
    network = ipaddress.IPv4Network(cidr_block, strict=False)
    bridge_name = f"br-{self._short_name(vpc_name, 12)}"
    
    # Create and configure bridge
    self.run_cmd(f"ip link add {bridge_name} type bridge")
    self.run_cmd(f"ip link set {bridge_name} up")
    
    # Assign gateway IP (first usable IP)
    gateway_ip = str(list(network.hosts())[0])
    self.run_cmd(f"ip addr add {gateway_ip}/{network.prefixlen} dev {bridge_name}")
```

### Network Namespace Subnets

Subnets are implemented as network namespaces for complete isolation:

```python
def add_subnet(self, vpc_name, subnet_name, subnet_cidr, subnet_type="private"):
    """Add subnet to existing VPC"""
    # Create namespace for subnet isolation
    ns_name = f"{self._short_name(vpc_name, 6)}-{self._short_name(subnet_name, 6)}"
    veth_host = f"vh-{self._short_name(subnet_name, 10)}"
    veth_ns = f"vn-{self._short_name(subnet_name, 10)}"
    
    # Create veth pair and connect to bridge
    self.run_cmd(f"ip netns add {ns_name}")
    self.run_cmd(f"ip link add {veth_host} type veth peer name {veth_ns}")
    self.run_cmd(f"ip link set {veth_ns} netns {ns_name}")
    self.run_cmd(f"ip link set {veth_host} master {config['bridge']}")
```

### NAT Gateway for Public Subnets

Public subnets get internet access through iptables NAT:

```python
def setup_nat(self, vpc_name, subnet_cidr):
    """Setup NAT for public subnet internet access"""
    result = self.run_cmd("ip route | grep default | awk '{print $5}' | head -1")
    internet_iface = result.stdout.strip()
    
    # Enable IP forwarding and configure NAT
    self.run_cmd("echo 1 > /proc/sys/net/ipv4/ip_forward")
    self.run_cmd(f"iptables -t nat -A POSTROUTING -s {subnet_cidr} -o {internet_iface} -j MASQUERADE")
```

### VPC Peering with Proper Isolation

VPC peering creates controlled communication channels:

```python
def peer_vpcs(self, vpc1_name, vpc2_name):
    """Create peering connection between two VPCs"""
    # Clean up existing peering interfaces
    self.run_cmd(f"ip link delete {peer_veth1}", check=False)
    
    # Create new veth pair for peering
    self.run_cmd(f"ip link add {peer_veth1} type veth peer name {peer_veth2}")
    
    # Add routes to namespaces (not host) for proper isolation
    for subnet_name, subnet_info in vpc1_config["subnets"].items():
        ns_name = subnet_info["namespace"]
        self.run_cmd(f"ip netns exec {ns_name} ip route add {vpc2_config['cidr']} via {vpc1_config['gateway']}")
```

## Usage Examples

### Complete VPC Setup

```bash
# Create VPC with subnets
sudo python3 vpcctl.py create-vpc vpc1 10.0.0.0/16
sudo python3 vpcctl.py add-subnet vpc1 public-subnet 10.0.1.0/24 --type public
sudo python3 vpcctl.py add-subnet vpc1 private-subnet 10.0.2.0/24 --type private

# Deploy applications
sudo python3 vpcctl.py deploy-app vpc1 public-subnet --type python --port 8080
sudo python3 vpcctl.py deploy-app vpc1 private-subnet --type python --port 8081

# Test connectivity
sudo python3 vpcctl.py test vpc1 public-subnet 8.8.8.8  # Should work
sudo python3 vpcctl.py test vpc1 private-subnet 8.8.8.8  # Should fail
```

### VPC Peering Demonstration

```bash
# Create second VPC
sudo python3 vpcctl.py create-vpc vpc2 172.16.0.0/16
sudo python3 vpcctl.py add-subnet vpc2 public-subnet2 172.16.1.0/24 --type public

# Test isolation (should fail)
sudo python3 vpcctl.py test vpc1 public-subnet 172.16.1.1

# Create peering
sudo python3 vpcctl.py peer-vpcs vpc1 vpc2

# Test connectivity after peering (should work)
sudo python3 vpcctl.py test vpc1 public-subnet 172.16.1.1

# Remove peering
sudo python3 vpcctl.py unpeer-vpcs vpc1 vpc2
```

### Security Policy Application

```bash
# Apply security rules from JSON file
sudo python3 vpcctl.py apply-policy vpc1 example-security-policy.json
```

## Automated Testing

Run the complete demonstration:

```bash
# Full automated test suite
sudo bash demo-complete.sh
```

This script validates:
- VPC creation and isolation
- Public/private subnet behavior
- NAT gateway functionality
- VPC peering connections
- Security policy enforcement
- Application deployment

## Key Technical Achievements

1. **Proper VPC Isolation**: Fixed routing issues to ensure VPCs are truly isolated by default
2. **Namespace-based Subnets**: Each subnet runs in its own network namespace for security
3. **Dynamic Interface Naming**: Handles Linux interface name length limits with hashing
4. **Comprehensive Error Handling**: Robust error handling and cleanup on failures
5. **Production-Ready Logging**: All operations logged with timestamps and details
6. **Automated Cleanup**: Complete resource cleanup to prevent conflicts

## Logging and Monitoring

All operations are logged to `/tmp/vpcctl/logs/` with:
- Command execution logs
- Timestamp information
- Error details and troubleshooting info
- Demo run summaries

## Cleanup and Management

```bash
# Clean up all resources
sudo bash cleanup.sh

# Delete specific VPC
sudo python3 vpcctl.py delete-vpc vpc1

# List all VPCs
sudo python3 vpcctl.py list
```

## Security Policy Example

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

## Conclusion

This VPC implementation demonstrates a deep understanding of Linux networking primitives and provides a solid foundation for understanding how cloud networking works under the hood. The project successfully implements all major VPC features with proper isolation, security, and management capabilities.

The comprehensive logging, automated testing, and cleanup functionality make this a production-ready system suitable for educational purposes and real-world networking experiments.
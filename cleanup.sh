#!/bin/bash
# VPC Cleanup Script
# Removes all VPC resources and configurations

echo "=== VPC Cleanup Script ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

VPCCTL="./vpcctl"

echo "Cleaning up all VPCs..."

# List and delete all VPCs
if [ -d "/tmp/vpcctl" ]; then
    for vpc_config in /tmp/vpcctl/*.json; do
        if [ -f "$vpc_config" ]; then
            vpc_name=$(basename "$vpc_config" .json)
            echo "Deleting VPC: $vpc_name"
            python3 $VPCCTL delete-vpc "$vpc_name" || true
        fi
    done
fi

# Additional cleanup for any orphaned resources
echo "Cleaning up orphaned network namespaces..."
for ns in $(ip netns list | grep -E "(demo-vpc|test-vpc)" | awk '{print $1}'); do
    echo "Deleting namespace: $ns"
    ip netns delete "$ns" 2>/dev/null || true
done

echo "Cleaning up orphaned bridges..."
for bridge in $(ip link show type bridge | grep -E "vpc-" | awk -F: '{print $2}' | tr -d ' '); do
    echo "Deleting bridge: $bridge"
    ip link delete "$bridge" 2>/dev/null || true
done

echo "Cleaning up orphaned veth pairs..."
for veth in $(ip link show type veth | grep -E "(veth-|peer-)" | awk -F: '{print $2}' | awk '{print $1}'); do
    echo "Deleting veth: $veth"
    ip link delete "$veth" 2>/dev/null || true
done

echo "Cleaning up iptables NAT rules..."
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true

echo "Removing configuration directory..."
rm -rf /tmp/vpcctl

echo "=== Cleanup completed ==="
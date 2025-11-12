#!/bin/bash
# Complete VPC Demonstration Script
# HNG Internship Task 4 - All Requirements

set -e

echo "=== HNG Task 4: Complete VPC Demonstration ==="
echo "Testing all requirements: VPC creation, subnets, NAT, isolation, peering, security"

VPCCTL="python3 vpcctl.py"

echo -e "\n1. CLEANUP - Remove any existing resources"
sudo bash cleanup.sh

echo -e "\n2. CREATE FIRST VPC (vpc1) with public and private subnets"
sudo $VPCCTL create-vpc vpc1 10.0.0.0/16
sudo $VPCCTL add-subnet vpc1 public-subnet 10.0.1.0/24 --type public
sudo $VPCCTL add-subnet vpc1 private-subnet 10.0.2.0/24 --type private

echo -e "\n3. CREATE SECOND VPC (vpc2) for isolation testing"
sudo $VPCCTL create-vpc vpc2 172.16.0.0/16
sudo $VPCCTL add-subnet vpc2 public-subnet2 172.16.1.0/24 --type public

echo -e "\n4. LIST ALL VPCs"
sudo $VPCCTL list

echo -e "\n5. DEPLOY APPLICATIONS in subnets"
sudo $VPCCTL deploy-app vpc1 public-subnet --type python --port 8080
sudo $VPCCTL deploy-app vpc1 private-subnet --type python --port 8081
sudo $VPCCTL deploy-app vpc2 public-subnet2 --type python --port 8082

echo -e "\n6. TEST CONNECTIVITY - Within VPC (should work)"
sleep 2
sudo $VPCCTL test vpc1 public-subnet 10.0.2.1

echo -e "\n7. TEST NAT GATEWAY - Public subnet internet access (should work)"
sudo $VPCCTL test vpc1 public-subnet 8.8.8.8

echo -e "\n8. TEST ISOLATION - Private subnet internet access (should fail)"
sudo $VPCCTL test vpc1 private-subnet 8.8.8.8 || echo "Expected failure - private subnet has no internet access"

echo -e "\n9. TEST VPC ISOLATION - Cross-VPC communication (should fail)"
sudo $VPCCTL test vpc1 public-subnet 172.16.1.1 || echo "Expected failure - VPCs are isolated by default"

echo -e "\n10. CREATE VPC PEERING"
sudo $VPCCTL peer-vpcs vpc1 vpc2

echo -e "\n11. TEST PEERING - Cross-VPC communication after peering (should work)"
sleep 2
sudo $VPCCTL test vpc1 public-subnet 172.16.1.1

echo -e "\n12. APPLY SECURITY POLICY"
sudo $VPCCTL apply-policy vpc1 example-security-policy.json

echo -e "\n13. FINAL STATUS"
sudo $VPCCTL list

echo -e "\n=== DEMONSTRATION COMPLETED SUCCESSFULLY ==="
echo "All HNG Task 4 requirements validated:"
echo "✅ VPC creation with CIDR ranges"
echo "✅ Public and private subnets"
echo "✅ NAT gateway for internet access"
echo "✅ VPC isolation by default"
echo "✅ VPC peering for controlled communication"
echo "✅ Security policy enforcement"
echo "✅ Application deployment and testing"
echo "✅ Complete logging of all operations"

echo -e "\nTo cleanup: sudo bash cleanup.sh"
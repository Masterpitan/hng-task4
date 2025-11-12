#!/usr/bin/env python3
"""
VPC Setup Validation Script
Checks system requirements and permissions
"""

import os
import sys
import subprocess
import shutil

def check_command(cmd):
    """Check if command exists"""
    return shutil.which(cmd) is not None

def run_command(cmd):
    """Run command and return success status"""
    try:
        subprocess.run(cmd, shell=True, check=True, capture_output=True)
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    print("=== VPC Setup Validation ===\n")

    # Check root privileges
    if os.geteuid() != 0:
        print("❌ Root privileges required. Please run with sudo.")
        return False
    else:
        print("✅ Root privileges: OK")

    # Check required commands
    required_commands = ['ip', 'iptables', 'python3']
    all_commands_ok = True

    for cmd in required_commands:
        if check_command(cmd):
            print(f"✅ {cmd}: Found")
        else:
            print(f"❌ {cmd}: Not found")
            all_commands_ok = False

    if not all_commands_ok:
        print("\n❌ Missing required commands. Please install:")
        print("   Ubuntu/Debian: sudo apt-get install iproute2 iptables python3")
        print("   CentOS/RHEL: sudo yum install iproute iptables python3")
        return False

    # Check network capabilities
    print("\n--- Network Capabilities ---")

    # Check if we can create network namespaces
    if run_command("ip netns add test-validation"):
        print("✅ Network namespace creation: OK")
        run_command("ip netns delete test-validation")
    else:
        print("❌ Network namespace creation: Failed")
        return False

    # Check if we can create bridges
    if run_command("ip link add test-bridge type bridge"):
        print("✅ Bridge creation: OK")
        run_command("ip link delete test-bridge")
    else:
        print("❌ Bridge creation: Failed")
        return False

    # Check if we can create veth pairs
    if run_command("ip link add test-veth1 type veth peer name test-veth2"):
        print("✅ Veth pair creation: OK")
        run_command("ip link delete test-veth1")
    else:
        print("❌ Veth pair creation: Failed")
        return False

    # Check iptables access
    if run_command("iptables -L > /dev/null"):
        print("✅ iptables access: OK")
    else:
        print("❌ iptables access: Failed")
        return False

    print("\n✅ All validation checks passed!")
    print("System is ready for VPC operations.")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

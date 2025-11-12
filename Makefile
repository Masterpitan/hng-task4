# VPC Control Tool Makefile
# HNG Internship Task 4

.PHONY: help install demo test cleanup

help:
	@echo "VPC Control Tool - Available commands:"
	@echo "  make install  - Install dependencies and setup"
	@echo "  make demo     - Run full demonstration"
	@echo "  make test     - Run basic tests"
	@echo "  make cleanup  - Clean up all VPC resources"
	@echo ""
	@echo "Manual usage:"
	@echo "  sudo python3 vpcctl create-vpc <name> <cidr>"
	@echo "  sudo python3 vpcctl add-subnet <vpc> <subnet> <cidr> --type <public|private>"
	@echo "  sudo python3 vpcctl list"
	@echo "  sudo python3 vpcctl delete-vpc <name>"

install:
	@echo "Checking dependencies..."
	@which python3 > /dev/null || (echo "Python3 required" && exit 1)
	@which ip > /dev/null || (echo "iproute2 required" && exit 1)
	@which iptables > /dev/null || (echo "iptables required" && exit 1)
	@echo "All dependencies satisfied"

demo:
	@echo "Running VPC demonstration..."
	@if [ "$$EUID" -ne 0 ]; then echo "Please run with sudo"; exit 1; fi
	@bash test-demo.sh

test:
	@echo "Running basic VPC tests..."
	@if [ "$$EUID" -ne 0 ]; then echo "Please run with sudo"; exit 1; fi
	@python3 vpcctl create-vpc test-vpc 192.168.0.0/16
	@python3 vpcctl add-subnet test-vpc test-subnet 192.168.1.0/24
	@python3 vpcctl list
	@python3 vpcctl delete-vpc test-vpc
	@echo "Basic tests passed"

cleanup:
	@echo "Cleaning up all VPC resources..."
	@if [ "$$EUID" -ne 0 ]; then echo "Please run with sudo"; exit 1; fi
	@bash cleanup.sh
## 🧩 Objective of This Mini Setup

We’ll **manually** simulate a very simple VPC with:

* 1 bridge (`br-vpc`) acting as the VPC router.
* 2 subnets (each as a network namespace):

  * **Public Subnet** → has internet access (via NAT)
  * **Private Subnet** → internal only (no internet)
* One simple **web server** in each subnet to test connectivity.

We’ll confirm:
✅ Communication between subnets
✅ Outbound internet from public subnet
✅ No outbound from private subnet
✅ Isolation between them

---

## 🪜 Step-by-Step Setup

> ⚠️ Run all commands with `sudo` privileges.

---

### **Step 1: Create the VPC Bridge**

```bash
sudo ip link add br-vpc type bridge
sudo ip addr add 10.0.0.1/24 dev br-vpc
sudo ip link set br-vpc up
```

🧠 `br-vpc` acts as your **VPC router**. It connects the public and private subnets.

---

### **Step 2: Create Subnets (Network Namespaces)**

```bash
sudo ip netns add ns-public
sudo ip netns add ns-private
```

Each namespace represents a **subnet** (like an isolated VM).

---

### **Step 3: Create veth Pairs to Connect Namespaces to the Bridge**

```bash
# Public subnet veth pair
sudo ip link add veth-public type veth peer name veth-public-br
sudo ip link set veth-public netns ns-public

# Private subnet veth pair
sudo ip link add veth-private type veth peer name veth-private-br
sudo ip link set veth-private netns ns-private
```

---

### **Step 4: Attach Bridge Ends to VPC Bridge**

```bash
sudo ip link set veth-public-br master br-vpc
sudo ip link set veth-private-br master br-vpc
sudo ip link set veth-public-br up
sudo ip link set veth-private-br up
```

Now the bridge connects both subnets.

---

### **Step 5: Configure IPs for Each Subnet**

```bash
# Inside public subnet
sudo ip netns exec ns-public ip addr add 10.0.0.11/24 dev veth-public
sudo ip netns exec ns-public ip link set veth-public up
sudo ip netns exec ns-public ip link set lo up
sudo ip netns exec ns-public ip route add default via 10.0.0.1

# Inside private subnet
sudo ip netns exec ns-private ip addr add 10.0.0.12/24 dev veth-private
sudo ip netns exec ns-private ip link set veth-private up
sudo ip netns exec ns-private ip link set lo up
sudo ip netns exec ns-private ip route add default via 10.0.0.1
```

---

### **Step 6: Enable IP Forwarding and NAT (for Internet Access)**

```bash
sudo sysctl -w net.ipv4.ip_forward=1

# Replace eth0 with your actual host network interface (check with `ip route | grep default`)
sudo iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
```

This gives NATed internet access to all in the 10.0.0.0/24 network.
We’ll later restrict it.

---

### **Step 7: Test Basic Connectivity**

#### Ping between subnets:

```bash
sudo ip netns exec ns-public ping -c 2 10.0.0.12
```

✅ Should work.

#### Ping host bridge:

```bash
sudo ip netns exec ns-private ping -c 2 10.0.0.1
```

✅ Should work.

---

### **Step 8: Simulate Internet Access**

We’ll test access from the public subnet:

```bash
sudo ip netns exec ns-public ping -c 2 8.8.8.8
```

✅ Should work.

Now block it for the private subnet:

```bash
sudo iptables -A FORWARD -s 10.0.0.12 -j DROP
sudo ip netns exec ns-private ping -c 2 8.8.8.8
```

❌ Should fail — no outbound from private subnet.

---

### **Step 9: Deploy Simple Web Servers**

#### Public Subnet Web Server

```bash
sudo ip netns exec ns-public python3 -m http.server 8080 --bind 10.0.0.11 &
```

#### Private Subnet Web Server

```bash
sudo ip netns exec ns-private python3 -m http.server 8080 --bind 10.0.0.12 &
```

---

### **Step 10: Test Connectivity**

#### From Host → Public Subnet

```bash
curl 10.0.0.11:8080
```

✅ Should work.

#### From Host → Private Subnet

```bash
curl 10.0.0.12:8080
```

❌ Should not work if you blocked private subnet.

#### From Public → Private

```bash
sudo ip netns exec ns-public curl 10.0.0.12:8080
```

✅ Works internally within same VPC.

---

### **Step 11: Cleanup**

When done, clean everything properly:

```bash
sudo ip netns del ns-public
sudo ip netns del ns-private
sudo ip link del br-vpc
sudo iptables -t nat -F
sudo iptables -F
```

---

## ✅ Results Recap

| Test                                 | Expected Result |
| ------------------------------------ | --------------- |
| Ping between subnets                 | ✅ Success       |
| Ping from private subnet to internet | ❌ Blocked       |
| Ping from public subnet to internet  | ✅ Success       |
| Host to public subnet                | ✅ Reachable     |
| Host to private subnet               | ❌ Blocked       |
| Inter-subnet traffic                 | ✅ Allowed       |

---

## 🌐 Optional Visualization (mental model)

```
        +--------------------+
        |     Host OS        |
        |                    |
        |   br-vpc (10.0.0.1)|
        +---------+----------+
                  |
   +--------------+----------------+
   |                               |
veth-public-br                 veth-private-br
   |                               |
   ↓                               ↓
[ns-public]                    [ns-private]
10.0.0.11                      10.0.0.12
```

---

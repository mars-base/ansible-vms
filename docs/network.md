# Network Architecture

VMs connect to the local network via a **bridge** (default `br0`). Two IP assignment modes are supported:

## DHCP Mode (default)

When `ip` field is empty, VMs receive IP addresses from the LAN's DHCP server — same subnet as the host.

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.x, DHCP via br0, virtio NIC)
```

Each VM is assigned a **pinned MAC address** in `vms.csv`, so its DHCP lease is stable. To look up a VM's IP:

```bash
ip neigh show dev br0 | grep -i <MAC>
```

Or use the `list-vms` playbook which does this automatically.

## Static IP Mode (Linux VMs)

For Linux VMs, you can configure static IP addresses by filling in the `ip`, `netmask`, `gateway`, and `dns` fields in `vms.csv`.

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.150, static IP, virtio NIC)
```

### Example vms.csv configuration

```csv
name,host,type,memory_mb,vcpus,os,disk_gb,data_disk_gb,base_image,bridge,mac,firmware,autostart,storage_dir,ip,netmask,gateway,dns
web-server,local,linux,4096,2,debian12,40,100,/path/to/debian-12.qcow2,br0,52:54:00:aa:bb:cc,,true,/var/lib/libvirt/images,192.168.1.150,24,192.168.1.1,"8.8.8.8,1.1.1.1"
```

### Notes

- Static IP configuration only works for **Linux VMs** (cloud-init network-config)
- Windows VMs do not support static IP configuration through this method
- When `ip` is empty or omitted, the VM will use DHCP (default behavior)
- The IP address is permanent and persists across reboots
- Ensure the static IP is outside the DHCP pool to avoid conflicts

### Generated network configuration

Cloud-init will generate a netplan configuration at `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
      - 192.168.1.150/24
      routes:
      - to: default
        via: 192.168.1.1
      nameservers:
        addresses:
        - 8.8.8.8
        - 1.1.1.1
```

### Verification

After VM creation, verify the static IP is active:

```bash
# Check IP address
ssh root@192.168.1.150 "ip addr show ens3 | grep inet"

# Check gateway
ssh root@192.168.1.150 "ip route | grep default"

# Check DNS
ssh root@192.168.1.150 "grep nameserver /etc/resolv.conf"
```

## Bridge Configuration

The KVM host requires a network bridge (`br0`) so VMs can access the LAN directly. Pick the method matching the host's network manager: **nmcli** if NetworkManager is active (most desktops), **ifupdown** for classic server configs. Check with `systemctl is-active NetworkManager`.

### Method 1: nmcli (NetworkManager)

First find the current connection profile, its IP config, and the NIC to bridge:

```bash
nmcli -f NAME,DEVICE,TYPE,STATE connection show
nmcli -f ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns connection show "<existing profile name>"
```

Create the bridge carrying the same static IP (or use `ipv4.method auto` for DHCP on br0), then attach the NIC as a bridge port, then disable the old profile so it doesn't reclaim the NIC:

```bash
# 1. Create bridge br0 with the host's IP config
sudo nmcli connection add type bridge ifname br0 con-name br0 \
    ipv4.method manual ipv4.addresses 192.168.1.100/24 \
    ipv4.gateway 192.168.1.1 ipv4.dns 192.168.1.1 \
    bridge.stp no

# 2. Attach the physical NIC as a bridge port
sudo nmcli connection add type bridge-slave ifname eth0 con-name br0-port-eth0 master br0

# 3. Stop the old profile from auto-activating
sudo nmcli connection modify "<existing profile name>" connection.autoconnect no

# 4. Switch over (brief link interruption; do this from the local console
#    or accept the drop if connected remotely)
sudo nmcli connection up br0
sudo nmcli connection down "<existing profile name>"
```

Both connections persist across reboots. To roll back: `nmcli connection up "<existing profile name>"` and restore `connection.autoconnect yes`.

### Method 2: ifupdown (/etc/network/interfaces)

`/etc/network/interfaces` example:

```bash
# Physical NIC — manual mode, no IP (managed by bridge)
auto eth0
iface eth0 inet manual
    pre-up ip link set $IFACE up
    post-down ip link set $IFACE down

# Bridge br0 — static IP, bridges eth0
auto br0
iface br0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
```

Replace `eth0` with your actual NIC name (check with `ip link`). After editing:

```bash
sudo systemctl restart networking
```

Verify the bridge is up:

```bash
ip addr show br0
bridge link show
```

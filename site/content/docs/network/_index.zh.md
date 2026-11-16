---
title: 网络
description: 虚拟机的网桥网络、DHCP 与静态 IP 配置。
weight: 50
icon: fa-solid fa-network-wired
menus:
  main:
    identifier: docs-network
    parent: docs
    weight: 50
    params:
      icon: fa-solid fa-network-wired
cascade:
  type: docs
  footer_style: slim
---

虚拟机通过**网桥**（默认 `br0`）接入本地网络，支持两种 IP 分配方式：

## DHCP 模式（默认）

当 `ip` 字段留空时，虚拟机从局域网的 DHCP 服务器获取 IP 地址——与宿主机处于同一子网。

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.x, DHCP via br0, virtio NIC)
```

每台虚拟机在 `vms.csv` 中都分配了**固定的 MAC 地址**，因此 DHCP 租约是稳定的。查询虚拟机 IP：

```bash
ip neigh show dev br0 | grep -i <MAC>
```

也可以使用 `list-vms` playbook，它会自动完成这一步。

## 静态 IP 模式（Linux 虚拟机）

对于 Linux 虚拟机，可在 `vms.csv` 中填写 `ip`、`netmask`、`gateway`、`dns` 字段来配置静态 IP。

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.150, static IP, virtio NIC)
```

### vms.csv 配置示例

```csv
name,host,type,memory_mb,vcpus,os,disk_gb,data_disk_gb,base_image,bridge,mac,firmware,autostart,storage_dir,ip,netmask,gateway,dns
web-server,local,linux,4096,2,debian12,40,100,/path/to/debian-12.qcow2,br0,52:54:00:aa:bb:cc,,true,/var/lib/libvirt/images,192.168.1.150,24,192.168.1.1,"8.8.8.8,1.1.1.1"
```

### 说明

- 静态 IP 配置仅适用于 **Linux 虚拟机**（cloud-init network-config）
- Windows 虚拟机不支持通过该方式配置静态 IP
- 当 `ip` 留空或省略时，虚拟机使用 DHCP（默认行为）
- IP 地址是持久的，重启后保持不变
- 确保静态 IP 位于 DHCP 池之外，避免地址冲突

### 生成的网络配置

cloud-init 会在 `/etc/netplan/50-cloud-init.yaml` 生成 netplan 配置：

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

### 验证

虚拟机创建完成后，验证静态 IP 是否生效：

```bash
# Check IP address
ssh root@192.168.1.150 "ip addr show ens3 | grep inet"

# Check gateway
ssh root@192.168.1.150 "ip route | grep default"

# Check DNS
ssh root@192.168.1.150 "grep nameserver /etc/resolv.conf"
```

## 网桥配置

KVM 宿主机需要网络网桥（`br0`），虚拟机才能直接访问局域网。根据宿主机的网络管理方式选择方法：NetworkManager 处于活动状态（大多数桌面环境）用 **nmcli**，传统服务器配置用 **ifupdown**。用 `systemctl is-active NetworkManager` 检查。

### 方法 1：nmcli（NetworkManager）

先找到当前的连接配置、其 IP 配置，以及要桥接的网卡：

```bash
nmcli -f NAME,DEVICE,TYPE,STATE connection show
nmcli -f ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns connection show "<existing profile name>"
```

创建承载相同静态 IP 的网桥（或在 br0 上用 `ipv4.method auto` 走 DHCP），然后挂接网卡作为网桥端口，再禁用旧配置以免它抢回网卡：

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

两个连接都会持久化，重启后依然有效。回滚方法：`nmcli connection up "<existing profile name>"` 并恢复 `connection.autoconnect yes`。

### 方法 2：ifupdown（/etc/network/interfaces）

`/etc/network/interfaces` 示例：

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

将 `eth0` 替换为实际的网卡名（用 `ip link` 查看）。修改后：

```bash
sudo systemctl restart networking
```

验证网桥已启用：

```bash
ip addr show br0
bridge link show
```

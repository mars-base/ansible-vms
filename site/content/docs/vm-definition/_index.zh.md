---
title: 虚拟机定义（vms.csv）
description: 通过 vms.csv 中的每一行配置虚拟机。
weight: 20
icon: fa-solid fa-file-csv
menus:
  main:
    identifier: docs-vm-definition
    parent: docs
    weight: 20
    params:
      icon: fa-solid fa-file-csv
cascade:
  type: docs
  footer_style: slim
---

虚拟机在 `vms.csv` 文件中定义，每一行代表一台虚拟机，字段如下：

| 字段 | 说明 | 示例 |
|-------|-------------|---------|
| `name` | 虚拟机名称 | `win11-dev` |
| `host` | KVM 宿主机（inventory 名称） | `local` |
| `type` | 系统类型：`windows` / `linux` / `macos` | `windows` |
| `memory_mb` | 内存大小（MB） | `8192` |
| `vcpus` | CPU 核数 | `4` |
| `os` | 系统变体 | `win11` |
| `disk_gb` | 系统盘大小 | `80` |
| `data_disk_gb` | 数据盘大小（0 表示无） | `10` |
| `base_image` | 基础 qcow2 镜像路径 | `/path/to/base.qcow2` |
| `bridge` | 网络网桥 | `br0` |
| `mac` | MAC 地址 | `52:54:00:xx:xx:xx` |
| `firmware` | `efi` 或留空（BIOS） | `efi` |
| `autostart` | 开机自启（默认：`false`） | `true` |
| `storage_dir` | 虚拟机存储路径（可选，默认：`/var/lib/libvirt/images`） | `/data/vms` |
| `ip` | 静态 IP（可选，留空 = DHCP）。Linux：创建时经 cloud-init 生效；macOS：之后由 `configure-macos-network.yaml` 配置，见 [macOS 虚拟机](/docs/macos/) | `192.168.1.100` |
| `netmask` | 子网 CIDR（可选，默认：`22`） | `24` |
| `gateway` | 默认网关（设置 `ip` 时必填） | `192.168.1.1` |
| `dns` | DNS 服务器，逗号分隔（设置 `ip` 时必填） | `8.8.8.8,8.8.4.4` |

## vms.csv 示例

```csv
name,host,type,memory_mb,vcpus,os,disk_gb,data_disk_gb,base_image,bridge,mac,firmware,autostart,storage_dir,ip,netmask,gateway,dns
win11-dev,local,windows,8192,4,win11,80,10,/home/user/images/win11-base.qcow2,br0,52:54:00:12:34:56,efi,true,/var/lib/libvirt/images,,,,
debian12-dev,local,linux,2048,2,debian12,20,0,/home/user/images/debian-12.qcow2,br0,52:54:00:12:34:57,,true,/var/lib/libvirt/images,192.168.1.100,24,192.168.1.1,"8.8.8.8,8.8.4.4"
```

## 要点

- **MAC 地址**：每台虚拟机需要唯一的 MAC 地址，以获得稳定的 DHCP 租约
- **Autostart**：只有 debian12-01 配置了 `autostart=true`（随宿主机启动）
- **存储**：虚拟机可使用自定义存储路径，默认 `/var/lib/libvirt/images`
- **静态 IP**：Linux 虚拟机通过 cloud-init；macOS 虚拟机通过 SSH 执行 `configure-macos-network.yaml`（macOS 没有 cloud-init）——见 [macOS 虚拟机](/docs/macos/)
- **幂等**：`create-vm` playbook 创建前会检查虚拟机是否已存在，可安全重复执行

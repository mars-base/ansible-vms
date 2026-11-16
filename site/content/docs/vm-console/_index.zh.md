---
title: 虚拟机控制台
description: 通过 SPICE 或 VNC 访问虚拟机显示控制台。
weight: 90
icon: fa-solid fa-terminal
menus:
  main:
    identifier: docs-vm-console
    parent: docs
    weight: 90
    params:
      icon: fa-solid fa-terminal
cascade:
  type: docs
  footer_style: slim
---

虚拟机根据系统类型使用不同的图形后端：
- **Windows 虚拟机**：SPICE 图形（端口 5900+）
- **Linux 虚拟机**：VNC 图形（端口 5900+）

## 连接虚拟机控制台

```bash
# Method 1: virt-viewer (recommended, auto-detects SPICE/VNC)
virt-viewer <vm-name>

# Method 2: Get display port manually
virsh vncdisplay <linux-vm-name>    # Returns :0, :1, etc.
virsh domdisplay <windows-vm-name>  # Returns spice://127.0.0.1:5900
```

## 通过 SSH 隧道远程访问

```bash
# On your local machine
ssh -L 5900:127.0.0.1:5900 user@kvm-host-ip
# Then connect to spice://127.0.0.1:5900 or vnc://127.0.0.1:5900 locally
```

## 示例

查看 Windows 虚拟机的启动过程：
```bash
virt-viewer win10-dev1  # Opens SPICE console to watch Windows boot
```

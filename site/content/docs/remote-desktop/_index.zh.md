---
title: 远程桌面
description: Windows 虚拟机的 RDP 访问。
weight: 100
icon: fa-solid fa-desktop
menus:
  main:
    identifier: docs-remote-desktop
    parent: docs
    weight: 100
    params:
      icon: fa-solid fa-desktop
cascade:
  type: docs
  footer_style: slim
---

Windows 虚拟机支持 3389 端口的 RDP（Remote Desktop Protocol）。

## 查找虚拟机 IP 地址

```bash
virsh domifaddr <vm-name>
```

## 通过 RDP 连接

### Linux 桌面（推荐）：Remmina

安装：`sudo apt install remmina remmina-plugin-rdp`

GUI：支持 RDP、VNC、SPICE、SSH
特性：剪贴板共享、文件夹重定向、多显示器

### 其他选择

- **xfreerdp**：`xfreerdp /v:<vm-ip> /u:Administrator`
- **Windows**：内置"远程桌面连接"（mstsc.exe）
- **macOS**：App Store 中的 "Microsoft Remote Desktop"

### 示例

```bash
# Linux: open Remmina and connect to 10.241.20.45
remmina -c rdp://10.241.20.45

# Or use xfreerdp
xfreerdp /v:10.241.20.45 /u:Administrator /p:<password>
```

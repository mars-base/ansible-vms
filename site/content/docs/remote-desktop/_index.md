---
title: Remote Desktop
description: RDP access to Windows virtual machines.
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

Windows VMs support RDP (Remote Desktop Protocol) on port 3389.

## Find VM IP address

```bash
virsh domifaddr <vm-name>
```

## Connect via RDP

### Linux desktop (recommended): Remmina

Install: `sudo apt install remmina remmina-plugin-rdp`

GUI: supports RDP, VNC, SPICE, SSH
Features: clipboard sharing, folder redirection, multi-monitor

### Other options

- **xfreerdp**: `xfreerdp /v:<vm-ip> /u:Administrator`
- **Windows**: built-in "Remote Desktop Connection" (mstsc.exe)
- **macOS**: "Microsoft Remote Desktop" from App Store

### Example

```bash
# Linux: open Remmina and connect to 10.241.20.45
remmina -c rdp://10.241.20.45

# Or use xfreerdp
xfreerdp /v:10.241.20.45 /u:Administrator /p:<password>
```

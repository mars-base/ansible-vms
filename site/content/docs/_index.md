---
title: Documentation
description: Learn how to define and manage KVM virtual machines with ansible-vms.
type: docs
icon: fa-solid fa-book
menus:
  main:
    identifier: docs
    weight: 20
    params:
      icon: fa-solid fa-book
cascade:
  type: docs
  footer_style: slim
---

Complete guide to defining and managing KVM virtual machines with Ansible and libvirt.

- [Getting Started](/docs/getting-started/) — Install dependencies and create your first VM
- [VM Definition](/docs/vm-definition/) — Configure VMs in `vms.csv`
- [VM Lifecycle](/docs/vm-lifecycle/) — List, start, stop, restart and destroy VMs
- [Base Images](/docs/base-images/) — Download Linux and Windows base images
- [Network](/docs/network/) — Bridge networking, DHCP and static IP
- [Data Disks](/docs/data-disks/) — Attach, resize and hot-plug data disks
- [Snapshots](/docs/snapshots/) — Create, restore and delete snapshots
- [User Accounts](/docs/setup-user/) — Create SSH users with passwordless sudo
- [VM Console](/docs/vm-console/) — VNC/SPICE and serial console access
- [Remote Desktop](/docs/remote-desktop/) — RDP access for Windows VMs
- [Firewall](/docs/firewall/) — Managed nftables firewall
- [macOS VMs](/docs/macos/) — Hackintosh guests with keyboard-free boot
- [macOS Base Image](/docs/macos-base-image/) — How the macOS base image was built
{.cards}

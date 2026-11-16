---
title: 文档
description: 了解如何用 ansible-vms 定义和管理 KVM 虚拟机。
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

用 Ansible 与 libvirt 定义和管理 KVM 虚拟机的完整指南。

- [快速开始](/docs/getting-started/) — 安装依赖并创建第一台虚拟机
- [虚拟机定义](/docs/vm-definition/) — 在 `vms.csv` 中配置虚拟机
- [虚拟机生命周期](/docs/vm-lifecycle/) — 列出、启动、停止、重启和销毁虚拟机
- [基础镜像](/docs/base-images/) — 下载 Linux 与 Windows 基础镜像
- [网络](/docs/network/) — 网桥网络、DHCP 与静态 IP
- [数据盘](/docs/data-disks/) — 挂载、扩容与热插拔数据盘
- [快照](/docs/snapshots/) — 创建、恢复与删除快照
- [用户账户](/docs/setup-user/) — 创建带免密 sudo 的 SSH 用户
- [虚拟机控制台](/docs/vm-console/) — VNC/SPICE 与串口控制台访问
- [远程桌面](/docs/remote-desktop/) — Windows 虚拟机的 RDP 访问
- [防火墙](/docs/firewall/) — 托管的 nftables 防火墙
- [macOS 虚拟机](/docs/macos/) — 免键盘启动的黑苹果客户机
- [macOS 基础镜像](/docs/macos-base-image/) — macOS 基础镜像的制作过程
{.cards}

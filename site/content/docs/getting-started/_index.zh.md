---
title: 快速开始
description: 安装依赖并创建第一台 KVM 虚拟机。
weight: 10
icon: fa-solid fa-rocket
menus:
  main:
    identifier: docs-getting-started
    parent: docs
    weight: 10
    params:
      icon: fa-solid fa-rocket
cascade:
  type: docs
  footer_style: slim
---

## 环境要求

- **宿主机系统**：Debian 12+ / Ubuntu，或 Fedora / Rocky Linux（新版本）
- **软件包**：由 `playbooks/install-dependencies.yaml` 安装（`qemu-kvm`、`libvirt`、`ovmf`/`edk2-ovmf`、`swtpm`）

## 安装

```bash
# Clone the repository
git clone https://github.com/mars-base/ansible-vms.git
cd ansible-vms

# Install Python dependencies
uv sync  # or: pip install -r requirements.txt

# Setup configuration files
cp ansible.cfg.example ansible.cfg  # edit with your host name
cp hosts.ini.example hosts.ini      # edit with your host name
cp vms.csv.example vms.csv          # edit with your VM definitions
```

## 快速上手

```bash
# Install required packages on KVM host
uv run ansible-playbook playbooks/install-dependencies.yaml

# Create VMs defined in vms.csv
uv run ansible-playbook playbooks/create-vm.yaml
```

## 项目结构

```
ansible-vms/
├── ansible.cfg.example          # Ansible 配置模板
├── hosts.ini.example            # Inventory 模板
├── vms.csv                      # 虚拟机定义（CSV 驱动）
├── pyproject.toml               # Python 依赖（uv）
├── requirements.txt             # pip 依赖
├── group_vars/
│   ├── all/                     # 全局变量
│   └── kvm_hosts/               # KVM 宿主机变量
├── host_vars/                   # 单主机变量
├── playbooks/
│   ├── create-vm.yaml           # 从 vms.csv 创建虚拟机
│   ├── destroy-vm.yaml          # 销毁虚拟机
│   ├── list-vms.yaml            # 列出虚拟机
│   ├── snapshot-vm.yaml         # 管理虚拟机快照
│   ├── setup-user.yaml          # 在 Linux 虚拟机上创建用户
│   ├── start-vm.yaml            # 启动虚拟机
│   ├── stop-vm.yaml             # 停止虚拟机
│   └── restart-vm.yaml          # 重启虚拟机
├── roles/
│   └── create_vm/               # 创建角色（libvirt XML）
├── scripts/                     # 辅助脚本
├── tools/                       # 工具脚本（vm-console、vm-login）
└── var/                         # 运行时数据（日志、facts 缓存）
```

## 下一步

- [虚拟机定义](/docs/vm-definition/) — 在 vms.csv 中配置虚拟机
- [虚拟机生命周期](/docs/vm-lifecycle/) — 启动、停止、重启、销毁虚拟机
- [快照](/docs/snapshots/) — 创建和恢复虚拟机快照
- [用户账户](/docs/setup-user/) — 创建 Linux 用户账户
- [数据盘](/docs/data-disks/) — 挂载、扩容和挂载数据盘
- [虚拟机控制台](/docs/vm-console/) — 访问虚拟机控制台
- [远程桌面](/docs/remote-desktop/) — Windows 虚拟机的 RDP 访问
- [网络](/docs/network/) — 网络架构与网桥配置
- [基础镜像](/docs/base-images/) — 下载 Linux 与 Windows 基础镜像

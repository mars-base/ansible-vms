---
title: 用户账户
description: 在 Linux 虚拟机上创建带 SSH 密钥和免密 sudo 的用户。
weight: 80
icon: fa-solid fa-user
menus:
  main:
    identifier: docs-setup-user
    parent: docs
    weight: 80
    params:
      icon: fa-solid fa-user
cascade:
  type: docs
  footer_style: slim
---

在 Linux 虚拟机上创建带 SSH 密钥和免密 sudo 的用户账户，自动跳过非 Linux 主机。

## 用法

```bash
# Create user on single VM
ap playbooks/setup-user.yaml -e "HOSTS=debian12-01" -e "username=admin"

# Create user on multiple VMs (host group)
ap playbooks/setup-user.yaml -e "HOSTS=vms" -e "username=admin"

# Specify SSH public key
ap playbooks/setup-user.yaml -e "HOSTS=debian12-01" -e "username=admin" -e "ssh_pubkey=/path/to/id_rsa.pub"
```

## 参数

- `HOSTS`：目标主机或主机组（默认：`vms`）
- `username`：要创建的用户名（默认：`admin`）
- `ssh_pubkey`：SSH 公钥文件路径（默认：`~/.ssh/id_rsa.pub`）
- `user_shell`：登录 shell（默认：`/bin/bash`）
- `user_groups`：用户组，逗号分隔（自动检测：Fedora/RHEL 用 `wheel`，Debian/Ubuntu 用 `sudo`）
- `passwordless_sudo`：启用免密 sudo（默认：`true`）

## 行为

- 通过 `gather_facts: true` 自动检测操作系统
- Linux 主机：创建用户、配置 SSH 密钥、启用免密 sudo
- 非 Linux 主机（Windows 等）：跳过，并显示检测到的操作系统
- 幂等：可在同一主机上安全重复执行

---
title: 虚拟机生命周期
description: 列出、启动、停止、重启和销毁虚拟机。
weight: 30
icon: fa-solid fa-arrows-rotate
menus:
  main:
    identifier: docs-vm-lifecycle
    parent: docs
    weight: 30
    params:
      icon: fa-solid fa-arrows-rotate
cascade:
  type: docs
  footer_style: slim
---

所有 playbook 都是幂等的（可安全重复执行）。

## 列出虚拟机

```bash
# List all VMs with status and IP
ap playbooks/list-vms.yaml
```

输出示例：
```
win11-dev            192.168.1.101   windows  4 vCPU 8192 MB    win11  shut off
win10-dev            192.168.1.102   windows  4 vCPU 8192 MB    win10  running
debian12-dev         192.168.1.103   linux    2 vCPU 2048 MB    debian12 running
```

## 启动虚拟机

```bash
# Start specific VM
ap playbooks/start-vm.yaml -e vm_name=debian12-dev
```

## 停止虚拟机

```bash
# Graceful shutdown
ap playbooks/stop-vm.yaml -e vm_name=win11-dev
```

使用 `virsh shutdown`，发送 ACPI 关机信号。对于配置了 QEMU guest agent 的 Windows 虚拟机，这会触发干净关机。

## 重启虚拟机

```bash
# Stop then start VM
ap playbooks/restart-vm.yaml -e vm_name=debian12-dev
```

## 销毁虚拟机

```bash
# Permanently delete VM (requires confirmation)
ap playbooks/destroy-vm.yaml -e vm_name=win11-dev -e confirm=true
```

删除内容：domain 定义、磁盘镜像（qcow2）、OVMF VARS、cloud-init ISO、TPM 状态。

**警告**：该操作具有破坏性且不可恢复，必须传入 `confirm=true`。

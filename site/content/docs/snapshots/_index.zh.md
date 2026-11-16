---
title: 快照
description: 创建、列出、恢复和删除虚拟机快照。
weight: 70
icon: fa-solid fa-clock-rotate-left
menus:
  main:
    identifier: docs-snapshots
    parent: docs
    weight: 70
    params:
      icon: fa-solid fa-clock-rotate-left
cascade:
  type: docs
  footer_style: slim
---

使用 libvirt 内置的快照支持创建、列出、恢复和删除虚拟机快照。

## 用法

```bash
# Create snapshot (default: shutdown VM first for disk consistency, then restore previous state)
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create

# Create snapshot without shutdown (live snapshot, VM continues running)
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e halt=false

# Create snapshot with custom name and description
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e snapshot_name=before-upgrade -e snapshot_desc="升级前快照"

# List all snapshots
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=list

# Restore to snapshot (requires confirmation, restores VM state at snapshot time)
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=restore -e snapshot_name=before-upgrade -e confirm=true

# Delete snapshot
uv run ansible-playbook playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=delete -e snapshot_name=before-upgrade
```

## 参数

- `vm_name`：虚拟机名称（必填）
- `snap_action`：`create` / `list` / `restore` / `delete`（必填）
- `snapshot_name`：快照名称（create 时自动生成；restore/delete 时必填）
- `snapshot_desc`：描述（可选，仅 create）
- `halt`：快照前先关机以保证磁盘一致性，完成后恢复之前的状态（可选，仅 create，默认：`true`）
- `confirm`：安全标志（restore 和 delete 必填）

## 行为

- **halt=true（默认）**：若虚拟机在运行 → 关机 → 快照 → 启动（恢复运行状态）。若虚拟机已关机 → 快照 → 保持关机（保留关机状态）。
- **halt=false**：虚拟机运行中创建快照（live snapshot）。速度更快，但磁盘写入可能不完整。
- **Restore** 将虚拟机恢复到快照时刻的精确状态（运行或关机，取决于快照时的状态）。

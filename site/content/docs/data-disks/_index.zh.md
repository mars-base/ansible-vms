---
title: 数据盘
description: 挂载、扩容、格式化数据盘，以及管理额外磁盘。
weight: 60
icon: fa-solid fa-hard-drive
menus:
  main:
    identifier: docs-data-disks
    parent: docs
    weight: 60
    params:
      icon: fa-solid fa-hard-drive
cascade:
  type: docs
  footer_style: slim
---

> **macOS 虚拟机**：本文档中的 playbook **不适用**于 macOS 客户机。
> macOS 磁盘位于 q35 内置的 SATA 控制器上（不支持热插拔，也没有
> virtio-blk 驱动），且 macOS 客户机内没有可供 Ansible 使用的 Python。
> 数据盘改为在创建虚拟机时根据 `data_disk_gb` 列自动创建
> （见 [macOS 虚拟机](/docs/macos/)）；各 playbook 会检测
> `type=macos` 并以 `diskutil` 提示中止。

## 挂载数据盘

```bash
# Attach data disk to a running VM (hot-plug, no reboot needed)
uv run ansible-playbook playbooks/attach-data-disk.yaml -e vm_name=debian12-dev
```

从 `vms.csv` 读取 `data_disk_gb`，虚拟机必须在 CSV 中定义了 `data_disk_gb > 0`。通过 `virsh attach-disk --config --live` 将磁盘热插到运行中的虚拟机（持久化 + 立即生效）。

在虚拟机内部格式化并挂载新磁盘：

```bash
mkfs.ext4 /dev/vdb
mkdir -p /data
mount /dev/vdb /data
```

## 扩容数据盘

```bash
# Resize data disk (reads target size from vms.csv)
uv run ansible-playbook playbooks/resize-data-disk.yaml -e vm_name=debian12-dev
```

从 `vms.csv` 读取目标 `data_disk_gb`。playbook 会：
1. 检查目标大小是否大于当前大小（不支持缩小）
2. 若虚拟机正在运行 → 优雅关机并等待停止
3. 使用 `qemu-img resize` 扩容 qcow2 文件
4. 若虚拟机之前在运行 → 自动重新启动

扩容完成后，在虚拟机内扩展文件系统：

```bash
# Linux VM
resize2fs /dev/vdb

# Windows VM (PowerShell)
$maxSize = (Get-PartitionSupportedSize -DriveLetter E).SizeMax
Resize-Partition -DriveLetter E -Size $maxSize
```

**注意**：如果虚拟机已处于关机状态，playbook 直接扩容磁盘，不会自动开机。

## 挂载磁盘

```bash
# Format and mount data disk inside VM (requires VM in hosts.ini)
uv run ansible-playbook playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data"
```

在 Linux 虚拟机内部格式化并挂载数据盘。要求虚拟机已在 `hosts.ini` 中定义。

### 参数

- `disk_device`：磁盘设备路径（默认：`/dev/vdb`）
- `mount_point`：挂载点（必填，如 `/data`）
- `disk_format`：文件系统类型（默认：`ext4`）
- `need_partition`：创建 GPT 分区（默认：`false`，裸盘挂载）
- `format_force`：强制重新格式化（默认：`false`）
- `auto_mount`：写入 fstab（默认：`true`）

### 示例

```bash
# With GPT partition (default)
uv run ansible-playbook playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data"

# Raw disk without partition
uv run ansible-playbook playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data" -e "need_partition=false"

# Force reformat (WARNING: destroys data)
uv run ansible-playbook playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data" -e "format_force=true"
```

playbook 会：
1. 按需安装 `parted`
2. 创建 GPT 分区表（当 `need_partition=true`）
3. 使用指定文件系统格式化磁盘
4. 以 UUID 写入 fstab
5. 挂载并验证

**Tags：** `-t partition`、`-t format`、`-t mount`（只执行特定步骤）

## 额外磁盘（添加 / 列出 / 删除）

可在运行时按需添加任意数量的额外 virtio-blk 磁盘，独立于
`data_disk_gb` 列（该列专供 `create-vm.yaml` 创建的单块数据盘）。
磁盘命名为 `<vm>-extra<N>.qcow2`，存放在虚拟机的存储目录中；下一个可用
索引和下一个可用宿主机目标（`vdX`）都会从**运行态**和持久化配置中自动
检测，重复执行不会冲突。

仅限 Linux 客户机：virtio-blk 热插拔对**运行中**的虚拟机有效
（`--config --live`，立即生效，无需重启）；**已关机**的虚拟机只会通过
`--config` 添加磁盘，下次启动时可见。

### 添加

```bash
# one 10G disk (index/letter picked automatically)
uv run ansible-playbook playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e extra_size=10G

# four 2G disks in one run
uv run ansible-playbook playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e count=4 -e extra_size=2G

# override the target directory (default: VM's storage dir from vms.csv)
uv run ansible-playbook playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e extra_dir=/data/disks
```

### 列出

```bash
uv run ansible-playbook playbooks/list-extra-disks.yaml -e vm_name=debian12-01
```

显示每块磁盘的索引、虚拟大小，以及在运行态 domain 和/或持久化配置中的目标设备：

```
extra1.qcow2: 2G, live=vdc, config=vdc
extra2.qcow2: 2G, live=vdd, config=vdd
```

### 删除

先卸载磁盘（运行中虚拟机的运行态 + 配置——virtio-blk 热拔除），再删除 qcow2 文件。该操作会销毁数据，必须传入 `confirm=true`：

```bash
uv run ansible-playbook playbooks/delete-extra-disk.yaml -e vm_name=debian12-01 -e extra_index=2 -e confirm=true
```

### 在客户机内识别磁盘

客户机内核会分配自己的 `vdX` 名称，通常与宿主机的目标设备不同。每块额外磁盘带有序列号 `<vm>-extra<N>`——按序列号匹配：

```bash
lsblk -o NAME,SERIAL,SIZE
# vdc  debian12-01-extra1  2G
```

之后用 `mount-disk.yaml` 格式化/挂载（传入**客户机内**的设备名，如 `-e disk_device=/dev/vdc`）。

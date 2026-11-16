---
title: 基础镜像
description: 为虚拟机下载 Linux、Windows 与 macOS 基础镜像。
weight: 40
icon: fa-solid fa-compact-disc
menus:
  main:
    identifier: docs-base-images
    parent: docs
    weight: 40
    params:
      icon: fa-solid fa-compact-disc
cascade:
  type: docs
  footer_style: slim
---

## Linux 基础镜像

Linux 虚拟机使用官方 cloud 镜像，这些镜像已预置 cloud-init 支持。

### Debian

**下载最新的 Debian 12（Bookworm）镜像：**

```bash
wget -O debian-12-genericcloud-amd64.qcow2 \
  https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

**其他版本**：在 https://cloud.debian.org/images/cloud/ 浏览 bookworm、bullseye、trixie 等版本。

### Ubuntu

**下载最新的 Ubuntu 24.04 LTS（Noble）镜像：**

```bash
wget -O ubuntu-24.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

**下载最新的 Ubuntu 26.04 LTS（Resolute）镜像：**

```bash
wget -O ubuntu-26.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
```

**重要**：Ubuntu cloud 镜像需要 **virtio** 网络驱动。本项目的虚拟机模板已使用 virtio，无需额外配置。

**注意**：请务必对照官方 SHA256SUMS 文件校验下载的镜像，避免镜像损坏导致启动失败。

**其他版本**：在 https://cloud-images.ubuntu.com/ 浏览其他 Ubuntu 发行版。

### Fedora

**下载最新的 Fedora 44 Cloud Base 镜像：**

```bash
wget -O Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2 \
  https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
```

**注意**：Fedora 使用 `wheel` 组授予 sudo 权限（而非 `sudo` 组）。`setup-user` playbook 会自动检测并使用正确的组。

**其他版本**：在 https://fedoraproject.org/cloud/download/ 浏览其他 Fedora 发行版。

### Rocky Linux

**下载最新的 Rocky Linux 10 Cloud Base 镜像：**

```bash
wget -O Rocky-10-GenericCloud-Base.latest.x86_64.qcow2 \
  https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2
```

**注意**：Rocky Linux 使用 `wheel` 组授予 sudo 权限（与 RHEL/CentOS 相同）。`setup-user` playbook 会自动检测并使用正确的组。

**其他版本**：在 https://rockylinux.org/download 浏览其他 Rocky Linux 发行版。

### 配置

在 `vms.csv` 的 `base_image` 字段中设置镜像路径：

```csv
# Debian
my-debian-vm,local,linux,...,/path/to/debian-12-genericcloud-amd64.qcow2,...

# Ubuntu
my-ubuntu-vm,local,linux,...,/path/to/ubuntu-24.04-server-cloudimg-amd64.img,...

# Fedora
my-fedora-vm,local,linux,...,/path/to/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2,...

# Rocky Linux
my-rocky-vm,local,linux,...,/path/to/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2,...
```

镜像会在首次启动时通过 cloud-init 自动配置（SSH 密钥、用户、软件包等，来自 `group_vars/kvm_hosts/vms_all.yaml`）。

## Windows 基础镜像

Windows qcow2 基础镜像由 [packer-windows-kubevirt](https://github.com/mars-base/packer-windows-kubevirt) 构建。它使用 Packer + QEMU 生成 sysprep 泛化的 Windows 镜像，包含：

- 预装 **virtio 驱动**（vioscsi、viostor、netkvm、vioserial、viorng、balloon、viofs）
- **QEMU Guest Agent** + **Cloudbase-Init**
- 启用 **WinRM HTTPS**（端口 5986）和 **RDP**（端口 3389）
- EFI 启动，带 secure boot 密钥

构建你自己的镜像：

```bash
git clone https://github.com/mars-base/packer-windows-kubevirt
cd packer-windows-kubevirt
packer build <template>
```

然后在 `vms.csv` 的 `base_image` 字段中设置输出路径。

## Windows 虚拟机特性

当 `type=windows` 时，domain XML 模板包含：

- **Hyper-V 优化项**（relaxed、vapic、spinlocks、synic、stimer 等），支持嵌套 WSL2
- **VMX 透传**，支持虚拟机内嵌套虚拟化（WSL2/Hyper-V）
- **EFI + vTPM 2.0**（OVMF secure boot + 模拟 TPM）
- **virtio-scsi** 磁盘总线 + **virtio** 网卡
- **Localtime** 时钟，带 hypervclock

## macOS 基础镜像

macOS 虚拟机使用在 KVM 宿主机上通过 [OSX-KVM](https://github.com/kholia/OSX-KVM) 手工制作的自包含 qcow2 基础镜像。与 Linux、Windows 镜像不同，它既不是下载的，也不是用 Packer 构建的：

- macOS Sonoma 14.8.9（x86_64），4 vCPU / 8 GB，账户 `admin` / `admin`，Remote Login 已开启
- OpenCore 引导盘 + 已 bless 的 OVMF NVRAM 模板，冷启动无需键盘操作
- 虚拟容量 64 GiB，实际占用约 29 GiB，无 backing file——可直接作为 backing 镜像使用

每台 macOS 虚拟机都会以其为基础派生独立的系统盘 overlay、OpenCore overlay，以及一份 per-VM 的 blessed OVMF VARS 文件。在 `vms.csv` 的 `base_image` 字段中设置镜像路径。

完整制作流程（安装介质下载、bless、NVRAM 校验、镜像转换）见 [macOS 基础镜像](/docs/macos-base-image/)。

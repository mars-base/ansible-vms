---
title: macOS 虚拟机
description: 与 Linux、Windows 虚拟机并行的免键盘黑苹果 macOS 客户机。
weight: 120
icon: fa-brands fa-apple
menus:
  main:
    identifier: docs-macos
    parent: docs
    weight: 120
    params:
      icon: fa-brands fa-apple
cascade:
  type: docs
  footer_style: slim
---

macOS 客户机与 Linux/Windows 虚拟机并行运行。基础镜像如何用
[kholia/OSX-KVM](https://github.com/kholia/OSX-KVM) 从零构建，见
[macOS 基础镜像](/docs/macos-base-image/)（中文）。

## macOS 与 Linux/Windows 的区别

| 方面 | Linux/Windows | macOS |
|--------|---------------|-------|
| 显示 | qxl/virtio/spice | 通过 `qemu:commandline` 使用 `vmware-svga` |
| SMC | — | 通过 `qemu:commandline` 使用 `isa-applesmc,osk=...` |
| 启动 | 直接引导系统盘 | OpenCore overlay（顺序 1）→ macOS 磁盘（顺序 2） |
| 固件 | 发行版 OVMF 或 SeaBIOS | 持久化 OVMF + **预先 bless** 的 NVRAM 模板 |
| 网络 | libvirt `<interface>` | 网桥，virtio 网卡固定在 root-bus `slot=0x05` |
| IP 配置 | cloud-init | 无 cloud-init — 默认 DHCP |
| 关机 | `virsh shutdown`（ACPI） | macOS 忽略 ACPI — 从桌面或通过 SSH 关机 |

## 资产

共享的只读模板位于 `macos_asset_dir`（默认
`/home/fish/bucket/kvm/macos/`）：

| 文件 | 用途 |
|------|---------|
| `macos-sonoma-base.img` | Sonoma 14.8.9 基础镜像，admin/admin，已开启 Remote Login |
| `OpenCore.qcow2` | OpenCore 引导盘（SIP 已关闭、自动引导） |
| `OVMF_VARS-blessed.fd` | 预 bless 的 NVRAM 模板——冷启动免键盘的关键 |

### 把资产复制到另一台宿主机

三个文件是自包含的——复制到新宿主机的 `macos_asset_dir` 即可在该主机上
创建 macOS 虚拟机。bless 后的 Preboot 卷 UUID、APFS 布局和 boot.efi 路径
都随文件一起迁移。

新宿主机还需要：

1. **`apt install ovmf`** —— 模板还引用了宿主机的
   `/usr/share/OVMF/OVMF_CODE_4M.fd`（发行版持久化构建）。**不要**
   使用 OSX-KVM 自带的非持久化副本，否则 bless 不可见，冷启动会停在
   Apple 的磁盘选择界面（见下方约束 1）
2. **匹配的拓扑** —— q35 + `1f:2` 处内置 SATA + 系统盘在 2 号端口是
   `domain-macos.xml.j2` 中硬编码的，使用同一个 ansible-vms role 即自动满足
3. QEMU >= 8.2.2 及相近版本的 libvirt（用于 `qemu:commandline`）

无需复制：`BaseSystem.img`、`fetch-macOS-v2.py`、
`boot-macos-install.sh`——仅在重建基础镜像时使用。

## 配置（vms.csv）

添加一行，`type=macos`。`disk_gb` **必须**等于基础镜像的虚拟大小（64）。
macOS 使用 DHCP，因此 **ip/netmask/gateway/dns 留空**（只有需要静态 IP
时才填写——见 [静态 IP](#静态-ip可选)）。VNC 端口由 libvirt 自动分配
（`list-vms` 显示实际端口）。

**数据盘**：把 `data_disk_gb` 列（第 8 列）设为大于 0 的大小，即可在同一个
内置 AHCI 控制器上挂载一块额外的 SATA 磁盘（`sdc`）——macOS 原生识别，
无需 kext。与 Linux/Windows 客户机一样，SATA 总线**不能**热插拔，所以要在
创建时设置（或冷 `attach` 后重启）；对已创建的虚拟机该列会被忽略。

```csv
macos-sonoma-01,local,macos,8192,4,macos-sonoma,64,0,/home/fish/bucket/kvm/macos/macos-sonoma-base.img,br0,52:54:00:ff:00:01,efi,false,/home/fish/bucket/kvm/macos,,,,,
```

## 创建

```bash
ap playbooks/create-vm.yaml -e vm_name=macos-sonoma-01
```

构建两个 overlay（系统盘 + OpenCore），从 bless 模板播种每台虚拟机的
NVRAM，并定义/启动 domain。冷启动无需任何键盘输入；登录窗口约 40 秒内
出现。

**网络**：默认 DHCP（`br0` 上游路由器）。查询 IP：

```bash
ap playbooks/list-vms.yaml
```

IP 列会列出每台虚拟机的地址（如 macOS 的 `192.168.100.45`），VNC 列显示
`127.0.0.1:<port>`。

> 对 macOS 客户机执行 Ansible 必须用 `-m raw`——客户机内没有 Python
> 解释器。

### 静态 IP（可选）

要把 macOS 虚拟机从 DHCP 切换为自定义静态 IP，分两步：

1. **先在 `vms.csv` 中定义网络**——填写 `ip`、`netmask`
   （CIDR 前缀，如 `22`）、`gateway` 和 `dns` 列（四项都必填；
   `configure-macos-network.yaml` 会在操作客户机前断言这一点）：

   ```csv
   ...,efi,false,/home/fish/bucket/kvm/macos,192.168.100.45,24,192.168.100.1,192.168.100.53,
   ```

2. **针对当前（DHCP）地址运行 playbook**：

   ```bash
   ap playbooks/configure-macos-network.yaml -e vm_name=macos-sonoma-01 -e boot_ip=192.168.100.45
   ```

   `boot_ip` 是虚拟机此刻响应的 DHCP 地址（用 `list-vms` 查询）。playbook
   通过 SSH 登录，按虚拟机的 MAC 定位 BSD 接口，执行
   `networksetup -setmanual`/`-setdnsservers`，并验证新的静态 IP 在 22
   端口可响应。之后把该虚拟机的条目在 `hosts.ini` 中更新（或新增）为
   静态 IP。

## 启动

```bash
ap playbooks/start-vm.yaml -e vm_name=macos-sonoma-01
```

## 停止

```bash
ap playbooks/stop-vm.yaml -e vm_name=macos-sonoma-01
```

macOS 忽略 ACPI 关机，因此 playbook 只打印提示：

- 从桌面：Apple 菜单 → 关机
- 或通过 SSH：`ssh admin@<ip> 'sudo shutdown -h now'`

> `virsh shutdown` 对 macOS 客户机无效——不要使用。

## 销毁

```bash
ap playbooks/destroy-vm.yaml -e vm_name=macos-sonoma-01 -e confirm=true
```

先停止虚拟机（见上）。共享的基础镜像和资产不会被触碰。

## 快照

macOS domain 通过 pflash OVMF 和 RAW NVRAM 文件启动，libvirt 因此拒绝
完整（含内存）快照。快照 playbook 会对 macOS 自动回退为**仅磁盘**快照：

```bash
# snapshot a running VM (disk-only)
ap playbooks/snapshot-vm.yaml -e vm_name=macos-sonoma-01 -e snap_action=create -e snapshot_name=my-snap -e halt=false

# revert (VM must be shut off first; playbook tells you)
ap playbooks/snapshot-vm.yaml -e vm_name=macos-sonoma-01 -e snap_action=restore -e snapshot_name=<snap> -e confirm=true
```

需要了解的局限：

- NVRAM **不**包含在快照中——启动状态永远不会回滚
- `halt=true` 时 playbook 会中止并提示：macOS 忽略 ACPI，如需一致的快照
  请先自行关机（桌面或 SSH）
- AHCI 上的 APFS 没有 TRIM，删除快照回收的空间有限

## 模板约束（domain-macos.xml.j2）

有四处细节必须与验证过的手工配置一致；违反任何一处都会表现为看似无关的
另一种故障：

1. **持久化 OVMF**：使用宿主机的 `/usr/share/OVMF/OVMF_CODE_4M.fd`，而非
   OSX-KVM 自带的非持久化构建
2. **bless 拓扑匹配**：磁盘位于 q35 内置 AHCI（PCI `1f:2`）；
   绝不能添加第二块 `ich9-ahci` 设备
3. **网卡固定在 root-bus `slot=0x05`**：macOS 的 virtio-net 驱动只会在
   固定的 root-bus 位置绑定——如果 libvirt 把网卡自动放到
   `pcie-root-port` 子设备上，客户机将永远看不到它
4. **`<seclabel type='none'/>`**：外部（仅磁盘）快照会把共享的
   `OpenCore.qcow2` / 基础镜像在 backing 链中多嵌套一层
   （… → `.inited` → overlay → base）。libvirt 的 `virt-aa-helper` 只允许
   XML 中列出的文件（源 + 一层 backingStore），更深层的共享资产会被
   AppArmor 拒绝，虚拟机无法启动。在此禁用按域的 AppArmor 是安全的——
   `qemu:commandline` 自定义设备已使该 domain 超出标准 confined-qemu 模型。

完整原理与 bless 流程：
[macOS 基础镜像](/docs/macos-base-image/)。

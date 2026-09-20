# macOS VMs (Hackintosh)

macOS guests alongside Linux/Windows VMs. Base image 制作详见 [macos-base-image.md](macos-base-image.md)。

## 与 Linux/Windows 的差异

| 方面 | Linux/Windows | macOS |
|------|---------------|-------|
| 显卡 | qxl/virtio/spice | `vmware-svga` via `qemu:commandline` |
| SMC | — | `isa-applesmc,osk=...` via `qemu:commandline` |
| 引导 | 系统盘直接启动 | OpenCore overlay (order 1) → macOS 盘 (order 2) |
| 固件 | distro OVMF 或 SeaBIOS | 持久化 OVMF + 预 bless 的 NVRAM 模板 |
| 网络 | libvirt `<interface>` | bridge，virtio NIC pin 到 root-bus `slot=0x05` |
| IP 配置 | cloud-init | 无 cloud-init，DHCP 或 SSH 手动设 |
| 关机 | `virsh shutdown` (ACPI) | macOS 不响应 ACPI shutdown，需桌面关机或 SSH |

## 资产

共享只读模板位于 `macos_asset_dir`（默认 `/home/fish/bucket/kvm/macos/`）：

| 文件 | 说明 |
|------|------|
| `macos-sonoma-base.img` | Sonoma 14.8.9 base image，admin/admin，Remote Login 已开 |
| `OpenCore.qcow2` | OpenCore 引导盘（SIP 已关，自动引导） |
| `OVMF_VARS-blessed.fd` | 预 bless 的 NVRAM 模板（冷启动免键盘的关键） |

### 拷贝到其他主机

这三个文件是自包含的，直接拷贝到新主机的 `macos_asset_dir`（默认
`/home/fish/bucket/kvm/macos/`）即可创建 macOS VM。bless 写入的 Preboot 卷
UUID、APFS 文件系统、boot.efi 路径都跟文件走，不依赖源主机状态。

新主机还需满足：

1. **`apt install ovmf`**——模板另引用宿主机系统文件 `/usr/share/OVMF/OVMF_CODE_4M.fd`
   （持久化版本）。必须是发行版的 ovmf 包，**不能**用 OSX-KVM 自带的非持久化版本，
   否则 bless 失效、冷启动弹磁盘选择界面（见"模板约束"第 1 条）
2. **拓扑一致**——q35 + 内置 SATA `1f:2` + 系统盘 sdb（port 2）由 `domain-macos.xml.j2`
   写死，走同一套 ansible-vms 模板即自动满足
3. QEMU >= 8.2.2、libvirt 版本相近（`qemu:commandline` 语法兼容）

不需要拷贝：`BaseSystem.img`、`fetch-macOS-v2.py`、`boot-macos-install.sh`——
只有重新制作 base image 时才用。

## 配置（vms.csv）

在 `vms.csv` 添加一行，`type=macos`，`disk_gb` 必须等于 base image 虚拟大小（64）。
macOS 使用 DHCP，**不填 ip/netmask/gateway/dns**。VNC 端口从 MAC 地址末字节推导（`5900 + hex末字节`）。

```csv
macos-sonoma-01,local,macos,8192,4,macos-sonoma,64,0,/home/fish/bucket/kvm/macos/macos-sonoma-base.img,br0,52:54:00:ff:00:01,efi,false,/home/fish/bucket/kvm/macos,,,,,
```

## 创建

```bash
ap playbooks/create-vm.yaml -e vm_name=macos-sonoma-01
```

创建两个 overlay（系统盘 + OpenCore），复制 blessed NVRAM，define 并 start。
冷启动免键盘，约 40s 到登录界面。

**网络**：默认 DHCP（br0 上游路由器）。查看 IP 用 list-vms 剧本：

```bash
ap playbooks/list-vms.yaml
```

输出的 IP 列即各 VM 地址（macOS 例：`192.168.100.45`）。

> ansible 只能用 `-m raw`（macOS 无 Python 解释器）。

## 开机

```bash
ap playbooks/start-vm.yaml -e vm_name=macos-sonoma-01
```

## 停机

```bash
ap playbooks/stop-vm.yaml -e vm_name=macos-sonoma-01
```

macOS 不响应 ACPI shutdown，剧本会提示：

- 桌面关机：Apple menu → Shut Down
- 或 SSH：`ssh admin@<ip> 'sudo shutdown -h now'`

> `virsh shutdown` 对 macOS 是 no-op，不要使用。

## 销毁

```bash
ap playbooks/destroy-vm.yaml -e vm_name=macos-sonoma-01 -e confirm=true
```

销毁前需先停机。base image 和共享资产不受影响。

## 模板约束（domain-macos.xml.j2）

三项必须匹配，否则表现为不同的无关故障：

1. **持久化 OVMF**：用宿主机 `/usr/share/OVMF/OVMF_CODE_4M.fd`，不是 OSX-KVM 自带的非持久化版本
2. **Bless 拓扑匹配**：磁盘必须挂 q35 内置 AHCI（PCI `1f:2`），不加额外 `ich9-ahci`
3. **NIC pin 到 root-bus `slot=0x05`**：macOS virtio-net 只识别固定 root-bus 位置，libvirt 自动分配到 `pcie-root-port` 子设备会导致网卡消失

详细原理和 bless 流程见 [macos-base-image.md](macos-base-image.md)。

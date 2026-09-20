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

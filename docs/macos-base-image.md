# 制作 macOS Sonoma base image（macos-sonoma-base.img）

在 Debian 12 KVM 宿主机上，用 [kholia/OSX-KVM](https://github.com/kholia/OSX-KVM) 方案手工安装 macOS Sonoma，再把成品盘固化成一张自包含的 qcow2 模板镜像，供后续派生 macOS VM 使用。

- 产出物：`/home/fish/bucket/kvm/macos/macos-sonoma-base.img`
- Guest：macOS Sonoma **14.8.9**（x86_64），4 vCPU / 8 GB，账户 `admin` / `admin`，Remote Login 已开
- OSX-KVM 仓库（下文简称 repo）：`/home/fish/bucket/OSX-KVM`
- 记录时间：2026-09-10（更新于 2026-09-20）

## 前置条件

- 宿主机 QEMU >= 8.2.2（本机 10.0.2）、libvirt >= 9（本机 11.3.0，来自 bookworm-backports）
- `/dev/kvm` 可用
- 已 clone OSX-KVM 仓库到 repo
- VNC 客户端：宿主机 `DISPLAY=:0` 上的 VNC viewer，或 `ssh -L` 转发后本地连接
- 磁盘空间：base image 实际约 29G，安装过程需额外空间

### OVMF 选择（重要）

**安装阶段**可以使用 OSX-KVM 自带的 OVMF（非持久化，不影响安装）：
- `OVMF_CODE_4M.fd`（3.5M）
- `OVMF_VARS-1920x1080.fd`（128K）——必须用不带 `-exp` 后缀的版本

**Bless + 集成到 libvirt 时**必须换成宿主机发行版的**持久化** OVMF：
- code: `/usr/share/OVMF/OVMF_CODE_4M.fd`
- vars: 540672 字节的持久化 VARS 文件（从真实 bless 后落盘的 VARS 复制而来）

> OSX-KVM 自带的 OVMF 是 RAM-backed / EmuVariable 版本，完全不读写磁盘上的 VARS 文件。
> bless 写入的 `efi-boot-device` 变量无法持久化，冷启动必然停在 Apple Startup Manager。

## 1. 下载并转换安装介质

```bash
cd /home/fish/bucket/OSX-KVM

# 从 Apple CDN 下载恢复镜像（交互式选版本，选 Sonoma）
./fetch-macOS-v2.py
# 产物：BaseSystem.dmg（753M）+ BaseSystem.chunklist

# 转 raw 格式（QEMU 需要 raw，不能直接挂 dmg）
sudo -n apt install -y dmg2img    # 如未安装
dmg2img -i BaseSystem.dmg BaseSystem.img
# 产物：BaseSystem.img（约 3G），安装器 + Recovery 环境
```

## 2. 创建安装目录和磁盘

```bash
WORK=/home/fish/bucket/kvm/macos-new
mkdir -p $WORK

# 创建目标安装盘（qcow2，按需选大小）
qemu-img create -f qcow2 $WORK/macos-sonoma-new.qcow2 64G

# 复制 OVMF VARS 模板（安装阶段用 OSX-KVM 自带的非持久化版本即可）
cp /home/fish/bucket/OSX-KVM/OVMF_VARS-1920x1080.fd $WORK/install-OVMF_VARS.fd
```

> qcow2 支持后期扩容：`qemu-img resize xxx.qcow2 128G` + guest 内
> `diskutil apfs resizeContainer diskN 0`，初始选小不影响后续。

## 3. 启动安装 VM

使用 `boot-macos-install.sh` 脚本（位于 `/home/fish/bucket/OSX-KVM/`）：

```bash
#!/bin/bash
# Install macOS Sonoma onto a fresh disk
set -euo pipefail
D=/home/fish/bucket/kvm
M=$D/macos-new
OSX=/home/fish/bucket/OSX-KVM
sudo -n qemu-system-x86_64 \
  -enable-kvm -m 8192 -smp 4,cores=2,sockets=1 \
  -cpu Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+aes,+xsave,+xsaveopt,check \
  -machine q35 \
  -device qemu-xhci,id=xhci \
  -device usb-kbd,bus=xhci.0 -device usb-tablet,bus=xhci.0 \
  -device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
  -drive if=pflash,format=raw,file=$M/install-OVMF_VARS.fd \
  -smbios type=2 \
  -drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file=$OSX/OpenCore/OpenCore.qcow2 \
  -device ide-hd,bus=ide.0,drive=OpenCoreBoot \
  -drive id=Installer,if=none,format=raw,file=$OSX/BaseSystem.img \
  -device ide-hd,bus=ide.1,drive=Installer \
  -drive id=MacHDD,if=none,format=qcow2,file=$M/macos-sonoma-new.qcow2 \
  -device ide-hd,bus=ide.2,drive=MacHDD \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -device vmware-svga -vnc 127.0.0.1:83
```

启动：

```bash
cd /home/fish/bucket/OSX-KVM
sudo -n bash boot-macos-install.sh
```

**要点：**
- 三块盘全部挂 q35 **内置 AHCI**（`ide.0` / `ide.1` / `ide.2`），**不额外加** `ich9-ahci` 设备——保证磁盘控制器在 PCI `1f:2`，这是后续 bless 正确落盘的前提（详见"技术背景：PCI 拓扑与 bless"）
- `snapshot=on` 保护 OpenCore 盘不被安装过程修改
- `usb-tablet` 让 VNC 客户端指针绝对定位（点击才准）
- VNC display `:83`（端口 5983）
- 使用宿主机持久化 OVMF CODE（`/usr/share/OVMF/OVMF_CODE_4M.fd`），确保 bless 后变量能落盘

## 4. VNC 完成安装

连接 VNC：

```bash
DISPLAY=:0 setsid nohup vncviewer 127.0.0.1:5983 Shared=false &
```

安装流程（全程人工点击，键盘不稳时以鼠标为主）：

1. **OpenCore 选择界面**：方向键选 `macOS Base System`，回车进 Recovery
2. Recovery 主窗口 -> 双击 **`Reinstall macOS Sonoma`** 行 -> 右下 **Continue**
3. 许可页 **Agree**
4. 目标磁盘选择页：如果只显示 `macOS Base System`（2.87G，Recovery 自身），说明目标盘还没分区。**点 Back 退回** Recovery
5. 打开 **Disk Utility** -> 菜单 `View -> Show All Devices` -> 选中 **`QEMU HARDDISK Media`**（整块虚拟盘）
6. **Erase**：Name `Macintosh HD` / Format **`APFS`** / Scheme **`GUID Partition Map`**，抹完关掉 Disk Utility
7. 重新进 **Reinstall macOS Sonoma**，此时列表出现 `Macintosh HD` -> Continue
8. 等待安装完成（几十分钟到一小时+），弹出 `Restart` -> 点击
9. 重启回 OpenCore 选择界面 -> 选 **`Macintosh HD`** -> 进首次启动引导
10. Setup Assistant：
    - 语言**只选 English**（减少语言包占用）
    - Region 随意（选美国/澳洲比较中性，别选 American Samoa 之类奇葩时区）
    - 键盘默认
    - 迁移选 **Not Now**
    - **不安装 Xcode CLI tools**（省 ~1.5G）
    - **Account**：Full Name / Account Name 用 `admin`，密码 `admin`

**坑：**
- 首次启动时 `vmware-svga` 驱动加载有一小段灰屏（几分钟），别当成卡死
- Recovery 主窗口的键盘导航不稳（Tab 移焦点可以、Space/Return 无法激活列表项），列表行必须**鼠标双击**
- 从 VNC 脚本化点击（手写 RFB PointerEvent）在 QEMU 上不稳（BrokenPipe），直接用真 VNC 客户端最省事

## 5. 体积优化（安装完成后、bless 之前）

SSH 或在 Terminal 里执行：

```bash
# 关休眠（省 ~4G sleepimage）
sudo pmset -a hibernatemode 0
sudo rm -f /var/vm/sleepimage

# 清缓存
sudo rm -rf /Library/Caches/* ~/Library/Caches/*

# 清日志
sudo rm -rf /var/log/*.gz /var/log/*.old /private/var/log/asl/*.asl
```

## 6. 开 Remote Login（SSH）

**System Settings -> General -> Sharing -> Remote Login** 打开，右侧 `i` -> 允许 **All users**。

> macOS 默认关闭 Remote Login；关掉 Network Firewall 或允许 ssh，避免
> `kex_exchange_identification: Connection closed`。

## 7. Bless + 干净关机

这是让冷启动免键盘的关键步骤（详见"技术背景：PCI 拓扑与 bless"）。

在 macOS guest 内执行：

```bash
# 确认 SIP 已关（OpenCore csr-active-config 已设 NVRAM Protections=disabled）
csrutil status

# 写入 efi-boot-device 到 OVMF NVRAM
sudo bless --mount / --setBoot --verbose

# 干净关机，让 OVMF 把变量落盘
sudo shutdown -h now
```

> **别硬 kill QEMU**——qcow2 会脏，还可能被 journal 卡住恢复。

看到 SSH 断、QEMU 进程自己退出（`pgrep -f qemu-system` 无输出）即可。

## 8. 校验并晋升 NVRAM 模板

```bash
# 校验 bless 写入的设备路径
virt-fw-vars -i $WORK/install-OVMF_VARS.fd -p | grep -E 'efi-boot-device|Boot0080'
# Boot0080 devpath 必须读作 ... PCI(dev=1f:2)/SATA(port=1)/Partition(nr=2)/.../boot.efi

# 晋升为共享模板
cp $WORK/install-OVMF_VARS.fd /home/fish/bucket/kvm/macos/OVMF_VARS-blessed.fd
```

## 9. 生成 base image

```bash
sudo qemu-img convert -f qcow2 -O qcow2 \
  $WORK/macos-sonoma-new.qcow2 \
  /home/fish/bucket/kvm/macos/macos-sonoma-base.img
sudo chown libvirt-qemu:libvirt-qemu /home/fish/bucket/kvm/macos/macos-sonoma-base.img
```

校验：

```bash
qemu-img info /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# 期望：file format: qcow2、virtual size: 64 GiB、**没有 backing file 行**
```

产物就是只读模板。派生新 VM 时以它为 backing：

```bash
qemu-img create -f qcow2 -b /home/fish/bucket/kvm/macos/macos-sonoma-base.img \
  -F qcow2 <vm-name>.qcow2
```

> **注意**：macOS APFS 在 AHCI SATA 上不支持 TRIM（QEMU 只有 virtio-blk/scsi/nvme 支持），
> 所以 `fstrim` 和 `qemu-img convert` 的稀疏回收效果有限。实测 Sonoma 精简安装的
> 地板约 29G，无法通过在线方式显著缩小。

---

## 技术背景：PCI 拓扑与 bless

这是 macOS-on-KVM 最容易踩坑的地方，理解它可以避免大量排查弯路。

### 问题

Apple `boot.efi` 自己画的 **Startup Manager**（磁盘选择界面）：只要 OVMF 里持久化的
`efi-boot-device` / `efi-boot-device-data` 变量缺失、或其中编码的设备路径跟当前
PCI 拓扑对不上，就会停在这里等键盘输入。

而 libvirt 对 macOS guest 的键盘注入（`send-key` / QMP `input-send-event`）实测
三种 USB 控制器（默认 xhci、pin 到 bus0 的 xhci、`ich9-ehci1` + `ich9-uhci1`）
全部无响应（截图像素级 AE=0），完全相同的设备配置在裸 qemu 里却是好的。

所以正确做法是让冷启动本身**不需要任何键盘输入**。

### PCI 拓扑匹配

`q35` 机器类型**自带**一块 ICH9 AHCI 控制器固定在 PCI **`1f:2`**，libvirt 的
`<controller type='sata'>` 用的就是这个内置控制器。

OSX-KVM 教程脚本里的 `-device ich9-ahci,id=sata` 是**额外**加的第二块控制器，
落在 `02:0`。在 `02:0` 拓扑下 bless 出来的 `efi-boot-device` device-path 放进
`1f:2` 拓扑的 libvirt 域里不匹配，照样弹 picker。

> 这个拓扑不匹配一度被误判为"libvirt 键盘坏了导致的集成障碍"，实际根因从头到尾只是
> 设备路径对不上。

### 正确做法

安装脚本（`boot-macos-install.sh`）不加额外 `ich9-ahci`，磁盘直接挂 q35 内置
AHCI 总线（`ide.0` / `ide.1` / `ide.2`），天然 `1f:2`。在这个拓扑下 bless，设备
路径就是 `PCI(dev=1f:2)/SATA(port=N)/...`，与任何同样使用 `1f:2` 的 libvirt 域
完全匹配。

### OpenCore config.plist 注意事项

`NVRAM > Delete` 列表里**不能**有 `efi-boot-device` / `efi-boot-device-data`
（只留 `boot-args` 和 `ForceDisplayRotationInEFI`），否则每次启动都会被自己抹掉，
破坏 bless 持久化。

### libvirt EFI 域生命周期坑

`virsh undefine` 对带 nvram 的域必须加 `--nvram`，而加了之后会**删除** VARS 文件。
因为这份 VARS 是预先烘焙好内容的模板（不是 libvirt 自动生成的空模板），手工重新
define 前必须先重新 `cp` 一次 `OVMF_VARS-blessed.fd` 到目标路径：

```
destroy -> undefine --nvram -> cp blessed 模板 -> define -> start
```

`create-vm` role 每次创建时都会重新播种 VARS，所以走 role 正常不受影响；只有手工
改 XML 重定义才需要记这个顺序。

## 技术背景：关键决策

- **选 Sonoma 而非最新 macOS**：OSX-KVM 对 Intel 模拟（Skylake-Client + OpenCore）+ Sonoma 组合最成熟；Tahoe 起 Intel 支持收窄
- **保留 OpenCore.qcow2 的 `snapshot=on`**：EFI 盘改动不落地，避免多次启动互相污染
- **不共用 OVMF_VARS .fd**：每台 VM 必须独立拷贝一份，否则 NVRAM 冲突

---

## 附录 A：OpenCore 引导盘

`OpenCore/OpenCore.qcow2` 是预构建的 OpenCore 引导盘，关键配置：

- **SIP 已关闭**：`csr-active-config` 设为 NVRAM Protections disabled
- **自动引导**：`Misc > Boot` 已配置跳过 picker（bless 后自动选 macOS 盘）
- **`NVRAM > Delete` 列表**：只删 `boot-args` 和 `ForceDisplayRotationInEFI`，**不能**删 `efi-boot-device` / `efi-boot-device-data`

安装时挂法：

```
-drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file=$OSX/OpenCore/OpenCore.qcow2
-device ide-hd,bus=ide.0,drive=OpenCoreBoot
```

`snapshot=on` 确保安装过程对 OpenCore 盘的改动不落盘，保持引导盘干净。

## 附录 B：OSX-KVM 仓库资产清单

仓库地址：[kholia/OSX-KVM](https://github.com/kholia/OSX-KVM)
本机路径：`/home/fish/bucket/OSX-KVM`

| 文件 | 大小 | 用途 |
|------|------|------|
| `fetch-macOS-v2.py` | -- | 从 Apple CDN 下载 macOS 恢复镜像（交互式选版本） |
| `BaseSystem.dmg` | 753M | Apple 官方恢复镜像原始下载 |
| `BaseSystem.img` | 3.0G | dmg2img 转换后的 raw 安装器，直接挂给 VM |
| `OpenCore/OpenCore.qcow2` | -- | 已打补丁的 OpenCore 引导盘（SIP 已关、自动引导） |
| `OVMF_CODE_4M.fd` | 3.5M | OSX-KVM 自带的 OVMF CODE（非持久化） |
| `OVMF_VARS-1920x1080.fd` | 128K | OSX-KVM 自带的 OVMF VARS 模板（非持久化） |

### 仓库内脚本说明

| 脚本 | 说明 |
|------|------|
| `boot-macos-install.sh` | base image 安装启动脚本（本文第 3 步） |
| `boot-macos-ctrl4.sh` | bless 实验脚本，用 q35 内置 AHCI（`1f:2`），不加额外 ich9-ahci |
| `boot-macos-experiment.sh` | 早期实验安装脚本（128G + 额外 ich9-ahci `02:0`），仅供参考 |
| `boot-macos-ctrl.sh` / `ctrl2` / `ctrl3` | 迭代版本，已不需要 |
| `boot-macOS-headless.sh` | OSX-KVM 原版 GUI 启动脚本 |

## 附录 C：磁盘布局

```
/home/fish/bucket/OSX-KVM/          # 开源项目目录（git clone）
+-- fetch-macOS-v2.py               # 安装介质下载工具
+-- BaseSystem.dmg / BaseSystem.img # macOS Sonoma 安装介质
+-- OpenCore/OpenCore.qcow2         # OpenCore 引导盘（共享，只读）
+-- OVMF_CODE_4M.fd                 # 非持久化 OVMF（仅安装阶段可用）
+-- OVMF_VARS-1920x1080.fd          # 非持久化 OVMF VARS（仅安装阶段可用）
+-- boot-macos-install.sh           # base 安装启动脚本
+-- boot-macos-ctrl4.sh             # bless 实验脚本

/home/fish/bucket/kvm/macos/        # ansible-vms 托管资产目录
+-- macos-sonoma-base.img           # 正式 base image（每台 VM 的 backing）
+-- OpenCore.qcow2                  # OpenCore 引导盘（从 OSX-KVM 复制）
+-- OVMF_CODE_4M.fd                 # 宿主机持久化 OVMF CODE（从 /usr/share/OVMF 复制）
+-- OVMF_VARS-blessed.fd            # 已 bless 的 NVRAM 模板（冷启动免键盘的关键）
+-- <vm-name>/                      # 每台 VM 的工作目录
    +-- <vm-name>.qcow2             # 系统盘 overlay（backing -> base）
    +-- <vm-name>-OpenCore.qcow2    # OpenCore overlay（backing -> 共享 OpenCore）
    +-- <vm-name>-OVMF_VARS.fd      # 从 blessed 模板复制的 per-VM NVRAM

/home/fish/bucket/kvm/macos-new/    # base image 安装临时目录
+-- macos-sonoma-new.qcow2          # 安装盘（安装完成后 convert 为 base）
+-- install-OVMF_VARS.fd            # 安装用 VARS 副本（bless 后晋升为 blessed）
```

## 附录 D：资产流转

```
fetch-macOS-v2.py -> BaseSystem.dmg -> dmg2img -> BaseSystem.img
                                                    |
boot-macos-install.sh（挂三块盘启动安装 VM）
    +-- OpenCore.qcow2          (ide.0, snapshot=on)
    +-- BaseSystem.img          (ide.1, 安装器)
    +-- macos-sonoma-new.qcow2  (ide.2, 目标盘)
                                                    |
安装完成 + bless + shutdown
    -> install-OVMF_VARS.fd 晋升为 OVMF_VARS-blessed.fd
                                                    |
qemu-img convert -> macos-sonoma-base.img
                                                    |
create-vm.yaml 自动化：每台新 VM 以 base 做 backing 派生 overlay
```

## 实测执行记录（2026-09-20，本次制作）

按上述步骤实际执行一遍，记录关键命令与验证结果，供下次复现对照。

### 安装阶段网络坑与修复

安装 VM 用 QEMU user-net（slirp NAT），guest 里 `ipconfig getifaddr en0` 拿到
`10.0.2.15`——这是 NAT 内部地址，宿主机无法直接 ping/SSH 到。修复：给
`boot-macos-install.sh` 的 `-netdev user,id=net0` 加上
`hostfwd=tcp::2222-:22`，宿主机通过 `ssh -p 2222 admin@127.0.0.1` 直接访问 guest，
不需要改网络拓扑、不需要 VNC 里手动敲命令。

```bash
# 宿主机验证（安装完成、Remote Login 已开之后）
sshpass -p admin ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  admin@127.0.0.1 'sw_vers; ipconfig getifaddr en0'
# ProductVersion: 14.8.9   10.0.2.15
```

### 体积优化（步骤 5）

```bash
sshpass -p admin ssh -p 2222 ... admin@127.0.0.1 '
  echo admin | sudo -S -p "" pmset -a hibernatemode 0
  echo admin | sudo -S -p "" rm -f /var/vm/sleepimage
  echo admin | sudo -S -p "" rm -rf /Library/Caches/* ~/Library/Caches/*
  echo admin | sudo -S -p "" sh -c "find /var/log -name *.gz -delete; rm -rf /private/var/log/asl/*.asl"
'
```

### bless 验证（步骤 7）

```bash
sshpass -p admin ssh -p 2222 ... admin@127.0.0.1 \
  'echo admin | sudo -S -p "" bless --mount / --setBoot --verbose'
```

关键输出（确认写入的是 UUID 指向 preboot 卷、拓扑正确）：

```
Setting EFI NVRAM:
    efi-boot-device='<array>...UUID</key><string>98FA02AF-D0A8-4E55-8B63-F9FC985A4251</string>...
    \System\Library\CoreServices\boot.efi</string></dict></array>'
```

关机（`shutdown -h now`，rc=255 是 SSH 断开的正常表现，不是错误）后，
宿主机上必须**等 QEMU 进程自己退出**（用 `pgrep`/`ps` 确认，不能用 `pgrep` 匹配
到自己刚执行的 shell 命令），否则 VARS 文件可能还没落盘完整。

### 校验 NVRAM（步骤 8）

```bash
virt-fw-vars -i /home/fish/bucket/kvm/macos-new/install-OVMF_VARS.fd -p \
  | grep -iE 'Boot00|efi-boot-device'
```

期望看到 `Boot0080`，devpath 必须读作 `PciRoot()/PCI(dev=1f:2)/SATA(port=2)/...`
——本次实测正是这个路径（`port=2` 对应安装盘挂在 `ide.2`，与 libvirt 域将来
用的拓扑一致，见"技术背景：PCI 拓扑与 bless"）：

```
Boot0080 : boot entry: title="" devpath=PciRoot()/PCI(dev=1f:2)/SATA(port=2)/Partition(nr=2)/Media(subtype=0x3)/FilePath(\...\boot.efi)
efi-boot-device      : blob: 444 bytes
efi-boot-device-data : blob: 264 bytes
```

### 生成 base image（步骤 9）

```bash
sudo qemu-img convert -f qcow2 -O qcow2 \
  /home/fish/bucket/kvm/macos-new/macos-sonoma-new.qcow2 \
  /home/fish/bucket/kvm/macos/macos-sonoma-base.img
sudo chown libvirt-qemu:libvirt-qemu /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# 实测耗时：4 分 24 秒
```

最终产物校验：

```bash
qemu-img info /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# file format: qcow2
# virtual size: 64 GiB
# disk size: 29.1 GiB      （无 backing file 行，自包含）
```

> 再次验证：虚拟盘从 128G 缩到 64G，**实际占用仍是 29.1G**（对比之前 128G 虚拟盘实测 28.9G，
> 基本一致）。印证了本文档开头结论：base image 无法通过调整虚拟盘大小来缩小实际占用，
> 29G 是 macOS APFS-on-AHCI 无 TRIM 支持下的固有地板（详见"体积优化"与"技术背景"两节）。

---
title: macOS Base Image
description: Build macos-sonoma-base.img from scratch with OSX-KVM on Debian 12.
weight: 130
icon: fa-brands fa-apple
menus:
  main:
    identifier: docs-macos-base-image
    parent: docs
    weight: 130
    params:
      icon: fa-brands fa-apple
cascade:
  type: docs
  footer_style: slim
---

On a Debian 12 KVM host, install macOS Sonoma by hand using the
[kholia/OSX-KVM](https://github.com/kholia/OSX-KVM) approach, then freeze the
resulting disk into a self-contained qcow2 template image for deriving macOS
VMs.

- Output: `/home/fish/bucket/kvm/macos/macos-sonoma-base.img`
- Guest: macOS Sonoma **14.8.9** (x86_64), 4 vCPU / 8 GB, account `admin` / `admin`, Remote Login enabled
- OSX-KVM repo (hereafter "repo"): `/home/fish/bucket/OSX-KVM`
- Recorded: 2026-09-10 (updated 2026-09-20)

## Prerequisites

- Host QEMU >= 8.2.2 (10.0.2 here), libvirt >= 9 (11.3.0 here, from bookworm-backports)
- `/dev/kvm` available
- OSX-KVM repo cloned to the repo path
- VNC client: a VNC viewer on the host's `DISPLAY=:0`, or `ssh -L` forwarding and connect locally
- Disk space: the base image is ~29G actual; installation needs extra space

### OVMF choice (important)

**During installation** you can use OSX-KVM's bundled OVMF (non-persistent;
does not affect the install):
- `OVMF_CODE_4M.fd` (3.5M)
- `OVMF_VARS-1920x1080.fd` (128K) — must be the version without the `-exp` suffix

**When blessing + integrating with libvirt** you must switch to the host
distro's **persistent** OVMF:
- code: `/usr/share/OVMF/OVMF_CODE_4M.fd`
- vars: the 540672-byte persistent VARS file (copied from the VARS written to
  disk after a real bless)

> OSX-KVM's bundled OVMF is the RAM-backed / EmuVariable variant; it never
> reads or writes the on-disk VARS file. The `efi-boot-device` variable
> written by bless cannot persist, and cold boot always stops at Apple
> Startup Manager.

## 1. Download and convert the installer media

```bash
cd /home/fish/bucket/OSX-KVM

# Download the recovery image from Apple's CDN (interactive version pick; choose Sonoma)
./fetch-macOS-v2.py
# Output: BaseSystem.dmg (753M) + BaseSystem.chunklist

# Convert to raw (QEMU needs raw; it cannot mount a dmg directly)
sudo -n apt install -y dmg2img    # if not installed
dmg2img -i BaseSystem.dmg BaseSystem.img
# Output: BaseSystem.img (~3G), installer + Recovery environment
```

## 2. Create the install directory and disk

```bash
WORK=/home/fish/bucket/kvm/macos-new
mkdir -p $WORK

# Create the target install disk (qcow2; size as needed)
qemu-img create -f qcow2 $WORK/macos-sonoma-new.qcow2 64G

# Copy the OVMF VARS template (the install phase can use OSX-KVM's non-persistent version)
cp /home/fish/bucket/OSX-KVM/OVMF_VARS-1920x1080.fd $WORK/install-OVMF_VARS.fd
```

> qcow2 can be enlarged later: `qemu-img resize xxx.qcow2 128G` + inside the
> guest `diskutil apfs resizeContainer diskN 0`. Starting small does not
> limit you.

## 3. Boot the install VM

Using the `boot-macos-install.sh` script (in `/home/fish/bucket/OSX-KVM/`):

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

Start it:

```bash
cd /home/fish/bucket/OSX-KVM
sudo -n bash boot-macos-install.sh
```

**Key points:**
- All three disks attach to q35's **built-in AHCI** (`ide.0` / `ide.1` / `ide.2`); do **not** add an `ich9-ahci` device — this keeps the disk controller at PCI `1f:2`, which is the prerequisite for bless to land correctly (see "Technical background: PCI topology and bless")
- `snapshot=on` protects the OpenCore disk from modification during installation
- `usb-tablet` gives the VNC client absolute pointer positioning (clicks land accurately)
- VNC display `:83` (port 5983)
- Uses the host's persistent OVMF CODE (`/usr/share/OVMF/OVMF_CODE_4M.fd`) so post-bless variables persist to disk

## 4. Complete the installation over VNC

Connect VNC:

```bash
DISPLAY=:0 setsid nohup vncviewer 127.0.0.1:5983 Shared=false &
```

Installation flow (fully manual clicking; prefer the mouse when the keyboard is unreliable):

1. **OpenCore picker**: arrow-key to `macOS Base System`, press Enter to enter Recovery
2. Recovery main window → double-click **`Reinstall macOS Sonoma`** → **Continue** (bottom right)
3. License page → **Agree**
4. Target disk page: if only `macOS Base System` (2.87G, the Recovery itself) is listed, the target disk is unpartitioned. Click **Back** to return to Recovery
5. Open **Disk Utility** → menu `View -> Show All Devices` → select **`QEMU HARDDISK Media`** (the whole virtual disk)
6. **Erase**: Name `Macintosh HD` / Format **`APFS`** / Scheme **`GUID Partition Map`**, then close Disk Utility
7. Enter **Reinstall macOS Sonoma** again; `Macintosh HD` now appears → Continue
8. Wait for the install (tens of minutes to an hour+); on `Restart` → click it
9. Back at the OpenCore picker → choose **`Macintosh HD`** → first-boot sequence
10. Setup Assistant:
    - Language: **English only** (smaller language packs)
    - Region: any (US/Australia are neutral; avoid odd timezones like American Samoa)
    - Keyboard: default
    - Migration: **Not Now**
    - **Do not install Xcode CLI tools** (saves ~1.5G)
    - **Account**: Full Name / Account Name `admin`, password `admin`

**Pitfalls:**
- On first boot the `vmware-svga` driver produces a grey screen for a few minutes — not a hang
- Keyboard navigation in the Recovery main window is unreliable (Tab moves focus, but Space/Return won't activate list items); list rows need a **mouse double-click**
- Scripted clicking over VNC (hand-written RFB PointerEvents) is unreliable on QEMU (BrokenPipe); a real VNC client is easiest

## 5. Size optimization (after install, before bless)

Via SSH or in Terminal:

```bash
# Disable hibernation (saves the ~4G sleepimage)
sudo pmset -a hibernatemode 0
sudo rm -f /var/vm/sleepimage

# Clear caches
sudo rm -rf /Library/Caches/* ~/Library/Caches/*

# Clear logs
sudo rm -rf /var/log/*.gz /var/log/*.old /private/var/log/asl/*.asl
```

## 6. Enable Remote Login (SSH)

**System Settings → General → Sharing → Remote Login** on; click the `i` on the
right → allow **All users**.

> macOS has Remote Login off by default; disable the Network Firewall or allow
> ssh to avoid `kex_exchange_identification: Connection closed`.

## 7. Bless + clean shutdown

This is the key step for keyboard-free cold boot (see "Technical background:
PCI topology and bless").

Inside the macOS guest:

```bash
# Confirm SIP is disabled (OpenCore csr-active-config sets NVRAM Protections=disabled)
csrutil status

# Write efi-boot-device into OVMF NVRAM
sudo bless --mount / --setBoot --verbose

# Clean shutdown so OVMF flushes the variables to disk
sudo shutdown -h now
```

> **Never hard-kill QEMU** — the qcow2 gets dirty and may need journal recovery.

Wait for SSH to drop and the QEMU process to exit on its own (`pgrep -f
qemu-system` returns nothing).

## 8. Verify and promote the NVRAM template

```bash
# Verify the device path written by bless
virt-fw-vars -i $WORK/install-OVMF_VARS.fd -p | grep -E 'efi-boot-device|Boot0080'
# Boot0080 devpath must read as ... PCI(dev=1f:2)/SATA(port=1)/Partition(nr=2)/.../boot.efi

# Promote to the shared template
cp $WORK/install-OVMF_VARS.fd /home/fish/bucket/kvm/macos/OVMF_VARS-blessed.fd
```

## 9. Produce the base image

```bash
sudo qemu-img convert -f qcow2 -O qcow2 \
  $WORK/macos-sonoma-new.qcow2 \
  /home/fish/bucket/kvm/macos/macos-sonoma-base.img
sudo chown libvirt-qemu:libvirt-qemu /home/fish/bucket/kvm/macos/macos-sonoma-base.img
```

Verify:

```bash
qemu-img info /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# Expect: file format: qcow2, virtual size: 64 GiB, **no backing file line**
```

The result is a read-only template. Derive new VMs from it as backing:

```bash
qemu-img create -f qcow2 -b /home/fish/bucket/kvm/macos/macos-sonoma-base.img \
  -F qcow2 <vm-name>.qcow2
```

> **Note**: macOS APFS on AHCI SATA does not support TRIM (QEMU only supports
> it on virtio-blk/scsi/nvme), so `fstrim` and sparse reclamation from
> `qemu-img convert` are limited. A lean Sonoma install measures ~29G as the
> floor; it cannot be meaningfully reduced online.

---

## Technical background: PCI topology and bless

This is the most common trap in macOS-on-KVM; understanding it avoids a lot
of dead-end debugging.

### The problem

Apple `boot.efi` draws its own **Startup Manager** (disk picker): if the
persisted `efi-boot-device` / `efi-boot-device-data` variables in OVMF are
missing, or the encoded device path does not match the current PCI topology,
it stops and waits for keyboard input.

And libvirt keyboard injection into macOS guests (`send-key` / QMP
`input-send-event`) was measured unresponsive across three USB controllers
(default xhci, xhci pinned to bus0, `ich9-ehci1` + `ich9-uhci1`) — pixel-level
screenshot diff AE=0 — while the identical device config works under bare
qemu.

So the correct approach is to make cold boot itself **require no keyboard
input**.

### PCI topology matching

The `q35` machine type **ships with** an ICH9 AHCI controller fixed at PCI
**`1f:2`**; libvirt's `<controller type='sata'>` uses this built-in controller.

The `-device ich9-ahci,id=sata` in OSX-KVM's tutorial scripts adds a
**second** controller at `02:0`. A bless under the `02:0` topology produces an
`efi-boot-device` device-path that does not match inside a libvirt domain on
`1f:2` — the picker appears again.

> This topology mismatch was once misdiagnosed as "libvirt's keyboard is
> broken, blocking integration"; the root cause was always just the device
> path mismatch.

### The correct approach

The install script (`boot-macos-install.sh`) adds no extra `ich9-ahci`; disks
attach directly to q35's built-in AHCI bus (`ide.0` / `ide.1` / `ide.2`),
naturally at `1f:2`. Bless in this topology writes a device path of
`PCI(dev=1f:2)/SATA(port=N)/...`, which matches any libvirt domain also using
`1f:2`.

### OpenCore config.plist notes

The `NVRAM > Delete` list must **not** contain `efi-boot-device` /
`efi-boot-device-data` (keep only `boot-args` and
`ForceDisplayRotationInEFI`), otherwise every boot erases them and breaks
bless persistence.

### libvirt EFI domain lifecycle pitfall

`virsh undefine` on a domain with nvram requires `--nvram`, and that
**deletes** the VARS file. Because this VARS is a pre-baked template (not
libvirt's auto-generated blank one), you must re-`cp` `OVMF_VARS-blessed.fd`
to the target path before manually re-defining:

```
destroy -> undefine --nvram -> cp blessed template -> define -> start
```

The `create-vm` role re-seeds the VARS on every creation, so the normal role
path is unaffected; only manual XML re-definition needs this ordering.

## Technical background: key decisions

- **Sonoma over the latest macOS**: OSX-KVM's combination of Intel emulation (Skylake-Client + OpenCore) + Sonoma is the most mature; Intel support narrows starting with Tahoe
- **Keep `snapshot=on` on OpenCore.qcow2**: EFI disk changes never land, avoiding cross-boot pollution
- **Never share the OVMF_VARS .fd**: each VM must get its own copy, or NVRAM conflicts arise

---

## Appendix A: OpenCore boot disk

`OpenCore/OpenCore.qcow2` is a pre-built OpenCore boot disk. Key settings:

- **SIP disabled**: `csr-active-config` set to NVRAM Protections disabled
- **Auto-boot**: `Misc > Boot` skips the picker (auto-selects the macOS disk after bless)
- **`NVRAM > Delete` list**: deletes only `boot-args` and `ForceDisplayRotationInEFI`, and must **not** delete `efi-boot-device` / `efi-boot-device-data`

Attach at install time:

```
-drive id=OpenCoreBoot,if=none,snapshot=on,format=qcow2,file=$OSX/OpenCore/OpenCore.qcow2
-device ide-hd,bus=ide.0,drive=OpenCoreBoot
```

`snapshot=on` ensures install-time changes never land on the OpenCore disk,
keeping the boot disk clean.

## Appendix B: OSX-KVM repo asset inventory

Repo: [kholia/OSX-KVM](https://github.com/kholia/OSX-KVM)
Local path: `/home/fish/bucket/OSX-KVM`

| File | Size | Purpose |
|------|------|------|
| `fetch-macOS-v2.py` | -- | Download macOS recovery images from Apple's CDN (interactive version pick) |
| `BaseSystem.dmg` | 753M | Original Apple recovery image download |
| `BaseSystem.img` | 3.0G | Raw installer after dmg2img, attached directly to the VM |
| `OpenCore/OpenCore.qcow2` | -- | Patched OpenCore boot disk (SIP disabled, auto-boot) |
| `OVMF_CODE_4M.fd` | 3.5M | OSX-KVM's bundled OVMF CODE (non-persistent) |
| `OVMF_VARS-1920x1080.fd` | 128K | OSX-KVM's bundled OVMF VARS template (non-persistent) |

### Repo scripts

| Script | Description |
|------|------|
| `boot-macos-install.sh` | Base image install boot script (step 3 above) |
| `boot-macos-ctrl4.sh` | Bless experiment script using q35's built-in AHCI (`1f:2`), no extra ich9-ahci |
| `boot-macos-experiment.sh` | Early experimental install script (128G + extra ich9-ahci `02:0`), reference only |
| `boot-macos-ctrl.sh` / `ctrl2` / `ctrl3` | Iterations, no longer needed |
| `boot-macOS-headless.sh` | OSX-KVM's original GUI boot script |

## Appendix C: Disk layout

```
/home/fish/bucket/OSX-KVM/          # open-source project dir (git clone)
+-- fetch-macOS-v2.py               # installer media downloader
+-- BaseSystem.dmg / BaseSystem.img # macOS Sonoma installer media
+-- OpenCore/OpenCore.qcow2         # OpenCore boot disk (shared, read-only)
+-- OVMF_CODE_4M.fd                 # non-persistent OVMF (install phase only)
+-- OVMF_VARS-1920x1080.fd          # non-persistent OVMF VARS (install phase only)
+-- boot-macos-install.sh           # base install boot script
+-- boot-macos-ctrl4.sh             # bless experiment script

/home/fish/bucket/kvm/macos/        # ansible-vms managed assets dir
+-- macos-sonoma-base.img           # official base image (backing for every VM)
+-- OpenCore.qcow2                  # OpenCore boot disk (copied from OSX-KVM)
+-- OVMF_CODE_4M.fd                 # host persistent OVMF CODE (copied from /usr/share/OVMF)
+-- OVMF_VARS-blessed.fd            # blessed NVRAM template (the key to keyboard-free cold boot)
+-- <vm-name>/                      # per-VM working dir
    +-- <vm-name>.qcow2             # system disk overlay (backing -> base)
    +-- <vm-name>-OpenCore.qcow2    # OpenCore overlay (backing -> shared OpenCore)
    +-- <vm-name>-OVMF_VARS.fd      # per-VM NVRAM copied from the blessed template

/home/fish/bucket/kvm/macos-new/    # base image install scratch dir
+-- macos-sonoma-new.qcow2          # install disk (converted to base when done)
+-- install-OVMF_VARS.fd            # install-phase VARS copy (promoted to blessed)
```

## Appendix D: Asset flow

```
fetch-macOS-v2.py -> BaseSystem.dmg -> dmg2img -> BaseSystem.img
                                                    |
boot-macos-install.sh (boots the install VM with three disks)
    +-- OpenCore.qcow2          (ide.0, snapshot=on)
    +-- BaseSystem.img          (ide.1, installer)
    +-- macos-sonoma-new.qcow2  (ide.2, target disk)
                                                    |
install complete + bless + shutdown
    -> install-OVMF_VARS.fd promoted to OVMF_VARS-blessed.fd
                                                    |
qemu-img convert -> macos-sonoma-base.img
                                                    |
create-vm.yaml automation: each new VM derives an overlay backed by the base
```

## Measured run log (2026-09-20, this build)

A full execution of the steps above, recording key commands and verification
results for future reproduction.

### Install-phase network pitfall and fix

The install VM uses QEMU user-net (slirp NAT); inside the guest
`ipconfig getifaddr en0` returns `10.0.2.15` — a NAT-internal address the
host can neither ping nor SSH. Fix: add `hostfwd=tcp::2222-:22` to the
`-netdev user,id=net0` line of `boot-macos-install.sh`; the host then reaches
the guest via `ssh -p 2222 admin@127.0.0.1`, with no network topology change
and no manual typing in VNC.

```bash
# Host-side verification (after install, with Remote Login enabled)
sshpass -p admin ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  admin@127.0.0.1 'sw_vers; ipconfig getifaddr en0'
# ProductVersion: 14.8.9   10.0.2.15
```

### Size optimization (step 5)

```bash
sshpass -p admin ssh -p 2222 ... admin@127.0.0.1 '
  echo admin | sudo -S -p "" pmset -a hibernatemode 0
  echo admin | sudo -S -p "" rm -f /var/vm/sleepimage
  echo admin | sudo -S -p "" rm -rf /Library/Caches/* ~/Library/Caches/*
  echo admin | sudo -S -p "" sh -c "find /var/log -name *.gz -delete; rm -rf /private/var/log/asl/*.asl"
'
```

### Bless verification (step 7)

```bash
sshpass -p admin ssh -p 2222 ... admin@127.0.0.1 \
  'echo admin | sudo -S -p "" bless --mount / --setBoot --verbose'
```

Key output (confirming a UUID-addressed preboot volume and correct topology):

```
Setting EFI NVRAM:
    efi-boot-device='<array>...UUID</key><string>98FA02AF-D0A8-4E55-8B63-F9FC985A4251</string>...
    \System\Library\CoreServices\boot.efi</string></dict></array>'
```

After shutdown (`shutdown -h now`; rc=255 is the normal SSH disconnect, not
an error), you must **wait for the QEMU process to exit on its own** on the
host (verify with `pgrep`/`ps`, not `pgrep` matching your own just-run shell
command), or the VARS file may not be fully flushed.

### NVRAM verification (step 8)

```bash
virt-fw-vars -i /home/fish/bucket/kvm/macos-new/install-OVMF_VARS.fd -p \
  | grep -iE 'Boot00|efi-boot-device'
```

Expect `Boot0080`, with devpath reading
`PciRoot()/PCI(dev=1f:2)/SATA(port=2)/...` — exactly what was measured this
run (`port=2` corresponds to the install disk on `ide.2`, matching the
topology future libvirt domains use, see "Technical background: PCI topology
and bless"):

```
Boot0080 : boot entry: title="" devpath=PciRoot()/PCI(dev=1f:2)/SATA(port=2)/Partition(nr=2)/Media(subtype=0x3)/FilePath(\...\boot.efi)
efi-boot-device      : blob: 444 bytes
efi-boot-device-data : blob: 264 bytes
```

### Producing the base image (step 9)

```bash
sudo qemu-img convert -f qcow2 -O qcow2 \
  /home/fish/bucket/kvm/macos-new/macos-sonoma-new.qcow2 \
  /home/fish/bucket/kvm/macos/macos-sonoma-base.img
sudo chown libvirt-qemu:libvirt-qemu /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# Measured duration: 4 min 24 s
```

Final artifact verification:

```bash
qemu-img info /home/fish/bucket/kvm/macos/macos-sonoma-base.img
# file format: qcow2
# virtual size: 64 GiB
# disk size: 29.1 GiB      (no backing file line, self-contained)
```

> Re-confirmed: shrinking the virtual disk from 128G to 64G kept the **actual
> footprint at 29.1G** (vs 28.9G measured for the earlier 128G virtual disk —
> essentially identical). This backs the conclusion stated at the top of this
> document: the base image cannot be shrunk by adjusting virtual disk size;
> 29G is the inherent floor for macOS APFS-on-AHCI without TRIM support (see
> the "Size optimization" and "Technical background" sections).

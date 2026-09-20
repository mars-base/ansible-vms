# macOS VMs (Hackintosh)

This project can create and manage macOS guests alongside Linux and Windows VMs.
macOS is not a normal KVM guest — Apple's `boot.efi` shows its own disk picker
(the **Startup Manager**) whenever the blessed EFI boot variable doesn't match
the current PCI topology, and `boot.efi` is picky in ways Linux/Windows firmware
isn't. This page documents the assets, the creation flow, and the two non-obvious
constraints that make cold boot work **with zero keyboard input**.

## How it differs from Linux/Windows

| Aspect | Linux/Windows | macOS |
|--------|---------------|-------|
| Video | qxl/virtio/spice | `vmware-svga` via `qemu:commandline` (no native libvirt model) |
| SMC | — | `isa-applesmc,osk=...` required, via `qemu:commandline` |
| Boot disk | system disk directly | OpenCore overlay (boot order 1) → macOS disk (order 2) |
| Firmware | distro OVMF or SeaBIOS | **distro persistent OVMF** + a **pre-blessed** NVRAM template |
| Network | libvirt `<interface>` | libvirt `<interface type='bridge'>`, virtio NIC **pinned to root-bus slot 0x05** (see Constraint 3) |
| Static IP | cloud-init at create time | no cloud-init — set once inside the guest (there is **no DHCP on br0**) |
| Keyboard via libvirt | works | **broken** (see below) — must boot without any input |

## Assets

Shared, read-only templates live in `macos_asset_dir` (default
`/home/fish/bucket/kvm/macos/`):

- `macos-sonoma-base.img` — self-contained macOS Sonoma 14.8.9 install, account
  `admin`/`admin`, Remote Login enabled. Each VM is a qcow2 **overlay** of it.
- `OpenCore.qcow2` — patched OpenCore (SIP disabled via `csr-active-config`,
  `Misc>Boot` tuned so it auto-boots). Each VM gets its own **overlay** so the
  base is never written.
- `OVMF_VARS-blessed.fd` — a persistent OVMF variable store containing a real,
  correct `efi-boot-device`/`efi-boot-device-data`/`Boot0080`. This is the
  template every new macOS VM's NVRAM is seeded from, and it is what makes
  keyboard-free cold boot possible. See "Re-baking" below.

The EFI **code** is the host's own `/usr/share/OVMF/OVMF_CODE_4M.fd` (see
"Constraint 1").

## Creating a macOS VM

1. Add a row to `vms.csv` with `type=macos`. `disk_gb` **must** equal the base
   image's virtual size (128). `bridge`/`ip`/`netmask`/`gateway`/`dns` are the
   static network the guest should end up on. The VNC port is derived from the
   IP's last octet (`5900 + last_octet`).

   ```csv
   macos-sonoma-01,local,macos,8192,4,macos-sonoma,128,0,/home/fish/bucket/kvm/macos/macos-sonoma-base.img,br0,52:54:00:ff:00:01,efi,false,/home/fish/bucket/kvm,10.241.20.80,22,10.241.20.1,"10.246.80.210,10.246.180.210",
   ```

2. Run the create playbook:

   ```bash
   ap playbooks/create-vm.yaml -e vm_name=macos-sonoma-01
   ```

   This builds the two overlays (system disk + OpenCore), copies
   `OVMF_VARS-blessed.fd` to the per-VM NVRAM path, and defines/starts the
   domain from `domain-macos.xml.j2` — a native `<interface type='bridge'>` on
   `vm.bridge` with the virtio NIC pinned to root-bus slot `0x05`.

3. Cold boot needs **no input**. Within ~40s the VM reaches the macOS login
   window.

4. **Network is DHCP by default**. The VM will get an address from the upstream
   DHCP server on `br0`. Find it with `sudo virsh domifaddr <name>` or check
   your router's DHCP lease table. If you need a static IP, SSH in and run:

   ```bash
   networksetup -setmanual "Ethernet" 10.241.20.80 255.255.252.0 10.241.20.1
   networksetup -setdnsservers "Ethernet" 10.246.80.210 10.246.180.210
   ```

   ```bash
   networksetup -setmanual "Ethernet" 10.241.20.80 255.255.252.0 10.241.20.1
   networksetup -setdnsservers "Ethernet" 10.246.80.210 10.246.180.210
   ```

   This static config is written into the overlay and persists across reboots,
   so a freshly-defined VM that reuses this base overlay boots already online.
   From here `ssh admin@10.241.20.80` and `ansible <name> -m ping` (via `raw`;
   the macOS guest has no Python interpreter for the fact-gathering modules).

## Template constraints

Three details in `domain-macos.xml.j2` must match the validated hand-built
config; each violation looks like a different, unrelated bug:

- Boot stops at Apple's Startup Manager (disk picker) → Constraint 1 or 2
- `ifconfig -a` shows no NIC, Network says "Not connected" → Constraint 3

### Constraint 1 — persistent OVMF, not OSX-KVM's bundled CODE

OSX-KVM's bundled `OVMF_CODE_4M.fd` is a **RAM-backed / EmuVariable** build: it
never reads or writes the on-disk VARS file. Any blessed variable you seed is
invisible to it, so the picker always appears. Use the host's own distro pair:

- code: `/usr/share/OVMF/OVMF_CODE_4M.fd`
- vars template: a **persistent** 540672-byte store (`OVMF_VARS-blessed.fd`),
  not OSX-KVM's 131072-byte nonpersistent one.

### Constraint 2 — the blessed device-path's SATA PCI address must match the domain

`efi-boot-device-data` encodes a full EFI device path including the SATA
controller's PCI slot. Apple `boot.efi` only auto-boots when that path resolves
in the current topology.

**`q35` already instantiates one ICH9 AHCI controller at PCI `1f:2`** — that is
the slot libvirt's `<controller type='sata'>` also uses. OSX-KVM's tutorial
scripts add a *second* `-device ich9-ahci,id=sata`, which lands at `02:0`. A
bless done on the `02:0` controller produces a device path that does **not**
match a libvirt domain's `1f:2`, so the picker still shows. The fix is to bless
while the disk sits on q35's built-in controller.

> Historical note: this mismatch, not the (real but separate) libvirt keyboard
> bug, was what blocked macOS integration for a while. Once the blessed NVRAM
> matches `1f:2`, cold boot is fully keyboard-free in both bare qemu and libvirt.

### Constraint 3 — the virtio NIC must be pinned to root-bus slot `0x05`

macOS's virtio-net kext (loaded via OpenCore's `VirtualX.SMCRuntime`/`VirtioNet`
bundle) only binds to a NIC at a **fixed root-bus position**. If libvirt is
allowed to auto-place the NIC on a `pcie-root-port` child (`bus 0x01 slot 0x00`
or similar), the guest never sees it — `ifconfig -a` shows no `enX`, and System
Settings reports "Not connected" even after `networksetup -setmanual` writes the
correct config (the config sits on a service whose hardware is gone).

`domain-macos.xml.j2` pins the interface explicitly:

```xml
<interface type='bridge'>
  <mac address='{{ vm.mac }}'/>
  <source bridge='{{ vm.bridge }}'/>
  <model type='virtio'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
</interface>
```

Slot `0x05` is the same one the earlier user-net `qemu:arg virtio-net-pci,...,addr=0x05`
used successfully. Do not remove the `<address>` — libvirt will happily reassign
it to a root-port child, and macOS will not enumerate the device.

### libvirt keyboard injection is dead for this guest

Independently of the above, `virsh send-key` / QMP `input-send-event` reach
nothing on the macOS guest across every USB controller tried (`qemu-xhci`
default, `qemu-xhci` pinned to bus0, `ich9-ehci1`+`ich9-uhci1`) — screenshots
are pixel-identical before and after (AE=0). Identical device setups work in
bare qemu, so this is a libvirt-side defect, not a macOS driver gap. (One input
bus not yet individually tested: the `<input bus='ps2'>` device libvirt auto-adds.)
This is exactly why the flow is designed to need zero input: pre-bless the NVRAM
so nothing must be typed at boot.

## Re-baking OVMF_VARS-blessed.fd

Only needed if the base image is rebuilt or its partition layout changes. Do it
in **bare qemu** (where the keyboard works), on a machine whose SATA is q35's
built-in `1f:2` controller. `/home/fish/bucket/OSX-KVM/boot-macos-ctrl4.sh` is a
reference launcher: note it does **not** add a second `ich9-ahci` — the disks use
`-device ide-hd,bus=ide.0/ide.1`.

1. Boot with a throwaway VARS copy; at the picker use the keyboard (works here)
   to select Macintosh HD; reach the desktop.
2. SIP is already off via OpenCore `csr-active-config` (`NVRAM Protections:
   disabled`). Confirm with `csrutil status`.
3. Bless and shut down cleanly so OVMF flushes to the VARS file:

   ```bash
   sudo bless --mount / --setBoot --verbose   # rc=0, writes efi-boot-device
   sudo shutdown -h now
   ```

4. Verify the file, then promote it as the shared template:

   ```bash
   virt-fw-vars -i <per-vm>.fd -p | grep -E 'efi-boot-device|Boot0080'
   # Boot0080 devpath must read ... PCI(dev=1f:2)/SATA(port=1)/...
   cp <per-vm>.fd /home/fish/bucket/kvm/macos/OVMF_VARS-blessed.fd
   ```

The OpenCore `config.plist` must **not** delete `efi-boot-device`/
`efi-boot-device-data` in its `NVRAM>Delete` list — only `boot-args` and
`ForceDisplayRotationInEFI` belong there; wiping the blessed vars defeats
persistence.

## Lifecycle gotcha: undefine an EFI macOS domain

libvirt 11.x refuses to `virsh undefine` an EFI domain without `--nvram`, and
passing `--nvram` **deletes** the variable store. Because macOS NVRAM is a
pre-blessed template (not a libvirt-managed auto-created var), the correct
manual cycle is:

```bash
virsh destroy <name>
virsh undefine --nvram <name>
cp /home/fish/bucket/kvm/macos/OVMF_VARS-blessed.fd <storage>/<name>/<name>-OVMF_VARS.fd
virsh define <xml>
virsh start <name>
```

The `create-vm` playbook already re-seeds VARS on each create, so normal
playbook use is fine; only hand-editing an XML and re-defining needs this order.

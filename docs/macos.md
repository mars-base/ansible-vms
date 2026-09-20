# macOS VMs (Hackintosh)

macOS guests run alongside Linux/Windows VMs. See
[macos-base-image.md](macos-base-image.md) (Chinese) for how the base image
was built from scratch with [kholia/OSX-KVM](https://github.com/kholia/OSX-KVM).

## How macOS differs from Linux/Windows

| Aspect | Linux/Windows | macOS |
|--------|---------------|-------|
| Video | qxl/virtio/spice | `vmware-svga` via `qemu:commandline` |
| SMC | — | `isa-applesmc,osk=...` via `qemu:commandline` |
| Boot | system disk directly | OpenCore overlay (order 1) → macOS disk (order 2) |
| Firmware | distro OVMF or SeaBIOS | persistent OVMF + a **pre-blessed** NVRAM template |
| Network | libvirt `<interface>` | bridge, virtio NIC pinned to root-bus `slot=0x05` |
| IP config | cloud-init | no cloud-init — DHCP by default |
| Shutdown | `virsh shutdown` (ACPI) | macOS ignores ACPI — shut down from the desktop or via SSH |

## Assets

Shared read-only templates live in `macos_asset_dir` (default
`/home/fish/bucket/kvm/macos/`):

| File | Purpose |
|------|---------|
| `macos-sonoma-base.img` | Sonoma 14.8.9 base image, admin/admin, Remote Login enabled |
| `OpenCore.qcow2` | OpenCore boot disk (SIP disabled, auto-boot) |
| `OVMF_VARS-blessed.fd` | Pre-blessed NVRAM template — what makes keyboard-free cold boot possible |

### Copying assets to another host

The three files are self-contained — copy them into the new host's
`macos_asset_dir` and macOS VMs can be created there. The blessed Preboot
volume UUID, APFS layout and boot.efi path all travel with the files.

The new host additionally needs:

1. **`apt install ovmf`** — the template also references the host's
   `/usr/share/OVMF/OVMF_CODE_4M.fd` (the persistent distro build). Do **not**
   use OSX-KVM's bundled non-persistent copy, or the bless is invisible and
   cold boot stops at Apple's disk picker (see Constraint 1 below)
2. **Matching topology** — q35 + built-in SATA at `1f:2` + system disk on
   port 2 are hardcoded in `domain-macos.xml.j2`, so using the same
   ansible-vms role satisfies this automatically
3. QEMU >= 8.2.2 and a similar libvirt version (for `qemu:commandline`)

No need to copy: `BaseSystem.img`, `fetch-macOS-v2.py`,
`boot-macos-install.sh` — only used when re-creating the base image.

## Configure (vms.csv)

Add a row with `type=macos`. `disk_gb` **must** equal the base image's virtual
size (64). macOS uses DHCP, so **leave ip/netmask/gateway/dns empty** (set
them only if you want a static IP via `configure-macos.yaml`). The VNC port is
auto-assigned by libvirt (`list-vms` shows the actual port).

```csv
macos-sonoma-01,local,macos,8192,4,macos-sonoma,64,0,/home/fish/bucket/kvm/macos/macos-sonoma-base.img,br0,52:54:00:ff:00:01,efi,false,/home/fish/bucket/kvm/macos,,,,,
```

## Create

```bash
ap playbooks/create-vm.yaml -e vm_name=macos-sonoma-01
```

Builds the two overlays (system disk + OpenCore), seeds the per-VM NVRAM from
the blessed template, and defines/starts the domain. Cold boot needs zero
keyboard input; the login window appears in ~40s.

**Network**: DHCP by default (upstream router on `br0`). Look up the IP with:

```bash
ap playbooks/list-vms.yaml
```

The IP column lists every VM's address (e.g. `192.168.100.45` for macOS),
and the VNC column shows `127.0.0.1:<port>`.

> Ansible against macOS guests must use `-m raw` — the guest has no Python
> interpreter.

## Start

```bash
ap playbooks/start-vm.yaml -e vm_name=macos-sonoma-01
```

## Stop

```bash
ap playbooks/stop-vm.yaml -e vm_name=macos-sonoma-01
```

macOS ignores ACPI shutdown, so the playbook only prints a notice:

- from the desktop: Apple menu → Shut Down
- or via SSH: `ssh admin@<ip> 'sudo shutdown -h now'`

> `virsh shutdown` is a no-op on macOS guests — do not use it.

## Destroy

```bash
ap playbooks/destroy-vm.yaml -e vm_name=macos-sonoma-01 -e confirm=true
```

Stop the VM first (see above). The shared base image and assets are never
touched.

## Template constraints (domain-macos.xml.j2)

Three details must match the validated hand-built config; each violation
looks like a different, unrelated bug:

1. **Persistent OVMF**: the host's `/usr/share/OVMF/OVMF_CODE_4M.fd`, not
   OSX-KVM's non-persistent bundled build
2. **Bless topology match**: disks sit on q35's built-in AHCI (PCI `1f:2`);
   never add a second `ich9-ahci` device
3. **NIC pinned to root-bus `slot=0x05`**: macOS's virtio-net driver only
   binds at a fixed root-bus position — if libvirt auto-places the NIC on a
   `pcie-root-port` child, the guest never sees it

Full rationale and the bless procedure:
[macos-base-image.md](macos-base-image.md).

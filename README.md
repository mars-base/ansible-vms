# ansible-vms

Ansible project for managing KVM virtual machines. VMs are defined in `vms.csv` and provisioned via libvirt domain XML templates.

## Requirements

- **Host OS**: Debian 12 (Bookworm)
- **Packages**: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `ovmf`, `swtpm`

## Quick Start

```bash
# 1. Setup
cp ansible.cfg.example ansible.cfg  # edit with your host name
cp hosts.ini.example hosts.ini  # edit with your host name
cp vms.csv.example vms.csv    # edit with your VM definitions
uv sync  # install ansible dependencies

# 2. Create VMs defined in vms.csv
uv run ansible-playbook playbooks/create-vm.yaml
```

## Documentation

### Getting Started
- [Getting Started](site/content/docs/getting-started/_index.md) - Installation, structure, and first steps
- [VM Definition](site/content/docs/vm-definition/_index.md) - Configure VMs in vms.csv

### VM Management
- [VM Lifecycle](site/content/docs/vm-lifecycle/_index.md) - Start, stop, restart, destroy VMs
- [Snapshots](site/content/docs/snapshots/_index.md) - Create and restore VM snapshots
- [User Accounts](site/content/docs/setup-user/_index.md) - Setup Linux user accounts
- [macOS VMs](site/content/docs/macos/_index.md) - Hackintosh guests, blessed NVRAM, keyboard-free boot (network via DHCP)
- [macOS Base Image](site/content/docs/macos-base-image/_index.md) - How the macOS Sonoma base image was built

### Storage
- [Data Disks](site/content/docs/data-disks/_index.md) - Attach, resize, and mount data disks; add/list/delete extra hot-plugged disks

### Access
- [VM Console](site/content/docs/vm-console/_index.md) - Access VM console (VNC/SPICE)
- [Remote Desktop](site/content/docs/remote-desktop/_index.md) - RDP access for Windows VMs

### Configuration
- [Network](site/content/docs/network/_index.md) - Network architecture and bridge configuration
- [Firewall](site/content/docs/firewall/_index.md) - nftables host firewall for VMs (playbooks/nftables.yaml)
- [Base Images](site/content/docs/base-images/_index.md) - Download Linux and Windows base images

Browse the docs as a website with `./scripts/serve-docs.sh start` → http://localhost:1313 (English) / http://localhost:1313/zh/ (中文).

## Custom Storage Path

By default, VM files are stored in `/var/lib/libvirt/images`. You can customize the storage path per-VM using the `storage_dir` field in `vms.csv`:

```csv
name,host,type,...,storage_dir
my-linux-vm,local,linux,...,/data/vms
```

When `storage_dir` is specified:
- A VM-specific subdirectory is automatically created: `<storage_dir>/<vm-name>/`
- VM files (qcow2, seed ISO, OVMF VARS) are stored in the isolated subdirectory
- The destroy playbook removes the entire VM subdirectory

When `storage_dir` is empty, VMs use the default path `/var/lib/libvirt/images/<vm-name>/`.

### Storage Directory Permissions

QEMU processes run as the `libvirt-qemu` user, so that user must be able to
**traverse every path component** and **read/write the disk files**. A custom
`storage_dir` commonly breaks this in two ways:

- **Untraversable path**: e.g. anything under `/home/<user>/` fails because
  home directories are `drwx------`. Error signature:
  `Cannot access storage file ... (as uid:64055): Permission denied`.
  Fix by mounting VM storage under a world-traversable path (e.g. `/mnt/wdisk`).
- **Wrong file ownership**: files created by root (via the playbooks) are not
  writable by `libvirt-qemu`. Fix once per storage root with a default ACL so
  all future VM subdirectories inherit access:

```bash
sudo chown -R libvirt-qemu:libvirt-qemu /mnt/wdisk/kvm   # one-off
# or better — applies to files/dirs the playbooks create later too:
sudo setfacl -d -m u:libvirt-qemu:rwX /mnt/wdisk/kvm
```

The base `qcow2` images only need to be readable (they are backing files).

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

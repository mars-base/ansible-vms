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
ap playbooks/create-vm.yaml
```

## Documentation

### Getting Started
- [Getting Started](docs/getting-started.md) - Installation, structure, and first steps
- [VM Definition](docs/vm-definition.md) - Configure VMs in vms.csv

### VM Management
- [VM Lifecycle](docs/vm-lifecycle.md) - Start, stop, restart, destroy VMs
- [Snapshots](docs/snapshots.md) - Create and restore VM snapshots
- [User Accounts](docs/setup-user.md) - Setup Linux user accounts

### Storage
- [Data Disks](docs/data-disks.md) - Attach, resize, and mount data disks

### Access
- [VM Console](docs/vm-console.md) - Access VM console (VNC/SPICE)
- [Remote Desktop](docs/remote-desktop.md) - RDP access for Windows VMs

### Configuration
- [Network](docs/network.md) - Network architecture and bridge configuration
- [Base Images](docs/base-images.md) - Download Linux and Windows base images

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

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

# ansible-vms

Ansible project for managing KVM virtual machines. VMs are defined in `vms.csv` and provisioned via libvirt domain XML templates.

## Requirements

- **Host OS**: Debian 12 (Bookworm)
- **Packages**: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `ovmf`, `swtpm`

## Structure

```
ansible-vms/
├── ansible.cfg.example          # Ansible config template
├── hosts.ini.example            # Inventory template
├── vms.csv                      # VM definitions (CSV-driven)
├── pyproject.toml               # Python dependencies (uv)
├── requirements.txt             # pip dependencies
├── group_vars/
│   ├── all/                     # Global variables
│   └── kvm_hosts/               # KVM host variables
├── host_vars/                   # Per-host variables
├── playbooks/
│   └── create-vm.yaml           # Create VMs from vms.csv
├── roles/
│   └── create_vm/               # VM creation role (libvirt XML)
├── roles_init/                  # Host initialization roles
├── scripts/                     # Helper scripts
└── var/                         # Runtime data (logs, facts cache)
```

## Quick Start

```bash
# 1. Setup
cp ansible.cfg.example ansible.cfg
cp hosts.ini.example hosts.ini
cp vms.csv.example vms.csv    # edit with your VM definitions
uv sync

# 2. Create VMs defined in vms.csv
ap playbooks/create-vm.yaml
```

## Playbooks

All playbooks are idempotent (safe to run multiple times).

### Install Dependencies

```bash
# Install required packages on KVM host
ap playbooks/install-dependencies.yaml
```

Installs: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `ovmf`, `swtpm`, `genisoimage`, etc.

### Create VMs

```bash
# Create all VMs defined in vms.csv
ap playbooks/create-vm.yaml

# Create VMs on specific host
ap playbooks/create-vm.yaml --limit local
```

Creates qcow2 overlay, generates domain XML, defines VM in libvirt, starts if `autostart=true`.

### List VMs

```bash
# List all VMs with status and IP
ap playbooks/list-vms.yaml
```

Output example:
```
win11-aifs           10.241.21.65    windows  4 vCPU 8192 MB    win11  shut off
debian12-01          10.241.23.118   linux    2 vCPU 2048 MB    debian12 running
```

### Start VM

```bash
# Start specific VM
ap playbooks/start-vm.yaml -e vm_name=debian12-01
```

### Stop VM

```bash
# Graceful shutdown
ap playbooks/stop-vm.yaml -e vm_name=win11-aifs
```

### Restart VM

```bash
# Stop then start VM
ap playbooks/restart-vm.yaml -e vm_name=debian12-01
```

### Destroy VM

```bash
# Permanently delete VM (requires confirmation)
ap playbooks/destroy-vm.yaml -e vm_name=win11-aifs -e confirm=true
```

Deletes: domain definition, disk images (qcow2), OVMF VARS, cloud-init ISO, TPM state.

**Warning**: This is destructive and irreversible. The `--confirm` flag is required.

## VM Definition (vms.csv)

| Field | Description | Example |
|-------|-------------|---------|
| `name` | VM name | `win11-aifs` |
| `host` | KVM host (inventory name) | `local` |
| `type` | OS type: `windows` / `linux` | `windows` |
| `memory_mb` | Memory in MB | `8192` |
| `vcpus` | CPU cores | `4` |
| `os` | OS variant | `win11` |
| `disk_gb` | System disk size | `80` |
| `data_disk_gb` | Data disk size | `10` |
| `base_image` | Base qcow2 image path | `/path/to/base.qcow2` |
| `bridge` | Network bridge | `br0` |
| `mac` | MAC address | `52:54:00:cc:68:2c` |
| `firmware` | `efi` or `bios` | `efi` |
| `autostart` | Auto-start on boot | `true` |

## Network Architecture

VMs connect to the local network via a **bridge** (default `br0`), receiving IP addresses from the LAN's DHCP server — same subnet as the host.

```
LAN (10.241.20.0/22, DHCP, gateway 10.241.20.1)
├── KVM Host (10.241.21.97, br0)
└── VM (10.241.21.x, DHCP via br0, virtio NIC)
```

Each VM is assigned a **pinned MAC address** in `vms.csv`, so its DHCP lease is stable. To look up a VM's IP:

```bash
ip neigh show dev br0 | grep -i <MAC>
```

Or use the `list-vms` playbook which does this automatically.

## Windows Base Image

The Windows qcow2 base image is built with [packer-windows-kubevirt](https://github.com/mars-base/packer-windows-kubevirt). It uses Packer + QEMU to produce a sysprep-generalized Windows image with:

- **virtio drivers** pre-installed (vioscsi, viostor, netkvm, vioserial, viorng, balloon, viofs)
- **QEMU Guest Agent** + **Cloudbase-Init**
- **WinRM HTTPS** (port 5986) + **RDP** (port 3389) enabled
- EFI boot with secure boot keys

Build your own custom image:

```bash
git clone https://github.com/mars-base/packer-windows-kubevirt
cd packer-windows-kubevirt
packer build <template>
```

Then set the output path in `vms.csv` `base_image` field.

## Windows VM Features

When `type=windows`, the domain XML template includes:

- **Hyper-V enlightenments** (relaxed, vapic, spinlocks, synic, stimer, etc.) for nested WSL2
- **VMX passthrough** for nested virtualization (WSL2/Hyper-V inside guest)
- **EFI + vTPM 2.0** (OVMF secure boot + emulated TPM)
- **virtio-scsi** disk bus + **virtio** NIC
- **Localtime** clock with hypervclock

## Idempotent

`create-vm` checks if the VM already exists before creating. Re-running the playbook produces no changes.

```bash
# First run: creates overlay, copies OVMF VARS, defines and starts VM
ap playbooks/create-vm.yaml

# Second run: detects existing VM, skips all steps
# ok=5  changed=0  skipped=7
```

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.

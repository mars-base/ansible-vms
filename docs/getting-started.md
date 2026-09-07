# Getting Started

## Requirements

- **Host OS**: Debian 12 (Bookworm)
- **Packages**: `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, `ovmf`, `swtpm`

## Installation

```bash
# Clone the repository
git clone https://github.com/mars-base/ansible-vms.git
cd ansible-vms

# Install Python dependencies
uv sync  # or: pip install -r requirements.txt

# Setup configuration files
cp ansible.cfg.example ansible.cfg  # edit with your host name
cp hosts.ini.example hosts.ini      # edit with your host name
cp vms.csv.example vms.csv          # edit with your VM definitions
```

## Quick Start

```bash
# Install required packages on KVM host
ap playbooks/install-dependencies.yaml

# Create VMs defined in vms.csv
ap playbooks/create-vm.yaml
```

## Project Structure

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
│   ├── create-vm.yaml           # Create VMs from vms.csv
│   ├── destroy-vm.yaml          # Destroy VMs
│   ├── list-vms.yaml            # List VMs
│   ├── snapshot-vm.yaml         # Manage VM snapshots
│   ├── setup-user.yaml          # Setup user accounts on Linux VMs
│   ├── start-vm.yaml            # Start VMs
│   ├── stop-vm.yaml             # Stop VMs
│   └── restart-vm.yaml          # Restart VMs
├── roles/
│   └── create_vm/               # VM creation role (libvirt XML)
├── scripts/                     # Helper scripts
├── tools/                       # Utility scripts (vm-console, vm-login)
└── var/                         # Runtime data (logs, facts cache)
```

## Next Steps

- [VM Definition](vm-definition.md) - Configure VMs in vms.csv
- [VM Lifecycle](vm-lifecycle.md) - Start, stop, restart, destroy VMs
- [Snapshots](snapshots.md) - Create and restore VM snapshots
- [User Accounts](setup-user.md) - Setup Linux user accounts
- [Data Disks](data-disks.md) - Attach, resize, and mount data disks
- [VM Console](vm-console.md) - Access VM console
- [Remote Desktop](remote-desktop.md) - RDP access for Windows VMs
- [Network](network.md) - Network architecture and bridge configuration
- [Base Images](base-images.md) - Download Linux and Windows base images

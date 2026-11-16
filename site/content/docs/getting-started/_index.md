---
title: Getting Started
description: Install dependencies and create your first KVM virtual machine.
weight: 10
icon: fa-solid fa-rocket
menus:
  main:
    identifier: docs-getting-started
    parent: docs
    weight: 10
    params:
      icon: fa-solid fa-rocket
cascade:
  type: docs
  footer_style: slim
---

## Requirements

- **Host OS**: Debian 12+ / Ubuntu, or Fedora / Rocky Linux (recent releases)
- **Packages**: installed by `playbooks/install-dependencies.yaml` (`qemu-kvm`, `libvirt`, `ovmf`/`edk2-ovmf`, `swtpm`)

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
uv run ansible-playbook playbooks/install-dependencies.yaml

# Create VMs defined in vms.csv
uv run ansible-playbook playbooks/create-vm.yaml
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

- [VM Definition](/docs/vm-definition/) - Configure VMs in vms.csv
- [VM Lifecycle](/docs/vm-lifecycle/) - Start, stop, restart, destroy VMs
- [Snapshots](/docs/snapshots/) - Create and restore VM snapshots
- [User Accounts](/docs/setup-user/) - Setup Linux user accounts
- [Data Disks](/docs/data-disks/) - Attach, resize, and mount data disks
- [VM Console](/docs/vm-console/) - Access VM console
- [Remote Desktop](/docs/remote-desktop/) - RDP access for Windows VMs
- [Network](/docs/network/) - Network architecture and bridge configuration
- [Base Images](/docs/base-images/) - Download Linux and Windows base images

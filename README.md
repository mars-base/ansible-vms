# ansible-vms

Ansible project for managing KVM virtual machines. VMs are defined in `vms.csv` and provisioned via libvirt domain XML templates.

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

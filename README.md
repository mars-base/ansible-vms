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
win11-dev            192.168.1.101   windows  4 vCPU 8192 MB    win11  shut off
win10-dev            192.168.1.102   windows  4 vCPU 8192 MB    win10  running
debian12-dev         192.168.1.103   linux    2 vCPU 2048 MB    debian12 running
```

### Start VM

```bash
# Start specific VM
ap playbooks/start-vm.yaml -e vm_name=debian12-dev
```

### Stop VM

```bash
# Graceful shutdown
ap playbooks/stop-vm.yaml -e vm_name=win11-dev
```

### Restart VM

```bash
# Stop then start VM
ap playbooks/restart-vm.yaml -e vm_name=debian12-dev
```

### Destroy VM

```bash
# Permanently delete VM (requires confirmation)
ap playbooks/destroy-vm.yaml -e vm_name=win11-dev -e confirm=true
```

Deletes: domain definition, disk images (qcow2), OVMF VARS, cloud-init ISO, TPM state.

**Warning**: This is destructive and irreversible. The `--confirm` flag is required.

## VM Definition (vms.csv)

| Field | Description | Example |
|-------|-------------|---------|
| `name` | VM name | `win11-dev` |
| `host` | KVM host (inventory name) | `local` |
| `type` | OS type: `windows` / `linux` | `windows` |
| `memory_mb` | Memory in MB | `8192` |
| `vcpus` | CPU cores | `4` |
| `os` | OS variant | `win11` |
| `disk_gb` | System disk size | `80` |
| `data_disk_gb` | Data disk size (0 for none) | `10` |
| `base_image` | Base qcow2 image path | `/path/to/base.qcow2` |
| `bridge` | Network bridge | `br0` |
| `mac` | MAC address | `52:54:00:xx:xx:xx` |
| `firmware` | `efi` or empty (BIOS) | `efi` |
| `autostart` | Auto-start on boot | `true` |
| `storage_dir` | VM storage path (optional, default: `/var/lib/libvirt/images`) | `/data/vms` |

## Network Architecture

VMs connect to the local network via a **bridge** (default `br0`), receiving IP addresses from the LAN's DHCP server — same subnet as the host.

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.x, DHCP via br0, virtio NIC)
```

Each VM is assigned a **pinned MAC address** in `vms.csv`, so its DHCP lease is stable. To look up a VM's IP:

```bash
ip neigh show dev br0 | grep -i <MAC>
```

Or use the `list-vms` playbook which does this automatically.

### Bridge Configuration

The KVM host requires a network bridge (`br0`) so VMs can access the LAN directly. Example `/etc/network/interfaces`:

```bash
# Physical NIC — manual mode, no IP (managed by bridge)
auto eth0
iface eth0 inet manual
    pre-up ip link set $IFACE up
    post-down ip link set $IFACE down

# Bridge br0 — static IP, bridges eth0
auto br0
iface br0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
    bridge_ports eth0
    bridge_stp off
    bridge_fd 0
    bridge_maxwait 0
```

Replace `eth0` with your actual NIC name (check with `ip link`). After editing:

```bash
sudo systemctl restart networking
```

Verify the bridge is up:

```bash
ip addr show br0
bridge link show
```


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

**Example:**
```bash
# VM with custom storage path (isolated in subdirectory)
ls /data/vms/my-linux-vm/
# Output: my-linux-vm.qcow2  my-linux-vm-data.qcow2  my-linux-vm-seed.iso

# VM with default storage path (also isolated)
ls /var/lib/libvirt/images/other-vm/
# Output: other-vm.qcow2  other-vm-seed.iso
```

This is useful when you want to:
- Store VMs on faster storage (SSD/NVMe)
- Use separate storage pools for different environments
- Isolate VM files for better organization and management
- Integrate with ZFS/LVM storage management

## Data Disk

Set `data_disk_gb` in `vms.csv` to attach an additional qcow2 disk to the VM:

```csv
my-linux-vm,local,linux,...,data_disk_gb=50,...
```

When `data_disk_gb > 0`:
- A thin-provisioned qcow2 data disk is created (`<name>-data.qcow2`)
- The disk is attached to the VM as a second virtio block device (`vdb` / `sdb`)
- Stored in the same `storage_dir` as the system disk

The data disk is **not** formatted or mounted automatically — you manage filesystem and mount inside the VM:

```bash
# Inside VM
mkfs.ext4 /dev/vdb
mkdir -p /data
mount /dev/vdb /data
```

Set `data_disk_gb=0` (or leave empty) for VMs without a data disk.

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

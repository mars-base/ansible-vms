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
│   ├── create-vm.yaml           # Create VMs from vms.csv
│   ├── destroy-vm.yaml          # Destroy VMs
│   ├── list-vms.yaml            # List VMs
│   ├── snapshot-vm.yaml         # Manage VM snapshots
│   ├── start-vm.yaml            # Start VMs
│   ├── stop-vm.yaml             # Stop VMs
│   └── restart-vm.yaml          # Restart VMs
├── roles/
│   └── create_vm/               # VM creation role (libvirt XML)
├── scripts/                     # Helper scripts
└── var/                         # Runtime data (logs, facts cache)
```

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

### Manage Snapshots

Create, list, revert, and delete VM snapshots using libvirt's built-in snapshot support.

```bash
# Create snapshot (default: shutdown VM first for disk consistency, then restore previous state)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create

# Create snapshot without shutdown (live snapshot, VM continues running)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e halt=false

# Create snapshot with custom name and description
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e snapshot_name=before-upgrade -e snapshot_desc="升级前快照"

# List all snapshots
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=list

# Revert to snapshot (requires confirmation, restores VM state at snapshot time)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=revert -e snapshot_name=before-upgrade -e confirm=true

# Delete snapshot
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=delete -e snapshot_name=before-upgrade
```

**Parameters:**
- `vm_name`: VM name (required)
- `snap_action`: `create` / `list` / `revert` / `delete` (required)
- `snapshot_name`: snapshot name (auto-generated for create; required for revert/delete)
- `snapshot_desc`: description (optional, create only)
- `halt`: shutdown VM before snapshot for disk consistency, then restore to previous state (optional, create only, default: `true`)
- `confirm`: safety flag (required for revert)

**Behavior:**
- `halt=true` (default): If VM is running → shutdown → snapshot → start (restore running state). If VM is off → snapshot → remain off (preserve off state).
- `halt=false`: Create snapshot while VM is running (live snapshot). Faster but may have incomplete disk writes.
- Revert restores the VM to the exact state at snapshot time (running or off depending on snapshot state).

### Attach Data Disk

```bash
# Attach data disk to a running VM (hot-plug, no reboot needed)
ap playbooks/attach-data-disk.yaml -e vm_name=debian12-dev
```

Reads `data_disk_gb` from `vms.csv`. The VM must have `data_disk_gb > 0` defined in CSV. Hot-plugs the disk to the running VM using `virsh attach-disk --config --live` (persistent + immediate effect).

Inside the VM, format and mount the new disk:

```bash
mkfs.ext4 /dev/vdb
mkdir -p /data
mount /dev/vdb /data
```

### Resize Data Disk

```bash
# Resize data disk (reads target size from vms.csv)
ap playbooks/resize-data-disk.yaml -e vm_name=debian12-dev
```

Reads target `data_disk_gb` from `vms.csv`. The playbook will:
1. Check if target size is larger than current (shrinking not supported)
2. If VM is running → graceful shutdown and wait for stop
3. Resize qcow2 file with `qemu-img resize`
4. If VM was running → automatically start VM again

After resize, expand the filesystem inside the VM:

```bash
# Linux VM
resize2fs /dev/vdb

# Windows VM (PowerShell)
$maxSize = (Get-PartitionSupportedSize -DriveLetter E).SizeMax
Resize-Partition -DriveLetter E -Size $maxSize
```

**Note**: If VM is already shut off, the playbook resizes the disk directly without auto-starting it.

### Mount Disk

```bash
# Format and mount data disk inside VM (requires VM in hosts.ini)
ap playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data"
```

Format and mount data disk inside Linux VM. Requires the VM to be defined in `hosts.ini`.

**Parameters:**
- `disk_device`: disk device path (default: `/dev/vdb`)
- `mount_point`: mount point (required, e.g. `/data`)
- `disk_format`: filesystem type (default: `ext4`)
- `need_partition`: create GPT partition (default: `false`, raw disk mount)
- `format_force`: force reformat (default: `false`)
- `auto_mount`: add to fstab (default: `true`)

**Examples:**

```bash
# With GPT partition (default)
ap playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data"

# Raw disk without partition
ap playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data" -e "need_partition=false"

# Force reformat (WARNING: destroys data)
ap playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data" -e "format_force=true"
```

The playbook will:
1. Install `parted` if needed
2. Create GPT partition table (if `need_partition=true`)
3. Format disk with specified filesystem
4. Add fstab entry with UUID
5. Mount and verify

**Tags:** `-t partition`, `-t format`, `-t mount` (run specific steps only)

### VM Console Access

VMs use different graphics backends based on OS type:
- **Windows VMs**: SPICE graphics (port 5900+)
- **Linux VMs**: VNC graphics (port 5900+)

**Connect to VM console:**

```bash
# Method 1: virt-viewer (recommended, auto-detects SPICE/VNC)
virt-viewer <vm-name>

# Method 2: Get display port manually
virsh vncdisplay <linux-vm-name>    # Returns :0, :1, etc.
virsh domdisplay <windows-vm-name>  # Returns spice://127.0.0.1:5900
```

**Remote access via SSH tunnel:**

```bash
# On your local machine
ssh -L 5900:127.0.0.1:5900 user@kvm-host-ip
# Then connect to spice://127.0.0.1:5900 or vnc://127.0.0.1:5900 locally
```

**Example:** View Windows VM boot process
```bash
virt-viewer win10-dev1  # Opens SPICE console to watch Windows boot
```

### Remote Desktop Access (Windows VMs)

Windows VMs support RDP (Remote Desktop Protocol) on port 3389.

**Find VM IP address:**
```bash
virsh domifaddr <vm-name>
```

**Connect via RDP:**

Linux desktop (recommended): **[Remmina](https://remmina.org/)**
- Install: `sudo apt install remmina remmina-plugin-rdp`
- GUI: supports RDP, VNC, SPICE, SSH
- Features: clipboard sharing, folder redirection, multi-monitor

Other options:
- **xfreerdp**: `xfreerdp /v:<vm-ip> /u:Administrator`
- **Windows**: built-in "Remote Desktop Connection" (mstsc.exe)
- **macOS**: "Microsoft Remote Desktop" from App Store

**Example:**
```bash
# Linux: open Remmina and connect to 10.241.20.45
remmina -c rdp://10.241.20.45

# Or use xfreerdp
xfreerdp /v:10.241.20.45 /u:Administrator /p:<password>
```

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
| `autostart` | Auto-start on boot (default: `false`) | `true` |
| `storage_dir` | VM storage path (optional, default: `/var/lib/libvirt/images`) | `/data/vms` |
| `ip` | Static IP address (optional, Linux only, empty = DHCP) | `192.168.1.100` |
| `netmask` | Subnet CIDR (optional, default: `22`) | `24` |
| `gateway` | Default gateway (required if `ip` is set) | `192.168.1.1` |
| `dns` | DNS servers, comma-separated (required if `ip` is set) | `8.8.8.8,8.8.4.4` |

## Network Architecture

VMs connect to the local network via a **bridge** (default `br0`). Two IP assignment modes are supported:

### DHCP Mode (default)

When `ip` field is empty, VMs receive IP addresses from the LAN's DHCP server — same subnet as the host.

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

### Static IP Mode (Linux VMs)

For Linux VMs, you can configure static IP addresses by filling in the `ip`, `netmask`, `gateway`, and `dns` fields in `vms.csv`.

```
LAN (192.168.1.0/24, DHCP, gateway 192.168.1.1)
├── KVM Host (192.168.1.100, br0)
└── VM (192.168.1.150, static IP, virtio NIC)
```

**Example vms.csv configuration:**

```csv
name,host,type,memory_mb,vcpus,os,disk_gb,data_disk_gb,base_image,bridge,mac,firmware,autostart,storage_dir,ip,netmask,gateway,dns
web-server,local,linux,4096,2,debian12,40,100,/path/to/debian-12.qcow2,br0,52:54:00:aa:bb:cc,,true,/var/lib/libvirt/images,192.168.1.150,24,192.168.1.1,"8.8.8.8,1.1.1.1"
```

**Notes:**
- Static IP configuration only works for **Linux VMs** (cloud-init network-config)
- Windows VMs do not support static IP configuration through this method
- When `ip` is empty or omitted, the VM will use DHCP (default behavior)
- The IP address is permanent and persists across reboots
- Ensure the static IP is outside the DHCP pool to avoid conflicts

**Generated network configuration:**

Cloud-init will generate a netplan configuration at `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
      - 192.168.1.150/24
      routes:
      - to: default
        via: 192.168.1.1
      nameservers:
        addresses:
        - 8.8.8.8
        - 1.1.1.1
```

**Verification:**

After VM creation, verify the static IP is active:

```bash
# Check IP address
ssh root@192.168.1.150 "ip addr show ens3 | grep inet"

# Check gateway
ssh root@192.168.1.150 "ip route | grep default"

# Check DNS
ssh root@192.168.1.150 "grep nameserver /etc/resolv.conf"
```

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

## Linux Base Image

The Linux VMs use official cloud images pre-configured with cloud-init support. Supported distributions:

### Debian

**Download the latest Debian 12 (Bookworm) image:**

```bash
wget -O debian-12-genericcloud-amd64.qcow2 \
  https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

**Alternative versions:** Browse https://cloud.debian.org/images/cloud/ for bookworm, bullseye, trixie, etc.

### Ubuntu

**Download the latest Ubuntu 24.04 LTS (Noble) image:**

```bash
wget -O ubuntu-24.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

**Download the latest Ubuntu 26.04 LTS (Resolute) image:**

```bash
wget -O ubuntu-26.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
```

**Important:** Ubuntu cloud images require the **virtio** network driver. The VM templates in this project already use virtio, so no additional configuration is needed.

**Note:** Always verify the downloaded image checksum against the official SHA256SUMS file to avoid corrupted images causing boot failures.

**Alternative versions:** Browse https://cloud-images.ubuntu.com/ for other Ubuntu releases.

### Configuration

Set the image path in `vms.csv` `base_image` field:

```csv
# Debian
my-debian-vm,local,linux,...,/path/to/debian-12-genericcloud-amd64.qcow2,...

# Ubuntu
my-ubuntu-vm,local,linux,...,/path/to/ubuntu-24.04-server-cloudimg-amd64.img,...
```

The image is automatically configured via cloud-init on first boot (SSH keys, user, packages, etc. from `group_vars/kvm_hosts/vms_all.yaml`).

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

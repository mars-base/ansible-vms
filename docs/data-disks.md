# Data Disks

> **macOS VMs**: the playbooks in this document do **not** apply to macOS guests.
> macOS disks sit on q35's built-in SATA controller (not hotpluggable, and no
> virtio-blk driver), and macOS guests have no Python for Ansible. The data
> disk is instead created automatically at VM-create time from the
> `data_disk_gb` column (see [macos.md](macos.md)); each playbook detects
> `type=macos` and aborts with a `diskutil` pointer.

## Attach Data Disk

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

## Resize Data Disk

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

## Mount Disk

```bash
# Format and mount data disk inside VM (requires VM in hosts.ini)
ap playbooks/mount-disk.yaml -e "HOSTS=debian13-01" -e "mount_point=/data"
```

Format and mount data disk inside Linux VM. Requires the VM to be defined in `hosts.ini`.

### Parameters

- `disk_device`: disk device path (default: `/dev/vdb`)
- `mount_point`: mount point (required, e.g. `/data`)
- `disk_format`: filesystem type (default: `ext4`)
- `need_partition`: create GPT partition (default: `false`, raw disk mount)
- `format_force`: force reformat (default: `false`)
- `auto_mount`: add to fstab (default: `true`)

### Examples

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

## Extra Disks (add / list / delete)

Add as many extra virtio-blk disks as needed at runtime, independent of the
`data_disk_gb` column (which stays reserved for the single disk
`create-vm.yaml` builds). Disks are named `<vm>-extra<N>.qcow2` in the VM's
storage dir; both the next free index and the next free host target (`vdX`)
are auto-detected from live **and** persistent config, so repeated runs never
collide.

Linux guests only: virtio-blk hot-plug works on a **running** VM
(`--config --live`, visible immediately, no reboot); a **shut-off** VM gets
the disk via `--config` only, visible on next boot.

### Add

```bash
# one 10G disk (index/letter picked automatically)
ap playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e extra_size=10G

# four 2G disks in one run
ap playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e count=4 -e extra_size=2G

# override the target directory (default: VM's storage dir from vms.csv)
ap playbooks/add-extra-disk-linux.yaml -e vm_name=debian12-01 -e extra_dir=/data/disks
```

### List

```bash
ap playbooks/list-extra-disks.yaml -e vm_name=debian12-01
```

Shows each disk's index, virtual size, and its target in the live domain
and/or persistent config:

```
extra1.qcow2: 2G, live=vdc, config=vdc
extra2.qcow2: 2G, live=vdd, config=vdd
```

### Delete

Detaches the disk (live + config on a running VM — virtio-blk hot-unplug)
and deletes the qcow2 file. Destroys data, so `confirm=true` is required:

```bash
ap playbooks/delete-extra-disk.yaml -e vm_name=debian12-01 -e extra_index=2 -e confirm=true
```

### Identifying a disk inside the guest

The guest kernel assigns its own `vdX` names, which usually differ from the
host target. Each extra disk carries a serial `<vm>-extra<N>` — match on it:

```bash
lsblk -o NAME,SERIAL,SIZE
# vdc  debian12-01-extra1  2G
```

Format/mount afterwards with `mount-disk.yaml` (pass the *guest* device
name, e.g. `-e disk_device=/dev/vdc`).

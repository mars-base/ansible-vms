# Data Disks

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

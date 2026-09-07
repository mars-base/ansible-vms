# VM Definition (vms.csv)

VMs are defined in `vms.csv` file. Each row represents a VM with the following fields:

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

## Example vms.csv

```csv
name,host,type,memory_mb,vcpus,os,disk_gb,data_disk_gb,base_image,bridge,mac,firmware,autostart,storage_dir,ip,netmask,gateway,dns
win11-dev,local,windows,8192,4,win11,80,10,/home/user/images/win11-base.qcow2,br0,52:54:00:12:34:56,efi,true,/var/lib/libvirt/images,,,,
debian12-dev,local,linux,2048,2,debian12,20,0,/home/user/images/debian-12.qcow2,br0,52:54:00:12:34:57,,true,/var/lib/libvirt/images,192.168.1.100,24,192.168.1.1,"8.8.8.8,8.8.4.4"
```

## Key Points

- **MAC addresses**: Each VM needs a unique MAC address for stable DHCP leases
- **Autostart**: Only debian12-01 is configured with `autostart=true` (starts on host boot)
- **Storage**: VMs can use custom storage paths or default `/var/lib/libvirt/images`
- **Static IP**: Only supported for Linux VMs via cloud-init
- **Idempotent**: The `create-vm` playbook checks if VM exists before creating, safe to run multiple times

# VM Console Access

VMs use different graphics backends based on OS type:
- **Windows VMs**: SPICE graphics (port 5900+)
- **Linux VMs**: VNC graphics (port 5900+)

## Connect to VM console

```bash
# Method 1: virt-viewer (recommended, auto-detects SPICE/VNC)
virt-viewer <vm-name>

# Method 2: Get display port manually
virsh vncdisplay <linux-vm-name>    # Returns :0, :1, etc.
virsh domdisplay <windows-vm-name>  # Returns spice://127.0.0.1:5900
```

## Remote access via SSH tunnel

```bash
# On your local machine
ssh -L 5900:127.0.0.1:5900 user@kvm-host-ip
# Then connect to spice://127.0.0.1:5900 or vnc://127.0.0.1:5900 locally
```

## Example

View Windows VM boot process:
```bash
virt-viewer win10-dev1  # Opens SPICE console to watch Windows boot
```

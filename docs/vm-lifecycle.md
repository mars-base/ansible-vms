# VM Lifecycle

All playbooks are idempotent (safe to run multiple times).

## List VMs

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

## Start VM

```bash
# Start specific VM
ap playbooks/start-vm.yaml -e vm_name=debian12-dev
```

## Stop VM

```bash
# Graceful shutdown
ap playbooks/stop-vm.yaml -e vm_name=win11-dev
```

Uses `virsh shutdown` which sends ACPI shutdown signal. For Windows VMs with QEMU guest agent configured, this triggers a clean shutdown.

## Restart VM

```bash
# Stop then start VM
ap playbooks/restart-vm.yaml -e vm_name=debian12-dev
```

## Destroy VM

```bash
# Permanently delete VM (requires confirmation)
ap playbooks/destroy-vm.yaml -e vm_name=win11-dev -e confirm=true
```

Deletes: domain definition, disk images (qcow2), OVMF VARS, cloud-init ISO, TPM state.

**Warning**: This is destructive and irreversible. The `confirm=true` flag is required.

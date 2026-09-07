# Snapshots

Create, list, restore, and delete VM snapshots using libvirt's built-in snapshot support.

## Usage

```bash
# Create snapshot (default: shutdown VM first for disk consistency, then restore previous state)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create

# Create snapshot without shutdown (live snapshot, VM continues running)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e halt=false

# Create snapshot with custom name and description
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=create -e snapshot_name=before-upgrade -e snapshot_desc="升级前快照"

# List all snapshots
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=list

# Restore to snapshot (requires confirmation, restores VM state at snapshot time)
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=restore -e snapshot_name=before-upgrade -e confirm=true

# Delete snapshot
ap playbooks/snapshot-vm.yaml -e vm_name=debian12-01 -e snap_action=delete -e snapshot_name=before-upgrade
```

## Parameters

- `vm_name`: VM name (required)
- `snap_action`: `create` / `list` / `restore` / `delete` (required)
- `snapshot_name`: snapshot name (auto-generated for create; required for restore/delete)
- `snapshot_desc`: description (optional, create only)
- `halt`: shutdown VM before snapshot for disk consistency, then restore to previous state (optional, create only, default: `true`)
- `confirm`: safety flag (required for restore and delete)

## Behavior

- **halt=true (default)**: If VM is running → shutdown → snapshot → start (restore running state). If VM is off → snapshot → remain off (preserve off state).
- **halt=false**: Create snapshot while VM is running (live snapshot). Faster but may have incomplete disk writes.
- **Restore** returns the VM to the exact state at snapshot time (running or off depending on snapshot state).

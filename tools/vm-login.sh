#!/bin/bash
# vm-login - Login to VM serial console interactively
# Usage: vm-login <vm-name>
#
# Exit: Ctrl+] then Enter (virsh console)
#        Ctrl+A D (socat mode)

set -euo pipefail

usage() {
    echo "Usage: vm-login <vm-name>"
    echo ""
    echo "Login to VM serial console interactively."
    echo "Uses virsh console (preferred) or socat fallback."
    echo ""
    echo "Exit:"
    echo "  virsh console mode:  Ctrl+] then Enter"
    echo "  socat mode:          Ctrl+A then D"
    exit 1
}

[[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]] && usage

VM_NAME="$1"

# Check VM exists
if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "Error: VM '$VM_NAME' not found"
    exit 1
fi

# Check VM is running
STATE=$(sudo virsh domstate "$VM_NAME")
if [[ "$STATE" != "running" ]]; then
    echo "Error: VM '$VM_NAME' is not running (state: $STATE)"
    exit 1
fi

# Check if we have a controlling TTY
if [[ -t 0 && -t 1 ]]; then
    echo "=== Connecting to $VM_NAME console (Ctrl+] to exit) ==="
    echo ">>> Press Enter to see login prompt"
    sudo virsh console "$VM_NAME"
else
    # Fallback: socat to PTY
    PTY=$(sudo virsh dumpxml "$VM_NAME" | grep -oP '/dev/pts/\d+' | head -1)
    if [[ -z "$PTY" ]]; then
        echo "Error: no serial PTY found for '$VM_NAME'"
        exit 1
    fi
    echo "=== Connecting to $VM_NAME via socat $PTY (Ctrl+A D to exit) ==="
    sudo socat -,raw,echo=0 "$PTY",raw,echo=0
fi

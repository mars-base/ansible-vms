#!/bin/bash
# vm-console - View VM serial console output
# Usage: vm-console <vm-name> [-n NUM]
#   -n NUM    Show last NUM lines (default: follow mode)
#
# Requires VM to have serial log configured in domain XML:
#   <serial type='pty'>
#     <log file='/var/log/libvirt/qemu/<vm-name>-serial.log' append='on'/>
#     ...

set -euo pipefail

usage() {
    echo "Usage: vm-console <vm-name> [-n NUM]"
    echo ""
    echo "View VM serial console output from log file."
    echo ""
    echo "Options:"
    echo "  -n NUM    Show last NUM lines and exit (default: follow mode)"
    echo "  -h        Show this help"
    echo ""
    echo "Exit: Ctrl+C"
    exit 1
}

[[ $# -lt 1 || "$1" == "-h" ]] && usage

VM_NAME="$1"
shift

TAIL_LINES=""
while getopts "n:" opt; do
    case $opt in
        n) TAIL_LINES="$OPTARG" ;;
        *) usage ;;
    esac
done

# Check VM exists
if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "Error: VM '$VM_NAME' not found"
    exit 1
fi

LOG_FILE="/var/log/libvirt/qemu/${VM_NAME}-serial.log"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: serial log not found: $LOG_FILE"
    echo "VM needs serial log configured in domain XML:"
    echo "  <log file='/var/log/libvirt/qemu/<vm>-serial.log' append='on'/>"
    exit 1
fi

# Strip ANSI escape sequences and terminal control codes
strip_ansi() {
    sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\[[0-9;]*[mGK]//g; s/\x1b\[?[0-9;]*[hlmnpr]//g; s/\x1b\[[!][a-zA-Z][0-9]*//g; s/\x1b[()][AB012]//g; s/\x1b\][0-9]+(\x07|\x1b\\)//g; s/\x0f//g; s/\x0e//g'
}

if [[ -n "$TAIL_LINES" ]]; then
    echo "=== $VM_NAME console (last $TAIL_LINES lines) ==="
    sudo tail -n "$TAIL_LINES" "$LOG_FILE" | strip_ansi
else
    echo "=== $VM_NAME console (follow mode, Ctrl+C to exit) ==="
    sudo tail -f "$LOG_FILE" | strip_ansi
fi

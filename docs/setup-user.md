# Setup User Account

Create user account on Linux VMs with SSH key and passwordless sudo. Auto-skips non-Linux hosts.

## Usage

```bash
# Create user on single VM
ap playbooks/setup-user.yaml -e "HOSTS=debian12-01" -e "username=diwen"

# Create user on multiple VMs (host group)
ap playbooks/setup-user.yaml -e "HOSTS=vms" -e "username=diwen"

# Specify SSH public key
ap playbooks/setup-user.yaml -e "HOSTS=debian12-01" -e "username=diwen" -e "ssh_pubkey=/path/to/id_rsa.pub"
```

## Parameters

- `HOSTS`: target host or group (default: `vms`)
- `username`: user name to create (default: `admin`)
- `ssh_pubkey`: SSH public key file path (default: `~/.ssh/id_rsa.pub`)
- `user_shell`: login shell (default: `/bin/bash`)
- `user_groups`: user groups, comma-separated (auto-detected: `wheel` for Fedora/RHEL, `sudo` for Debian/Ubuntu)
- `passwordless_sudo`: enable passwordless sudo (default: `true`)

## Behavior

- Auto-detects OS via `gather_facts: true`
- Linux hosts: creates user, configures SSH key, enables passwordless sudo
- Non-Linux hosts (Windows, etc.): skipped with message showing detected OS
- Idempotent: safe to run multiple times on same host

---
title: Firewall
description: Manage the host firewall with nftables on Debian and RedHat family hosts.
weight: 110
icon: fa-solid fa-shield-halved
menus:
  main:
    identifier: docs-firewall
    parent: docs
    weight: 110
    params:
      icon: fa-solid fa-shield-halved
cascade:
  type: docs
  footer_style: slim
---

The `nftables` role manages the KVM host firewall. It supports Debian-family hosts (Debian, Ubuntu) and RedHat-family hosts (Fedora, Rocky Linux).

On Ubuntu, ufw is installed and enabled on some images; it is disabled by default (`nftables_disable_ufw`) so the two managers do not fight over the ruleset. On Fedora and Rocky, firewalld is stopped and masked by default (`nftables_disable_firewalld`) for the same reason.

## Usage

```bash
# Copy the variable template and fill in live values
cp group_vars/nftables/main.yml.example group_vars/nftables/main.yml

# Add hosts to the [nftables] group in hosts.ini, then apply:
uv run ansible-playbook playbooks/nftables.yaml

# Or target hosts directly via HOSTS pattern
uv run ansible-playbook playbooks/nftables.yaml -e HOSTS=<pattern>
```

> `nftables_ssh_sources` must contain at least one entry unless `nftables_ssh_allow_all` is true, and should include the Ansible control node. The role refuses to apply an empty list otherwise. Existing SSH sessions survive the reload (established/related is accepted), but new ones are dropped unless the source is listed.

## What the role does

1. Validates inputs before touching the host (OS family, IPv4/CIDR format of `nftables_ssh_sources`, non-empty SSH ports, set names).
2. Installs nftables (apt on Debian family, dnf on RedHat family); on Debian family, removes netfilter-persistent / iptables-persistent by default.
3. Disables conflicting managers: `ufw --force disable` on Ubuntu (when active); stops and masks firewalld on Fedora/Rocky.
4. Renders the ruleset to `/etc/nftables.conf` (Debian family) or `/etc/sysconfig/nftables.conf` (RedHat family), validated with `nft -c -f` before writing; reloads via `nft -f` when the content changes.
5. Enables the nftables service at boot.

The rendered config defines two independent tables, `inet _filter` and `inet _nat`, deleting and recreating only these on reload — unrelated tables (for example Docker's) are left untouched.

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `nftables_ssh_sources` | Source IPv4 addresses/CIDRs allowed to establish SSH | — (required unless allow-all) |
| `nftables_ssh_allow_all` | Accept SSH from any source | `false` |
| `nftables_ssh_ports` | Host SSH port list; list every port sshd listens on | `[22]` |
| `nftables_sets` | Named address sets (`name` + `subnet` list) | `[]` |
| `nftables_rules` | Rules inserted verbatim into `filter_default`, `filter_forward`, `nat_prerouting`, `nat_postrouting` | `[]` |
| `filter_forward_default_policy` | FORWARD chain default policy | `drop` |
| `net_postrouting_default_policy` | POSTROUTING chain default policy | `accept` |
| `nftables_remove_iptables_persistent` | Remove netfilter-persistent / iptables-persistent | `true` |
| `nftables_disable_ufw` | Disable ufw when installed and active | `true` |
| `nftables_disable_firewalld` | Stop and mask firewalld on RedHat family when installed | `true` |

## Example

```yaml
nftables_ssh_sources:
  - 10.0.0.0/8
  - 192.168.10.0/24
nftables_ssh_ports:
  - 22

nftables_sets:
  - name: cloud_inner
    subnet:
      - "10.5.0.0/16"

nftables_rules:
  - chain: filter_default
    rules:
      - ip saddr $cloud_inner counter jump nolimit
      - tcp dport 50001-50999 counter jump nolimit
  # dnat port 52001 to 192.168.1.2:8080
  - chain: nat_prerouting
    rules:
      - tcp dport 52001 counter dnat ip to 192.168.1.2:8080
  - chain: nat_postrouting
    rules:
      - ip daddr 192.168.1.2 tcp dport 8080 counter masquerade
```

## Built-in chains

- `deny` — drop
- `nolimit` — accept
- `switch` — kill switch; point rules at it to toggle:

```bash
sudo nft flush chain inet _filter switch
sudo nft add rule inet _filter switch counter jump deny
```

## Notes

- With `nftables_sets` and `nftables_rules` empty, only loopback, established/related traffic, DHCP replies, ICMP and SSH from `nftables_ssh_sources` are accepted.
- The role replaces the distro-shipped `/etc/nftables.conf` with its own template. On a host that was already running the distro config, the leftover empty `inet filter` table is removed only when it provably cannot filter traffic (no rules, no drop/reject policies).
- On Fedora and Rocky, `nftables.service`'s `ExecReload` begins with `flush ruleset`, which would wipe foreign tables. The role therefore reloads by running `nft -f <config>` directly instead of `systemctl reload nftables`.
- Masking firewalld also blocks D-Bus activation, so `firewall-cmd` cannot bring it back. Restore with `systemctl unmask firewalld`.

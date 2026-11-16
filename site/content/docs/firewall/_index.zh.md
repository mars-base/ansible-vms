---
title: 防火墙
description: 在 Debian 与 RedHat 系主机上用 nftables 管理宿主机防火墙。
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

`nftables` role 管理 KVM 宿主机的防火墙，支持 Debian 系（Debian、Ubuntu）与 RedHat 系（Fedora、Rocky Linux）主机。

在 Ubuntu 上，部分镜像自带并启用了 ufw；默认会将其禁用（`nftables_disable_ufw`），避免两个管理器争抢规则集。在 Fedora 和 Rocky 上，firewalld 默认被停止并 mask（`nftables_disable_firewalld`），原因相同。

## 用法

```bash
# Copy the variable template and fill in live values
cp group_vars/nftables/main.yml.example group_vars/nftables/main.yml

# Add hosts to the [nftables] group in hosts.ini, then apply:
uv run ansible-playbook playbooks/nftables.yaml

# Or target hosts directly via HOSTS pattern
uv run ansible-playbook playbooks/nftables.yaml -e HOSTS=<pattern>
```

> 除非 `nftables_ssh_allow_all` 为 true，`nftables_ssh_sources` 必须至少包含一条记录，且应包含 Ansible 控制节点，否则 role 拒绝应用空列表。已建立的 SSH 会话在重载后不会中断（established/related 被放行），但来源不在列表中的新连接会被丢弃。

## role 做了什么

1. 在改动主机前校验输入（OS family、`nftables_ssh_sources` 的 IPv4/CIDR 格式、SSH 端口非空、set 名称）。
2. 安装 nftables（Debian 系用 apt，RedHat 系用 dnf）；Debian 系默认移除 netfilter-persistent / iptables-persistent。
3. 禁用冲突的管理器：Ubuntu 上执行 `ufw --force disable`（当处于活动状态）；Fedora/Rocky 上停止并 mask firewalld。
4. 将规则集渲染到 `/etc/nftables.conf`（Debian 系）或 `/etc/sysconfig/nftables.conf`（RedHat 系），写入前先用 `nft -c -f` 校验；内容变化时通过 `nft -f` 重载。
5. 设置 nftables 服务开机自启。

渲染出的配置定义了两张独立的表 `inet _filter` 和 `inet _nat`，重载时只删除并重建这两张表——无关的表（例如 Docker 的）不受影响。

## 变量

| 变量 | 说明 | 默认值 |
|----------|-------------|---------|
| `nftables_ssh_sources` | 允许建立 SSH 连接的来源 IPv4 地址/CIDR | —（除非 allow-all，否则必填） |
| `nftables_ssh_allow_all` | 接受任意来源的 SSH | `false` |
| `nftables_ssh_ports` | 宿主机 SSH 端口列表；列出 sshd 监听的每个端口 | `[22]` |
| `nftables_sets` | 命名地址集合（`name` + `subnet` 列表） | `[]` |
| `nftables_rules` | 原样插入 `filter_default`、`filter_forward`、`nat_prerouting`、`nat_postrouting` 的规则 | `[]` |
| `filter_forward_default_policy` | FORWARD 链默认策略 | `drop` |
| `net_postrouting_default_policy` | POSTROUTING 链默认策略 | `accept` |
| `nftables_remove_iptables_persistent` | 移除 netfilter-persistent / iptables-persistent | `true` |
| `nftables_disable_ufw` | 已安装且启用时禁用 ufw | `true` |
| `nftables_disable_firewalld` | RedHat 系已安装 firewalld 时停止并 mask | `true` |

## 示例

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

## 内置链

- `deny` — drop
- `nolimit` — accept
- `switch` — 总开关，把规则指向它即可切换：

```bash
sudo nft flush chain inet _filter switch
sudo nft add rule inet _filter switch counter jump deny
```

## 说明

- 当 `nftables_sets` 和 `nftables_rules` 都为空时，只放行 loopback、established/related 流量、DHCP 应答、ICMP，以及来自 `nftables_ssh_sources` 的 SSH。
- role 用自己的模板替换发行版自带的 `/etc/nftables.conf`。对于之前已在运行发行版配置的主机，残留的空 `inet filter` 表只有在可证明不会过滤流量时（无规则、无 drop/reject 策略）才会被删除。
- 在 Fedora 和 Rocky 上，`nftables.service` 的 `ExecReload` 以 `flush ruleset` 开头，会清空无关的表。因此 role 直接执行 `nft -f <config>` 重载，而不使用 `systemctl reload nftables`。
- mask firewalld 同时会阻止 D-Bus 激活，`firewall-cmd` 无法将其拉起。用 `systemctl unmask firewalld` 恢复。

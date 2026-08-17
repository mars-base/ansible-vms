# ansible-vms

KVM 虚拟机 Ansible 管理工程，用于在 KVM 宿主机上创建、管理和初始化虚拟机。

## 目录结构

```
ansible-vms/
├── ansible.cfg              # Ansible 配置（不提交，用 .example 生成）
├── ansible.cfg.example      # Ansible 配置示例
├── hosts.ini                # Inventory（不提交，用 .example 生成）
├── hosts.ini.example        # Inventory 示例
├── pyproject.toml           # 项目依赖（uv）
├── requirements.txt         # pip 依赖
├── group_vars/
│   ├── all/                 # 全局变量
│   └── kvm_hosts/           # KVM 宿主机变量
├── host_vars/               # 单机变量
├── playbooks/
│   ├── setup-kvm-host.yaml  # 部署 KVM 宿主机
│   ├── create-vm.yaml       # 创建虚拟机
│   ├── manage-vm.yaml       # 管理虚拟机生命周期
│   ├── list-vms.yaml        # 列出所有虚拟机
│   └── init-vm.yaml         # 初始化虚拟机
├── roles/
│   ├── kvm_host/            # 安装 KVM/libvirt 宿主机环境
│   ├── create_vm/           # 创建虚拟机（cloud-init + libvirt）
│   ├── manage_vm/           # 管理虚拟机生命周期
│   └── vm_init/             # 虚拟机内部初始化
├── roles_init/
│   ├── py3venv/             # Python3 虚拟环境
│   ├── rsyslog/             # 日志服务
│   └── logrotate/           # 日志轮转
├── scripts/                 # 辅助脚本
├── sql/                     # SQL 文件
└── var/                     # 运行时数据（日志、facts 缓存）
```

## 快速开始

### 1. 初始化环境

```bash
# 复制配置文件
cp ansible.cfg.example ansible.cfg
cp hosts.ini.example hosts.ini
# 编辑 hosts.ini，填入实际的 KVM 宿主机 IP

# 创建虚拟环境并安装依赖
uv sync
# 或
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

### 2. 部署 KVM 宿主机

```bash
ap playbooks/setup-kvm-host.yaml
```

### 3. 创建虚拟机

```bash
ap playbooks/create-vm.yaml -e vm_name=vm-dev-01 -e vm_vcpus=4 -e vm_memory_mb=8192 -e vm_disk_gb=100
```

### 4. 列出虚拟机

```bash
ap playbooks/list-vms.yaml
```

### 5. 管理虚拟机

```bash
# 启动
ap playbooks/manage-vm.yaml -e vm_name=vm-dev-01 -e vm_action=start
# 停止
ap playbooks/manage-vm.yaml -e vm_name=vm-dev-01 -e vm_action=stop
# 删除（含磁盘）
ap playbooks/manage-vm.yaml -e vm_name=vm-dev-01 -e vm_action=delete
```

### 6. 初始化虚拟机内部

```bash
ap -e HOSTS=vm_dev playbooks/init-vm.yaml
```

## 支持的操作系统镜像

| 标识 | 发行版 |
|------|--------|
| `ubuntu22.04` | Ubuntu 22.04 LTS (Jammy) |
| `ubuntu24.04` | Ubuntu 24.04 LTS (Noble) |
| `debian12` | Debian 12 (Bookworm) |

## 注意事项

- `hosts.ini` 和 `ansible.cfg` 已在 `.gitignore` 中，请勿提交含真实 IP/密码的文件
- 敏感变量请使用 `.example` 文件配合 Ansible Vault 管理
- 创建虚拟机使用 cloud-init 进行首次启动配置，需宿主机能访问 cloud image 下载 URL

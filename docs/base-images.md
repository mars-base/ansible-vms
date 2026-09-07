# Base Images

## Linux Base Images

The Linux VMs use official cloud images pre-configured with cloud-init support.

### Debian

**Download the latest Debian 12 (Bookworm) image:**

```bash
wget -O debian-12-genericcloud-amd64.qcow2 \
  https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2
```

**Alternative versions:** Browse https://cloud.debian.org/images/cloud/ for bookworm, bullseye, trixie, etc.

### Ubuntu

**Download the latest Ubuntu 24.04 LTS (Noble) image:**

```bash
wget -O ubuntu-24.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

**Download the latest Ubuntu 26.04 LTS (Resolute) image:**

```bash
wget -O ubuntu-26.04-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img
```

**Important:** Ubuntu cloud images require the **virtio** network driver. The VM templates in this project already use virtio, so no additional configuration is needed.

**Note:** Always verify the downloaded image checksum against the official SHA256SUMS file to avoid corrupted images causing boot failures.

**Alternative versions:** Browse https://cloud-images.ubuntu.com/ for other Ubuntu releases.

### Fedora

**Download the latest Fedora 44 Cloud Base image:**

```bash
wget -O Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2 \
  https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2
```

**Note:** Fedora uses `wheel` group for sudo privileges (not `sudo`). The `setup-user` playbook automatically detects this and uses the correct group.

**Alternative versions:** Browse https://fedoraproject.org/cloud/download/ for other Fedora releases.

### Rocky Linux

**Download the latest Rocky Linux 10 Cloud Base image:**

```bash
wget -O Rocky-10-GenericCloud-Base.latest.x86_64.qcow2 \
  https://dl.rockylinux.org/pub/rocky/10/images/x86_64/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2
```

**Note:** Rocky Linux uses `wheel` group for sudo privileges (same as RHEL/CentOS). The `setup-user` playbook automatically detects this and uses the correct group.

**Alternative versions:** Browse https://rockylinux.org/download for other Rocky Linux releases.

### Configuration

Set the image path in `vms.csv` `base_image` field:

```csv
# Debian
my-debian-vm,local,linux,...,/path/to/debian-12-genericcloud-amd64.qcow2,...

# Ubuntu
my-ubuntu-vm,local,linux,...,/path/to/ubuntu-24.04-server-cloudimg-amd64.img,...

# Fedora
my-fedora-vm,local,linux,...,/path/to/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2,...

# Rocky Linux
my-rocky-vm,local,linux,...,/path/to/Rocky-10-GenericCloud-Base.latest.x86_64.qcow2,...
```

The image is automatically configured via cloud-init on first boot (SSH keys, user, packages, etc. from `group_vars/kvm_hosts/vms_all.yaml`).

## Windows Base Image

The Windows qcow2 base image is built with [packer-windows-kubevirt](https://github.com/mars-base/packer-windows-kubevirt). It uses Packer + QEMU to produce a sysprep-generalized Windows image with:

- **virtio drivers** pre-installed (vioscsi, viostor, netkvm, vioserial, viorng, balloon, viofs)
- **QEMU Guest Agent** + **Cloudbase-Init**
- **WinRM HTTPS** (port 5986) + **RDP** (port 3389) enabled
- EFI boot with secure boot keys

Build your own custom image:

```bash
git clone https://github.com/mars-base/packer-windows-kubevirt
cd packer-windows-kubevirt
packer build <template>
```

Then set the output path in `vms.csv` `base_image` field.

## Windows VM Features

When `type=windows`, the domain XML template includes:

- **Hyper-V enlightenments** (relaxed, vapic, spinlocks, synic, stimer, etc.) for nested WSL2
- **VMX passthrough** for nested virtualization (WSL2/Hyper-V inside guest)
- **EFI + vTPM 2.0** (OVMF secure boot + emulated TPM)
- **virtio-scsi** disk bus + **virtio** NIC
- **Localtime** clock with hypervclock

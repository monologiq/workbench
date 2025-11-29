# Arch Linux Workbench

QEMU/KVM setup for building ISO, creating, editing scripts and much more.


## Getting started

```bash
sudo pacman -S qemu-full virt-manager virtfs libvirt edk2-ovmf swtpm dnsmasq iptables-nft
sudo usermod -aG libvirt,kvm $USER
```

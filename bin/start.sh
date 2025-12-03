#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MIRROR_SOURCE="https://last-public-archlinux.snap.mirrors.ovh.net/archlinux/iso/latest/archlinux-x86_64.iso"

download_iso() {
	curl -# -C - -o "$ROOT_DIR/iso/${MIRROR_SOURCE##*/}" -O "$MIRROR_SOURCE"
}

install_deps() {
	sudo pacman -S --needed qemu-full virt-manager virt-viewer dnsmasq bridge-utils libvirt ebtables iptables-nft edk2-ovmf swtpm tpm2-tools
}

enable_service() {
	sudo usermod -aG libvirt,kvm $USER
	sudo systemctl enable libvirtd
	sudo systemctl start libvirtd
}


create_drive() {
	if [ ! -e "$ROOT_DIR/drives/arch.qcow2" ]; then
		qemu-img create -f qcow2 $ROOT_DIR/drives/arch.qcow2 20G
	fi
}

efi_vars() {
	cp /usr/share/edk2/x64/OVMF_VARS.4m.fd $ROOT_DIR/efi/ARCH_VARS.fd
	cp /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd $ROOT_DIR/efi/ARCH_CODE.secboot.fd
}

case "$1" in
	install)
		install_deps
		efi_vars
		# download_iso
		# create_drive
		;;
	*)
		;;
esac

mkdir -p $ROOT_DIR/.cache
mkdir -p $ROOT_DIR/.cache/tpm

swtpm socket \
  --tpmstate dir=$ROOT_DIR/.cache/tpm \
  --ctrl type=unixio,path=$ROOT_DIR/.cache/tpm/swtpm-sock \
  --tpm2 \
  --daemon

qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -cpu host \
  -smp 2 \
  -drive file=$ROOT_DIR/drives/arch.qcow2,format=qcow2,if=virtio \
  -cdrom $ROOT_DIR/iso/archlinux-x86_64.iso \
  -boot d \
  -drive if=pflash,format=raw,readonly=on,file=$ROOT_DIR/efi/ARCH_CODE.fd \
  -drive if=pflash,format=raw,file=$ROOT_DIR/efi/ARCH_VARS.fd \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::9222-:22 \
  -chardev socket,id=chrtpm,path=$ROOT_DIR/.cache/tpm/swtpm-sock \
  -tpmdev emulator,id=tpm0,chardev=chrtpm \
  -device tpm-tis,tpmdev=tpm0 \
  -vga virtio


pkill -f "swtpm socket.*tpm_state"
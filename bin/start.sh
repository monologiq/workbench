#!/usr/bin/env bash

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

MACHINES_DIR="$ROOT_DIR/.machines"

DRIVES_DIR="$MACHINES_DIR/drives"
EFI_DIR="$MACHINES_DIR/efi"
ISO_DIR="$MACHINES_DIR/iso"
TPM2_DIR="$MACHINES_DIR/tpm"

ARCH="x86_64"

MIRROR_SOURCE="https://last-public-archlinux.snap.mirrors.ovh.net/archlinux/iso/latest/archlinux-$ARCH.iso"

download_iso() {
	curl -# -C - -o "$ISO_DIR/${MIRROR_SOURCE##*/}" -O "$MIRROR_SOURCE"
}

init() {
	mkdir -p "$MACHINES_DIR" "$DRIVES_DIR" "$EFI_DIR" "$ISO_DIR" "$TPM2_DIR"

	sudo pacman -S --needed --noconfirm \
		qemu-full \
		virt-manager \
		virt-viewer \
		dnsmasq \
		bridge-utils \
		libvirt \
		ebtables \
		iptables-nft \
		edk2-ovmf \
		swtpm \
		tpm2-tools

	if [ $ARCH = "x86_64" ]; then
		cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$EFI_DIR"/ARCH_VARS.fd
		cp /usr/share/edk2/x64/OVMF_CODE.4m.fd "$EFI_DIR"/ARCH_CODE.fd
	fi

	# sudo usermod -aG libvirt,kvm $USER
	curl -# -C - -o "$ISO_DIR/${MIRROR_SOURCE##*/}" -O "$MIRROR_SOURCE"

	qemu-img create -f qcow2 "$DRIVES_DIR"/archlinux-$ARCH.qcow2 20G
}

start() {
	swtpm socket \
	  --tpmstate dir="$TPM2_DIR" \
	  --ctrl type=unixio,path="$TPM2_DIR"/swtpm-sock \
	  --tpm2 \
	  --daemon

	qemu-system-x86_64 \
	  -enable-kvm \
	  -m 2048 \
	  -cpu host \
	  -smp 2 \
	  -drive file="$DRIVES_DIR"/archlinux-$ARCH.qcow2,format=qcow2,if=virtio \
	  -cdrom "$ISO_DIR"/archlinux-$ARCH.iso \
	  -boot d \
	  -drive if=pflash,format=raw,readonly=on,file="$EFI_DIR"/ARCH_CODE.fd \
	  -drive if=pflash,format=raw,file="$EFI_DIR"/ARCH_VARS.fd \
	  -net nic,model=virtio \
	  -net user,hostfwd=tcp::9222-:22 \
	  -chardev socket,id=chrtpm,path="$TPM2_DIR"/swtpm-sock \
	  -tpmdev emulator,id=tpm0,chardev=chrtpm \
	  -device tpm-tis,tpmdev=tpm0 \
	  -vga virtio

	pkill -f "swtpm socket.*tpm_state"
}

case "$1" in
	init)
		init
		;;
	start)
		start
		;;
	*)
		;;
esac

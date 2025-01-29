#!/bin/bash

set -e

KS_FILE='https://raw.githubusercontent.com/geometriccross/slurm_cluster/refs/heads/main/anaconda-ks.cfg'

origin_iso="${1:-r9.5_mini.iso}"
if [ ! -e "$origin_iso" ]; then
	wget --inet4-only -O "${origin_iso}" https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.5-x86_64-minimal.iso
fi

custom_iso="${2:-changed.iso}"

mnt_dir=$(mktemp -d)
iso_dir=$(mktemp -d)

# mount and copy for edit
sudo mount -oro,loop "$origin_iso" "$mnt_dir"
cp -a "$mnt_dir"/* "$iso_dir"/
sudo umount "$mnt_dir"
rmdir "$mnt_dir"

# append ks file ref in uefi boot cfg
sed -i "s|\(linuxefi .*quiet\)|\1 inst.ks=$KS_FILE|" "$iso_dir/EFI/BOOT/grub.cfg"

# -as mkisofs
# 	run in compatible mode
# -c
# 	specify boot catalog file
# -b
# 	specify iso boot binary
# --no-emul-boot
# 	normal type booting
# --boot-load-size
# 	specify boot sector size, basically this set 4
# --boot-info-table
# 	bt this, iso infos can easily access
xorriso -as mkisofs \
	-o "$custom_iso" \
	-c isolinux/boot.cat \
	-b isolinux/isolinux.bin \
	--no-emul-boot --boot-load-size 4 --boot-info-table \
	"$iso_dir"

rm -rf "$iso_dir"

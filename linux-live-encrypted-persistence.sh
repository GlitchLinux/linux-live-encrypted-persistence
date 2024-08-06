#!/bin/bash

# Prompt the user to enter the partition
echo "Please enter the partition (e.g., /dev/sdxx):"
read PARTITION

if [ -z "$PARTITION" ]; then
    echo "No partition entered. Exiting."
    exit 1
fi

# Check if the partition exists
if ! sudo fdisk -l | grep -q "$PARTITION"; then
    echo "Partition $PARTITION does not exist. Exiting."
    exit 1
fi

# Perform the steps to encrypt and set up the partition
set -e

echo "Starting disk operations on $PARTITION"
sudo fdisk -l

echo "Formatting $PARTITION with LUKS"
sudo cryptsetup --verbose --verify-passphrase luksFormat $PARTITION

echo "Opening LUKS partition"
sudo cryptsetup luksOpen $PARTITION LUKS

echo "Creating ext3 filesystem on encrypted partition"
sudo mkfs.ext3 /dev/mapper/LUKS

echo "Labeling filesystem as persistence"
sudo e2label /dev/mapper/LUKS PERSISTENCE

echo "Creating mount point /mnt/LUKS"
sudo mkdir -p /mnt/LUKS

echo "Mounting encrypted partition"
sudo mount /dev/mapper/LUKS /mnt/LUKS

echo "Changing directory to /mnt/LUKS"
cd /mnt/LUKS

echo "Creating persistence.conf"
sudo touch persistence.conf

echo "Editing persistence.conf"
sudo bash -c 'echo "/ union" > persistence.conf'

# Prompt user for the name of their live system
echo "Please enter the name of your live system:"
read LIVE_SYSTEM_NAME

# Prompt user to enter if their live system uses initrd.img or initrd.gz
echo "Does your live system use initrd.img or initrd.gz? (Enter 'img' or 'gz'):"
read INITRD_TYPE

# Check if the user input is valid
if [[ "$INITRD_TYPE" != "img" && "$INITRD_TYPE" != "gz" ]]; then
    echo "Invalid input. Please enter 'img' or 'gz'. Exiting."
    exit 1
fi

# Create the grub.cfg content with user input
GRUB_CFG_CONTENT=$(cat <<EOF
# All labels that look like "__LABEL__" are replaced by SED in
# /usr/bin/remastersys around lines 345-400.
# Translations in /usr/share/locale/pt_BR/LC_MESSAGES/remastersys.po

set default="0"
set timeout="10"

function load_video {
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
}

loadfont /usr/share/grub/unicode.pf2

set gfxmode=640x480
load_video
insmod gfxterm
set locale_dir=/boot/grub/locale
set lang=C
insmod gettext
background_image -m stretch /boot/grub/grub.png
terminal_output gfxterm
insmod png
if background_image /boot/grub/grub.png; then
    true
else
    set menu_color_normal=cyan/blue
    set menu_color_highlight=white/blue
fi

menuentry "$LIVE_SYSTEM_NAME - LIVE" {
    linux /live/vmlinuz boot=live config quiet
    initrd /live/initrd.$INITRD_TYPE
}

menuentry "$LIVE_SYSTEM_NAME - Boot ISO to RAM" {
    linux /live/vmlinuz boot=live config quiet toram
    initrd /live/initrd.$INITRD_TYPE
}

menuentry "$LIVE_SYSTEM_NAME - Encrypted Persistence" {
    linux /live/vmlinuz boot=live components quiet splash noeject findiso=\${iso_path} persistent=cryptsetup persistence-encryption=luks persistence
    initrd /live/initrd.$INITRD_TYPE
}
EOF
)

# Save the grub.cfg to the encrypted partition
echo "$GRUB_CFG_CONTENT" | sudo tee /mnt/LUKS/grub.cfg

echo "Returning to home directory"
cd ~

echo "Unmounting encrypted partition"
sudo umount /dev/mapper/LUKS

echo "Closing LUKS partition"
sudo cryptsetup luksClose /dev/mapper/LUKS

# Final message to the user
cat <<EOF
The encrypted persistent partition has been set up and a custom grub.cfg has been saved to it.
However, the system will not be able to boot with the encrypted persistence just yet.

To enable this, you need to replace the grub.cfg at /boot/grub/grub.cfg in the current live system with the one saved to the encrypted partition. This must be done externally and cannot be done from the current live boot.

If the live partition is FAT32, it's straightforward:
1. Simply mount the partitions using another Linux system and replace the grub.cfg.

If the live partition uses the JOLIET filesystem:
1. You must edit the actual ISO you used and replace the grub.cfg in it.
2. Then the live partition must be recreated using the custom ISO. The gnome-disk-utility is an easy tool for reflashing a partition with an ISO file.

Disk setup completed successfully.
EOF

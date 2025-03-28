#!/bin/bash

# Color variables
WHITE='\033[1;37m'
BRIGHT_GREEN='\033[1;32m'
RESET='\033[0m'

# Header
echo -e "${WHITE}+--------------------------------------------------------------+${RESET}"
echo -e "${WHITE}|  WARNING: The selected partition will be COMPLETELY ERASED!  |${RESET}"
echo -e "${WHITE}|           Backup your data before proceeding!                |${RESET}"
echo -e "${WHITE}|  Any data present on the partition will be PERMANENTLY LOST  |${RESET}"
echo -e "${WHITE}+--------------------------------------------------------------+${RESET}"

# Prompt for the partition
echo -e "${BRIGHT_GREEN}Enter the partition that you want encrypted: (e.g. /dev/sdxx):${RESET}"
echo ""
read PARTITION

# Check if the partition is empty
if [ -z "$PARTITION" ]; then
    echo -e "${WHITE}No partition entered. Exiting.${RESET}"
    exit 1
fi

# Check if the partition exists
if ! sudo fdisk -l | grep -q "$PARTITION"; then
    echo -e "${WHITE}Partition $PARTITION does not exist. Exiting.${RESET}"
    exit 1
fi

# Perform disk operations
echo -e "${WHITE}Starting disk operations on $PARTITION...${RESET}"
echo ""
sudo fdisk -l

echo -e "${WHITE}Formatting $PARTITION with LUKS encryption...${RESET}"
echo ""
sudo cryptsetup luksFormat "$PARTITION"
echo -e "${BRIGHT_GREEN}Please enter passphrase to open the new LUKS encryption:${RESET}"
echo ""
sudo cryptsetup luksOpen "$PARTITION" encData

echo -e "${WHITE}Creating ext4 filesystem on encrypted partition...${RESET}"
sudo mkfs.ext4 /dev/mapper/encData

echo -e "${WHITE}Labeling filesystem as persistence${RESET}"
sudo e2label /dev/mapper/encData persistence

echo -e "${WHITE}Creating mount point at /mnt/persistence${RESET}"
sudo mkdir -p /mnt/persistence

echo -e "${WHITE}Mounting encrypted partition...${RESET}"
sudo mount /dev/mapper/encData /mnt/persistence

echo -e "${WHITE}Creating persistence.conf file...${RESET}"
sudo touch /mnt/persistence/persistence.conf

echo -e "${WHITE}Editing persistence.conf${RESET}"
echo "/ union" | sudo tee /mnt/persistence/persistence.conf > /dev/null

echo -e "${WHITE}Returning to home directory...${RESET}"
cd ~

echo -e "${WHITE}Unmounting encrypted partition...${RESET}"
sudo umount /mnt/persistence

echo -e "${WHITE}Closing LUKS partition...${RESET}"
sudo cryptsetup luksClose encData

# Completion message
echo -e "${WHITE}+-----------------------------------------------------+${RESET}"
echo -e "${BRIGHT_GREEN}| THE ENCRYPTED PERSISTENT PARTITION HAS BEEN CREATED |${RESET}"
echo -e "${WHITE}+-----------------------------------------------------+${RESET}"

# Final prompt to exit the script
echo -e "\n${BRIGHT_GREEN}Press Enter to exit the script...${RESET}"
read -r

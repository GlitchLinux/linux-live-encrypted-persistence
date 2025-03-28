#!/bin/bash

# Define colors for styling
RED='\e[1;91m'
BRIGHT_GREEN='\e[1;92m'
WHITE='\e[1;97m'
RESET='\e[0m'

# Function to display a warning message with colors
display_warning() {
    echo -e "\n${RED}+--------------------------------------------------------------+${RESET}"
    echo -e "${RED}|${RESET} ${BRIGHT_GREEN} WARNING: The selected partition will be COMPLETELY ERASED! ${RESET} ${RED}|${RESET}"
    echo -e "${RED}|${RESET} ${BRIGHT_GREEN} Backup your data before proceeding!               ${RESET} ${RED}|${RESET}"
    echo -e "${RED}|${RESET} ${BRIGHT_GREEN} Any data present on the partition will be PERMANENTLY LOST ${RESET} ${RED}|${RESET}"
    echo -e "${RED}+--------------------------------------------------------------+${RESET}\n"
}

# Display warning before proceeding
display_warning

# Prompt the user to enter the partition
echo -e "${WHITE}Please enter the partition (e.g., /dev/sdxx):${RESET}"
echo ""
read PARTITION

if [ -z "$PARTITION" ]; then
    echo -e "${RED}No partition entered. Exiting.${RESET}"
    exit 1
fi

# Check if the partition exists
if ! sudo fdisk -l | grep -q "$PARTITION"; then
    echo -e "${RED}Partition $PARTITION does not exist. Exiting.${RESET}"
    exit 1
fi

# Set error handling
set -e

# Check if the mount point is already in use and unmount if necessary
MOUNTED=$(findmnt -no TARGET "$PARTITION" 2>/dev/null || true)
if [[ -n "$MOUNTED" ]]; then
    echo -e "\n${RED}Partition $PARTITION is currently mounted at $MOUNTED. Unmounting...${RESET}"
    sudo umount -lf "$PARTITION" || {
        echo -e "${RED}Failed to unmount $PARTITION. Exiting.${RESET}"
        exit 1
    }
fi

# Make sure the mount point /mnt/persistence is free
if mountpoint -q /mnt/persistence; then
    echo -e "${RED}/mnt/persistence is already mounted. Unmounting...${RESET}"
    sudo umount -lf /mnt/persistence || {
        echo -e "${RED}Failed to unmount /mnt/persistence. Exiting.${RESET}"
        exit 1
    }
fi

# Perform the steps to encrypt and set up the partition
echo -e "\n${BRIGHT_GREEN}Starting disk operations on $PARTITION...${RESET}"
sudo fdisk -l

# Formatting partition with LUKS
echo -e "\n${BRIGHT_GREEN}Formatting $PARTITION with LUKS encryption...${RESET}"
echo -e "${WHITE}Please enter a passphrase for LUKS encryption:${RESET}"

# LUKS Format Step
sudo cryptsetup luksFormat "$PARTITION"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to format the partition with LUKS encryption. Exiting.${RESET}"
    exit 1
fi

# Opening LUKS partition as encData
echo -e "\n${BRIGHT_GREEN}Opening LUKS partition as encData...${RESET}"
sudo cryptsetup luksOpen "$PARTITION" encData

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to open LUKS partition. Exiting.${RESET}"
    exit 1
fi

# Creating ext4 filesystem
echo -e "\n${BRIGHT_GREEN}Creating ext4 filesystem on encrypted partition!${RESET}"
sudo mkfs.ext4 /dev/mapper/encData

# Labeling filesystem as 'persistence'
echo -e "\n${BRIGHT_GREEN}Labeling filesystem as persistence${RESET}"
sudo e2label /dev/mapper/encData persistence

# Creating mount point
echo -e "\n${BRIGHT_GREEN}Creating mount point at /mnt/persistence${RESET}"
sudo mkdir -p /mnt/persistence

# Mounting encrypted partition
echo -e "\n${BRIGHT_GREEN}Mounting encrypted partition!${RESET}"
sudo mount /dev/mapper/encData /mnt/persistence

# Changing directory to mount point
echo -e "\n${BRIGHT_GREEN}Changing directory to /mnt/persistence${RESET}"
cd /mnt/persistence

# Creating persistence.conf file
echo -e "\n${BRIGHT_GREEN}Creating persistence.conf!${RESET}"
sudo touch persistence.conf

# Editing persistence.conf
echo -e "\n${BRIGHT_GREEN}Editing persistence.conf!${RESET}"
sudo bash -c 'echo "/ union" > persistence.conf'

# Returning to home directory
echo -e "\n${BRIGHT_GREEN}Returning to home directory!${RESET}"
cd ~

# Unmounting encrypted partition
echo -e "\n${BRIGHT_GREEN}Unmounting encrypted partition.${RESET}"
sudo umount /dev/mapper/encData

# Closing LUKS partition
echo -e "\n${BRIGHT_GREEN}Closing LUKS partition.${RESET}"
sudo cryptsetup luksClose /dev/mapper/encData

# Completion message
echo -e "\n${BRIGHT_GREEN}THE ENCRYPTED PERSITENT PARTITION HAVE BEEN CREATED!${RESET}\n"

# Final prompt to exit the script
echo -e "\nPress Enter to exit the script."
read -r


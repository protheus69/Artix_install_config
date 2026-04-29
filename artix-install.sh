#!/bin/bash
set -e

# Affichage des disques
lsblk

# Definir le disque d'installation
TESTDISK=0
while [ $TESTDISK -eq 0 ]; do
  read -p "Choisissez le disque d'installation :" DISK
  # Verification de la saisie
  if [ -e "/dev/$DISK" ]; then
    echo "Vous avez choisi : " $DISK
    TESTDISK=1
  else
    echo "Erreur : /dev/$DISK n'existe pas !"
  fi
done

# Creation des partitions
echo -e "\n--- CONFIGURATION FDISK ---"
echo -e "Creez vos partitions comme suit :\n 1: EFI (1G, type EFI)\n 2: SWAP (taille de votre RAM + 2G, type Swap)\n 3: ROOT (Reste, type Linux 23)\n"
read -p "Appuyez sur ENTREE pour lancer fdisk..."
fdisk /dev/$DISK

# Gestion intelligente du nom des partitions (NVMe vs SATA)
if [[ $DISK == nvme* ]]; then
    P_PREFIX="${DISK}p"
else
    P_PREFIX="${DISK}"
fi

# Creations des variables de partition
PART_EFI="/dev/${P_PREFIX}1"
PART_SWAP="/dev/${P_PREFIX}2"
PART_ROOT="/dev/${P_PREFIX}3"

# Suppression des precedentes signatures de systeme de fichiers
echo "Nettoyage des signatures sur $PART_EFI, $PART_SWAP, $PART_ROOT..."
wipefs -a $PART_EFI
wipefs -a $PART_SWAP
wipefs -a $PART_ROOT

# Creation des systemes de fichier
echo "Creation des systemes de fichiers sur $PART_EFI, $PART_SWAP, $PART_ROOT..."
mkfs.fat -F 32 $PART_EFI
mkswap $PART_SWAP
mkfs.btrfs $PART_ROOT

#Creation des sous volumes btrfs
echo "Creation des sous volumes sur la partition ROOT"
mount $PART_ROOT /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
umount /mnt

#Montage des partitions
echo "Montage des partitions"
swapon $PART_SWAP
mount -o noatime,compress=zstd,subvol=@ $PART_ROOT /mnt
mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}
mount -o noatime,compress=zstd,subvol=@home $PART_ROOT /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots $PART_ROOT /mnt/.snapshots
mount -o noatime,compress=zstd,subvol=@var_log $PART_ROOT /mnt/var/log
mount $PART_EFI /mnt/boot/efi

#Mise a jour de la date
echo "Mise a jour de la date et l'heure"
rc-service ntpd start

#Installation des paquets de base
echo "Installation des paquets de base"
basestrap /mnt base base-devel openrc elogind-openrc btrfs-progs

#Installation du kernel
basestrap /mnt linux linux-firmware intel-ucode sof-firmware

#Generation du fichier fstab
echo "Generation du fichier fstab"
fstabgen -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
OK=0
while [ $OK -eq 0 ]; do
    read -p "Le fstab est-il correct ? [o/n] : " answer
    case $answer in
        [Oo]* ) 
            OK=1 
            echo "Parfait, passons à la suite."
            ;;
        [Nn]* ) 
            echo "Ouverture de nano pour correction..."
            nano /mnt/etc/fstab
            cat /mnt/etc/fstab # Réaffiche pour vérification
            ;;
        * ) 
            echo "Répondez par O ou N."
            ;;
    esac
done

# on copie le script d'installation dans /mnt/
sed -i "3 i\DISK=$DISK" artix-install-chroot.sh
cp artix-install-chroot.sh /mnt/
chmod +x /mnt/artix-install-chroot.sh
cp artix-postinstall.sh /mnt/
chmod +x /mnt/artix-postinstall.sh

echo "Tapez la commande - artix-chroot /mnt - pour entrer dans le chroot"
echo "Esuite lancez la commande - ./artix-install-chroot.sh - pour continuer l'installation"

exit











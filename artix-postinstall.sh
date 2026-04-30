#!/bin/bash
set -e
#On lance ce scripts dans /home/seb avec sudo 

# genere le fichier /etc/pacman.d/mirrorlist-arch et installe les clefs GPG
pacman -S artix-archlinux-support

echo " ajout des depots Arch"

sed -i '/#[lib32]/{s/#[lib32]/[lib32]/; n; s/^.//}' /etc/pacman.conf
echo "# Arch" >> /etc/pacman.conf
echo "[extra]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
echo "" >> /etc/pacman.conf
echo "[multilib]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf

pacman -Sy

echo " Installation du serveur graphique"
# nvidia-dkms n'existe pas dans les depots Artix, utilisation de nvidia-580xx pour les pilotes propriétaire
pacman -S --needed xorg nvidia-580xx-dkms nvidia-580xx-settings nvidia-580xx-utils nvidia-prime xf86-input-libinput intel-media-driver

echo " Installation de kde et activation des services"
pacman -S --needed plasma kde-applications cups-openrc
pacman -S --noconfirm --needed sddm-openrc
rc-update add sddm default
rc-update add cupsd default
# Son et bluetooth
pacman -S --noconfirm --needed pipewire-openrc pipewire-pulse-openrc wireplumber-openrc
pacman -S --noconfirm --needed bluez bluez-openrc bluez-utils
sudo -u seb rc-update add -U pipewire default
sudo -u seb rc-update add -U pipewire-pulse default
sudo -u seb rc-update add -U wireplumber default
rc-update add bluetoothd default
# Gestion de l'energie
pacman -S power-profiles-daemon-openrc
rc-update add power-profiles-daemon default
# Installation de paru
echo "Installation de paru"
pacman -S --noconfirm --needed git rustup
sudo -u seb rustup update default
sudo -u seb git clone https://aur.archlinux.org/paru.git
cd paru
sudo -u seb makepkg -si
cd ..
# Configuration des snapshots
echo " Mise en place du systeme de snapshots"
umount /.snapshots 2>/dev/null
btrfs subvolume delete @snapshots 2>/dev/null
rm -rf /.snapshots

pacman -S --noconfirm --needed grub-btrfs snapper snap-pac

snapper -c root create-config /
btrfs subvolume delete /.snapshots
mkdir /.snapshots
#TODO /utilisation de variable pour le disk
mount /dev/nvme0n1p3 /mnt -o subvolid=5
btrfs subvolume create /mnt/@snapshots
umount /mnt
mount -o subvol=@snapshots /dev/nvme0n1p3 /.snapshots

paru snap-pac-grub

pacman -S --noconfirm --needed chrony-openrc
rc-update add chronyd default

echo " Ajouts des groupes pour l'utilisateur"
#TODO utilisation de variable pour l'utilisateur
usermod -a -G input,power,optical,lp,scanner,dbus,uucp seb

snapper -c root create -d "Base install"
grub-mkconfig -o /boot/grub/grub.cfg

exit

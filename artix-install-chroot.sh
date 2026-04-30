#!/bin/bash
set -e

# Configuration du fuseau horaire
echo "Configuration du fuseau horaire"
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Localisation (décommenter fr_FR.UTF-8)
echo "Localisation du systeme"
sed -i 's/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/g' /etc/locale.gen 
locale-gen
echo 'export LANG="fr_FR.UTF-8"' > /etc/locale.conf
echo 'export LC_COLLATE="C"' >> /etc/locale.conf
sed -i 's/keymap="us"/keymap="fr"/g' /etc/conf.d/keymaps
echo "KEYMAP=fr" > /etc/vconsole.conf

# Installation de grub
echo "Installation de grub"
pacman -S --noconfirm grub os-prober efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
grub-mkconfig -o /boot/grub/grub.cfg

# Mot de passe root (il faudra le taper)
echo "Définition du mot de passe ROOT :"
passwd

# Creation de l'utilisateur
echo "Creation d'un utilisateur"
read -p "Entrez un nom d'utilisateur [seb]:" USER
if [[ -z $USER ]]; then
    USER="seb"
fi
useradd -m -G wheel,storage,video,audio $USER
passwd $USER

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Nom de la machine
echo "Definir un nom de machine"
read -p "Entrez un nom pour cette machine [Katana-Artix]:" MNAME
if [[ -z $MNAME ]]; then
  MNAME="Katana-Artix"
fi
echo "$MNAME" > /etc/hostname
echo "127.0.1.1        $MNAME.localdomain  $MNAME" >> /etc/hosts
echo "hostname='$MNAME'" > /etc/conf.d/hostname

echo "Installation du service reseau"
pacman -S --noconfirm --needed dhcpcd networkmanager-openrc dbus-openrc elogind-openrc
rc-update add NetworkManager default
rc-update add dbus default
rc-update add elogind boot

mv /artix-postinstall.sh /home/$USER/

echo -e "\n--- INSTALLATION CHROOT TERMINEE ---"
echo "1. Tapez 'exit'"
echo "2. Tapez 'umount -R /mnt'"
echo "3. Tapez 'reboot'"
echo "Apres le reboot, lancez /artix-postinstall.sh"

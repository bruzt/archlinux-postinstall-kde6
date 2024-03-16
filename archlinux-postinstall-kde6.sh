#!/bin/bash

#set -e # exit script on error

if (( $EUID != 0 )); then
    echo "Please run this script with sudo"
    exit
fi

function archKde6 {

  #sed -i 's/\#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf

  pacman -Sy --noconfirm --needed archlinux-keyring
  yes | LC_ALL=en_US.UTF-8 pacman -Syu
  pacman -Syu --noconfirm

  if [[ $(glxinfo | grep -E "OpenGL vendor|OpenGL renderer") == *"AMD"* ]]; then
    pacman -S --noconfirm --needed vulkan-radeon lib32-vulkan-radeon mesa-utils vulkan-tools #adriconf

  elif [[ $(glxinfo | grep -E "OpenGL vendor|OpenGL renderer") == *"Intel"* ]]; then
    pacman -S --noconfirm --needed vulkan-intel lib32-vulkan-intel mesa-utils vulkan-tools #adriconf

  elif [[ $(glxinfo | grep -E "OpenGL vendor|OpenGL renderer") == *"NVIDIA"* ]]; then
    pacman -S --noconfirm --needed nvidia nvidia-utils lib32-nvidia-utils nvidia-settings
  fi

  pacman -S --noconfirm --needed discover packagekit-qt6 fwupd colord-kde kimageformats kdeplasma-addons
  pacman -S --noconfirm --needed flatpak xdg-desktop-portal-kde xdg-desktop-portal-gtk
  pacman -S --noconfirm --needed partitionmanager filelight kolourpaint kcalc haruna ttf-droid noto-fonts-emoji net-tools
  pacman -S --noconfirm --needed plasma-firewall ufw
  #pacman -S --noconfirm --needed timeshift

  pacman -S --noconfirm --needed print-manager cups system-config-printer
  systemctl enable cups
  ufw allow 631/tcp

  pacman -S --noconfirm --needed base-devel git go
  pacman -S --noconfirm --needed chromium qbittorrent
  pacman -S --noconfirm --needed ark p7zip unarchiver
  pacman -S --noconfirm --needed gwenview qt6-imageformats
  pacman -S --noconfirm --needed virtualbox virtualbox-host-modules-arch

  if [[ $(pacman -Qe | grep -E "yay") != *"yay"* ]]; then
    sudo -u $SUDO_USER git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u $SUDO_USER makepkg -si --noconfirm --needed
    cd ..
    rm -rf yay
  fi

  sudo -u $SUDO_USER yay -S --noconfirm --needed dropbox

  pacman -S --noconfirm --needed steam-native-runtime gamemode lib32-gamemode lutris ### https://github.com/lutris/docs/blob/master/WineDependencies.md
  pacman -S --noconfirm --needed goverlay mangohud lib32-mangohud # vkbasalt lib32-vkbasalt

  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y com.github.tchx84.Flatseal org.onlyoffice.desktopeditors com.github.wwmm.easyeffects org.kde.kdenlive com.heroicgameslauncher.hgl net.davidotek.pupgui2 com.obsproject.Studio #org.videolan.VLC
  flatpak install -y com.leinardi.gst io.github.thetumultuousunicornofdarkness.cpu-x

  bash -c 'echo "vm.max_map_count=16777216" >> /etc/sysctl.d/99-sysctl.conf'

  ### DEV
  #pacman -S --noconfirm --needed code docker
  #flatpak install -y com.google.AndroidStudio rest.insomnia.Insomnia
  #flatpak install -y com.unity.UnityHub org.freedesktop.Sdk.Extension.dotnet org.freedesktop.Sdk.Extension.mono6

  echo "[Desktop Entry]
  Name=Trash
  Name[pt_BR]=Lixeira
  Comment=Contains deleted files
  Comment[pt_BR]=Contém arquivos deletados
  Icon=user-trash-full
  EmptyIcon=user-trash
  Type=Link
  URL=trash:/" > /home/$SUDO_USER/trash.desktop

  echo '# Add in ~/.bashrc or ~/.bash_profile
  function parse_git_branch () {
    git branch 2> /dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/(\1)/"
  }

  RED="\[\033[01;31m\]"
  YELLOW="\[\033[01;33m\]"
  GREEN="\[\033[01;32m\]"
  BLUE="\[\033[01;34m\]"
  NO_COLOR="\[\033[00m\]"

  # without host
  # PS1="$GREEN\u$NO_COLOR:$BLUE\w$YELLOW\$(parse_git_branch)$NO_COLOR\$ "
  # with host
  PS1="$GREEN\u@\h$NO_COLOR:$BLUE\w$YELLOW\$(parse_git_branch)$NO_COLOR\$ "' >> /home/$SUDO_USER/.bashrc


  ## FILESHARING
  pacman -S --noconfirm --needed kdenetwork-filesharing
  ufw allow CIFS
  mkdir /var/lib/samba/usershares
  groupadd -r sambashare
  chown root:sambashare /var/lib/samba/usershares
  chmod 1770 /var/lib/samba/usershares

  echo "[global]
    workgroup = WORKGROUP
    server string %h server (Samba, EndeavourOS)
    log file = /var/log/samba/log.%m
    max log size = 1000
    logging = file
    panic action = /usr/share/samba/panic-action %d
    server role = standalone server
    obey pam restrictions = yes
    unix password sync = yes
    passwd program = /usr/bin/passwd %u
    passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssucessfully* .
    pam password change = yes
    map to guest = bad user
    usershare allow guests = yes
    usershare max shares = 100
    usershare owner only = true
    usershare path = /var/lib/samba/usershares
    printing = CUPS

  [printers]
    comment = All Printers
    browseable = no
    path = /var/tmp
    printable = yes
    guest ok = no
    read only = yes
    create mask = 0700

  [print$]
    comment = Printer Drivers
    path = /var/lib/samba/printers
    browseable = yes
    read only = yes
    guest ok = no" > /etc/samba/smb.conf


  gpasswd sambashare -a $SUDO_USER

  #testparm

  systemctl enable smb

  reboot
}

function configZram {

    pacman -S zram-generator

    bash -c 'echo "[zram0]
        zram-size = ram * 2
        compression-algorithm = zstd
        swap-priority = 100
        fs-type = swap" > /etc/systemd/zram-generator.conf'

    systemctl daemon-reload

    systemctl start systemd-zram-setup@zram0.service
}

function configKeyringAutoUpdate {
  echo "[Unit]
    Description=Update archlinux-keyring regularly

    [Timer]
    OnCalendar=daily
    Persistent=true

    [Install]
    WantedBy=multi-user.target" > /usr/lib/systemd/system/update-keyring.timer

  echo "[Unit]
    After=network-online.target nss-lookup.target
    ConditionFileIsExecutable=/usr/bin/update-keyring
    Description=Update archlinux-keyring regularly
    Wants=network-online.target

    [Service]
    ExecStart=/usr/bin/update-keyring
    Restart=on-failure
    RestartSec=1minute" > /usr/lib/systemd/system/update-keyring.service

  echo "#!/usr/bin/bash

    pacman -Sy --needed --noconfirm archlinux-keyring" > /usr/bin/update-keyring

  chmod +x /usr/bin/update-keyring

  systemctl daemon-reload

  systemctl enable update-keyring.timer
}

archKde6

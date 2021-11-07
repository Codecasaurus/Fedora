# Generated by pykickstart v3.34
#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard --xlayouts='us (mac)','de (mac)'
# System language
lang de_DE.UTF-8
# Shutdown after installation
shutdown
# Network information
network  --bootproto=dhcp --device=link --activate
# Firewall configuration
firewall --enabled --service=mdns
# Use network installation
url --url="file:///PATH/"
# url --url="https://dl.fedoraproject.org/pub/fedora/linux/releases/35/Everything/x86_64/os/"
repo --name="fedora" --baseurl="https://dl.fedoraproject.org/pub/fedora/linux/releases/35/Everything/x86_64/os/"
repo --name="fedora-updates" --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f35&arch=x86_64
repo --name="rpmfusion-free" --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-35&arch=x86_64 --includepkgs="rpmfusion-free-release"
repo --name="rpmfusion-free-updates" --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-35&arch=x86_64
repo --name="rpmfusion-free-tainted" --mirrorlist=https://mirrors.rpmfusion.org/metalink?repo=free-fedora-tainted-35&arch=x86_64
repo --name="rpmfusion-nonfree" --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-35&arch=x86_64 --includepkgs="rpmfusion-nonfree-release"
repo --name="rpmfusion-nonfree-updates" --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-35&arch=x86_64
repo --name="rpmfusion-nonfree-tainted" --mirrorlist=https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-tainted-35&arch=x86_64
# System timezone
timezone Europe/Berlin
# SELinux configuration
selinux --permissive
# System services
services --enabled="NetworkManager,ModemManager,sshd"
# System bootloader configuration
bootloader --location=none
reqpart
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --size=30000

%post
# FIXME: it'd be better to get this installed from a package
cat > /etc/rc.d/init.d/livesys << EOF
#!/bin/bash
#
# live: Init script for live image
#
# chkconfig: 345 00 99
# description: Init script for live image.
### BEGIN INIT INFO
# X-Start-Before: display-manager
### END INIT INFO

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ]; then
    exit 0
fi

if [ -e /.liveimg-configured ] ; then
    configdone=1
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

livedir="LiveOS"
for arg in \`cat /proc/cmdline\` ; do
  if [ "\${arg##rd.live.dir=}" != "\${arg}" ]; then
    livedir=\${arg##rd.live.dir=}
    return
  fi
  if [ "\${arg##live_dir=}" != "\${arg}" ]; then
    livedir=\${arg##live_dir=}
    return
  fi
done

# enable swaps unless requested otherwise
swaps=\`blkid -t TYPE=swap -o device\`
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -n "\$swaps" ] ; then
  for s in \$swaps ; do
    action "Enabling swap partition \$s" swapon \$s
  done
fi
if ! strstr "\`cat /proc/cmdline\`" noswap && [ -f /run/initramfs/live/\${livedir}/swap.img ] ; then
  action "Enabling swap file" swapon /run/initramfs/live/\${livedir}/swap.img
fi

mountPersistentHome() {
  # support label/uuid
  if [ "\${homedev##LABEL=}" != "\${homedev}" -o "\${homedev##UUID=}" != "\${homedev}" ]; then
    homedev=\`/sbin/blkid -o device -t "\$homedev"\`
  fi

  # if we're given a file rather than a blockdev, loopback it
  if [ "\${homedev##mtd}" != "\${homedev}" ]; then
    # mtd devs don't have a block device but get magic-mounted with -t jffs2
    mountopts="-t jffs2"
  elif [ ! -b "\$homedev" ]; then
    loopdev=\`losetup -f\`
    if [ "\${homedev##/run/initramfs/live}" != "\${homedev}" ]; then
      action "Remounting live store r/w" mount -o remount,rw /run/initramfs/live
    fi
    losetup \$loopdev \$homedev
    homedev=\$loopdev
  fi

  # if it's encrypted, we need to unlock it
  if [ "\$(/sbin/blkid -s TYPE -o value \$homedev 2>/dev/null)" = "crypto_LUKS" ]; then
    echo
    echo "Setting up encrypted /home device"
    plymouth ask-for-password --command="cryptsetup luksOpen \$homedev EncHome"
    homedev=/dev/mapper/EncHome
  fi

  # and finally do the mount
  mount \$mountopts \$homedev /home
  # if we have /home under what's passed for persistent home, then
  # we should make that the real /home.  useful for mtd device on olpc
  if [ -d /home/home ]; then mount --bind /home/home /home ; fi
  [ -x /sbin/restorecon ] && /sbin/restorecon /home
  if [ -d /home/liveuser ]; then USERADDARGS="-M" ; fi
}

findPersistentHome() {
  for arg in \`cat /proc/cmdline\` ; do
    if [ "\${arg##persistenthome=}" != "\${arg}" ]; then
      homedev=\${arg##persistenthome=}
      return
    fi
  done
}

if strstr "\`cat /proc/cmdline\`" persistenthome= ; then
  findPersistentHome
elif [ -e /run/initramfs/live/\${livedir}/home.img ]; then
  homedev=/run/initramfs/live/\${livedir}/home.img
fi

# if we have a persistent /home, then we want to go ahead and mount it
if ! strstr "\`cat /proc/cmdline\`" nopersistenthome && [ -n "\$homedev" ] ; then
  action "Mounting persistent /home" mountPersistentHome
fi

if [ -n "\$configdone" ]; then
  exit 0
fi

# add fedora user with no passwd
action "Adding live user" useradd \$USERADDARGS -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser > /dev/null

# Remove root password lock
passwd -d root > /dev/null

# turn off firstboot for livecd boots
systemctl --no-reload disable firstboot-text.service 2> /dev/null || :
systemctl --no-reload disable firstboot-graphical.service 2> /dev/null || :
systemctl stop firstboot-text.service 2> /dev/null || :
systemctl stop firstboot-graphical.service 2> /dev/null || :

# don't use prelink on a running live image
sed -i 's/PRELINKING=yes/PRELINKING=no/' /etc/sysconfig/prelink &>/dev/null || :

# turn off mdmonitor by default
systemctl --no-reload disable mdmonitor.service 2> /dev/null || :
systemctl --no-reload disable mdmonitor-takeover.service 2> /dev/null || :
systemctl stop mdmonitor.service 2> /dev/null || :
systemctl stop mdmonitor-takeover.service 2> /dev/null || :

# don't enable the gnome-settings-daemon packagekit plugin
gsettings set org.gnome.software download-updates 'false' || :

# don't start cron/at as they tend to spawn things which are
# disk intensive that are painful on a live image
systemctl --no-reload disable crond.service 2> /dev/null || :
systemctl --no-reload disable atd.service 2> /dev/null || :
systemctl stop crond.service 2> /dev/null || :
systemctl stop atd.service 2> /dev/null || :

# turn off abrtd on a live image
systemctl --no-reload disable abrtd.service 2> /dev/null || :
systemctl stop abrtd.service 2> /dev/null || :

# Don't sync the system clock when running live (RHBZ #1018162)
sed -i 's/rtcsync//' /etc/chrony.conf

# Mark things as configured
touch /.liveimg-configured

# add static hostname to work around xauth bug
# https://bugzilla.redhat.com/show_bug.cgi?id=679486
echo "localhost" > /etc/hostname

EOF

# bah, hal starts way too late
cat > /etc/rc.d/init.d/livesys-late << EOF
#!/bin/bash
#
# live: Late init script for live image
#
# chkconfig: 345 99 01
# description: Late init script for live image.

. /etc/init.d/functions

if ! strstr "\`cat /proc/cmdline\`" rd.live.image || [ "\$1" != "start" ] || [ -e /.liveimg-late-configured ] ; then
    exit 0
fi

exists() {
    which \$1 >/dev/null 2>&1 || return
    \$*
}

touch /.liveimg-late-configured

# read some variables out of /proc/cmdline
for o in \`cat /proc/cmdline\` ; do
    case \$o in
    ks=*)
        ks="--kickstart=\${o#ks=}"
        ;;
    xdriver=*)
        xdriver="\${o#xdriver=}"
        ;;
    esac
done

# if liveinst or textinst is given, start anaconda
if strstr "\`cat /proc/cmdline\`" liveinst ; then
   plymouth --quit
   /usr/sbin/liveinst \$ks
fi
if strstr "\`cat /proc/cmdline\`" textinst ; then
   plymouth --quit
   /usr/sbin/liveinst --text \$ks
fi

# configure X, allowing user to override xdriver
if [ -n "\$xdriver" ]; then
   cat > /etc/X11/xorg.conf.d/00-xdriver.conf <<FOE
Section "Device"
	Identifier	"Videocard0"
	Driver	"\$xdriver"
EndSection
FOE
fi

EOF

chmod 755 /etc/rc.d/init.d/livesys
/sbin/restorecon /etc/rc.d/init.d/livesys
/sbin/chkconfig --add livesys

chmod 755 /etc/rc.d/init.d/livesys-late
/sbin/restorecon /etc/rc.d/init.d/livesys-late
/sbin/chkconfig --add livesys-late

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
releasever=$(rpm -q --qf '%{version}\n' --whatprovides system-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
echo "Packages within this LiveCD"
rpm -qa
# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Remove random-seed
rm /var/lib/systemd/random-seed

# Remove the rescue kernel and image to save space
# Installation will recreate these on the target
rm -f /boot/*-rescue*
%end

%post

cat >> /etc/rc.d/init.d/livesys << EOF


# disable updates plugin
cat >> /usr/share/glib-2.0/schemas/org.gnome.software.gschema.override << FOE
[org.gnome.software]
download-updates=false
FOE

# don't autostart gnome-software session service
rm -f /etc/xdg/autostart/gnome-software-service.desktop

# disable the gnome-software shell search provider
cat >> /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini << FOE
DefaultDisabled=true
FOE

# don't run gnome-initial-setup
mkdir ~liveuser/.config
touch ~liveuser/.config/gnome-initial-setup-done

# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
  # need to move it to anaconda.desktop to make shell happy
  mv /usr/share/applications/liveinst.desktop /usr/share/applications/anaconda.desktop

  cat >> /usr/share/glib-2.0/schemas/org.gnome.shell.gschema.override << FOE
[org.gnome.shell]
favorite-apps=['firefox.desktop', 'evolution.desktop', 'rhythmbox.desktop', 'shotwell.desktop', 'org.gnome.Nautilus.desktop', 'anaconda.desktop']
FOE

  # Make the welcome screen show up
  if [ -f /usr/share/anaconda/gnome/fedora-welcome.desktop ]; then
    mkdir -p ~liveuser/.config/autostart
    cp /usr/share/anaconda/gnome/fedora-welcome.desktop /usr/share/applications/
    cp /usr/share/anaconda/gnome/fedora-welcome.desktop ~liveuser/.config/autostart/
  fi

  # Copy Anaconda branding in place
  if [ -d /usr/share/lorax/product/usr/share/anaconda ]; then
    cp -a /usr/share/lorax/product/* /
  fi
fi

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up auto-login
cat > /etc/gdm/custom.conf << FOE
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=liveuser
FOE

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/

EOF

%end

%post
# Repositories
dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm https://prerelease.keybase.io/keybase_amd64.rpm
# Element
dnf -y copr enable taw/element && dnf -y install element
# negativo17 nvidia repository
dnf -y config-manager --add-repo=https://negativo17.org/repos/fedora-nvidia.repo
# Packages
dnf -y install rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted --refresh
# NVIDIA
# dnf -y install nvidia-driver nvidia-settings
# Signal Desktop as Flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub org.signal.Signal
# Czkawka as Flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub com.github.qarmin.czkawka
# Portfolio Performance
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub info.portfolio_performance.PortfolioPerformance
# DBeaverCommunity
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub io.dbeaver.DBeaverCommunity
# AusweisApp2
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub de.bund.ausweisapp.ausweisapp2
# WhatsAppQT
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub io.bit3.WhatsAppQT
# Zoom
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub us.zoom.Zoom
# Jabref
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub org.jabref.jabref

# Enable nemo as file manager (default: only available under cinnamon)
sed -i '/OnlyShowIn=X-Cinnamon/I s/^/#/' /usr/share/applications/nemo.desktop
# Set nemo as default file manager
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search

# dnf-automatic security upgrades
# timer configuration: /etc/systemd/system/multi-user.target.wants/dnf-automatic.timer
# echo -n '[commands]
# upgrade_type = security
# random_sleep = 0
# download_updates = yes
# apply_updates = yes

# [emitters]
# emit_via = stdio

# [email]
# email_from = dnf@localhost
# email_to = root@localhost
# email_host = localhost

# [command]

# [command_email]
# email_from = dnf@localhost
# email_to = root@localhost

# [base]
# debuglevel = 1' > /etc/dnf/automatic.conf;
# systemctl enable --now dnf-automatic.timer

# usbguard configuration #
# usbguard generate-policy > rules.conf
# cp rules.conf /etc/usbguard/rules.conf
# chmod 0600 /etc/usbguard/rules.conf
# edit configuration #
# vim /etc/usbguard/usbguard-daemon.conf
# systemctl enable --now usbguard
# enable notifier for user #
# systemctl enable --now --user usbguard-notifier.service

# For every user who wants to use Syncthing.
# systemctl enable --now syncthing@USER.service

rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
dnf -y install code

# Branding
sed -i -e 's/Generic release/Prodora/g' /etc/fedora-release /etc/issue
echo -e 'Prodora 35' > /etc/system-release
echo -e 'NAME=Prodora
VERSION="35 (Smart-Tux)"
ID=prodora
ID_LIKE=fedora
VERSION_ID=35
PRETTY_NAME="Prodora 35 (Smart-Tux)"
ANSI_COLOR="0;34"
LOGO=generic-logo-icon
CPE_NAME="cpe:/o:smart-tux:prodora:35"
HOME_URL="https://smart-tux.de/"
SUPPORT_URL="https://smart-tux.de/kontakt"
BUG_REPORT_URL="https://smart-tux.de/kontakt"
REDHAT_BUGZILLA_PRODUCT="Generic"
REDHAT_BUGZILLA_PRODUCT_VERSION=%{bug_version}
REDHAT_SUPPORT_PRODUCT="Generic"
REDHAT_SUPPORT_PRODUCT_VERSION=%{bug_version}
PRIVACY_POLICY_URL="https://smart-tux.de/"' > /etc/os-release
%end

%packages
@admin-tools
@anaconda-tools
@base-x
@container-management
@core
@development-tools
@editors
@firefox
@fonts
@gnome-desktop
@guest-desktop-agents
@hardware-support
@libreoffice
@multimedia
@networkmanager-submodules
@office
@printing
@sound-and-video
@system-tools
HandBrake
HandBrake-gui
NetworkManager-*
age
alacarte
anaconda
anaconda-live
asciinema
audacious
audacity-freeworld
backintime-qt
baobab
bijiben
blivet-gui
borgbackup
borgmatic
brasero
calibre
certbot
chkconfig
chromium-freeworld
clementine
cockpit
cockpit-machines
cockpit-networkmanager
cockpit-packagekit
cockpit-storaged
cockpit-system
darktable
dbus-x11
ddrescue
dialect
digikam
distribution-gpg-keys
distribution-gpg-keys-copr
dnf-automatic
dnf-plugin-system-upgrade
dracut-config-generic
dracut-live
dvdisaster
efibootmgr
evince
evolution
exfat-utils
fdupes
ffmpeg
filezilla
firefox
flatpak
freerdp
gedit
generic-logos
generic-release
generic-release-notes
gimp
gimp-heif-plugin
gimp-jxl-plugin
gimp-lensfun
gimp-resynthesizer
git-all
glibc-all-langpacks
gmic-gimp
gnome-books
gnome-calendar
gnome-chess
gnome-clocks
gnome-contacts
gnome-extensions-app
gnome-firmware
gnome-maps
gnome-online-accounts
gnome-shell-extension-apps-menu
gnome-shell-extension-background-logo
gnome-shell-extension-dash-to-dock
gnome-shell-extension-places-menu
gnome-shell-extension-system-monitor-applet
gnome-terminal
gnome-todo
gnome-tweaks
gnome-usage
gnome-weather
gnucash
gparted
grub2
grub2-efi
grub2-efi-*-cdboot
grub2-efi-ia32
gst
gstreamer1*
gthumb
guestfs-tools
htop
icedtea-web
iftop
initscripts
inkscape
java-openjdk
k3b
kdenlive
keepassxc
kernel
kernel-modules
kernel-modules-extra
kid3
krita
langpacks-de
langpacks-en
libaacs
libbdplus
libbluray-utils
libgnome-keyring
libheif
libimobiledevice-utils
libreoffice
libtool
libva-intel*
libva-utils
libva-vdpau-driver
libvirt
marker
memtest86+
mesa*
nemo
nemo-audio-tab
nemo-compare
nemo-extensions
nemo-fileroller
nemo-preview
nemo-python
nemo-seahorse
nemo-search-helpers
neofetch
nmap
nutty
obs-studio
ocl-icd
opencl-*
p7zip
p7zip-plugins
pam-u2f
pamu2fcfg
paperkey
pcsc-lite
phoronix-test-suite
picard
plantumlqeditor
playonlinux
powertop
python3-certbot-apache
python3-dnf-plugin-local
python3-dnf-plugins-extras-snapper
qemu
remmina
reptyr
screenfetch
seahorse
seahorse-nautilus
seahorse-sharing
sha3sum
shim
shim-ia32
simplescreenrecorder
snapper
soundconverter
spice-gtk
ssss
syncthing
sysbench
syslinux
terminator
testdisk
texlive-plantuml
texlive-scheme-full
texstudio
thunderbird
tikzit
tldr
transmission
usbguard
usbguard-notifier
vim-enhanced
virt-manager
virt-viewer
vlc
vulkan*
xorgxrdp
xrdp
youtube-dl
-@dial-up
-@input-methods
-@standard
-fedora-logos
-fedora-release
-fedora-release-notes
-gfs2-utils
-reiserfs-utils

%end

# Orange Pi 2E+
## Properties
* router + plex media player
* hostanme: kiska
* wlan0: HWMac 12:81:c6:e7:c5:62
* eth0: HWMac 02:81:c6:e7:c5:62
* Armbian: headless debian-bases server

## Armbian Stretch
Image can be found at http://www.orangepi.org/downloadresources/.

### Install on SD
Download and extract the archive
```
wget https://dl.armbian.com/orangepiplus2e/Debian_stretch_next.7z
7za e Debian_stretch_next.7z
```
As root, copy image to SD card and sync
```
sudo dd if=Armbian_5.59_Orangepiplus2e_Debian_stretch_next_4.14.65.img of=/dev/mmcblk0 && sync
```
Boot the orangepi with the SD card. 

### Initial config:
After login as root (root:1234), follow the initialisation step.

### Update the system to buster:
Update the system
```
apt update
apt upgrade
reboot
```
Reboot and un the `armbian-config` utils with:
```
armbian-config
```
And follow the menu to:
* System/Update firmware
* System/SSH: set `PermitRootLogin` to `no`
* System/ZSH
* System/minimal desktop
* Personal/Timezone: America/Anchorage
* Personal/Hostaneme: kiska
* Software/Headers
* Software/Full

### Upgrade the sytem to buster
Update repository sources from stretch to buster in `/etc/apt/sources.list`.

Comment out the `stretch-backports` repository and update
```
apt update
apt upgrade
reboot
```

## Install graphic server with mali kernel driver
To compile `mali` with `USING_UMP=0`, `libump` and its dependencies `dri2` are needed

### dri2
Install dependencies
```
apt install -y xutils-dev pkgconf libtool libx11-dev x11proto-dri2-dev libdrm-dev libxext-dev xorg-dev mesa-utils mesa-utils-extra
```
Clone, compile and install

```
git clone https://github.com/robclark/libdri2
cd libdri2/
autoreconf -i
./configure --prefix=/usr
make && make install
ldconfig
cd ..
```

### libump
Clone, compile and install
```
git clone https://github.com/linux-sunxi/libump
cd libump/
autoreconf -i
./configure --prefix=/usr
make
make install
cd ..
```

### Mali driver
Check if `CONFIG_CMA` and `CONFIG_DMA_CMA` are enabled in the kernel with
```
grep 'CONFIG_CMA' /boot/config-$(uname -r)
grep 'CONFIG_DMA_CMA' /boot/config-$(uname -r)
```
Install linux sources and headers for the current kernel version. 
```
apt install -y linux-headers-next-sunxi linux-image-next-sunxi quilt
```
Check if the kernel name between the running kernel (`uname -a`) and the sources are the same  in `/usr/src/linux-source-$(uname -r)/include/generated/utsrelease.h` and '`/usr/src/linux-source-$(uname -r)/include/config/kernel.release`. It should match the kernel version `4.14.18-sunxi`, otherwise modify it to match the running kernel. 

Build the kernel module after applying patch TODO STILL NOT WORKING
```
cd ~
git clone https://github.com/mripard/sunxi-mali.git
cd sunxi-mali
./build.sh -r r6p2 -a
make JOBS=4 USING_UMP=0 BUILD=release USING_PROFILING=0 MALI_PLATFORM=sunxi USING_DVFS=1 USING_DEVFREQ=1 KDIR=/usr/src/linux-headers-$(uname -r) CROSS_COMPILE=arm-linux-gnueabihf- -C r6p2/src/devicedrv/mali
make JOBS=4 USING_UMP=0 BUILD=release USING_PROFILING=0 MALI_PLATFORM=sunxi USING_DVFS=1 USING_DEVFREQ=1 KDIR=/usr/src/linux-headers-$(uname -r) CROSS_COMPILE=arm-linux-gnueabihf- -C r6p2/src/devicedrv/mali install
cd ..
```
Load the module
```
depmod
modprobe mali
```
Copy the blob 
```
git clone https://github.com/free-electrons/mali-blobs.git
cd mali-blobs
cp -a r6p2/arm/fbdev/lib* /usr/lib
cp -a r6p2/arm/fbdev/lib* /usr/lib/arm-linux-gnueabihf
cd ..
```
Set permission to mali:
```
echo "KERNEL==\"mali\", MODE=\"0660\", GROUP=\"video\"" > /etc/udev/rules.d/50-mali.rules
```

### Install fbturbo driver 

Build driver
```
git clone -b 0.4.0 https://github.com/ssvb/xf86-video-fbturbo.git
cd xf86-video-fbturbo
autoreconf -vi
./configure --prefix=/usr
make
make install
```
Configure Xorg Server
```
cp xorg.conf /etc/X11/xorg.conf.d/99-sunxifbturbo.conf
cd ..
```

### Install ther xerver
Install XFCE
```
apt install xfce4
```
Install input driver
```
apt install  xserver-xorg-input-all xterm
```

Check if the correct driver (`FBTURBO`) is loaded in `/var/log/Xorg.0.log` in a X session
```
...
(II) Module fbturbo: vendor="X.Org Foundation"
   compiled for 1.12.4, module version = 0.4.0
   Module class: X.Org Video Driver
   ABI class: X.Org Video Driver, version 12.1
(II) FBTURBO: driver for framebuffer: fbturbo
(--) using VT number 7
...
```
Check and es acceleration with
```
es2gears
glxgears
es2_infos
glxinfos
```


### Install to EMMC
Copy SD to EMMC, with
```
nand-sata-install
```
Use SD as storage. Format SD card as f2fs
```
mkfs.f2fs /dev/mmcblk0p1 
mkdir /mnt/data
```
Add to mountfs:
```
/dev/mmcblk0p1  /mnt/data       f2fs    defaults,nofail,x-systemd.device-timetout=1     0 2
```
Give write permission to `/mnt/data` to the group users
```
usermod -a -G users megavolts
chown root:users /mnt/data -R
chmod 775 /mnt/data/ -R
```


## Essential packages
```
apt install -y mlocate tilda midori tigervnc-standalone-server tigervnc-common tigervnc-scraping-server nmap
updatedb
```

### Set up a tigervnc server
Run `vncserver` and setup a password
~/.vnc/xstartup
```
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
```
Make sure ~/.vnc/xstartup has a execute permission:
```
chmod u+x ~/.vnc/xstartup
```
Edit the optional config file `~/.vnc/config`:
```
securitytypes=tlsvnc
desktop=sandbox
geometry=1200x700
dpi=96
localhost
alwaysshared
```
Create a user service script at `/usr/lib/systemd/user/vncserver@.service`:
```
# /usr/lib/systemd/user/vncserver@.service
#
# 1. Switches for vncserver should be entered in ~/.vnc/config rather than
#    hard-coded into this unit file. See the vncserver(1) manpage.
#
# 2. Users wishing for the server to continue running after the owner logs
#    out MUST enable 'linger' with loginctl like this:
#    `loginctl enable-linger username`
#    
# 3. The server can be enabled and started like this once configured:
#    `systemctl --user start vncserver@:<display>.service`
#    `systemctl --user enable vncserver@:<display>.service`

[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
ExecStartPre=/bin/bash -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver %i
ExecStop=/usr/bin/vncserver -kill %i

[Install]
WantedBy=default.target
```
Start the service:
```
systemctl --user start vncserver@:1.service
```
Make sure the vncserver does not stop after you disconnect:
```
loginctl enable-linger kiska
```
To log in remotly via ssh
```
ssh megavolts@10.25.166.154 -L 5901:localhost:5901
```
And then log into vnc
```
vncviewer localhost:5901
```
TODO keep the session alive

### x0vncserver
User x0vncserver to get remote access to the current desktop runnin on the host.

Create a system service script at `/etc/systemd/system/x0vncserver.service`:
```
[Unit]
Description=Remote desktop service (VNC)
After=syslog.target network.target

[Service]
Type=forking
User=kiska
ExecStart=/bin/bash -c '/usr/bin/x0vncserver -display :0 -rfbport 5900 -passwordfile /home/kiska/.vnc/passwd &'

[Install]
WantedBy=multi-user.target
```
Start the service on demand:
```
systemctl start x0vncserver
```
And then take control via
```
vncviewer IP:0
```
Enable audio, with pulsaudio
```
apt install -y pulseaudio pulseaudio-dlna pulseaudio-module-bluetooth pulseaudio-equalizer pulseaudio-module-jack pulseaudio-zero
apt install -y xfce4-pulseaudio-plugin pavuontrol paprefs pavumeter pulseaudio-module-zeroconf pamix pasystray
pulseuadio -D
```

## Install PlexMediaServer
Add the repositories and key, as root:
```
wget -O - https://dev2day.de/pms/dev2day-pms.gpg.key | sudo apt-key add -
echo "deb https://dev2day.de/pms/ buster main" | sudo tee /etc/apt/sources.list.d/pms.list
apt-get update
```
Install plex and start the service as plex user
```
apt-get install plexmediaserver-installer
service plexmediaserver start
service plexmediaserver enable
```
### Remote config
To set up plex remotely, create a ssh tunnel between the server and the host:
```
ssh IP -L 8888:localhost:32400
```
In a webbrowser, configure plex media server at 'localhost:8888/web'

## Install PlexMediaPlayer
### Install libdvpau-sunxi
Install dependencies
```
apt install -y libpixman-1-dev libvdpau-dev pkg-config
```
Compile libcedrus
```
git clone https://github.com/linux-sunxi/libcedrus.git
cd libcedrus
make
make install
cd ..
```
Set permission
```
echo "KERNEL==\"disp\", MODE=\"0660\", GROUP=\"video\"" > /etc/udev/rules.d/50-disp.rules
echo "KERNEL==\"cedar\", MODE=\"0660\", GROUP=\"video\"" > /etc/udev/rules.d/50-cedar_dev.rules
```
Compile libvdpau-sunxi
```
git clone https://github.com/linux-sunxi/libvdpau-sunxi.git
cd libvdpau-sunxi
make
make install
ldconfig
ln -s /usr/lib/arm-linux-gnueabihf/vdpau/libvdpau_sunxi.so.1 /usr/lib/libvdpau_nvidia.so
cd ..
``` 

### Compile mpv
Install dependencies
```
apt install -y autoconf automake libtool libharfbuzz-dev libfreetype6-dev libfontconfig1-dev libvdpau-dev libva-dev  yasm libasound2-dev libpulse-dev libuchardet-dev zlib1g-dev libfribidi-dev git libsdl2-dev cmake libgnutls28-dev libgnutls30
```
Compile `mpv` with `ffmpeg`
```
git clone https://github.com/mpv-player/mpv-build.git
cd mpv-build
echo --enable-libmpv-shared > mpv_options
./rebuild -j4
./install
ldconfig
cd ..
```

### Install Qt>5.11.1
Install the following dependencies, for build essentials
```
apt install -y qtwebengine5-dev qml-module-qtwebengine libqt5x11extras5-dev qml-module-qtwebchannel qml-module-qtquick-controlsplex
```

### Compile PMP
Clone, build PMP in a subdir and install
```
git clone git://github.com/plexinc/plex-media-player
cd plex-media-player
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Debug -DQTROOT=/usr/bin/ -DCMAKE_INSTALL_PREFIX=/usr/local/ ..
make -j4
make install
cd ..
```


## Configure AP/router
```
apt install -y hostapd dnsmasq bridge-utils
```
### Network interfaces
* bridge `br0` between `eth0` and `wlan0`
* NAT between `usb0` and `br0`
Edit `/etc/network/interfaces.hotspot`:
```
source /etc/network/interfaces.d/*

# Wired adapter #1
auto eth0
allow-hotplug eth0
no-auto-down eth0
iface eth0 inet manual

# Wireless adapter #1
auto wlan0
allow-hotplug wlan0
no-auto-down wlan0
iface wlan0 inet manual

# Thethered usb connection
auto usb0
iface usb0 inet dhcp

# Local loopback
auto lo
iface lo inet loopback

# Bridge br0: eth0 <-> wlan0
auto br0
iface br0 inet static
        bridge_ports eth0 wlan0
        address 10.0.0.1
        netmask 255.255.255.0

post-up iptables-restore < /etc/iptables/iptables.hostapd
        
```
Restart network
```
systemctl stop NetworkManager
systemctl start networking
systemctl enable networking
```

### Hostpad
Adjust the option in `/etc/hostapd.conf`, especially `ssid` and `wpa_passphrase`:
```
interface=wlan0
bridge=br0

ssid=RedTrim
driver=nl80211

hw_mode=g
channel=2

wpa=3
auth_algs=1

rsn_pairwise=CCMP
wpa_key_mgmt=WPA-PSK
wpa_passphrase=113RoxieRd
```
Uncomment in `/etc/default/hostapd`
```
DAEMON_CONF="/etc/hostapd.conf"
```
Start and enable on success `hostapd.service`
```
systemctl start hostapd
systemctl enable hostapd
```

### Configure dnsmasq
Adjust the option in `/etc/dnsmasq.conf`, especially `interface` and `dhcp-range`:
```
# DNS server
server=8.8.8.8
server=8.8.4.4

interface=br0
dhcp-range=10.0.0.2,10.0.0.22,255.255.255.0,24h
```
If needed reserve some IP, in `/etc/dnsmas.conf`
```
# IP reserved
# ulva, mediaserver
dhcp-host=30:85:A9:3C:4F:FE,10.0.0.11
```
Start the service `dnsmasq` and enable on success
```
systemctl start dnsmasq
systemctl enable dnsmasq
```

### Enable packet forwarding
For ipv4:
```
sysctl net.ipv4.ip_forward=1
```
And make the change persistant in `/etc/sysctl.d/30-ipforward.conf`
```
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1  
```

### Enable NAT:
Add the following IP tables rules:
```
iptables -t nat -A POSTROUTING -o usb0 -j MASQUERADE
iptables -A FORWARD -o usb0 -i br0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i br0 -o usb0 -j ACCEPT
iptables -A FORWARD -o eth0 -i br0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i br0 -o eth0 -j ACCEPT
```
Save the rules
```
mkdir /etc/iptables
iptables-save > /etc/iptables/iptables.hostapd
```

### Create script to switch on/off the AP
```
nano -w /usr/bin/switchAP.sh
#!/bin/bash
case $1 in:
   start)
      cp /etc/network/interfaces.hotspot /etc/network/interfaces
      systemctl stop NetworkManager
      systemctl start networking
      systemctl restart hostapd
      systemctl restart dnsmasq
      ;;
   stop)
      cp /etc/network/interfaces.default /ect/network/interfaces
      systemctl stop networking
      systemctl start NetworkManager
      systemctl stop hostapd
      systemctl stop dnsmasq
      ;;
   restart)
      stop
      start
      ;;
     *)
   echo $"Usage: $0 {start|stop|restart}"
   exit 1
esac
```
Make it executable
```
chmod +x /usr/bin/switchAP.sh
```

### Source:
* https://github.com/mripard/sunxi-mali
* https://github.com/mripard/sunxi-mali/issues/34
* http://linux-sunxi.org/Xorg#fbturbo_driver


# Source
* https://diyprojects.io/orange-pi-plus-2e-unpacking-installing-armbian-emmc-memory/




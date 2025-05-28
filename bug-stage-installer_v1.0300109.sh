#!/bin/bash

# Verificación de root
if [ "$(id -u)" != "0" ]; then
   echo "Este script debe ejecutarse como root" 1>&2
   exit 1
fi

# Configuración básica
export LFS=/mnt/lfs
INSTALL_LOG="/tmp/lfs-install.log"
TARGET_ARCH="x86_64"
DNF_CONF="/etc/dnf/dnf.conf"

# Menú principal
function main_menu() {
    clear
    echo "============================================"
    echo " Instalador de Linux From Scratch Personalizado"
    echo "============================================"
    echo " 1. Preparar particiones del disco"
    echo " 2. Instalar sistema base (OpenRC)"
    echo " 3. Instalar DNF Package Manager"
    echo " 4. Instalar Xorg (sin Wayland)"
    echo " 5. Instalar GNOME Desktop"
    echo " 6. Instalar Ptyxis Terminal"
    echo " 7. Configuración final del sistema"
    echo " 8. Instalación completa automatizada"
    echo " 9. Salir"
    echo "============================================"
    
    read -p "Seleccione una opción [1-9]: " option
    case $option in
        1) prepare_disk ;;
        2) install_base_system ;;
        3) install_dnf ;;
        4) install_xorg ;;
        5) install_gnome ;;
        6) install_ptyxis ;;
        7) final_config ;;
        8) full_installation ;;
        9) exit 0 ;;
        *) echo "Opción inválida"; sleep 1; main_menu ;;
    esac
}

# 1. Preparación de disco
function prepare_disk() {
    clear
    echo "=== PREPARACIÓN DE DISCO ==="
    echo "Listando dispositivos disponibles:"
    lsblk
    
    read -p "Ingrese el dispositivo a particionar (ej. /dev/sda): " disk
    read -p "¿Crear tabla de particiones nueva? [y/N]: " new_table
    
    if [[ "$new_table" =~ [yY] ]]; then
        parted -s $disk mklabel gpt
    fi
    
    # Crear particiones
    echo "Creando particiones..."
    parted -s $disk mkpart primary ext4 1MiB 500MiB
    parted -s $disk set 1 boot on
    parted -s $disk mkpart primary ext4 500MiB 20GiB
    parted -s $disk mkpart primary linux-swap 20GiB 24GiB
    
    # Formatear particiones
    mkfs.ext4 ${disk}1
    mkfs.ext4 ${disk}2
    mkswap ${disk}3
    swapon ${disk}3
    
    # Montar particiones
    mkdir -p $LFS
    mount ${disk}2 $LFS
    mkdir -p $LFS/boot
    mount ${disk}1 $LFS/boot
    
    echo "Particionado completado. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 2. Instalar sistema base con OpenRC
function install_base_system() {
    clear
    echo "=== INSTALACIÓN DEL SISTEMA BASE ==="
    
    # Verificar montaje
    if ! mountpoint -q $LFS; then
        echo "Error: $LFS no está montado. Configure las particiones primero."
        sleep 2
        main_menu
        return
    fi
    
    echo "Descargando e instalando paquetes base..."
    mkdir -p $LFS/sources
    cd $LFS/sources
    
    # Descargar paquetes esenciales
    wget http://www.linuxfromscratch.org/lfs/view/stable-systemd/wget-list
    wget --input-file=wget-list --continue
    
    # Extraer y compilar (simplificado para el ejemplo)
    for pkg in *.tar.*; do
        tar xf $pkg
        cd ${pkg%.tar.*}
        
        # Configuración especial para paquetes clave
        if [[ "$pkg" == *"glibc"* ]]; then
            ./configure --prefix=/usr --disable-systemd --without-selinux
        else
            ./configure --prefix=/usr
        fi
        
        make -j$(nproc)
        make DESTDIR=$LFS install
        cd ..
    done
    
    # Instalar OpenRC
    echo "Instalando OpenRC..."
    wget https://github.com/OpenRC/openrc/archive/refs/tags/0.44.tar.gz -O openrc-0.44.tar.gz
    tar xvf openrc-0.44.tar.gz
    cd openrc-0.44
    make DESTDIR=$LFS install
    
    # Configuración básica de OpenRC
    chroot $LFS /bin/bash -c "
        mkdir -p /etc/runlevels/{boot,sysinit,default,nonetwork,shutdown}
        ln -s /etc/init.d/{devfs,dmesg,fsck,hostname,hwclock,modules} /etc/runlevels/sysinit/
        ln -s /etc/init.d/{mount-ro,urandom} /etc/runlevels/shutdown/
        ln -s /etc/init.d/{consolefont,keymaps,udev} /etc/runlevels/boot/
    "
    
    echo "Sistema base instalado. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 3. Instalar DNF
function install_dnf() {
    clear
    echo "=== INSTALACIÓN DE DNF ==="
    
    chroot $LFS /bin/bash -c "
        # Instalar dependencias
        dnf install -y python3 rpm libsolv hawkey librepo libcomps libmodulemd
        
        # Instalar DNF desde git
        cd /tmp
        git clone https://github.com/rpm-software-management/dnf.git
        cd dnf
        python3 setup.py build
        python3 setup.py install
        
        # Configuración básica
        mkdir -p /etc/dnf
        echo '[main]' > /etc/dnf/dnf.conf
        echo 'gpgcheck=1' >> /etc/dnf/dnf.conf
        echo 'installonly_limit=3' >> /etc/dnf/dnf.conf
        echo 'clean_requirements_on_remove=True' >> /etc/dnf/dnf.conf
        echo 'best=True' >> /etc/dnf/dnf.conf
    "
    
    echo "DNF instalado correctamente. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 4. Instalar Xorg sin Wayland
function install_xorg() {
    clear
    echo "=== INSTALACIÓN DE XORG ==="
    
    chroot $LFS /bin/bash -c "
        dnf install -y xorg-x11-server-Xorg xorg-x11-apps xorg-x11-drivers \
                       xorg-x11-xinit --exclude=*wayland*
        
        # Configuración para deshabilitar Wayland
        mkdir -p /etc/X11/xorg.conf.d
        echo 'Section \"ServerFlags\"' > /etc/X11/xorg.conf.d/00-no-wayland.conf
        echo '    Option \"AllowEmptyInput\" \"off\"' >> /etc/X11/xorg.conf.d/00-no-wayland.conf
        echo '    Option \"DontVTSwitch\" \"off\"' >> /etc/X11/xorg.conf.d/00-no-wayland.conf
        echo '    Option \"DontZap\" \"off\"' >> /etc/X11/xorg.conf.d/00-no-wayland.conf
        echo 'EndSection' >> /etc/X11/xorg.conf.d/00-no-wayland.conf
    "
    
    echo "Xorg instalado sin Wayland. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 5. Instalar GNOME sin systemd
function install_gnome() {
    clear
    echo "=== INSTALACIÓN DE GNOME ==="
    
    chroot $LFS /bin/bash -c "
        dnf install -y gnome-session gnome-shell gnome-terminal nautilus gdm \
                       gnome-control-center gnome-tweaks gnome-backgrounds \
                       --exclude=*systemd* --exclude=*wayland*
        
        # Configurar GDM con OpenRC
        echo '#!/sbin/openrc-run' > /etc/init.d/gdm
        echo 'command=\"/usr/sbin/gdm\"' >> /etc/init.d/gdm
        echo 'command_args=\"--nodaemon\"' >> /etc/init.d/gdm
        echo 'pidfile=\"/run/gdm.pid\"' >> /etc/init.d/gdm
        chmod +x /etc/init.d/gdm
        rc-update add gdm default
        
        # Configuración adicional de GNOME
        gsettings set org.gnome.settings-daemon.plugins.power active false
        gsettings set org.gnome.settings-daemon.plugins.background active false
    "
    
    echo "GNOME instalado sin systemd. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 6. Instalar Ptyxis Terminal
function install_ptyxis() {
    clear
    echo "=== INSTALACIÓN DE PTYXIS TERMINAL ==="
    
    chroot $LFS /bin/bash -c "
        dnf install -y vte291-devel gtk3-devel cmake vala
        cd /tmp
        git clone https://github.com/ptyxis/ptyxis.git
        cd ptyxis
        mkdir build
        cd build
        cmake ..
        make
        make install
    "
    
    echo "Ptyxis Terminal instalado. Volviendo al menú principal..."
    sleep 2
    main_menu
}

# 7. Configuración final
function final_config() {
    clear
    echo "=== CONFIGURACIÓN FINAL ==="
    
    # Configurar usuario
    read -p "Nombre de usuario para el nuevo sistema: " username
    chroot $LFS /bin/bash -c "
        useradd -m -G audio,video,wheel $username
        passwd $username
        passwd root
    "
    
    # Configurar red
    chroot $LFS /bin/bash -c "
        dnf install -y dhclient networkmanager-openrc
        rc-update add NetworkManager default
    "
    
    # Configurar GRUB
    chroot $LFS /bin/bash -c "
        dnf install -y grub2
        grub-install ${disk}
        grub-mkconfig -o /boot/grub/grub.cfg
    "
    
    # Crear fstab
    echo "# <file system> <mount point>   <type>  <options>       <dump>  <pass>" > $LFS/etc/fstab
    echo "${disk}2       /               ext4    defaults        1       1" >> $LFS/etc/fstab
    echo "${disk}1       /boot           ext4    defaults        1       2" >> $LFS/etc/fstab
    echo "${disk}3       none            swap    sw              0       0" >> $LFS/etc/fstab
    
    echo "Configuración final completada. El sistema está listo para usar."
    read -p "¿Desea reiniciar ahora? [y/N]: " reboot_now
    if [[ "$reboot_now" =~ [yY] ]]; then
        umount -R $LFS
        reboot
    fi
    
    main_menu
}

# 8. Instalación completa automatizada
function full_installation() {
    echo "=== INSTALACIÓN COMPLETA AUTOMATIZADA ==="
    echo "Este proceso tomará bastante tiempo..."
    
    prepare_disk
    install_base_system
    install_dnf
    install_xorg
    install_gnome
    install_ptyxis
    final_config
    
    echo "¡Instalación completada con éxito!"
}

# Iniciar menú principal
main_menu

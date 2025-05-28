#!/bin/bash

# Verificación de root
if [ "$(id -u)" != "0" ]; then
   echo "Este script debe ejecutarse como root" 1>&2
   exit 1
fi

# Configuración básica
INSTALL_LOG="/tmp/lfs-postinstall.log"

function main_menu() {
    clear
    echo "============================================"
    echo " Utilidades de Post-Instalación LFS"
    echo "============================================"
    echo " 1. Configurar usuarios adicionales"
    echo " 2. Instalar controladores propietarios"
    echo " 3. Configurar red avanzada"
    echo " 4. Instalar software adicional"
    echo " 5. Personalizar GNOME"
    echo " 6. Salir"
    echo "============================================"
    
    read -p "Seleccione una opción [1-6]: " option
    case $option in
        1) config_users ;;
        2) install_drivers ;;
        3) config_network ;;
        4) install_software ;;
        5) customize_gnome ;;
        6) exit 0 ;;
        *) echo "Opción inválida"; sleep 1; main_menu ;;
    esac
}

function config_users() {
    clear
    echo "=== CONFIGURACIÓN DE USUARIOS ==="
    
    read -p "Nombre del nuevo usuario: " newuser
    useradd -m -G audio,video,wheel $newuser
    passwd $newuser
    
    read -p "¿Desea agregar más usuarios? [y/N]: " more_users
    if [[ "$more_users" =~ [yY] ]]; then
        config_users
    else
        main_menu
    fi
}

function install_drivers() {
    clear
    echo "=== CONTROLADORES PROPIETARIOS ==="
    
    echo "1. Controladores NVIDIA"
    echo "2. Controladores AMD"
    echo "3. Controladores WiFi"
    echo "4. Volver"
    
    read -p "Seleccione una opción [1-4]: " driver_opt
    case $driver_opt in
        1)
            echo "Instalando controladores NVIDIA..."
            dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
            echo "¡Controladores instalados! Reinicie para aplicar los cambios."
            ;;
        2)
            echo "Instalando controladores AMD..."
            dnf install -y xorg-x11-drv-amdgpu
            ;;
        3)
            echo "Instalando firmware WiFi..."
            dnf install -y linux-firmware
            ;;
        4)
            main_menu
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    sleep 2
    main_menu
}

function config_network() {
    clear
    echo "=== CONFIGURACIÓN DE RED ==="
    
    echo "1. Configurar WiFi"
    echo "2. Configurar red por cable"
    echo "3. Configurar proxy"
    echo "4. Volver"
    
    read -p "Seleccione una opción [1-4]: " net_opt
    case $net_opt in
        1)
            echo "Configurando WiFi..."
            nmtui
            ;;
        2)
            echo "Configurando red por cable..."
            nmtui
            ;;
        3)
            read -p "URL del proxy (ej: http://proxy.example.com:8080): " proxy_url
            echo "export http_proxy=\"$proxy_url\"" >> /etc/profile
            echo "export https_proxy=\"$proxy_url\"" >> /etc/profile
            echo "Proxy configurado correctamente."
            ;;
        4)
            main_menu
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    sleep 2
    main_menu
}

function install_software() {
    clear
    echo "=== SOFTWARE ADICIONAL ==="
    
    echo "1. Suite ofimática"
    echo "2. Navegadores web"
    echo "3. Multimedia"
    echo "4. Herramientas de desarrollo"
    echo "5. Volver"
    
    read -p "Seleccione una opción [1-5]: " soft_opt
    case $soft_opt in
        1)
            dnf install -y libreoffice
            ;;
        2)
            echo "1. Firefox"
            echo "2. Chromium"
            echo "3. Ambos"
            read -p "Seleccione: " browser_opt
            case $browser_opt in
                1) dnf install -y firefox ;;
                2) dnf install -y chromium ;;
                3) dnf install -y firefox chromium ;;
                *) echo "Opción inválida" ;;
            esac
            ;;
        3)
            dnf install -y vlc ffmpeg
            ;;
        4)
            dnf install -y git gcc make python3 nodejs
            ;;
        5)
            main_menu
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    sleep 2
    main_menu
}

function customize_gnome() {
    clear
    echo "=== PERSONALIZACIÓN DE GNOME ==="
    
    echo "1. Cambiar tema"
    echo "2. Instalar extensiones"
    echo "3. Configurar fondos"
    echo "4. Volver"
    
    read -p "Seleccione una opción [1-4]: " gnome_opt
    case $gnome_opt in
        1)
            dnf install -y gnome-themes-extra
            echo "Temas adicionales instalados. Use gnome-tweaks para cambiarlos."
            ;;
        2)
            dnf install -y chrome-gnome-shell
            echo "Visite https://extensions.gnome.org/ para instalar extensiones."
            ;;
        3)
            mkdir -p /usr/share/backgrounds/custom
            read -p "Ruta completa a la imagen de fondo: " bg_path
            cp "$bg_path" /usr/share/backgrounds/custom/
            chmod 644 /usr/share/backgrounds/custom/*
            ;;
        4)
            main_menu
            ;;
        *)
            echo "Opción inválida"
            ;;
    esac
    
    sleep 2
    main_menu
}

# Iniciar menú principal
main_menu

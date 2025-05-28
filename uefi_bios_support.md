# Instalación de Soporte UEFI/BIOS en LFS Personalizado

Para implementar soporte dual (UEFI y BIOS) en tu distribución LFS personalizada, necesitarás modificar el instalador y añadir componentes específicos. Aquí te detallo cómo hacerlo:

## 1. Modificaciones al Script de Instalación (`bug-stage-installer_v1.03xxxxx.sh`)

### Detección Automática de Firmware:

```bash
function detect_firmware() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI"
    else
        echo "BIOS"
    fi
}
```

### Modificación a la Función `prepare_disk()`:

```bash
function prepare_disk() {
    clear
    echo "=== PREPARACIÓN DE DISCO ==="
    FIRMWARE_TYPE=$(detect_firmware)
    echo "Detectado firmware: $FIRMWARE_TYPE"
    
    lsblk
    read -p "Ingrese el dispositivo a particionar (ej. /dev/sda): " disk
    
    # Crear tabla de particiones
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        parted -s $disk mklabel gpt
        # Partición ESP (EFI System Partition)
        parted -s $disk mkpart primary fat32 1MiB 513MiB
        parted -s $disk set 1 esp on
        # Partición root
        parted -s $disk mkpart primary ext4 513MiB 20GiB
        # Swap
        parted -s $disk mkpart primary linux-swap 20GiB 24GiB
        
        # Formatear
        mkfs.fat -F32 ${disk}1
        mkfs.ext4 ${disk}2
        mkswap ${disk}3
        swapon ${disk}3
        
        # Montar
        mkdir -p $LFS/boot/efi
        mount ${disk}1 $LFS/boot/efi
    else
        parted -s $disk mklabel msdos
        # Partición boot (BIOS)
        parted -s $disk mkpart primary ext4 1MiB 513MiB
        parted -s $disk set 1 boot on
        # Partición root
        parted -s $disk mkpart primary ext4 513MiB 20GiB
        # Swap
        parted -s $disk mkpart primary linux-swap 20GiB 24GiB
        
        # Formatear
        mkfs.ext4 ${disk}1
        mkfs.ext4 ${disk}2
        mkswap ${disk}3
        swapon ${disk}3
        
        # Montar
        mkdir -p $LFS/boot
        mount ${disk}1 $LFS/boot
    fi
    
    mount ${disk}2 $LFS
    echo "Particionado completado para $FIRMWARE_TYPE"
}
```

## 2. Paquetes Adicionales Necesarios

### Para Soporte UEFI:

```bash
function install_uefi_support() {
    chroot $LFS /bin/bash -c "
        dnf install -y efibootmgr grub2-efi-x64 shim
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LFS
        grub-mkconfig -o /boot/grub/grub.cfg
        
        # Instalar shim para Secure Boot (opcional)
        cp /boot/efi/EFI/fedora/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
        cp /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi
    "
}
```

### Para Soporte BIOS Legacy:

```bash
function install_bios_support() {
    chroot $LFS /bin/bash -c "
        dnf install -y grub2
        grub-install $disk
        grub-mkconfig -o /boot/grub/grub.cfg
    "
}
```

## 3. Modificación a la Función `final_config()`

```bash
function final_config() {
    FIRMWARE_TYPE=$(detect_firmware)
    
    # Configuración de GRUB según firmware
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        install_uefi_support
    else
        install_bios_support
    fi
    
    # Configuración adicional común...
}
```

## 4. Configuración del Bootloader Dual (UEFI+BIOS)

Para sistemas que necesiten soporte dual:

```bash
function install_dual_boot_support() {
    chroot $LFS /bin/bash -c "
        # Instalar paquetes para ambos modos
        dnf install -y grub2-efi-x64 grub2-common efibootmgr shim
        
        # Instalar para BIOS
        grub-install $disk
        
        # Instalar para UEFI
        grub-install --target=x86_64-efi --efi-directory=/boot/efi \
                    --bootloader-id=LFS --recheck --no-nvram
        
        # Configurar GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
        
        # Configurar NVRAM (solo UEFI)
        efibootmgr --create --disk $disk --part 1 \
                  --loader /EFI/LFS/grubx64.efi \
                  --label "LFS Custom" --verbose
    "
}
```

## 5. Configuración del FSTAB para Ambos Casos

Modifica la creación del fstab para manejar ambos casos:

```bash
# Crear fstab
echo "# <file system> <mount point>   <type>  <options>       <dump>  <pass>" > $LFS/etc/fstab

if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
    echo "${disk}1       /boot/efi       vfat    umask=0077      0       1" >> $LFS/etc/fstab
    echo "${disk}2       /               ext4    defaults        1       2" >> $LFS/etc/fstab
else
    echo "${disk}1       /boot           ext4    defaults        1       2" >> $LFS/etc/fstab
    echo "${disk}2       /               ext4    defaults        1       1" >> $LFS/etc/fstab
fi

echo "${disk}3       none            swap    sw              0       0" >> $LFS/etc/fstab
```

## 6. Verificación Post-Instalación

Añade una función para verificar la instalación del bootloader:

```bash
function verify_bootloader() {
    FIRMWARE_TYPE=$(detect_firmware)
    
    if [[ "$FIRMWARE_TYPE" == "UEFI" ]]; then
        chroot $LFS /bin/bash -c "
            efibootmgr -v
            [ -f /boot/efi/EFI/BOOT/BOOTX64.EFI ] && echo "UEFI bootloader instalado correctamente"
        "
    else
        chroot $LFS /bin/bash -c "
            dd if=$disk bs=512 count=1 2>/dev/null | strings | grep GRUB
            [ $? -eq 0 ] && echo "BIOS bootloader instalado correctamente"
        "
    fi
}
```

## 7. Instrucciones para Secure Boot (Opcional)

Si necesitas soporte para Secure Boot:

```bash
function setup_secure_boot() {
    chroot $LFS /bin/bash -c "
        dnf install -y mokutil shim-signed
        mkdir -p /boot/efi/EFI/BOOT
        cp /usr/share/shim-signed/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
        cp /usr/share/shim-signed/mmx64.efi /boot/efi/EFI/BOOT/
        cp /boot/efi/EFI/LFS/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi
        
        echo "Configure Secure Boot en su firmware BIOS/UEFI"
        echo "O use mokutil para registrar las claves:"
        echo "mokutil --import /path/to/key.der"
    "
}
```

## Consideraciones Importantes

1. **Tamaño de partición ESP**: Recomendado al menos 512MB para UEFI
2. **Sistema de archivos**: La partición ESP debe ser FAT32
3. **Orden de particiones**: En UEFI, la partición ESP debe ser la primera
4. **Entorno chroot**: Asegúrate de montar /dev, /proc, /sys antes de chroot
5. **Hardware específico**: Algunas placas madre pueden requerir configuraciones adicionales



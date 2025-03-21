#!/bin/bash
# Mantenimiento macOS v1.2.0

# Solicitar permisos de administrador
if [[ $EUID -ne 0 ]]; then
    echo "Este script requiere permisos de administrador. Introduce tu contraseña:"
    exec sudo "$0" "$@"
fi

# Identificar versión de macOS
macos_version=$(sw_vers -productVersion | cut -d '.' -f 2)

# Comienzo del mantenimiento
echo "--- Iniciando mantenimiento en macOS ---"

# Verificar y reparar disco (APFS y HFS+)
echo "Verificando y reparando el volumen principal..."
if [[ $macos_version -ge 13 ]]; then
    diskutil verifyVolume /
    diskutil repairVolume /
else
    diskutil verifyDisk disk0
    diskutil repairDisk disk0
fi

# Reparar permisos (solo Mojave y anteriores)
if [[ $macos_version -lt 15 ]]; then
    echo "Reparando permisos del sistema... (solo para macOS Mojave y anteriores)"
    diskutil repairPermissions /
else
    echo "La reparación de permisos no es necesaria en macOS 10.15 o superior."
fi

# Limpiar cachés del sistema y usuario
echo "Limpiando cachés del sistema y usuario..."
rm -rf ~/Library/Caches/* ~/Library/Logs/* ~/Library/Saved\ Application\ State/* 2>/dev/null
sudo rm -rf /Library/Caches/* /System/Library/Caches/* /private/var/log/* 2>/dev/null
sudo rm -rf /private/var/tmp/* /private/var/folders/* 2>/dev/null

# Limpiar metadatos y cachés de iconos
echo "Eliminando caché de iconos y Spotlight..."
sudo find /private/var/folders -name "com.apple.iconservices" -exec rm -rf {} +
sudo find /private/var/folders -name "com.apple.metadata" -exec rm -rf {} +
sudo rm -rf ~/.Spotlight-V100 2>/dev/null
sudo mdutil -E /

# Limpiar DNS y reiniciar servicios de red
echo "Restableciendo configuraciones de red..."
dscacheutil -flushcache
killall -HUP mDNSResponder
networksetup -setv6off Wi-Fi
networksetup -setv6automatic Wi-Fi
ifconfig en0 down
ifconfig en0 up

# Liberar memoria RAM
echo "Liberando memoria RAM..."
sudo purge

# Limpiar swap (solo si no está en uso)
echo "Eliminando archivos de intercambio..."
sudo rm -f /private/var/vm/swapfile*

# Cerrar procesos pesados de indexación
echo "Deteniendo procesos de indexación momentáneamente..."
sudo pkill -f "mds"
sudo pkill -f "mdworker"
sudo pkill -f "corespotlightd"

# Instrucción para ejecutar fsck en modo de recuperación
echo "Para verificar y reparar el sistema de archivos, reinicia en modo de recuperación y ejecuta:"
echo "'/sbin/fsck -fy'"

# Finalización del mantenimiento
echo "--- Mantenimiento completado en macOS ---"

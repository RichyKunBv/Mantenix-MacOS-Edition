#!/bin/bash
# Mantenimiento macOS v1.1.0

# Solicitar permisos de administrador
if [[ $EUID -ne 0 ]]; then
    echo "Este script requiere permisos de administrador. Introduce tu contraseña:"
    exec sudo "$0" "$@"
fi

# Identificar versión de macOS
macos_version=$(sw_vers -productVersion | cut -d '.' -f 2)

# Comienzo del mantenimiento
echo "--- Iniciando mantenimiento en macOS ---"

# Verificar y reparar disco
echo "Verificando el disco principal..."
diskutil verifyDisk disk0
diskutil repairDisk disk0

# Reparar permisos en macOS Mojave (10.14) y anteriores
if [[ $macos_version -lt 15 ]]; then
    echo "Reparando permisos del sistema... (solo para macOS Mojave y anteriores)"
    diskutil repairPermissions /
else
    echo "La reparación de permisos no es necesaria en macOS 10.15 o superior."
fi

# Limpiar cachés accesibles
echo "Limpiando cachés accesibles..."
rm -rf ~/Library/Caches/* 2>/dev/null
rm -rf ~/Library/Logs/* 2>/dev/null
sudo rm -rf /Library/Caches/* 2>/dev/null

# Limpiar DNS y reiniciar servicios de red
echo "Restableciendo configuraciones de red..."
dscacheutil -flushcache
killall -HUP mDNSResponder
networksetup -setv6off Wi-Fi
networksetup -setv6automatic Wi-Fi
ifconfig en0 down
ifconfig en0 up

# Instrucción para ejecutar fsck en modo de recuperación
echo "Para verificar y reparar el sistema de archivos, reinicia en modo de recuperación y ejecuta:"
echo "'/sbin/fsck -fy'"

# Finalización del mantenimiento
echo "--- Mantenimiento completado en macOS ---"
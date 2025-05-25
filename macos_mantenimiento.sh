#!/bin/bash
# Mantenimiento macOS v2.0.0

# Colores para la interfaz
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/RichyKunBv/macOS_Maintenance"

# Solicitar permisos de administrador
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este script requiere permisos de administrador. Introduce tu contraseña:${NC}"
        exec sudo "$0" "$@"
    fi
}

# Funciones
get_macos_version() {
    sw_vers -productVersion | cut -d '.' -f 2
}

perform_disk_check() {
    echo -e "${YELLOW}--- Verificando y reparando el volumen principal ---${NC}"
    macos_version=$(get_macos_version)
    if [[ $macos_version -ge 13 ]]; then
        echo -e "${BLUE}Ejecutando diskutil verifyVolume / (macOS 10.13+)...${NC}"
        diskutil verifyVolume / || echo -e "${RED}Error al verificar el volumen.${NC}"
        echo -e "${BLUE}Ejecutando diskutil repairVolume / (macOS 10.13+)...${NC}"
        diskutil repairVolume / || echo -e "${RED}Error al reparar el volumen.${NC}"
    else
        echo -e "${BLUE}Ejecutando diskutil verifyDisk disk0 (macOS anterior a 10.13)...${NC}"
        diskutil verifyDisk disk0 || echo -e "${RED}Error al verificar el disco.${NC}"
        echo -e "${BLUE}Ejecutando diskutil repairDisk disk0 (macOS anterior a 10.13)...${NC}"
        diskutil repairDisk disk0 || echo -e "${RED}Error al reparar el disco.${NC}"
    fi
    echo -e "${GREEN}Verificación/Reparación de disco completada.${NC}"
    sleep 2
}

repair_permissions_legacy() {
    echo -e "${YELLOW}--- Reparando permisos del sistema (Solo macOS Mojave y anteriores) ---${NC}"
    macos_version=$(get_macos_version)
    if [[ $macos_version -lt 15 ]]; then
        echo -e "${BLUE}Ejecutando diskutil repairPermissions /...${NC}"
        diskutil repairPermissions / || echo -e "${RED}Error al reparar permisos.${NC}"
        echo -e "${GREEN}Reparación de permisos completada.${NC}"
    else
        echo -e "${YELLOW}La reparación de permisos no es necesaria en macOS 10.15 (Catalina) o superior.${NC}"
    fi
    sleep 2
}

reset_network_settings() {
    echo -e "${YELLOW}--- Restableciendo configuraciones de red ---${NC}"
    echo -e "${BLUE}Limpiando caché de DNS...${NC}"
    dscacheutil -flushcache
    killall -HUP mDNSResponder
    echo -e "${BLUE}Configurando IPv6 en Wi-Fi (desactivando y activando)...${NC}"
    networksetup -setv6off Wi-Fi 2>/dev/null
    networksetup -setv6automatic Wi-Fi 2>/dev/null
    echo -e "${BLUE}Reiniciando interfaz de red (en0)...${NC}"
    ifconfig en0 down 2>/dev/null
    ifconfig en0 up 2>/dev/null
    echo -e "${GREEN}Restablecimiento de red completado.${NC}"
    sleep 2
}

free_ram() {
    echo -e "${YELLOW}--- Liberando memoria RAM ---${NC}"
    echo -e "${BLUE}Ejecutando sudo purge...${NC}"
    sudo purge
    echo -e "${GREEN}Memoria RAM liberada.${NC}"
    sleep 2
}

stop_indexing_processes() {
    echo -e "${YELLOW}--- Deteniendo procesos de indexación momentáneamente ---${NC}"
    echo -e "${BLUE}Deteniendo mds, mdworker y corespotlightd...${NC}"
    sudo pkill -f "mds"
    sudo pkill -f "mdworker"
    sudo pkill -f "corespotlightd"
    echo -e "${GREEN}Procesos de indexación detenidos.${NC}"
    sleep 2
}

show_fsck_instruction() {
    echo -e "${YELLOW}--- Instrucción para fsck en modo de recuperación ---${NC}"
    echo -e "${BLUE}Para verificar y reparar el sistema de archivos de manera más profunda, reinicia tu Mac en ${RED}modo de recuperación${NC} (manteniendo Command + R al iniciar) y luego ejecuta la siguiente línea en la Terminal:${NC}"
    echo -e "${GREEN}'/sbin/fsck -fy'${NC}"
    echo ""
    echo -e "${YELLOW}Pulsa cualquier tecla para volver al menú...${NC}"
    read -n 1 -s
}

clean_caches_and_temp() {
    echo -e "${YELLOW}--- Limpiando cachés del sistema, usuario y archivos temporales ---${NC}"
    echo -e "${BLUE}Eliminando cachés de usuario, logs y estados de aplicaciones guardados...${NC}"
    rm -rf ~/Library/Caches/* ~/Library/Logs/* ~/Library/Saved\ Application\ State/* 2>/dev/null
    echo -e "${BLUE}Eliminando cachés del sistema...${NC}"
    sudo rm -rf /Library/Caches/* /System/Library/Caches/* /private/var/log/* 2>/dev/null
    echo -e "${BLUE}Eliminando archivos temporales en /private/var/tmp y /private/var/folders...${NC}"
    sudo rm -rf /private/var/tmp/* /private/var/folders/* 2>/dev/null
    echo -e "${GREEN}Limpieza de cachés y temporales completada.${NC}"
    sleep 2
}

clean_icons_and_spotlight() {
    echo -e "${YELLOW}--- Limpiando caché de iconos y reconstruyendo índice de Spotlight ---${NC}"
    echo -e "${BLUE}Eliminando caché de iconos...${NC}"
    sudo find /private/var/folders -name "com.apple.iconservices" -exec rm -rf {} +
    echo -e "${BLUE}Eliminando caché de metadatos...${NC}"
    sudo find /private/var/folders -name "com.apple.metadata" -exec rm -rf {} +
    echo -e "${BLUE}Eliminando caché de Spotlight y reconstruyendo índice...${NC}"
    sudo rm -rf ~/.Spotlight-V100 2>/dev/null
    sudo mdutil -E /
    echo -e "${GREEN}Limpieza de iconos y Spotlight completada.${NC}"
    sleep 2
}

clean_swap_files() {
    echo -e "${YELLOW}--- Limpiando archivos de intercambio (Swap) ---${NC}"
    echo -e "${RED}¡Atención! Esta acción puede afectar la estabilidad del sistema si la memoria SWAP está en uso intensivo.${NC}"
    read -p "¿Deseas continuar? (s/N): " confirm
    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
        echo -e "${BLUE}Eliminando archivos de intercambio...${NC}"
        sudo rm -f /private/var/vm/swapfile*
        echo -e "${GREEN}Archivos de intercambio eliminados.${NC}"
    else
        echo -e "${YELLOW}Operación de limpieza de SWAP cancelada.${NC}"
    fi
    sleep 2
}


group_clean_all() {
    echo -e "${BLUE}--- Ejecutando todas las tareas de limpieza ---${NC}"
    clean_caches_and_temp
    clean_icons_and_spotlight
    clean_swap_files 
    echo -e "${GREEN}Todas las tareas de limpieza completadas.${NC}"
    sleep 2
}

group_system_maintenance() {
    echo -e "${BLUE}--- Ejecutando tareas de mantenimiento del sistema ---${NC}"
    perform_disk_check
    repair_permissions_legacy
    reset_network_settings
    free_ram
    stop_indexing_processes
    echo -e "${GREEN}Todas las tareas de mantenimiento del sistema completadas.${NC}"
    echo -e "${YELLOW}Se recomienda revisar la instrucción para fsck para un mantenimiento más profundo.${NC}"
    sleep 2
}

update_homebrew() {
    echo -e "${YELLOW}--- Actualizando Homebrew ---${NC}"
    if command -v brew &>/dev/null; then
        echo -e "${BLUE}Homebrew está instalado.${NC}"
        ORIGINAL_USER="${SUDO_USER}"

        if [ -z "$ORIGINAL_USER" ]; then
            echo -e "${RED}No se pudo determinar el usuario original (SUDO_USER no establecido).${NC}"
            echo -e "${RED}Esto ocurre si el script se ejecuta directamente como root o si sudo no pasó la variable.${NC}"
            echo -e "${RED}Saltando la actualización de Homebrew para evitar problemas de permisos.${NC}"
            sleep 4
            return
        fi

        echo -e "${BLUE}Ejecutando actualización de Homebrew como el usuario '${ORIGINAL_USER}'...${NC}"
        su - "$ORIGINAL_USER" -c "brew update && brew upgrade --all && brew cleanup"

        if [ $? -eq 0 ]; then 
            echo -e "${GREEN}Homebrew y todos los paquetes actualizados y limpiados correctamente.${NC}"
        else
            echo -e "${RED}Hubo un error durante la actualización de Homebrew.${NC}"
            echo -e "${RED}Asegúrate de que el usuario '${ORIGINAL_USER}' tiene los permisos correctos para su instalación de Homebrew.${NC}"
        fi
    else
        echo -e "${YELLOW}Homebrew no está instalado en tu sistema. Puedes instalarlo visitando: https://brew.sh/${NC}"
    fi
    sleep 3
}

run_all_maintenance() {
    echo -e "${BLUE}--- Ejecutando TODAS las tareas de Mantenimiento ---${NC}"
    group_clean_all 
    
    group_system_maintenance
    update_homebrew 
    echo -e "${GREEN}Todas las tareas de mantenimiento y actualización completadas.${NC}"
    echo -e "${YELLOW}Se recomienda reiniciar el sistema para aplicar todos los cambios.${NC}"
    sleep 3
}

# --- Menú Principal ---
show_menu() {
    clear
    echo -e "${GREEN}--- Menú de Mantenimiento para macOS v2.0 ---${NC}"
    echo -e "${BLUE}Selecciona una opción:${NC}"
    echo "------------------------------------------------------"
    echo -e "${YELLOW}  1.${NC} Limpieza General "
    echo -e "${YELLOW}  2.${NC} Mantenimiento del Sistema "
    echo -e "${YELLOW}  3.${NC} Actualizar Homebrew "
    echo "------------------------------------------------------"
    echo -e "${YELLOW}  A.${NC} Ejecutar TODO el Mantenimiento "
    echo -e "${YELLOW}  Y.${NC} Próximamente "
    echo -e "${YELLOW}  X.${NC} Salir"
    echo "------------------------------------------------------"
    read -p "Introduce tu elección: " choice
    echo ""

    case "$choice" in
        1) group_clean_all ;;
        2) group_system_maintenance ;;
        3) update_homebrew ;;
        A|a) run_all_maintenance ;;
        Y|y)
            echo -e "${YELLOW}¡Próximamente más funciones! Visita nuestro repositorio para estar al tanto:${NC}"
            echo -e "${BLUE}${REPO_URL}${NC}"
            if command -v open &>/dev/null; then
                open "$REPO_URL"
            elif command -v xdg-open &>/dev/null; then 
                xdg-open "$REPO_URL"
            fi
            sleep 5
            ;;
        X|x) echo -e "${BLUE}Saliendo del script. ¡Hasta pronto!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida. Por favor, intenta de nuevo.${NC}"; sleep 2 ;;
    esac
}

check_sudo
while true; do
    show_menu
done

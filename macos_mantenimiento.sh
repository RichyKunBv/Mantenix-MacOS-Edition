#!/bin/bash
# Mantenimiento macOS
CURRENT_VERSION="2.1.2"

# --- URLs del Repositorio ---
REPO_URL="https://github.com/RichyKunBv/macOS_Maintenance"
RAW_REPO_URL="https://raw.githubusercontent.com/RichyKunBv/macOS_Maintenance/main"

# --- Colores y Estilos ---
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# --- Funciones de Utilidad ---

# Indicador de actividad (spinner)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# Pausa interactiva
press_any_key() {
    echo -e "\n${YELLOW}Pulsa cualquier tecla para volver al menú...${NC}"
    read -n 1 -s -r
}

# Solicitar permisos de administrador si no los tiene
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este script requiere permisos de administrador.${NC}"
        exec sudo -p "Por favor, introduce tu contraseña para continuar: " "$0" "$@"
    fi
}

# Identificar versión de macOS
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
    clean_swap_files # Esta función pide confirmación
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
    echo -e "${YELLOW}--- Actualización de Homebrew ---${NC}"
    
    # Verificar si Homebrew está instalado usando rutas conocidas
    BREW_PATHS=("/usr/local/bin/brew" "/opt/homebrew/bin/brew" "$HOME/.linuxbrew/bin/brew")
    BREW_FOUND=0
    
    for path in "${BREW_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            brew="$path"
            BREW_FOUND=1
            break
        fi
    done
    
    if [[ $BREW_FOUND -eq 0 ]] && ! command -v brew &>/dev/null; then
        echo -e "${RED}❌ Homebrew no está instalado.${NC}"
        echo -e "${YELLOW}Para instalarlo, ejecuta este comando en tu terminal:${NC}"
        echo -e "${BLUE}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        sleep 3
        return
    fi

    # Obtener usuario original (no root)
    ORIGINAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
    
    if [[ -z "$ORIGINAL_USER" || "$ORIGINAL_USER" == "root" ]]; then
        echo -e "${RED}❌ Error: No se pudo obtener el usuario no-root.${NC}"
        echo -e "${YELLOW}Ejecuta el script sin 'sudo' para actualizar Homebrew.${NC}"
        sleep 3
        return
    fi

    echo -e "${BLUE}🔄 Actualizando Homebrew como usuario '$ORIGINAL_USER'...${NC}"
    
    # Comandos para actualizar
    sudo -u "$ORIGINAL_USER" bash <<'BREW_UPDATE'
        # Cargar entorno del usuario
        [[ -f ~/.bash_profile ]] && source ~/.bash_profile
        [[ -f ~/.zshrc ]] && source ~/.zshrc
        
        # Actualizar todo
        brew update
        brew upgrade
        brew upgrade --cask
        brew cleanup
        brew doctor
BREW_UPDATE

    echo -e "${GREEN}✅ Homebrew y todos los paquetes actualizados correctamente.${NC}"
    sleep 3
}

run_all_maintenance() {
    echo -e "${BLUE}--- Ejecutando TODAS las tareas de Mantenimiento ---${NC}"
    group_clean_all # Contiene la confirmación de swap
    group_system_maintenance
    update_homebrew # Se ejecuta sin detección previa para esta opción
    echo -e "${GREEN}Todas las tareas de mantenimiento y actualización completadas.${NC}"
    echo -e "${YELLOW}Se recomienda reiniciar el sistema para aplicar todos los cambios.${NC}"
    sleep 3
}

# --- AUTO-ACTUALIZACION ---
check_for_updates() {
    echo -e "${CYAN}Buscando actualizaciones...${NC}"
    
    REMOTE_VERSION=$(curl -sL "${RAW_REPO_URL}/version.txt")
    
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${RED}❌ Error: No se pudo contactar con GitHub. Revisa tu conexión a internet.${NC}"
        press_any_key
        return
    fi
    
    echo -e "${BLUE}Versión actual:   ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}Última versión:   ${GREEN}$REMOTE_VERSION${NC}"
    
    if [ "$CURRENT_VERSION" = "$REMOTE_VERSION" ]; then
        echo -e "\n${GREEN}✅ ¡Estás al día! Ya tienes la última versión.${NC}"
    elif [ "$(printf '%s\n%s\n' "$REMOTE_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$CURRENT_VERSION" ]; then
        echo -e "\n${YELLOW}✨ ¡Nueva versión disponible!${NC}"
        read -p "   ¿Deseas actualizar ahora? (S/n): " choice
        
        # Si la elección está vacía o es 's'/'S', se actualiza.
        if [[ -z "$choice" || "$choice" == "s" || "$choice" == "S" ]]; then
            echo -n -e "${CYAN}Descargando la nueva versión...${NC}"
            
            SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
            TMP_FILE=$(mktemp)
            
            # El comando de descarga se ejecuta en segundo plano para poder mostrar el spinner
            curl -sL "${RAW_REPO_URL}/macos_mantenimiento.sh" -o "$TMP_FILE" &
            spinner $! # Inicia el spinner con el PID del proceso curl
            
            # Verificar si la descarga fue exitosa (el archivo temporal no está vacío)
            if [ -s "$TMP_FILE" ]; then
                echo -e "${GREEN}✅ Descarga completa.${NC}"
                chmod +x "$TMP_FILE"
                mv "$TMP_FILE" "$SCRIPT_PATH"
                
                echo -e "${GREEN}🔄 ¡Actualización completada! El script se reiniciará ahora...${NC}"
                sleep 2
                
                # --- LA MAGIA DEL AUTO-REINICIO ---
                exec "$SCRIPT_PATH"
            else
                echo -e "${RED}❌ Error: La descarga falló. El archivo está vacío.${NC}"
                rm -f "$TMP_FILE"
            fi
        else
            echo -e "${YELLOW}Actualización cancelada.${NC}"
        fi
    else
        echo -e "\n${CYAN}Estás utilizando una versión de desarrollo (más nueva que la oficial).${NC}"
    fi
    press_any_key
}

# --- MENÚ PRINCIPAL ---
show_menu() {
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}          MAINTENANCE TOOL FOR MACOS v${CURRENT_VERSION}         ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${BLUE}  Bienvenido, ${SUDO_USER:-$USER}. Selecciona una tarea.${NC}"
    echo ""
    echo -e "   ${YELLOW}1)${NC} Limpieza General (Cachés, Logs, Swap)"
    echo -e "   ${YELLOW}2)${NC} Mantenimiento del Sistema (Discos, RAM, Red)"
    echo -e "   ${YELLOW}3)${NC} Actualizar Homebrew (Paquetes y Fórmulas)"
    echo -e "   ${YELLOW}4)${NC} Instrucciones para revisión profunda (fsck)"
    echo "   ----------------------------------------------------"
    echo -e "   ${CYAN}A)${NC} Ejecutar TODO el Mantenimiento"
    echo ""
    echo -e "   ${YELLOW}Y)${NC} Buscar Actualizaciones del Script"
    echo -e "   ${RED}X)${NC} Salir"
    echo -e "${GREEN}======================================================${NC}"
    read -p "   >> Introduce tu elección: " choice
    echo ""

    case "$choice" in
        1) group_clean_all; press_any_key ;;
        2) group_system_maintenance; press_any_key ;;
        3) update_homebrew; press_any_key ;;
        4) show_fsck_instruction ;; # Esta ya tiene su propia pausa
        A|a) run_all_maintenance; press_any_key ;;
        Y|y) check_for_updates ;; # El actualizador maneja su propia pausa/reinicio
        X|x) echo -e "${BLUE}Saliendo... ¡Hasta pronto!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida. Por favor, intenta de nuevo.${NC}"; sleep 2 ;;
    esac
}

# --- Bucle Principal del Script ---
check_sudo
while true; do
    show_menu
done

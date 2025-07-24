#!/bin/bash
# Mantenimiento macOS
CURRENT_VERSION="2.2.1"

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

# --- Funciones de Detección de Sistema ---

# Obtener versión completa de macOS (ej: 10.15.7)
get_macos_version_full() {
    sw_vers -productVersion
}

# Obtener versión mayor de macOS (ej: 10 o 11)
get_macos_major_version() {
    sw_vers -productVersion | cut -d '.' -f 1
}

# Obtener versión menor de macOS (ej: 15 para 10.15)
get_macos_version() {
    sw_vers -productVersion | cut -d '.' -f 2
}

# Comprobar si la versión actual es al menos la requerida
is_at_least_version() {
    local required=$1
    local current=$(get_macos_version_full)
    if [[ $(echo "$current $required" | tr ' ' '\n' | sort -V | head -n1) == "$required" ]]; then
        return 0 # true, es al menos esta versión
    else
        return 1 # false, es menor que esta versión
    fi
}

# Obtener la arquitectura de CPU (Intel o Apple Silicon)
get_cpu_architecture() {
    if [ "$(uname -m)" = "arm64" ]; then
        echo "apple_silicon"
    else
        echo "intel"
    fi
}

# Obtener la ruta del volumen de sistema según la versión de macOS
get_system_volume_path() {
    local major_ver=$(get_macos_major_version)
    local minor_ver=$(get_macos_minor_version)
    
    if [[ "$major_ver" -ge 11 ]]; then
        echo "/System/Volumes/Data"
    elif [[ "$major_ver" -eq 10 && "$minor_ver" -ge 15 ]]; then
        echo "/System/Volumes/Data"
    else
        echo "/"
    fi
}

# Verificar disponibilidad de una herramienta
check_tool_availability() {
    local tool=$1
    if command -v "$tool" &>/dev/null; then
        return 0 # true, herramienta disponible
    else
        return 1 # false, herramienta no disponible
    fi
}

# Verificar estado de SIP (System Integrity Protection)
check_sip_status() {
    if csrutil status | grep -q "enabled"; then
        echo -e "${YELLOW}SIP está activado. Algunas operaciones pueden estar restringidas.${NC}"
        return 0 # SIP activado
    else
        return 1 # SIP desactivado
    fi
}


# --- Comandos ---

perform_disk_check() {
    echo -e "${YELLOW}--- Verificando y reparando el volumen principal ---${NC}"
    
    # Usar la nueva función de detección de versión
    if is_at_least_version "10.13"; then
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
    
    # Usar la nueva función de detección de versión
    if ! is_at_least_version "10.15"; then
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


# --Limpieza cache Xcode--
clean_xcode_cache() {
    local XCODE_CACHE_PATH="$HOME/Library/Developer/Xcode/DerivedData"
        if [ -d "$XCODE_CACHE_PATH" ] && [ "$(ls -A $XCODE_CACHE_PATH)" ]; then
        echo -e "${YELLOW}Se detectó caché de Xcode (${CYAN}DerivedData${YELLOW}).${NC}"
        read -p "   ¿Deseas limpiarlo? (puede tardar en regenerarse) (S/n): " choice
        if [[ -z "$choice" || "$choice" == "s" || "$choice" == "S" ]]; then
            echo -n -e "${BLUE}Limpiando caché de Xcode...${NC}"
            rm -rf "$XCODE_CACHE_PATH"/* &
            spinner $!
            echo -e "${GREEN}✅ Caché de Xcode limpiado.${NC}"
        else
            echo -e "${YELLOW}Omitiendo limpieza de Xcode.${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️ No se encontró caché de Xcode para limpiar.${NC}"
    fi
}
clean_pkg_managers_cache() {
    echo -e "${YELLOW}--- Buscando cachés de gestores de paquetes ---${NC}"
    local cleaned_something=false
    if command -v npm &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de npm...${NC}"
        npm cache clean --force &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ Caché de npm limpiado.${NC}"
        cleaned_something=true
    fi
    if command -v pip &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de pip...${NC}"
        pip cache purge &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ Caché de pip limpiado.${NC}"
        cleaned_something=true
    fi
    if ! $cleaned_something; then
        echo -e "${BLUE}ℹ️ No se encontraron gestores de paquetes (npm, pip) para limpiar.${NC}"
    fi
}
developer_tools_cleanup() {
    echo -e "${CYAN}--- Limpieza de Herramientas de Desarrollo ---${NC}"
    clean_xcode_cache
    echo ""
    clean_pkg_managers_cache
}


# --Revisión profunda--
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
    
    # Verificar si tenemos permisos para acceder a ciertas ubicaciones
    if is_at_least_version "10.14"; then
        echo -e "${BLUE}Nota: En macOS Mojave y posteriores, es posible que necesites otorgar permisos de acceso completo al disco a Terminal.${NC}"
    fi
    
    # Obtener la ruta correcta del volumen de datos según la versión de macOS
    local data_volume_path=$(get_system_volume_path)
    
    echo -e "${BLUE}Eliminando cachés de usuario, logs y estados de aplicaciones guardados...${NC}"
    rm -rf ~/Library/Caches/* ~/Library/Logs/* ~/Library/Saved\ Application\ State/* 2>/dev/null
    
    echo -e "${BLUE}Eliminando cachés del sistema...${NC}"
    if check_sip_status; then
        echo -e "${YELLOW}SIP está activado. Algunas operaciones de limpieza pueden estar limitadas.${NC}"
        sudo rm -rf /Library/Caches/* 2>/dev/null
        # No intentamos limpiar /System/Library/Caches cuando SIP está activado
    else
        sudo rm -rf /Library/Caches/* /System/Library/Caches/* 2>/dev/null
    fi
    
    sudo rm -rf /private/var/log/* 2>/dev/null
    
    echo -e "${BLUE}Eliminando archivos temporales en /private/var/tmp y /private/var/folders...${NC}"
    sudo rm -rf /private/var/tmp/* /private/var/folders/* 2>/dev/null
    
    echo -e "${GREEN}Limpieza de cachés y temporales completada.${NC}"
    sleep 2
}

clean_icons_and_spotlight() {
    echo -e "${YELLOW}--- Limpiando caché de iconos y reconstruyendo índice de Spotlight ---${NC}"
    
    # Verificar si tenemos las herramientas necesarias
    if ! check_tool_availability "mdutil"; then
        echo -e "${RED}Error: La herramienta mdutil no está disponible en este sistema.${NC}"
        echo -e "${YELLOW}Omitiendo reconstrucción de índice de Spotlight.${NC}"
        return
    fi
    
    # Obtener la ruta correcta del volumen de datos según la versión de macOS
    local data_volume_path=$(get_system_volume_path)
    
    echo -e "${BLUE}Eliminando caché de iconos...${NC}"
    if is_at_least_version "10.15"; then
        # En Catalina y posteriores, la ubicación puede ser diferente
        sudo find /private/var/folders -name "com.apple.iconservices*" -exec rm -rf {} \; 2>/dev/null
        if [ "$(get_cpu_architecture)" = "apple_silicon" ]; then
            # Ubicación específica para Apple Silicon
            sudo find /System/Volumes/Data/private/var/folders -name "com.apple.iconservices*" -exec rm -rf {} \; 2>/dev/null
        fi
    else
        # Para versiones anteriores
        sudo find /private/var/folders -name "com.apple.iconservices" -exec rm -rf {} + 2>/dev/null
    fi
    
    echo -e "${BLUE}Eliminando caché de metadatos...${NC}"
    sudo find /private/var/folders -name "com.apple.metadata*" -exec rm -rf {} \; 2>/dev/null
    
    echo -e "${BLUE}Eliminando caché de Spotlight y reconstruyendo índice...${NC}"
    sudo rm -rf ~/.Spotlight-V100 2>/dev/null
    
    # Reconstruir el índice de Spotlight en la ubicación correcta
    if is_at_least_version "10.15"; then
        echo -e "${BLUE}Reconstruyendo índice de Spotlight para macOS Catalina o superior...${NC}"
        sudo mdutil -i off / && sudo mdutil -i on /
        sudo mdutil -E $data_volume_path
    else
        echo -e "${BLUE}Reconstruyendo índice de Spotlight para macOS Mojave o anterior...${NC}"
        sudo mdutil -E /
    fi
    
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


# --- Indices ---

# -- Limpieza General --    --
group_clean_all() {
    echo -e "${BLUE}--- Ejecutando todas las tareas de limpieza ---${NC}"
    clean_caches_and_temp
    clean_icons_and_spotlight
    clean_swap_files # Esta función pide confirmación
    echo -e "${GREEN}Todas las tareas de limpieza completadas.${NC}"
    sleep 2
}


# --Mantenimiento del Sistema--
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


# --Actualizar Homebrew--
detect_homebrew() {
    local arch=$(get_cpu_architecture)
    if [ "$arch" = "apple_silicon" ]; then
        if [ -x "/opt/homebrew/bin/brew" ]; then
            echo "/opt/homebrew/bin/brew"
            return 0
        fi
    else
        if [ -x "/usr/local/bin/brew" ]; then
            echo "/usr/local/bin/brew"
            return 0
        fi
    fi
    
    # Búsqueda en rutas adicionales
    local BREW_PATHS=("$HOME/.linuxbrew/bin/brew" "$HOME/.homebrew/bin/brew")
    for path in "${BREW_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Búsqueda en PATH
    if command -v brew &>/dev/null; then
        echo "$(command -v brew)"
        return 0
    fi
    
    return 1 # No encontrado
}

update_homebrew() {
    echo -e "${YELLOW}--- Actualización de Homebrew ---${NC}"

    # Usar la nueva función de detección
    local brew_path=$(detect_homebrew)
    if [ -z "$brew_path" ]; then
        echo -e "${RED}❌ Homebrew no está instalado.${NC}"
        echo -e "${YELLOW}Para instalarlo, ejecuta este comando en tu terminal:${NC}"
        echo -e "${BLUE}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        sleep 3
        return
    fi
    
    echo -e "${BLUE}🔍 Homebrew detectado en: $brew_path${NC}"

    # Obtener usuario original (no root)
    ORIGINAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"

    if [[ -z "$ORIGINAL_USER" || "$ORIGINAL_USER" == "root" ]]; then
        echo -e "${RED}❌ Error: No se pudo obtener el usuario no-root.${NC}"
        echo -e "${YELLOW}Ejecuta el script sin 'sudo' para actualizar Homebrew.${NC}"
        sleep 3
        return
    fi

    echo -e "${BLUE}🔄 Actualizando Homebrew como usuario '$ORIGINAL_USER'...${NC}"

    # Comandos para actualizar usando la ruta específica de brew
    sudo -u "$ORIGINAL_USER" bash <<BREW_UPDATE
        # Cargar entorno del usuario
        [[ -f ~/.bash_profile ]] && source ~/.bash_profile
        [[ -f ~/.zshrc ]] && source ~/.zshrc

        # Usar la ruta específica de brew detectada
        BREW_PATH="$brew_path"
        echo "Usando Homebrew en: \$BREW_PATH"
        
        # Actualizar todo
        \$BREW_PATH update
        \$BREW_PATH upgrade
        \$BREW_PATH upgrade --cask
        \$BREW_PATH cleanup
        \$BREW_PATH doctor
BREW_UPDATE

    echo -e "${GREEN}✅ Homebrew y todos los paquetes actualizados correctamente.${NC}"
    sleep 3
}


# --Ejecutar TODO el Mantenimiento--
run_all_maintenance() {
    echo -e "${BLUE}--- Ejecutando TODAS las tareas de Mantenimiento ---${NC}"
    group_clean_all # Contiene la confirmación de swap
    group_system_maintenance
    update_homebrew # Se ejecuta sin detección previa para esta opción
    clean_xcode_cache
    echo -e "${GREEN}Todas las tareas de mantenimiento y actualización completadas.${NC}"
    echo -e "${YELLOW}Se recomienda reiniciar el sistema para aplicar todos los cambios.${NC}"
    sleep 3
}

# --- AUTO-ACTUALIZACION ---

# --Buscar Actualizaciones del Script--
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

#--- SALUD MAC ---

# --Salud del Sistema--
show_health_report() {
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}                REPORTE DE SALUD DEL MAC              ${NC}"
    echo -e "${GREEN}======================================================${NC}"

    # --- Batería ---
    echo -e "${CYAN}🔋 BATERÍA:${NC}"
    if pmset -g batt | grep -q 'InternalBattery'; then
        local PERCENTAGE=$(pmset -g batt | grep -o '[0-9]*%;' | tr -d '%;')
        local HEALTH_INFO=$(system_profiler SPPowerDataType)
        local CYCLE_COUNT=$(echo "$HEALTH_INFO" | grep "Cycle Count" | awk '{print $3}')
        local MAX_CAPACITY=$(echo "$HEALTH_INFO" | grep "Maximum Capacity" | awk '{print $3}')
        echo -e "   - Nivel de Carga:   ${YELLOW}$PERCENTAGE%${NC}"
        echo -e "   - Ciclos de Carga:  ${YELLOW}${CYCLE_COUNT:-N/A}${NC}"
        if [ -n "$MAX_CAPACITY" ]; then
            echo -e "   - Salud de Batería: ${YELLOW}${MAX_CAPACITY}${NC}"
        else
            local CONDITION=$(echo "$HEALTH_INFO" | grep "Condition" | awk '{print $2}')
            echo -e "   - Condición:        ${YELLOW}${CONDITION:-N/A}${NC}"
        fi
    else
        echo -e "   ${BLUE}No se detectó batería (Mac de escritorio).${NC}"
    fi
    echo ""

    # --- Almacenamiento ---
    echo -e "${CYAN}💾 ALMACENAMIENTO:${NC}"
    local data_volume_path=$(get_system_volume_path)
    local DISK_INFO=$(df -h "$data_volume_path" | tail -n 1)
    echo -e "   - Capacidad Total:  ${YELLOW}$(echo "$DISK_INFO" | awk '{print $2}')${NC}"
    echo -e "   - Espacio Utilizado: ${YELLOW}$(echo "$DISK_INFO" | awk '{print $3}') ($(echo "$DISK_INFO" | awk '{print $5}'))${NC}"
    echo -e "   - Espacio Disponible: ${YELLOW}$(echo "$DISK_INFO" | awk '{print $4}')${NC}"
    echo ""

    # --- CPU y RAM ---
    echo -e "${CYAN}🧠 CPU Y MEMORIA RAM:${NC}"
    local CPU_MODEL=$(sysctl -n machdep.cpu.brand_string | sed 's/@.*//' | xargs)
    local RAM_BYTES=$(sysctl -n hw.memsize)
    local RAM_GB=$(echo "scale=2; $RAM_BYTES / 1024 / 1024 / 1024" | bc)
    echo -e "   - CPU: ${YELLOW}$CPU_MODEL${NC}"
    echo -e "   - RAM Instalada: ${YELLOW}${RAM_GB} GB${NC}"
    echo -e "${GREEN}======================================================${NC}"
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
    echo -e "   ${YELLOW}1)${NC} Limpieza General"
    echo -e "   ${YELLOW}2)${NC} Mantenimiento del Sistema"
    echo -e "   ${YELLOW}3)${NC} Actualizar Homebrew"
    echo -e "   ${YELLOW}4)${NC} Revisión profunda"
    echo -e "   ${YELLOW}5)${NC} Salud del Sistema"
    echo "   ----------------------------------------------------"
    echo -e "   ${CYAN}A)${NC} Ejecutar TODO el Mantenimiento"
    echo -e "   ${CYAN}B)${NC} Limpieza cache Xcode"
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
        4) show_fsck_instruction ;;
        5) show_health_report ;;
        A|a) run_all_maintenance; press_any_key ;;
        B|b) clean_xcode_cache; press_any_key ;;
        Y|y) check_for_updates ;;
        X|x) echo -e "${BLUE}Saliendo... ¡Hasta pronto!${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción inválida. Por favor, intenta de nuevo.${NC}"; sleep 2 ;;
    esac
}

# --- Verificación de Compatibilidad ---
check_compatibility() {
    echo -e "${CYAN}Verificando compatibilidad del sistema...${NC}"
    local macos_version=$(get_macos_version_full)
    local arch=$(get_cpu_architecture)
    
    echo -e "${BLUE}Versión de macOS detectada: ${GREEN}$macos_version${NC}"
    echo -e "${BLUE}Arquitectura detectada: ${GREEN}$arch${NC}"
    
    # Verificar versión mínima (High Sierra = 10.13)
    if ! is_at_least_version "10.13"; then
        echo -e "${RED}⚠️ Este script requiere macOS High Sierra (10.13) o superior.${NC}"
        echo -e "${YELLOW}Tu versión actual ($macos_version) no es compatible.${NC}"
        exit 1
    fi
    
    # Verificar SIP si es necesario para algunas operaciones
    check_sip_status
    
    # Verificar permisos de acceso al disco
    if is_at_least_version "10.14"; then
        echo -e "${YELLOW}Nota: En macOS Mojave (10.14) y posteriores, algunas operaciones pueden requerir permisos adicionales.${NC}"
        echo -e "${BLUE}Si encuentras errores de permisos, ve a Preferencias del Sistema > Seguridad y Privacidad > Privacidad > Acceso Completo al Disco y añade Terminal.${NC}"
    fi
    
    echo -e "${GREEN}✅ Sistema compatible. Continuando...${NC}"
    sleep 2
}

# --- Bucle Principal del Script ---
check_sudo
check_compatibility
while true; do
    show_menu
done

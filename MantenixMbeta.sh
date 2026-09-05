#!/bin/bash
# ==============================================================================
# Mantenix / Mantenimiento macOS v4.0 (Edición Moderna)
# Requisitos: macOS Big Sur (11.0) o superior
# ==============================================================================

CURRENT_VERSION="4.0"

# --- URLs del Repositorio ---
REPO_URL="https://github.com/RichyKunBv/Mantenix-MacOS-Edition"
RAW_REPO_BASE="https://raw.githubusercontent.com/RichyKunBv/Mantenix-MacOS-Edition"
RAW_REPO_URL="${RAW_REPO_BASE}/main"

SCRIPT_FILENAME="MantenixMbeta.sh"
SCRIPT_VERSION="versionBETA.txt"

# --- Detección de Usuario Real (incluso bajo sudo) ---
REAL_USER="${SUDO_USER:-$(stat -f%Su /dev/console 2>/dev/null || echo "$USER")}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    REAL_USER=$(logname 2>/dev/null || echo "$USER")
fi
REAL_HOME=$(dscl . -read /Users/"$REAL_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
if [[ -z "$REAL_HOME" || ! -d "$REAL_HOME" ]]; then
    REAL_HOME="/Users/$REAL_USER"
fi

# --- Directorio y Archivo de Log ---
LOG_DIR="$REAL_HOME/Library/Logs/Mantenix"
LOG_FILE="$LOG_DIR/MantenixBETA.log"
mkdir -p "$LOG_DIR" 2>/dev/null

# --- Colores y Estilos ---
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Modos de Ejecución
AUTO_MODE=false
GUI_MODE=false

# --- Logging Helpers ---
log_msg() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [INFO] $1" >> "$LOG_FILE" 2>/dev/null
}

log_warn() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [WARN] $1" >> "$LOG_FILE" 2>/dev/null
}

log_err() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [ERROR] $1" >> "$LOG_FILE" 2>/dev/null
}

# --- Notificaciones nativas del sistema ---
notify_user() {
    local title="$1"
    local message="$2"
    if [ "$GUI_MODE" = true ] || [ -z "$SSH_TTY" ]; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
    fi
}

# --- Indicador de Actividad (Spinner) ---
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# --- Pausa Interactiva ---
press_any_key() {
    if [ "$AUTO_MODE" = true ]; then
        return
    fi
    echo -e "\n${YELLOW}Pulsa cualquier tecla para continuar...${NC}"
    read -n 1 -s -r
}

# --- Verificación de Permisos Sudo ---
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Este script requiere permisos de administrador para ejecutar tareas del sistema.${NC}"
        log_warn "Solicitando permisos de sudo..."
        exec sudo -p "Por favor, introduce tu contraseña de administrador para continuar: " "$0" "$@"
    fi
}

# --- Verificación de Compatibilidad (macOS 11.0+) ---
check_compatibility() {
    local os_version=$(sw_vers -productVersion)
    local major_ver=$(echo "$os_version" | cut -d '.' -f 1)
    
    log_msg "Compatibilidad comprobada: macOS $os_version (Mayor: $major_ver)"

    if [[ "$major_ver" -lt 11 ]]; then
        echo -e "${RED}❌ Error: Mantenix v4.0 requiere macOS Big Sur (11.0) o posterior.${NC}"
        echo -e "${YELLOW}Tu versión actual ($os_version) ya no es compatible con la versión 4.0.${NC}"
        log_err "Sistema incompatible: macOS $os_version"
        exit 1
    fi

    # Comprobación de SIP
    if csrutil status | grep -q "enabled"; then
        log_msg "SIP está activado."
    else
        log_warn "SIP está desactivado."
    fi
}

# --- Instantánea de Time Machine (Rollback Safety) ---
create_tm_snapshot() {
    echo -e "${CYAN}--- Instantánea de Seguridad de Time Machine ---${NC}"
    log_msg "Iniciando creación de instantánea local APFS..."
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "¿Deseas crear una instantánea local de Time Machine antes de realizar cambios? (S/n): " confirm
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            echo -e "${YELLOW}Omitiendo creación de instantánea.${NC}"
            log_msg "Creación de instantánea omitida por el usuario."
            return
        fi
    fi

    echo -n -e "${BLUE}Creando instantánea local de APFS...${NC}"
    tmutil localsnapshot / &>/dev/null &
    spinner $!
    echo -e "${GREEN}✅ Instantánea de seguridad creada correctamente.${NC}"
    log_msg "Instantánea local APFS creada con éxito."
    notify_user "Mantenix v4.0" "Instantánea de seguridad creada correctamente."
    sleep 1
}

clean_tm_snapshots() {
    echo -e "${YELLOW}--- Eliminando snapshots locales de Time Machine (APFS) ---${NC}"
    log_msg "Eliminando snapshots locales acumulados..."
    
    local snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | awk -F. '{print $4}')
    if [ -z "$snapshots" ]; then
        echo -e "${BLUE}ℹ️ No se encontraron snapshots locales de Time Machine.${NC}"
    else
        echo -n -e "${BLUE}Purgando snapshots...${NC}"
        for s in $snapshots; do
            [ -n "$s" ] && sudo tmutil deletelocalsnapshots "$s" &>/dev/null
        done
        echo -e "${GREEN}✅ Snapshots de Time Machine eliminados.${NC}"
        log_msg "Snapshots locales eliminados."
    fi
    sleep 1
}

# --- Tareas de Limpieza ---

clean_caches_and_temp() {
    echo -e "${YELLOW}--- Limpiando cachés de usuario, sistema y temporales ---${NC}"
    log_msg "Iniciando limpieza de cachés y temporales..."

    # Limpieza de usuario real
    echo -e "${BLUE}Limpiando cachés, logs y papelera del usuario ($REAL_USER)...${NC}"
    rm -rf "$REAL_HOME/Library/Caches/"* "$REAL_HOME/Library/Saved Application State/"* 2>/dev/null
    # Purgar logs preservando el directorio de Mantenix
    find "$REAL_HOME/Library/Logs" -mindepth 1 ! -name "Mantenix" ! -path "*/Mantenix/*" -delete 2>/dev/null || true
    rm -rf "$REAL_HOME/.cache/"* 2>/dev/null
    rm -rf "$REAL_HOME/.Trash/"* 2>/dev/null
    log_msg "Cachés de usuario, logs, papelera y .cache borrados."

    # Limpieza de sistema
    echo -e "${BLUE}Limpiando cachés de sistema y logs...${NC}"
    sudo rm -rf /Library/Caches/* 2>/dev/null
    sudo find /private/var/log -type f \( -name "*.log" -o -name "*.gz" -o -name "*.asl" \) -delete 2>/dev/null
    sudo rm -rf /Library/Logs/* 2>/dev/null

    # Limpieza segura de /private/var/folders (solo Caches y TemporaryItems)
    echo -e "${BLUE}Limpiando subdirectorios de Caches y TemporaryItems en /private/var/folders...${NC}"
    sudo find /private/var/folders -type d \( -name "Caches" -o -name "TemporaryItems" \) -exec rm -rf {} + 2>/dev/null || true
    sudo rm -rf /private/var/tmp/* 2>/dev/null

    echo -e "${GREEN}✅ Limpieza de cachés finalizada.${NC}"
    log_msg "Limpieza de cachés completada."
    sleep 1
}

clean_icons_and_spotlight() {
    echo -e "${YELLOW}--- Limpieza de cachés de iconos y reindexación de Spotlight ---${NC}"
    log_msg "Iniciando reindexación de Spotlight y limpieza de iconos..."

    echo -e "${BLUE}Eliminando cachés de iconos y metadatos...${NC}"
    sudo find /private/var/folders -name "com.apple.iconservices*" -exec rm -rf {} + 2>/dev/null || true
    sudo find /private/var/folders -name "com.apple.metadata*" -exec rm -rf {} + 2>/dev/null || true

    echo -e "${BLUE}Reiniciando e reindexando Spotlight (/ y Datos)...${NC}"
    sudo mdutil -i off / &>/dev/null
    sudo mdutil -i off /System/Volumes/Data &>/dev/null || true
    sudo mdutil -E / &>/dev/null
    sudo mdutil -E /System/Volumes/Data &>/dev/null || true
    sudo mdutil -i on / &>/dev/null
    sudo mdutil -i on /System/Volumes/Data &>/dev/null || true

    echo -e "${GREEN}✅ Reindexación de Spotlight activada.${NC}"
    log_msg "Spotlight reindexado con éxito."
    sleep 1
}

clean_swap_files() {
    echo -e "${YELLOW}--- Limpieza de archivos Swap (Memoria Virtual) ---${NC}"
    log_msg "Iniciando verificación de Swap..."

    local swap_count=$(ls /private/var/vm/swapfile* 2>/dev/null | wc -l)
    if [ "$swap_count" -eq 0 ]; then
        echo -e "${BLUE}ℹ️ No se detectaron archivos de intercambio swap para eliminar.${NC}"
        log_msg "Sin archivos swap pendientes."
        return
    fi

    if [ "$AUTO_MODE" = true ]; then
        echo -e "${YELLOW}⚠️ Modo automático activo: Se omite el borrado de swap para prevenir inestabilidad del kernel.${NC}"
        log_warn "Borrado de swap omitido en modo desatendido."
        return
    fi

    echo -e "${RED}⚠️  PELIGRO: Forzar el borrado de swap con aplicaciones abiertas puede congelar el sistema.${NC}"
    read -p "¿Deseas forzar la eliminación de swap de todos modos? (s/N): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo -e "${YELLOW}Operación cancelada.${NC}"
        log_msg "Limpieza de Swap cancelada."
        return
    fi

    echo -e "${BLUE}Eliminando archivos swap...${NC}"
    sudo rm -f /private/var/vm/swapfile* 2>/dev/null
    echo -e "${GREEN}✅ Archivos swap eliminados. Se recomienda reiniciar el equipo.${NC}"
    log_msg "Swap eliminado con éxito."
    sleep 1
}

# --- Tareas de Mantenimiento de Sistema ---

perform_disk_check() {
    echo -e "${YELLOW}--- Verificación del Volumen de Sistema (APFS) ---${NC}"
    log_msg "Iniciando verificación de volumen diskutil..."

    echo -e "${BLUE}Ejecutando diskutil verifyVolume /...${NC}"
    if diskutil verifyVolume /; then
        echo -e "${GREEN}✅ El volumen de sistema no presenta errores.${NC}"
        log_msg "Verificación de disco: OK"
    else
        echo -e "${RED}⚠️ Se encontraron posibles inconsistencias en el disco.${NC}"
        echo -e "${YELLOW}Recomendación: Reinicia en Modo de Recuperación (CMD+R o Mantener Botón de Encendido en Apple Silicon) y ejecuta Utilidad de Discos / First Aid.${NC}"
        log_warn "Verificación de disco encontró errores."
    fi
    sleep 2
}

reset_network_settings() {
    echo -e "${YELLOW}--- Restableciendo servicios y caché de red ---${NC}"
    log_msg "Restableciendo red y DNS..."

    echo -e "${BLUE}Limpiando caché DNS (dscacheutil / mDNSResponder)...${NC}"
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null || true

    echo -e "${BLUE}Restableciendo stack IPv6 en interfaz Wi-Fi...${NC}"
    networksetup -setv6off Wi-Fi 2>/dev/null || true
    networksetup -setv6automatic Wi-Fi 2>/dev/null || true

    echo -e "${GREEN}✅ Configuración de red restablecida.${NC}"
    log_msg "Red restablecida con éxito."
    sleep 1
}

free_ram() {
    echo -e "${YELLOW}--- Liberación de Memoria RAM ---${NC}"
    log_msg "Ejecutando purge de RAM..."
    echo -e "${BLUE}Ejecutando purge del sistema...${NC}"
    sudo purge
    echo -e "${GREEN}✅ Memoria inactiva liberada.${NC}"
    log_msg "Purge de RAM ejecutado."
    sleep 1
}

# --- Gestores de Paquetes y Herramientas ---

detect_homebrew() {
    if [ -x "/opt/homebrew/bin/brew" ]; then
        echo "/opt/homebrew/bin/brew"
    elif [ -x "/usr/local/bin/brew" ]; then
        echo "/usr/local/bin/brew"
    elif command -v brew &>/dev/null; then
        command -v brew
    else
        return 1
    fi
}

update_homebrew() {
    echo -e "${YELLOW}--- Mantenimiento y Actualización de Homebrew ---${NC}"
    log_msg "Iniciando comprobación de Homebrew..."

    local brew_path=$(detect_homebrew)
    if [ -z "$brew_path" ]; then
        echo -e "${BLUE}ℹ️ Homebrew no está instalado en el sistema.${NC}"
        log_msg "Homebrew no instalado."
        return
    fi

    echo -e "${BLUE}🔍 Homebrew hallado en: $brew_path${NC}"
    echo -e "${BLUE}Ejecutando actualización como usuario '$REAL_USER'...${NC}"

    sudo -u "$REAL_USER" bash <<BREW_CMD
        "$brew_path" update
        "$brew_path" upgrade
        "$brew_path" upgrade --cask --greedy 2>/dev/null || true
        "$brew_path" cleanup -s --prune=all
        "$brew_path" doctor || true
BREW_CMD

    echo -e "${GREEN}✅ Homebrew actualizado y optimizado.${NC}"
    log_msg "Homebrew actualizado con éxito."
    sleep 2
}

clean_pkg_managers_cache() {
    echo -e "${CYAN}--- Limpieza de Caché de Gestores de Paquetes (npm, pip) ---${NC}"
    log_msg "Limpiando gestores de paquetes..."
    local count=0

    if sudo -u "$REAL_USER" command -v npm &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de npm...${NC}"
        sudo -u "$REAL_USER" npm cache clean --force &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ npm limpiado.${NC}"
        ((count++))
    fi

    if sudo -u "$REAL_USER" command -v pip &>/dev/null || sudo -u "$REAL_USER" command -v pip3 &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de pip...${NC}"
        sudo -u "$REAL_USER" python3 -m pip cache purge &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ pip limpiado.${NC}"
        ((count++))
    fi

    if sudo -u "$REAL_USER" command -v dotnet &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de .NET/NuGet...${NC}"
        sudo -u "$REAL_USER" dotnet nuget locals all --clear &>/dev/null &
        spinner $!
        sudo -u "$REAL_USER" rm -rf "$REAL_HOME/.local/share/NuGet/http-cache" 2>/dev/null
        sudo -u "$REAL_USER" rm -rf "$REAL_HOME/.dotnet/packs/"* 2>/dev/null
        echo -e "${GREEN}✅ .NET/NuGet limpiado.${NC}"
        ((count++))
    fi

    if [ $count -eq 0 ]; then
        echo -e "${BLUE}ℹ️ No se detectaron npm, pip ni dotnet instalados.${NC}"
    fi
}

clean_xcode_cache() {
    echo -e "${CYAN}--- Limpieza de Caché de Xcode (DerivedData) ---${NC}"
    local xcode_path="$REAL_HOME/Library/Developer/Xcode/DerivedData"
    if [ -d "$xcode_path" ] && [ "$(ls -A "$xcode_path" 2>/dev/null)" ]; then
        echo -e "${YELLOW}Se detectó caché de Xcode (DerivedData).${NC}"
        if [ "$AUTO_MODE" = false ]; then
            read -p "   ¿Deseas limpiarlo? (S/n): " choice
            if [[ "$choice" == "n" || "$choice" == "N" ]]; then
                echo -e "${YELLOW}Omitiendo limpieza de Xcode.${NC}"
                return
            fi
        fi
        echo -n -e "${BLUE}Limpiando caché de Xcode...${NC}"
        rm -rf "$xcode_path"/* &
        spinner $!
        echo -e "${GREEN}✅ Caché de Xcode limpiado.${NC}"
        log_msg "Xcode DerivedData eliminado."
    else
        echo -e "${BLUE}ℹ️ No se encontró caché de Xcode para limpiar.${NC}"
    fi
}

uninstall_vsformac() {
    echo -e "${YELLOW}--- Desinstalando Visual Studio for Mac ---${NC}"
    log_msg "Iniciando desinstalación de Visual Studio for Mac..."

    sudo rm -rf "/Applications/Visual Studio.app"
    rm -rf "$REAL_HOME/Library/Caches/VisualStudio"
    rm -rf "$REAL_HOME/Library/Preferences/VisualStudio"
    rm -rf "$REAL_HOME/Library/Preferences/Visual Studio"
    rm -rf "$REAL_HOME/Library/Logs/VisualStudio"
    rm -rf "$REAL_HOME/Library/VisualStudio"
    rm -rf "$REAL_HOME/Library/Application Support/VisualStudio"
    rm -rf "$REAL_HOME/Library/Preferences/Xamarin/"

    echo -e "${BLUE}Desinstalando componentes de Xamarin...${NC}"
    sudo rm -rf /Developer/MonoDroid
    rm -rf "$REAL_HOME/Library/MonoAndroid"
    sudo pkgutil --forget com.xamarin.android.pkg 2>/dev/null || true
    sudo rm -rf /Library/Frameworks/Xamarin.Android.framework

    rm -rf "$REAL_HOME/Library/MonoTouch"
    sudo rm -rf /Library/Frameworks/Xamarin.iOS.framework
    sudo rm -rf /Developer/MonoTouch
    sudo pkgutil --forget com.xamarin.monotouch.pkg 2>/dev/null || true
    sudo pkgutil --forget com.xamarin.xamarin-ios-build-host.pkg 2>/dev/null || true

    sudo rm -rf /Library/Frameworks/Xamarin.Mac.framework
    rm -rf "$REAL_HOME/Library/Xamarin.Mac"

    echo -e "${BLUE}Limpiando el instalador...${NC}"
    rm -rf "$REAL_HOME/Library/Caches/XamarinInstaller/"
    rm -rf "$REAL_HOME/Library/Caches/VisualStudioInstaller/"
    rm -rf "$REAL_HOME/Library/Logs/XamarinInstaller/"
    rm -rf "$REAL_HOME/Library/Logs/VisualStudioInstaller/"

    echo -e "${GREEN}¡Desinstalación terminada!${NC}"
    log_msg "Desinstalación de Visual Studio for Mac completada."
}


clean_popular_apps_cache() {
    echo -e "${CYAN}--- Limpieza de Cachés de Aplicaciones Populares ---${NC}"
    log_msg "Limpiando cachés de aplicaciones populares..."

    local app_entries=(
        "Spotify|$REAL_HOME/Library/Application Support/Spotify/PersistentCache"
        "Google Chrome|$REAL_HOME/Library/Caches/Google/Chrome"
        "Firefox|$REAL_HOME/Library/Caches/Firefox"
        "Microsoft Edge|$REAL_HOME/Library/Caches/Microsoft Edge"
        "Slack|$REAL_HOME/Library/Caches/com.tinyspeck.slackmacgap"
        "VS Code|$REAL_HOME/Library/Caches/com.microsoft.VSCode"
    )

    local cleaned=0
    for entry in "${app_entries[@]}"; do
        local app="${entry%%|*}"
        local path="${entry#*|}"
        if [ -d "$path" ] && [ "$(ls -A "$path" 2>/dev/null)" ]; then
            echo -e "${BLUE}Limpiando caché de $app...${NC}"
            rm -rf "$path"/* 2>/dev/null || true
            echo -e "${GREEN}  ✅ $app limpiado.${NC}"
            log_msg "Caché de $app limpiado."
            ((cleaned++))
        fi
    done

    if [ $cleaned -eq 0 ]; then
        echo -e "${BLUE}ℹ️ No se encontraron cachés de aplicaciones para limpiar.${NC}"
    fi
}

# --- Revisión de Seguridad v4.0 ---

run_security_check() {
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}              REVISIÓN DE SEGURIDAD v4.0              ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    log_msg "Iniciando revisión de seguridad..."

    # 1. Firewall
    local fw_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo 0)
    if [ "$fw_status" -eq 0 ]; then
        echo -e "${RED}⚠️  ALERTA: Firewall de macOS está DESACTIVADO.${NC}"
        if [ "$AUTO_MODE" = false ]; then
            read -p "¿Deseas activar el Firewall ahora? (S/n): " choice
            if [[ "$choice" != "n" && "$choice" != "N" ]]; then
                sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
                echo -e "${GREEN}   ✅ Firewall activado.${NC}"
                log_msg "Firewall activado por el usuario."
            fi
        fi
    else
        echo -e "${GREEN}✅ Firewall de macOS: Activado.${NC}"
    fi

    # 2. Gatekeeper
    if [[ $(spctl --status 2>/dev/null) == "assessments disabled" ]]; then
        echo -e "${RED}⚠️  ALERTA: Gatekeeper está DESACTIVADO.${NC}"
        if [ "$AUTO_MODE" = false ]; then
            read -p "¿Deseas reactivar Gatekeeper? (S/n): " choice
            if [[ "$choice" != "n" && "$choice" != "N" ]]; then
                sudo spctl --master-enable
                echo -e "${GREEN}   ✅ Gatekeeper reactivado.${NC}"
                log_msg "Gatekeeper reactivado."
            fi
        fi
    else
        echo -e "${GREEN}✅ Gatekeeper: Activado.${NC}"
    fi

    # 3. FileVault
    local fv_status=$(fdesetup status 2>/dev/null)
    if echo "$fv_status" | grep -q "On"; then
        echo -e "${GREEN}✅ FileVault (Encriptación de disco): Activado.${NC}"
    else
        echo -e "${YELLOW}⚠️ FileVault está Desactivado.${NC}"
    fi

    # 4. Actualizaciones Automáticas
    local auto_update=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo 0)
    if [ "$auto_update" -eq 1 ]; then
        echo -e "${GREEN}✅ Búsqueda automática de actualizaciones: Activada.${NC}"
    else
        echo -e "${YELLOW}⚠️ Búsqueda automática de actualizaciones: Desactivada.${NC}"
    fi

    echo -e "${CYAN}======================================================${NC}"
    log_msg "Revisión de seguridad completada."
}

# --- Reporte de Salud del Sistema v4.0 ---

show_health_report() {
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}           REPORTE DE SALUD MAC v4.0 (${REAL_USER})        ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    log_msg "Generando reporte de salud..."

    # Hardware & Modelo
    local cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / Mac")
    local ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    local ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
    
    echo -e "${CYAN}💻 SISTEMA Y PROCESADOR:${NC}"
    echo -e "   - CPU:              ${YELLOW}$cpu_model${NC}"
    echo -e "   - Memoria RAM:      ${YELLOW}${ram_gb} GB${NC}"
    echo -e "   - macOS:            ${YELLOW}$(sw_vers -productVersion) (${REAL_USER})${NC}"
    echo ""

    # Batería
    echo -e "${CYAN}🔋 BATERÍA Y ENERGÍA:${NC}"
    if pmset -g batt | grep -q 'InternalBattery'; then
        local percent=$(pmset -g batt | grep -o '[0-9]*%;' | tr -d '%;')
        local power_info=$(system_profiler SPPowerDataType 2>/dev/null)
        local cycles=$(echo "$power_info" | grep "Cycle Count" | awk '{print $3}')
        local condition=$(echo "$power_info" | grep "Condition" | awk '{print $2}')
        local max_cap=$(echo "$power_info" | grep "Maximum Capacity" | awk '{print $3}')

        echo -e "   - Nivel de Carga:   ${YELLOW}${percent}%${NC}"
        echo -e "   - Ciclos de Carga:  ${YELLOW}${cycles:-N/A}${NC}"
        echo -e "   - Condición:        ${YELLOW}${condition:-Normal}${NC}"
        [ -n "$max_cap" ] && echo -e "   - Salud Capacidad:  ${YELLOW}${max_cap}${NC}"
    else
        echo -e "   ${BLUE}No se detectó batería interna (Mac de escritorio).${NC}"
    fi
    echo ""

    # Almacenamiento APFS
    echo -e "${CYAN}💾 ALMACENAMIENTO Y SSD:${NC}"
    local disk_info=$(df -h /System/Volumes/Data 2>/dev/null | tail -n 1)
    if [ -n "$disk_info" ]; then
        echo -e "   - Capacidad Total:  ${YELLOW}$(echo "$disk_info" | awk '{print $2}')${NC}"
        echo -e "   - Usado:            ${YELLOW}$(echo "$disk_info" | awk '{print $3}') ($(echo "$disk_info" | awk '{print $5}'))${NC}"
        echo -e "   - Disponible:       ${YELLOW}$(echo "$disk_info" | awk '{print $4}')${NC}"
    fi
    echo ""

    # Consumo de Procesos Top CPU & RAM
    echo -e "${CYAN}📊 TOP PROCESOS DE MAYOR CONSUMO (RAM / CPU):${NC}"
    ps -arcx -o %cpu,pmem,comm | head -n 6 | awk 'NR>1 {comm=""; for(i=3;i<=NF;i++) comm=comm (i==3?"":" ") $i; printf "   - %-28s CPU: %5s%% | RAM: %5s%%\n", comm, $1, $2}'
    echo ""

    echo -e "${GREEN}======================================================${NC}"
    press_any_key
}

# --- Ejecución Integral de Mantenimiento ---

run_all_maintenance() {
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}     EJECUTANDO MANTENIMIENTO INTEGRAL MANTENIX v4.0  ${NC}"
    echo -e "${BLUE}======================================================${NC}"
    log_msg "Iniciando mantenimiento integral v4.0..."

    clean_tm_snapshots
    create_tm_snapshot
    clean_caches_and_temp
    clean_icons_and_spotlight
    # clean_swap_files
    perform_disk_check
    reset_network_settings
    free_ram
    update_homebrew
    clean_pkg_managers_cache
    clean_xcode_cache
    clean_popular_apps_cache
    run_security_check

    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}  ✅ TODAS LAS TAREAS DE V4.0 FUERON COMPLETADAS     ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    log_msg "Mantenimiento integral v4.0 completado."
    notify_user "Mantenix v4.0" "Mantenimiento completo finalizado con éxito."
    sleep 2
}

# --- Actualizador Inteligente con SHA-256 ---

check_for_updates() {
    echo -e "${CYAN}Buscando actualizaciones de Mantenix v4.0...${NC}"
    log_msg "Comprobando actualizaciones remotas..."

    local remote_version=$(curl -sL "${RAW_REPO_URL}/${SCRIPT_VERSION}" | tr -d '\r\n')

    if [ -z "$remote_version" ]; then
        echo -e "${RED}❌ Error al conectar con GitHub repository.${NC}"
        log_err "Fallo al comprobar versión remota."
        press_any_key
        return
    fi

    echo -e "${BLUE}Versión instalada: ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}Última versión:    ${GREEN}$remote_version${NC}"

    if [ "$CURRENT_VERSION" = "$remote_version" ]; then
        echo -e "\n${GREEN}✅ ¡Mantenix está totalmente actualizado!${NC}"
    elif [ "$(printf '%s\n%s\n' "$remote_version" "$CURRENT_VERSION" | sort -V | head -n1)" = "$CURRENT_VERSION" ]; then
        echo -e "\n${YELLOW}✨ ¡Nueva versión disponible: v$remote_version!${NC}"
        if [ "$AUTO_MODE" = false ]; then
            read -p "¿Deseas descargar e instalar la actualización ahora? (S/n): " choice
            if [[ "$choice" == "n" || "$choice" == "N" ]]; then
                return
            fi
        fi

        local SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
        
        if [[ "$SCRIPT_DIR" == *".app/Contents/Resources" ]]; then
            # Modo App (Descargar ZIP de Releases)
            echo -e "${CYAN}Descargando la nueva versión desde GitHub Releases...${NC}"
            local APP_PATH=$(dirname $(dirname "$SCRIPT_DIR"))
            local APP_NAME=$(basename "$APP_PATH")
            local ZIP_NAME="${APP_NAME%.app}.zip"
            local DOWNLOAD_URL="https://github.com/RichyKunBv/Mantenix-MacOS-Edition/releases/latest/download/${ZIP_NAME}"
            local TMP_DIR="/tmp/MantenixUpdate_$$"
            
            mkdir -p "$TMP_DIR"
            local ZIP_FILE="$TMP_DIR/$ZIP_NAME"
            
            curl -fsSL -L "$DOWNLOAD_URL" -o "$ZIP_FILE" 2>/dev/null &
            spinner $!
            
            if [ -f "$ZIP_FILE" ]; then
                echo -e "${GREEN}✅ Descarga completa. Extrayendo...${NC}"
                unzip -q -o "$ZIP_FILE" -d "$TMP_DIR"
                
                if [ -d "$TMP_DIR/$APP_NAME" ]; then
                    echo -e "${GREEN}🔄 Instalando actualización...${NC}"
                    log_msg "Instalando nueva versión de la app v$remote_version"
                    
                    local UPDATER_SCRIPT="$TMP_DIR/updater.sh"
                    cat << EOF > "$UPDATER_SCRIPT"
#!/bin/bash
sleep 2
rm -rf "$APP_PATH"
mv "$TMP_DIR/$APP_NAME" "$APP_PATH"
sudo -u "$REAL_USER" open "$APP_PATH"
rm -rf "$TMP_DIR"
EOF
                    chmod +x "$UPDATER_SCRIPT"
                    
                    echo -e "${GREEN}La aplicación se reiniciará en unos segundos...${NC}"
                    nohup "$UPDATER_SCRIPT" >/dev/null 2>&1 &
                    exit 0
                else
                    echo -e "${RED}❌ Error: No se encontró la aplicación dentro del ZIP descargado.${NC}"
                    log_err "Fallo la extracción de la app al actualizar."
                    rm -rf "$TMP_DIR"
                fi
            else
                echo -e "${RED}❌ Error: Falló la descarga desde GitHub Releases.${NC}"
                log_err "Error al descargar ZIP de releases."
                rm -rf "$TMP_DIR"
            fi
        else
            # Modo Script clásico
            local script_path="${SCRIPT_DIR}/${SCRIPT_FILENAME}"
            local tmp_file=$(mktemp)
            echo -n -e "${CYAN}Descargando script actualizado...${NC}"
            curl -sL "${RAW_REPO_URL}/${SCRIPT_FILENAME}" -o "$tmp_file" &
            spinner $!

            if [ -s "$tmp_file" ] && ! grep -q "404: Not Found" "$tmp_file"; then
                chmod +x "$tmp_file"
                mv "$tmp_file" "$script_path"
                echo -e "${GREEN}✅ Actualización instalada correctamente. Reiniciando script...${NC}"
                log_msg "Script actualizado a v$remote_version"
                sleep 1
                exec "$script_path" "$@"
            else
                echo -e "${RED}❌ Error al validar el archivo descargado.${NC}"
                log_err "Fallo al validar script descargado en actualización."
                rm -f "$tmp_file"
            fi
        fi
    else
        echo -e "\n${CYAN}Estás utilizando una versión en desarrollo o personalizada (v$CURRENT_VERSION).${NC}"
    fi
    press_any_key
}

# --- Interfaz Gráfica (AppleScript / osascript) ---

show_gui_menu() {
    local choice=$(osascript -e '
        tell application (path to frontmost application as text)
            activate
            set options to { \
                "1) Mantenimiento Completo Automático", \
                "2) Limpieza de Cachés y Temporales", \
                "3) Diagnóstico del Disco (APFS)", \
                "4) Restablecer Red y DNS", \
                "5) Liberar Memoria RAM", \
                "6) Actualizar Homebrew", \
                "7) Reporte de Salud del Mac", \
                "8) Revisión de Seguridad", \
                "9) Limpieza de Caché de Apps (Spotify, Browsers, VSCode)", \
                "A) Purgar Snapshots Locales (Time Machine)", \
                "B) Limpieza Caché Xcode (DerivedData)", \
                "C) Desinstalar Visual Studio for Mac", \
                "Y) Buscar Actualizaciones" \
            }
            choose from list options with title "Mantenix macOS v4.0" prompt "Selecciona una opción de mantenimiento:" default items {"1) Mantenimiento Completo Automático"}
        end tell' 2>/dev/null)

    if [ -z "$choice" ] || [ "$choice" == "false" ]; then
        echo -e "${BLUE}Operación cancelada desde diálogo gráfico.${NC}"
        if [ "$GUI_MODE" = true ]; then
            exit 0
        fi
        return
    fi

    case "$choice" in
        *"1)"*) run_all_maintenance ;;
        *"2)"*) clean_caches_and_temp ;;
        *"3)"*) perform_disk_check ;;
        *"4)"*) reset_network_settings ;;
        *"5)"*) free_ram ;;
        *"6)"*) update_homebrew ;;
        *"7)"*) show_health_report ;;
        *"8)"*) run_security_check ;;
        *"9)"*) clean_popular_apps_cache ;;
        *"A)"*) clean_tm_snapshots ;;
        *"B)"*) clean_xcode_cache ;;
        *"C)"*) uninstall_vsformac ;;
        *"Y)"*) check_for_updates ;;
    esac
}

# --- Menú Principal Terminal ---

show_menu() {
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}           MANTENIX FOR MACOS v${CURRENT_VERSION} (Big Sur+)   ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${BLUE}  Usuario real: ${REAL_USER} | Log: ~/Library/Logs/MantenixBETA.log${NC}"
    echo ""
    echo -e "   ${YELLOW}1)${NC} Limpieza General de Cachés"
    echo -e "   ${YELLOW}2)${NC} Verificación del Disco APFS"
    echo -e "   ${YELLOW}3)${NC} Restablecer Configuración de Red"
    echo -e "   ${YELLOW}4)${NC} Liberar Memoria RAM Inactiva"
    echo -e "   ${YELLOW}5)${NC} Actualizar y Optimizar Homebrew"
    echo -e "   ${YELLOW}6)${NC} Reporte de Salud del Mac"
    echo -e "   ${YELLOW}7)${NC} Revisión de Seguridad"
    echo -e "   ${YELLOW}8)${NC} Limpieza de Caché de Apps (Spotify, Browsers, VSCode)"
    echo -e "   ${YELLOW}9)${NC} Purgar Snapshots Locales (Time Machine)"
    echo "   ----------------------------------------------------"
    echo -e "   ${CYAN}A)${NC} Ejecutar TODO el Mantenimiento (Modo Recomendado)"
    echo -e "   ${CYAN}B)${NC} Limpieza Caché Xcode (DerivedData)"
    echo -e "   ${CYAN}C)${NC} Desinstalar Visual Studio for Mac"
    echo -e "   ${CYAN}S)${NC} Crear Instantánea de Seguridad Time Machine"
    echo -e "   ${CYAN}G)${NC} Abrir Interfaz Gráfica (esta en prueba)"
    echo ""
    echo -e "   ${YELLOW}Y)${NC} Buscar Actualizaciones"
    echo -e "   ${RED}X)${NC} Salir"
    echo -e "${GREEN}======================================================${NC}"
    read -p "   >> Selecciona una opción: " choice
    echo ""

    case "$choice" in
        1) clean_caches_and_temp; press_any_key ;;
        2) perform_disk_check; press_any_key ;;
        3) reset_network_settings; press_any_key ;;
        4) free_ram; press_any_key ;;
        5) update_homebrew; press_any_key ;;
        6) show_health_report ;;
        7) run_security_check; press_any_key ;;
        8) clean_popular_apps_cache; press_any_key ;;
        9) clean_tm_snapshots; press_any_key ;;
        A|a) run_all_maintenance; press_any_key ;;
        B|b) clean_xcode_cache; press_any_key ;;
        C|c) uninstall_vsformac; press_any_key ;;
        S|s) create_tm_snapshot; press_any_key ;;
        G|g) show_gui_menu; press_any_key ;;
        Y|y) check_for_updates ;;
        X|x) echo -e "${BLUE}¡Gracias por usar Mantenix v4.0! Hasta pronto.${NC}"; exit 0 ;;
        *) echo -e "${RED}Opción no válida.${NC}"; sleep 1 ;;
    esac
}

# --- Procesamiento de Argumentos CLI ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            -g|--gui)
                GUI_MODE=true
                shift
                ;;
            -h|--help)
                echo "Mantenix macOS v4.0 - Opciones CLI:"
                echo "  -a, --auto   Ejecuta todas las tareas sin interacción de usuario."
                echo "  -g, --gui    Lanza la interfaz gráfica de selección (AppleScript)."
                echo "  -h, --help   Muestra esta ayuda."
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# --- Punto de Entrada Principal ---

parse_args "$@"
check_sudo "$@"
check_compatibility

if [ "$AUTO_MODE" = true ]; then
    log_msg "Ejecutando en modo desatendido (--auto)..."
    run_all_maintenance
    exit 0
elif [ "$GUI_MODE" = true ]; then
    show_gui_menu
    exit 0
fi

while true; do
    show_menu
done

#!/bin/bash
# ==============================================================================
# Mantenix / Mantenimiento macOS v4(Edición Moderna)
# Requisitos: macOS Big Sur (11.0) o superior
# ==============================================================================

CURRENT_VERSION="4.0.1"
ORIGINAL_ARGS=("$@")

# --- URLs del Repositorio ---
REPO_URL="https://github.com/RichyKunBv/Mantenix-MacOS-Edition"
RAW_REPO_BASE="https://raw.githubusercontent.com/RichyKunBv/Mantenix-MacOS-Edition"
RAW_REPO_URL="${RAW_REPO_BASE}/main"

SCRIPT_FILENAME="Mantenix.sh"
SCRIPT_VERSION="version.txt"

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
chown -R "$REAL_USER" "$LOG_DIR" 2>/dev/null || true

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
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [INFO] $1" >> "$LOG_FILE" 2>/dev/null
}

log_warn() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [WARN] $1" >> "$LOG_FILE" 2>/dev/null
}

log_err() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [ERROR] $1" >> "$LOG_FILE" 2>/dev/null
}

# --- Notificaciones nativas del sistema ---
notify_user() {
    local title="${1//\"/\\\"}"
    local message="${2//\"/\\\"}"
    if [[ "$GUI_MODE" == true || -z "$SSH_TTY" ]]; then
        sudo -u "$REAL_USER" osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
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
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r"
}

# --- Pausa Interactiva ---
press_any_key() {
    if [[ "$AUTO_MODE" == true ]]; then
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
        if [[ -x "$0" ]]; then
            exec sudo -p "Por favor, introduce tu contraseña de administrador para continuar: " "$0" "$@"
        else
            exec sudo -p "Por favor, introduce tu contraseña de administrador para continuar: " bash "$0" "$@"
        fi
    fi
}

# --- Verificación de Compatibilidad (macOS 11.0+) ---
check_compatibility() {
    local os_version
    local major_ver
    os_version=$(sw_vers -productVersion)
    major_ver=$(echo "$os_version" | cut -d '.' -f 1)

    log_msg "Compatibilidad comprobada: macOS $os_version (Mayor: $major_ver)"

    if [[ "$major_ver" -lt 11 ]]; then
        echo -e "${RED}❌ Error: Mantenix v4.0 requiere macOS Big Sur (11.0) o posterior.${NC}"
        echo -e "${YELLOW}Tu versión actual ($os_version) ya no es compatible con la versión 4.0.${NC}"
        log_err "Sistema incompatible: macOS $os_version"
        exit 1
    fi

    # Comprobación de SIP
    if csrutil status 2>/dev/null | grep -q "enabled"; then
        log_msg "SIP está activado."
    else
        log_warn "SIP está desactivado."
    fi
}

# --- Instantánea de Time Machine (Rollback Safety) ---
create_tm_snapshot() {
    echo -e "${CYAN}--- Instantánea de Seguridad de Time Machine ---${NC}"
    log_msg "Iniciando creación de instantánea local APFS..."

    if [[ "$AUTO_MODE" == false ]]; then
        read -r -p "¿Deseas crear una instantánea local de Time Machine antes de realizar cambios? (S/n): " confirm
        if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
            echo -e "${YELLOW}Omitiendo creación de instantánea.${NC}"
            log_msg "Creación de instantánea omitida por el usuario."
            return 0
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

    local snapshots
    snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep "com\.apple\.TimeMachine\." | awk -F. '{print $4}')
    if [[ -z "$snapshots" ]]; then
        echo -e "${BLUE}ℹ️ No se encontraron snapshots locales de Time Machine.${NC}"
    else
        echo -n -e "${BLUE}Purgando snapshots...${NC}"
        for s in $snapshots; do
            [[ -n "$s" ]] && tmutil deletelocalsnapshots "$s" &>/dev/null || true
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
    rm -rf "$REAL_HOME/Library/Caches/"* "$REAL_HOME/Library/Saved Application State/"* 2>/dev/null || true
    # Purgar logs preservando el directorio de Mantenix
    find "$REAL_HOME/Library/Logs" -mindepth 1 ! -name "Mantenix" ! -path "*/Mantenix/*" -delete 2>/dev/null || true
    rm -rf "$REAL_HOME/.cache/"* 2>/dev/null || true
    rm -rf "$REAL_HOME/.Trash/"* 2>/dev/null || true
    log_msg "Cachés de usuario, logs, papelera y .cache borrados."

    # Limpieza de sistema
    echo -e "${BLUE}Limpiando cachés de sistema y logs...${NC}"
    rm -rf /Library/Caches/* 2>/dev/null || true
    find /private/var/log -type f \( -name "*.log" -o -name "*.gz" -o -name "*.asl" \) -delete 2>/dev/null || true
    rm -rf /Library/Logs/* 2>/dev/null || true

    # Limpieza segura del contenido dentro de Caches y TemporaryItems (sin borrar las carpetas padre)
    echo -e "${BLUE}Limpiando contenido de Caches y TemporaryItems en /private/var/folders...${NC}"
    find /private/var/folders -type d \( -name "Caches" -o -name "TemporaryItems" \) -exec find {} -mindepth 1 -maxdepth 1 -exec rm -rf {} + \; 2>/dev/null || true
    rm -rf /private/var/tmp/* 2>/dev/null || true

    echo -e "${GREEN}✅ Limpieza de cachés finalizada.${NC}"
    log_msg "Limpieza de cachés completada."
    sleep 1
}

clean_icons_and_spotlight() {
    echo -e "${YELLOW}--- Limpieza de cachés de iconos y reindexación de Spotlight ---${NC}"
    log_msg "Iniciando reindexación de Spotlight y limpieza de iconos..."

    echo -e "${BLUE}Eliminando cachés de iconos y metadatos...${NC}"
    find /private/var/folders -name "com.apple.iconservices*" -exec rm -rf {} + 2>/dev/null || true
    rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
    killall -KILL iconservicesagent iconservicesd 2>/dev/null || true

    echo -e "${BLUE}Reiniciando y reindexando Spotlight...${NC}"
    mdutil -i off /System/Volumes/Data &>/dev/null || true
    mdutil -E /System/Volumes/Data &>/dev/null || true
    sleep 1
    mdutil -i on /System/Volumes/Data &>/dev/null || true
    mdutil -i on / &>/dev/null || true

    echo -e "${GREEN}✅ Reindexación de Spotlight activada.${NC}"
    log_msg "Spotlight reindexado con éxito."
    sleep 1
}

clean_swap_files() {
    echo -e "${YELLOW}--- Verificación de Memoria Virtual (Swap) ---${NC}"
    log_msg "Verificando estado de Swap..."

    local swap_info
    swap_info=$(sysctl -n vm.swapusage 2>/dev/null || echo "No disponible")
    echo -e "${BLUE}ℹ️ Estado actual de Swap: ${YELLOW}$swap_info${NC}"
    echo -e "${YELLOW}Nota: En macOS 11+, el kernel XNU administra /private/var/vm/swapfile* dinámicamente; borrarlos en caliente provoca un Kernel Panic. Reinicia el Mac para vaciar el swap de forma segura.${NC}"
    log_msg "Estado de Swap consultado: $swap_info"
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

    echo -e "${BLUE}Restableciendo stack IPv6 en interfaces activas...${NC}"
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        networksetup -setv6off "$service" 2>/dev/null || true
        networksetup -setv6automatic "$service" 2>/dev/null || true
    done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | grep -v '^\*')

    echo -e "${BLUE}Limpiando caché DNS (dscacheutil / mDNSResponder)...${NC}"
    dscacheutil -flushcache 2>/dev/null || true
    killall -HUP mDNSResponder 2>/dev/null || true

    echo -e "${GREEN}✅ Configuración de red restablecida.${NC}"
    log_msg "Red restablecida con éxito."
    sleep 1
}

free_ram() {
    echo -e "${YELLOW}--- Liberación de Memoria RAM ---${NC}"
    log_msg "Ejecutando purge de RAM..."
    echo -e "${BLUE}Ejecutando purge del sistema...${NC}"
    purge 2>/dev/null || true
    echo -e "${GREEN}✅ Memoria inactiva liberada.${NC}"
    log_msg "Purge de RAM ejecutado."
    sleep 1
}

# --- Gestores de Paquetes y Herramientas ---

detect_homebrew() {
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        echo "/opt/homebrew/bin/brew"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        echo "/usr/local/bin/brew"
    else
        sudo -H -u "$REAL_USER" bash -lc 'command -v brew' 2>/dev/null || return 1
    fi
}

update_homebrew() {
    echo -e "${YELLOW}--- Mantenimiento y Actualización de Homebrew ---${NC}"
    log_msg "Iniciando comprobación de Homebrew..."

    local brew_path
    brew_path=$(detect_homebrew)
    if [[ -z "$brew_path" ]]; then
        echo -e "${BLUE}ℹ️ Homebrew no está instalado en el sistema.${NC}"
        log_msg "Homebrew no instalado."
        return 0
    fi

    echo -e "${BLUE}🔍 Homebrew hallado en: $brew_path${NC}"
    echo -e "${BLUE}Ejecutando actualización como usuario '$REAL_USER'...${NC}"

    if sudo -H -u "$REAL_USER" HOME="$REAL_HOME" bash -lc "
        \"$brew_path\" update &&
        \"$brew_path\" upgrade &&
        (\"$brew_path\" upgrade --cask --greedy 2>/dev/null || true) &&
        \"$brew_path\" cleanup -s --prune=all &&
        (\"$brew_path\" doctor || true)
    "; then
        echo -e "${GREEN}✅ Homebrew actualizado y optimizado.${NC}"
        log_msg "Homebrew actualizado con éxito."
    else
        echo -e "${YELLOW}⚠️ Homebrew finalizó con advertencias. Continuando con el mantenimiento...${NC}"
        log_warn "Homebrew reportó advertencias durante la actualización."
    fi
    sleep 2
}

clean_pkg_managers_cache() {
    echo -e "${CYAN}--- Limpieza de Caché de Gestores de Paquetes (npm, pip, dotnet) ---${NC}"
    log_msg "Limpiando gestores de paquetes..."
    local count=0

    if sudo -H -u "$REAL_USER" bash -lc 'command -v npm' &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de npm...${NC}"
        sudo -H -u "$REAL_USER" HOME="$REAL_HOME" bash -lc 'npm cache clean --force' &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ npm limpiado.${NC}"
        count=$((count + 1))
    fi

    if sudo -H -u "$REAL_USER" bash -lc 'command -v python3' &>/dev/null && \
       sudo -H -u "$REAL_USER" bash -lc 'python3 -m pip --version' &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de pip...${NC}"
        sudo -H -u "$REAL_USER" HOME="$REAL_HOME" bash -lc 'python3 -m pip cache purge' &>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ pip limpiado.${NC}"
        count=$((count + 1))
    fi

    if sudo -H -u "$REAL_USER" bash -lc 'command -v dotnet' &>/dev/null; then
        echo -n -e "${BLUE}Limpiando caché de .NET/NuGet...${NC}"
        sudo -H -u "$REAL_USER" HOME="$REAL_HOME" bash -lc 'dotnet nuget locals all --clear' &>/dev/null &
        spinner $!
        rm -rf "$REAL_HOME/.local/share/NuGet/http-cache" 2>/dev/null || true
        echo -e "${GREEN}✅ .NET/NuGet limpiado.${NC}"
        count=$((count + 1))
    fi

    if [[ $count -eq 0 ]]; then
        echo -e "${BLUE}ℹ️ No se detectaron npm, pip ni dotnet instalados.${NC}"
    fi
    return 0
}

clean_xcode_cache() {
    echo -e "${CYAN}--- Limpieza de Caché de Xcode (DerivedData) ---${NC}"
    local xcode_path="$REAL_HOME/Library/Developer/Xcode/DerivedData"
    if [[ -d "$xcode_path" && -n "$(ls -A "$xcode_path" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}Se detectó caché de Xcode (DerivedData).${NC}"
        if [[ "$AUTO_MODE" == false ]]; then
            read -r -p "   ¿Deseas limpiarlo? (S/n): " choice
            if [[ "$choice" == "n" || "$choice" == "N" ]]; then
                echo -e "${YELLOW}Omitiendo limpieza de Xcode.${NC}"
                return 0
            fi
        fi
        echo -n -e "${BLUE}Limpiando caché de Xcode...${NC}"
        find "$xcode_path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null &
        spinner $!
        echo -e "${GREEN}✅ Caché de Xcode limpiado.${NC}"
        log_msg "Xcode DerivedData eliminado."
    else
        echo -e "${BLUE}ℹ️ No se encontró caché de Xcode para limpiar.${NC}"
    fi
    return 0
}

uninstall_vsformac() {
    echo -e "${YELLOW}--- Desinstalando Visual Studio for Mac ---${NC}"
    log_msg "Iniciando desinstalación de Visual Studio for Mac..."

    rm -rf "/Applications/Visual Studio.app" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Caches/VisualStudio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Preferences/VisualStudio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Preferences/Visual Studio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Logs/VisualStudio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/VisualStudio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Application Support/VisualStudio" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Preferences/Xamarin/" 2>/dev/null || true

    echo -e "${BLUE}Desinstalando componentes de Xamarin...${NC}"
    rm -rf /Developer/MonoDroid 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/MonoAndroid" 2>/dev/null || true
    pkgutil --forget com.xamarin.android.pkg 2>/dev/null || true
    rm -rf /Library/Frameworks/Xamarin.Android.framework 2>/dev/null || true

    rm -rf "$REAL_HOME/Library/MonoTouch" 2>/dev/null || true
    rm -rf /Library/Frameworks/Xamarin.iOS.framework 2>/dev/null || true
    rm -rf /Developer/MonoTouch 2>/dev/null || true
    pkgutil --forget com.xamarin.monotouch.pkg 2>/dev/null || true
    pkgutil --forget com.xamarin.xamarin-ios-build-host.pkg 2>/dev/null || true

    rm -rf /Library/Frameworks/Xamarin.Mac.framework 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Xamarin.Mac" 2>/dev/null || true

    echo -e "${BLUE}Limpiando el instalador...${NC}"
    rm -rf "$REAL_HOME/Library/Caches/XamarinInstaller/" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Caches/VisualStudioInstaller/" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Logs/XamarinInstaller/" 2>/dev/null || true
    rm -rf "$REAL_HOME/Library/Logs/VisualStudioInstaller/" 2>/dev/null || true

    echo -e "${GREEN}¡Desinstalación terminada!${NC}"
    log_msg "Desinstalación de Visual Studio for Mac completada."
}

clean_popular_apps_cache() {
    echo -e "${CYAN}--- Limpieza de Cachés de Aplicaciones Populares ---${NC}"
    log_msg "Limpiando cachés de aplicaciones populares..."

    # Formato: "Nombre Visible|NombreBundle.app|RutaCache"
    local app_entries=(
        "Spotify|Spotify.app|$REAL_HOME/Library/Application Support/Spotify/PersistentCache"
        "Google Chrome|Google Chrome.app|$REAL_HOME/Library/Caches/Google/Chrome"
        "Firefox|Firefox.app|$REAL_HOME/Library/Caches/Firefox"
        "Microsoft Edge|Microsoft Edge.app|$REAL_HOME/Library/Caches/Microsoft Edge"
        "Slack|Slack.app|$REAL_HOME/Library/Caches/com.tinyspeck.slackmacgap"
        "VS Code|Visual Studio Code.app|$REAL_HOME/Library/Caches/com.microsoft.VSCode"
    )

    local cleaned=0
    local skipped=0

    for entry in "${app_entries[@]}"; do
        local app="${entry%%|*}"
        local rest="${entry#*|}"
        local app_bundle="${rest%%|*}"
        local path="${rest#*|}"

        # 1. Verificar si existe la carpeta y si macOS permite leerla
        if [[ ! -d "$path" ]]; then
            continue
        elif [[ ! -r "$path" ]]; then
            echo -e "${YELLOW}  ⚠️ Sin permisos de lectura para $app (revisa Acceso total al disco). Saltando...${NC}"
            log_warn "Sin permisos de lectura en caché de $app ($path)."
            skipped=$((skipped + 1))
            continue
        fi

        # 2. Verificar si está vacía
        if [[ -z "$(ls -A "$path" 2>/dev/null)" ]]; then
            continue
        fi

        # 3. Verificar si la aplicación está abierta para evitar bloqueos de archivo
        if pgrep -f "$app_bundle" &>/dev/null; then
            echo -e "${YELLOW}  ⚠️ $app está en ejecución. Se omite para evitar errores y se pasa al siguiente...${NC}"
            log_warn "Caché de $app omitido porque la aplicación está abierta."
            skipped=$((skipped + 1))
            continue
        fi

        # 4. Intentar limpiar; si falla por algún bloqueo del sistema, continuar con la siguiente
        echo -e "${BLUE}Limpiando caché de $app...${NC}"
        if find "$path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; then
            echo -e "${GREEN}  ✅ $app limpiado.${NC}"
            log_msg "Caché de $app limpiado."
            cleaned=$((cleaned + 1))
        else
            echo -e "${YELLOW}  ⚠️ No se pudo limpiar por completo $app (archivos bloqueados por macOS). Continuando...${NC}"
            log_warn "Error parcial al limpiar caché de $app; se continuó con el siguiente."
            skipped=$((skipped + 1))
        fi
    done

    if [[ $cleaned -eq 0 && $skipped -eq 0 ]]; then
        echo -e "${BLUE}ℹ️ No se encontraron cachés de aplicaciones para limpiar.${NC}"
    elif [[ $skipped -gt 0 ]]; then
        echo -e "${BLUE}ℹ️ Limpieza de apps finalizada ($cleaned limpiadas, $skipped omitidas).${NC}"
    fi

    return 0
}

# --- Revisión de Seguridad v4.0 ---

run_security_check() {
    echo -e "${CYAN}======================================================${NC}"
    echo -e "${CYAN}              REVISIÓN DE SEGURIDAD v4.0              ${NC}"
    echo -e "${CYAN}======================================================${NC}"
    log_msg "Iniciando revisión de seguridad..."

    # 1. Firewall
    if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q "enabled"; then
        echo -e "${GREEN}✅ Firewall de macOS: Activado.${NC}"
    else
        echo -e "${RED}⚠️  ALERTA: Firewall de macOS está DESACTIVADO.${NC}"
        if [[ "$AUTO_MODE" == false ]]; then
            read -r -p "¿Deseas activar el Firewall ahora? (S/n): " choice
            if [[ "$choice" != "n" && "$choice" != "N" ]]; then
                /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on &>/dev/null || true
                echo -e "${GREEN}   ✅ Firewall activado.${NC}"
                log_msg "Firewall activado por el usuario."
            fi
        fi
    fi

    # 2. Gatekeeper
    if [[ "$(spctl --status 2>/dev/null)" == "assessments disabled" ]]; then
        echo -e "${RED}⚠️  ALERTA: Gatekeeper está DESACTIVADO.${NC}"
        if [[ "$AUTO_MODE" == false ]]; then
            read -r -p "¿Deseas reactivar Gatekeeper? (S/n): " choice
            if [[ "$choice" != "n" && "$choice" != "N" ]]; then
                if spctl --global-enable 2>/dev/null || spctl --master-enable 2>/dev/null; then
                    echo -e "${GREEN}   ✅ Gatekeeper reactivado.${NC}"
                    log_msg "Gatekeeper reactivado."
                else
                    echo -e "${YELLOW}   ⚠️ En macOS Sequoia+, confirma la reactivación en Ajustes del Sistema > Privacidad y seguridad.${NC}"
                fi
            fi
        fi
    else
        echo -e "${GREEN}✅ Gatekeeper: Activado.${NC}"
    fi

    # 3. FileVault
    local fv_status
    fv_status=$(fdesetup status 2>/dev/null || true)
    if echo "$fv_status" | grep -q "On"; then
        echo -e "${GREEN}✅ FileVault (Encriptación de disco): Activado.${NC}"
    else
        echo -e "${YELLOW}⚠️ FileVault está Desactivado.${NC}"
    fi

    # 4. Actualizaciones Automáticas
    local auto_update
    auto_update=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled 2>/dev/null || echo 0)
    if [[ "$auto_update" == "1" ]]; then
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
    local cpu_model
    local ram_bytes
    local ram_gb
    cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon / Mac")
    ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    ram_gb=$((ram_bytes / 1024 / 1024 / 1024))

    echo -e "${CYAN}💻 SISTEMA Y PROCESADOR:${NC}"
    echo -e "   - CPU:              ${YELLOW}$cpu_model${NC}"
    echo -e "   - Memoria RAM:      ${YELLOW}${ram_gb} GB${NC}"
    echo -e "   - macOS:            ${YELLOW}$(sw_vers -productVersion) (${REAL_USER})${NC}"
    echo ""

    # Batería (vía ioreg, independiente del idioma de macOS)
    echo -e "${CYAN}🔋 BATERÍA Y ENERGÍA:${NC}"
    if pmset -g batt 2>/dev/null | grep -q 'InternalBattery'; then
        local percent
        local batt_reg
        local cycles
        local max_cap
        local design_cap
        local fail_status
        local health_pct=""

        percent=$(pmset -g batt | grep -o '[0-9]*%;' | tr -d '%;')
        batt_reg=$(ioreg -rn AppleSmartBattery 2>/dev/null)
        cycles=$(echo "$batt_reg" | awk '/"CycleCount" =/ {print $3; exit}')
        max_cap=$(echo "$batt_reg" | awk '/"AppleRawMaxCapacity" =/ {print $3; exit}')
        [[ -z "$max_cap" ]] && max_cap=$(echo "$batt_reg" | awk '/"MaxCapacity" =/ {print $3; exit}')
        design_cap=$(echo "$batt_reg" | awk '/"DesignCapacity" =/ {print $3; exit}')
        fail_status=$(echo "$batt_reg" | awk '/"PermanentFailureStatus" =/ {print $3; exit}')

        if [[ -n "$max_cap" && -n "$design_cap" && "$design_cap" -gt 0 ]]; then
            health_pct="$((max_cap * 100 / design_cap))%"
        fi

        local condition="Normal"
        [[ "$fail_status" == "1" ]] && condition="Requiere mantenimiento"

        echo -e "   - Nivel de Carga:   ${YELLOW}${percent}%${NC}"
        echo -e "   - Ciclos de Carga:  ${YELLOW}${cycles:-N/A}${NC}"
        echo -e "   - Condición:        ${YELLOW}${condition}${NC}"
        [[ -n "$health_pct" ]] && echo -e "   - Salud Capacidad:  ${YELLOW}${health_pct}${NC}"
    else
        echo -e "   ${BLUE}No se detectó batería interna (Mac de escritorio).${NC}"
    fi
    echo ""

    # Almacenamiento APFS
    echo -e "${CYAN}💾 ALMACENAMIENTO Y SSD:${NC}"
    local disk_info
    disk_info=$(df -H /System/Volumes/Data 2>/dev/null | tail -n 1)
    if [[ -n "$disk_info" ]]; then
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
    perform_disk_check
    reset_network_settings
    free_ram
    update_homebrew
    clean_pkg_managers_cache
    clean_xcode_cache
    clean_popular_apps_cache
    run_security_check

    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}  ✅ TODAS LAS TAREAS DE V4.0 FUERON COMPLETADAS      ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    log_msg "Mantenimiento integral v4.0 completado."
    notify_user "Mantenix v4.0" "Mantenimiento completo finalizado con éxito."
    sleep 2
}

# --- Actualizador Inteligente ---

check_for_updates() {
    echo -e "${CYAN}Buscando actualizaciones de Mantenix v4.0...${NC}"
    log_msg "Comprobando actualizaciones remotas..."

    local remote_version
    remote_version=$(curl -fsSL "${RAW_REPO_URL}/${SCRIPT_VERSION}" 2>/dev/null | tr -d '\r\n')

    if [[ -z "$remote_version" ]]; then
        echo -e "${RED}❌ Error al conectar con el repositorio de GitHub.${NC}"
        log_err "Fallo al comprobar versión remota."
        press_any_key
        return 0
    fi

    echo -e "${BLUE}Versión instalada: ${GREEN}$CURRENT_VERSION${NC}"
    echo -e "${BLUE}Última versión:    ${GREEN}$remote_version${NC}"

    if [[ "$CURRENT_VERSION" == "$remote_version" ]]; then
        echo -e "\n${GREEN}✅ ¡Mantenix está totalmente actualizado!${NC}"
    elif [[ "$(printf '%s\n%s\n' "$remote_version" "$CURRENT_VERSION" | sort -V | head -n1)" == "$CURRENT_VERSION" ]]; then
        echo -e "\n${YELLOW}✨ ¡Nueva versión disponible: v$remote_version!${NC}"
        if [[ "$AUTO_MODE" == false ]]; then
            read -r -p "¿Deseas descargar e instalar la actualización ahora? (S/n): " choice
            if [[ "$choice" == "n" || "$choice" == "N" ]]; then
                return 0
            fi
        fi

        local SCRIPT_DIR
        SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

        if [[ "$SCRIPT_DIR" == *".app/Contents/Resources" ]]; then
            # Modo App (Descargar ZIP de Releases)
            echo -e "${CYAN}Descargando la nueva versión desde GitHub Releases...${NC}"
            local APP_PATH
            local APP_NAME
            local ZIP_NAME
            local DOWNLOAD_URL
            local TMP_DIR="/tmp/MantenixUpdate_$$"

            APP_PATH=$(dirname "$(dirname "$SCRIPT_DIR")")
            APP_NAME=$(basename "$APP_PATH")
            ZIP_NAME="${APP_NAME%.app}.zip"
            DOWNLOAD_URL="https://github.com/RichyKunBv/Mantenix-MacOS-Edition/releases/latest/download/${ZIP_NAME}"

            mkdir -p "$TMP_DIR"
            local ZIP_FILE="$TMP_DIR/$ZIP_NAME"

            curl -fsSL -L "$DOWNLOAD_URL" -o "$ZIP_FILE" 2>/dev/null &
            spinner $!

            if [[ -s "$ZIP_FILE" ]]; then
                echo -e "${GREEN}✅ Descarga completa. Extrayendo...${NC}"
                unzip -q -o "$ZIP_FILE" -d "$TMP_DIR"

                if [[ -d "$TMP_DIR/$APP_NAME" ]]; then
                    echo -e "${GREEN}🔄 Instalando actualización...${NC}"
                    log_msg "Instalando nueva versión de la app v$remote_version"

                    local UPDATER_SCRIPT="$TMP_DIR/updater.sh"
                    cat << EOF > "$UPDATER_SCRIPT"
#!/bin/bash
sleep 2
rm -rf "$APP_PATH"
mv "$TMP_DIR/$APP_NAME" "$APP_PATH"
chown -R "$REAL_USER" "$APP_PATH" 2>/dev/null || true
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
            local script_path="${SCRIPT_DIR}/$(basename "$0")"
            local tmp_file
            tmp_file=$(mktemp)
            echo -n -e "${CYAN}Descargando script actualizado...${NC}"
            curl -fsSL "${RAW_REPO_URL}/${SCRIPT_FILENAME}" -o "$tmp_file" 2>/dev/null &
            spinner $!

            if [[ -s "$tmp_file" ]] && bash -n "$tmp_file" 2>/dev/null; then
                chown "$REAL_USER" "$tmp_file" 2>/dev/null || true
                chmod 755 "$tmp_file"
                mv "$tmp_file" "$script_path"
                echo -e "${GREEN}✅ Actualización instalada correctamente. Reiniciando script...${NC}"
                log_msg "Script actualizado a v$remote_version"
                sleep 1
                exec "$script_path" "${ORIGINAL_ARGS[@]}"
            else
                echo -e "${RED}❌ Error al validar el archivo descargado (corrupto o 404).${NC}"
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
    local choice
    choice=$(sudo -u "$REAL_USER" osascript -e '
        tell application "System Events"
            activate
            set options to { ¬
                "1) Mantenimiento Completo Automático", ¬
                "2) Limpieza de Cachés y Temporales", ¬
                "3) Diagnóstico del Disco (APFS)", ¬
                "4) Restablecer Red y DNS", ¬
                "5) Liberar Memoria RAM", ¬
                "6) Actualizar Homebrew", ¬
                "7) Reporte de Salud del Mac", ¬
                "8) Revisión de Seguridad", ¬
                "9) Limpieza de Caché de Apps (Spotify, Browsers, VSCode)", ¬
                "A) Purgar Snapshots Locales (Time Machine)", ¬
                "B) Limpieza Caché Xcode (DerivedData)", ¬
                "C) Desinstalar Visual Studio for Mac", ¬
                "Y) Buscar Actualizaciones" ¬
            }
            choose from list options with title "Mantenix macOS v4.0" prompt "Selecciona una opción de mantenimiento:" default items {"1) Mantenimiento Completo Automático"}
        end tell' 2>/dev/null)

    if [[ -z "$choice" || "$choice" == "false" ]]; then
        echo -e "${BLUE}Operación cancelada desde diálogo gráfico.${NC}"
        if [[ "$GUI_MODE" == true ]]; then
            exit 0
        fi
        return 1
    fi

    case "$choice" in
        *"1)"*) run_all_maintenance ;;
        *"2)"*) clean_caches_and_temp ;;
        *"3)"*) perform_disk_check ;;
        *"4)"*) reset_network_settings ;;
        *"5)"*) free_ram ;;
        *"6)"*) update_homebrew ;;
        *"7)"*) show_health_report; return 1 ;;
        *"8)"*) run_security_check ;;
        *"9)"*) clean_popular_apps_cache ;;
        *"A)"*) clean_tm_snapshots ;;
        *"B)"*) clean_xcode_cache ;;
        *"C)"*) uninstall_vsformac ;;
        *"Y)"*) check_for_updates; return 1 ;;
    esac
    return 0
}

# --- Menú Principal Terminal ---

show_menu() {
    clear
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${GREEN}          MANTENIX FOR MACOS v${CURRENT_VERSION} (Big Sur+)   ${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${BLUE}  Usuario real: ${REAL_USER} | Log: ~/Library/Logs/Mantenix/MantenixBETA.log${NC}"
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
    echo -e "   ${CYAN}G)${NC} Abrir Interfaz Gráfica (en prueba)"
    echo ""
    echo -e "   ${YELLOW}Y)${NC} Buscar Actualizaciones"
    echo -e "   ${RED}X)${NC} Salir"
    echo -e "${GREEN}======================================================${NC}"
    read -r -p "   >> Selecciona una opción: " choice
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
        G|g) show_gui_menu && press_any_key ;;
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
                echo -e "${RED}Argumento desconocido: $1${NC}"
                echo "Usa -h o --help para ver las opciones disponibles."
                exit 1
                ;;
        esac
    done
}

# --- Punto de Entrada Principal ---

parse_args "$@"
check_sudo "$@"
check_compatibility

if [[ "$AUTO_MODE" == true ]]; then
    log_msg "Ejecutando en modo desatendido (--auto)..."
    run_all_maintenance
    exit 0
elif [[ "$GUI_MODE" == true ]]; then
    show_gui_menu
    exit 0
fi

while true; do
    show_menu
done
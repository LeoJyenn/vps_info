#!/bin/bash

# 系统信息监控脚本 (System Information Monitoring Script)
# 适用于多种 Linux 发行版 (Compatible with multiple Linux distributions)

# Check if running on Linux
if [[ "$(uname)" != "Linux" ]]; then
    echo "本脚本仅适用于Linux系统。"
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
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIVIDER="${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

clear # Clear the screen for better visibility

# Function to get network traffic
get_network_traffic() {
    # Get received and sent bytes
    local rx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{received += $2} END {print received}')
    local tx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{sent += $10} END {print sent}')

    # Convert to GB - carefully handle the calculation to avoid BC errors
    if [[ -n "$rx_bytes" && "$rx_bytes" != "0" ]]; then
        local rx_gb=$(echo "scale=2; $rx_bytes/1024/1024/1024" | bc 2>/dev/null || echo "0.00")
    else
        local rx_gb="0.00"
    fi

    if [[ -n "$tx_bytes" && "$tx_bytes" != "0" ]]; then
        local tx_gb=$(echo "scale=2; $tx_bytes/1024/1024/1024" | bc 2>/dev/null || echo "0.00")
    else
        local tx_gb="0.00"
    fi

    echo "$rx_gb $tx_gb"
}

# Function to get geographical location based on IP
get_geo_location() {
    local ip=$1
    if [[ -z "$ip" || "$ip" == "Unknown" ]]; then
        echo "未知"
        return
    fi

    local geo=$(curl -s --max-time 3 "https://ipinfo.io/${ip}/json" 2>/dev/null)
    if [[ -n "$geo" && "$geo" != *"error"* ]]; then
        local country=$(echo "$geo" | grep '"country"' | cut -d'"' -f4)
        local city=$(echo "$geo" | grep '"city"' | cut -d'"' -f4)
        if [[ -n "$country" && -n "$city" ]]; then
            # 转换国家代码为中文名称
            case "$country" in
            "US") country="美国" ;;
            "CN") country="中国" ;;
            "JP") country="日本" ;;
            "KR") country="韩国" ;;
            "SG") country="新加坡" ;;
            "RU") country="俄罗斯" ;;
            "DE") country="德国" ;;
            "GB") country="英国" ;;
            "CA") country="加拿大" ;;
            "AU") country="澳大利亚" ;;
            "FR") country="法国" ;;
            esac
            echo "$country $city"
        else
            echo "未知"
        fi
    else
        echo "未知"
    fi
}

# Function to format network congestion algorithm output
format_cong_algo() {
    local algo=$1
    case "$algo" in
    "bbr") echo "BBR" ;;
    "cubic") echo "CUBIC" ;;
    "reno") echo "RENO" ;;
    "vegas") echo "VEGAS" ;;
    "westwood") echo "WESTWOOD" ;;
    *) echo "$algo" ;;
    esac
}

# Get system information with error handling
hostname=$(hostname)
provider=$(if [ -f /sys/devices/virtual/dmi/id/product_name ]; then cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "未知"; else echo "未知"; fi)

# Try multiple methods to get OS version
if command -v lsb_release &>/dev/null; then
    os_version=$(lsb_release -d 2>/dev/null | awk -F':' '{print $2}' | xargs)
elif [ -f /etc/os-release ]; then
    os_version=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d'"' -f2)
else
    os_version="未知"
fi

kernel_version=$(uname -r)
cpu_arch=$(uname -m)
cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "未知")
cpu_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo "未知")

# Get CPU usage with improved error handling
cpu_usage_raw=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' || echo "0")
cpu_usage="${cpu_usage_raw}%"

# Get memory information with error handling
if command -v free &>/dev/null; then
    mem_info=$(free -m | grep Mem)
    total_mem=$(echo $mem_info | awk '{print $2}')
    used_mem=$(echo $mem_info | awk '{print $3}')
    if [[ -n "$used_mem" && -n "$total_mem" && "$total_mem" != "0" ]]; then
        mem_percent=$(echo "scale=2; ($used_mem/$total_mem)*100" | bc 2>/dev/null || echo "0")
        mem_percent="${mem_percent}%"
    else
        mem_percent="未知"
    fi

    # Get swap information
    swap_info=$(free -m | grep Swap)
    total_swap=$(echo $swap_info | awk '{print $2}')
    used_swap=$(echo $swap_info | awk '{print $3}')
    if [[ -n "$used_swap" && -n "$total_swap" ]]; then
        if [[ "$total_swap" -eq 0 ]]; then
            swap_percent="0%"
        else
            swap_percent=$(echo "scale=2; ($used_swap/$total_swap)*100" | bc 2>/dev/null || echo "0")
            swap_percent="${swap_percent}%"
        fi
    else
        swap_percent="未知"
    fi
else
    total_mem="未知"
    used_mem="未知"
    mem_percent="未知"
    total_swap="未知"
    used_swap="未知"
    swap_percent="未知"
fi

# Get disk information with error handling
if command -v df &>/dev/null; then
    disk_info=$(df -h / 2>/dev/null | grep -v Filesystem)
    disk_used=$(echo $disk_info | awk '{print $3}')
    disk_total=$(echo $disk_info | awk '{print $2}')
    disk_percent=$(echo $disk_info | awk '{print $5}')
else
    disk_used="未知"
    disk_total="未知"
    disk_percent="未知"
fi

# Get network traffic with error handling
if [ -f /proc/net/dev ]; then
    read rx_gb tx_gb <<<"$(get_network_traffic)"
    # 确保值不为空，改成两位小数
    rx_gb=${rx_gb:-"0.00"}
    tx_gb=${tx_gb:-"0.00"}

    # 如果值为0.00，尝试以MB为单位显示
    if [[ "$rx_gb" == "0.00" ]]; then
        rx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{received += $2} END {print received}')
        if [[ -n "$rx_bytes" && "$rx_bytes" != "0" ]]; then
            rx_mb=$(echo "scale=2; $rx_bytes/1024/1024" | bc 2>/dev/null || echo "0.00")
            rx_display="${rx_mb} MB"
        else
            rx_display="0.00 GB"
        fi
    else
        rx_display="${rx_gb} GB"
    fi

    if [[ "$tx_gb" == "0.00" ]]; then
        tx_bytes=$(cat /proc/net/dev | grep -v lo | awk '{sent += $10} END {print sent}')
        if [[ -n "$tx_bytes" && "$tx_bytes" != "0" ]]; then
            tx_mb=$(echo "scale=2; $tx_bytes/1024/1024" | bc 2>/dev/null || echo "0.00")
            tx_display="${tx_mb} MB"
        else
            tx_display="0.00 GB"
        fi
    else
        tx_display="${tx_gb} GB"
    fi
else
    rx_display="未知"
    tx_display="未知"
fi

# Get network congestion algorithm with error handling
if command -v sysctl &>/dev/null; then
    tcp_cong_raw=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}' || echo "未知")
    tcp_cong=$(format_cong_algo "$tcp_cong_raw")
else
    tcp_cong="未知"
fi

# Get public IP addresses with timeout to avoid hanging
ipv4_addr=$(curl -s --max-time 3 https://ipv4.icanhazip.com 2>/dev/null || echo "未知")
ipv6_addr=$(curl -s --max-time 3 https://ipv6.icanhazip.com 2>/dev/null || echo "不可用")

# Get location based on IP
location=$(get_geo_location "$ipv4_addr")

# Get system time
sys_time=$(date "+%Y-%m-%d %H:%M %p")

# Get uptime with error handling and convert to Chinese
if command -v uptime &>/dev/null; then
    # Try different methods to get uptime in a format we can parse
    if uptime -p &>/dev/null; then
        # Use 'uptime -p' if available (modern systems)
        uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')

        # 更精确的中文转换
        uptime_str=$(echo "$uptime_str" | sed 's/\([0-9]\+\) week/\1周/g' | sed 's/\([0-9]\+\) weeks/\1周/g')
        uptime_str=$(echo "$uptime_str" | sed 's/\([0-9]\+\) day/\1天/g' | sed 's/\([0-9]\+\) days/\1天/g')
        uptime_str=$(echo "$uptime_str" | sed 's/\([0-9]\+\) hour/\1小时/g' | sed 's/\([0-9]\+\) hours/\1小时/g')
        uptime_str=$(echo "$uptime_str" | sed 's/\([0-9]\+\) minute/\1分钟/g' | sed 's/\([0-9]\+\) minutes/\1分钟/g')
        uptime_str=$(echo "$uptime_str" | sed 's/\([0-9]\+\) second/\1秒/g' | sed 's/\([0-9]\+\) seconds/\1秒/g')
        uptime_str=$(echo "$uptime_str" | sed 's/, / /g')
    else
        # Fall back to parsing traditional uptime output
        uptime_full=$(uptime)
        # Extract days
        days=$(echo "$uptime_full" | grep -o '[0-9]\+ day' | awk '{print $1}')
        if [[ -z "$days" ]]; then
            days=$(echo "$uptime_full" | grep -o '[0-9]\+ days' | awk '{print $1}')
        fi
        # Extract time
        time_part=$(echo "$uptime_full" | grep -o '[0-9][0-9]:[0-9][0-9]')
        hours=$(echo "$time_part" | cut -d':' -f1)
        minutes=$(echo "$time_part" | cut -d':' -f2)

        # Build uptime string in Chinese
        uptime_str=""
        [[ -n "$days" ]] && uptime_str="${days}天 "
        [[ -n "$hours" && "$hours" != "00" ]] && uptime_str="${uptime_str}${hours}小时 "
        [[ -n "$minutes" && "$minutes" != "00" ]] && uptime_str="${uptime_str}${minutes}分钟"
        uptime_str=$(echo "$uptime_str" | sed 's/ $//') # 去除尾部空格
    fi

    # 确保没有空格后面跟单位
    uptime_info=$(echo "$uptime_str" | sed 's/ \([周天小时分钟秒]\)/\1/g')
else
    uptime_info="未知"
fi

# Print header with decoration
echo -e "\n${WHITE}${BOLD}✦ 系统信息详情 ✦${NC}"
echo -e "$DIVIDER"

# Column layout with improved formatting
echo -e "► 主机名: ${PURPLE}$hostname${NC}"
echo -e "► 运营商: ${PURPLE}$provider${NC}"
echo -e "$DIVIDER"
echo -e "► 系统版本: ${PURPLE}$os_version${NC}"
echo -e "► Linux版本: ${PURPLE}$kernel_version${NC}"
echo -e "$DIVIDER"
echo -e "► CPU架构: ${PURPLE}$cpu_arch${NC}"
echo -e "► CPU型号: ${PURPLE}$cpu_model${NC}"
echo -e "► CPU核心数: ${PURPLE}$cpu_cores${NC}"
echo -e "$DIVIDER"
echo -e "► CPU占用: ${PURPLE}$cpu_usage${NC}"
echo -e "► 物理内存: ${PURPLE}${used_mem}/${total_mem} MB (${mem_percent})${NC}"
echo -e "► 虚拟内存: ${PURPLE}${used_swap}/${total_swap}MB (${swap_percent})${NC}"
echo -e "► 硬盘占用: ${PURPLE}${disk_used}/${disk_total} (${disk_percent})${NC}"
echo -e "$DIVIDER"
echo -e "► 总接收: ${PURPLE}${rx_display}${NC}"
echo -e "► 总发送: ${PURPLE}${tx_display}${NC}"
echo -e "$DIVIDER"
echo -e "► 网络拥塞算法: ${PURPLE}$tcp_cong${NC}"
echo -e "$DIVIDER"
echo -e "► 公网IPv4地址: ${PURPLE}$ipv4_addr${NC}"
echo -e "► 公网IPv6地址: ${PURPLE}$ipv6_addr${NC}"
echo -e "$DIVIDER"
echo -e "► 地理位置: ${PURPLE}$location${NC}"
echo -e "► 系统时间: ${PURPLE}$sys_time${NC}"
echo -e "$DIVIDER"
echo -e "► 运行时长: ${PURPLE}$uptime_info${NC}"
echo -e "$DIVIDER"
echo -e "${GREEN}✓ 系统检测完成${NC}"

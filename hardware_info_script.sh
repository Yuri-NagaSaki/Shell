#!/bin/bash

# 硬件信息收集脚本 - 兼容Debian/Ubuntu/CentOS
# 此脚本需要root权限运行

# 设置输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}此脚本需要root权限运行.${NC}"
   echo "请使用 sudo 或者切换到root用户后再运行."
   exit 1
fi

# 创建临时目录存储输出
TEMP_DIR=$(mktemp -d)
OUTPUT_FILE="$TEMP_DIR/hardware_info_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"

# 检测Linux发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        DISTRO=$(cat /etc/redhat-release | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]')
        if [[ $DISTRO == "centos" ]]; then
            VERSION=$(cat /etc/redhat-release | sed 's/.*release \([0-9]\).*/\1/')
        fi
    else
        DISTRO="unknown"
        VERSION="unknown"
    fi
    
    echo -e "${GREEN}检测到系统发行版: ${NC}$DISTRO $VERSION"
}

# 安装必要的工具
install_tools() {
    echo -e "\n${BLUE}===正在安装必要的工具===${NC}"
    
    case $DISTRO in
        debian|ubuntu)
            apt-get update -qq
            apt-get install -y -qq dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            ;;
        centos|rhel|fedora)
            if [ "$VERSION" -ge 8 ]; then
                dnf install -y -q dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            else
                yum install -y -q dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            fi
            ;;
        *)
            echo -e "${YELLOW}未知的Linux发行版，尝试安装必要的工具...${NC}"
            if command -v apt-get > /dev/null; then
                apt-get update -qq
                apt-get install -y -qq dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            elif command -v dnf > /dev/null; then
                dnf install -y -q dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            elif command -v yum > /dev/null; then
                yum install -y -q dmidecode lshw hdparm smartmontools util-linux lsscsi pciutils usbutils ipmitool bc > /dev/null 2>&1
            else
                echo -e "${RED}无法安装必要的工具，某些硬件信息可能无法获取.${NC}"
            fi
            ;;
    esac
    
    echo -e "${GREEN}工具安装完成${NC}"
}

# 获取系统基本信息
get_system_info() {
    {
        echo "=============================================="
        echo "              系统基本信息"
        echo "=============================================="
        echo "主机名: $(hostname)"
        echo "操作系统: $(cat /etc/os-release | grep "PRETTY_NAME" | cut -d= -f2 | tr -d \")"
        echo "内核版本: $(uname -r)"
        echo "系统架构: $(uname -m)"
        echo "系统时间: $(date)"
        echo "系统启动时间: $(uptime -s)"
        echo "系统运行时间: $(uptime -p)"
        echo "系统负载: $(cat /proc/loadavg)"
    } >> "$OUTPUT_FILE"
}

# 获取CPU信息
get_cpu_info() {
    {
        echo -e "\n=============================================="
        echo "                 CPU信息"
        echo "=============================================="
        
        # CPU型号和基本信息
        echo "CPU型号:"
        lscpu | grep "型号名称\|Model name" | sed 's/^[^:]*: *//' | head -1
        
        # CPU数量信息
        SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')
        CORES_PER_SOCKET=$(lscpu | grep "每个座的核数\|Core(s) per socket" | awk '{print $NF}')
        THREADS_PER_CORE=$(lscpu | grep "每个核的线程数\|Thread(s) per core" | awk '{print $NF}')
        TOTAL_CORES=$((SOCKETS * CORES_PER_SOCKET))
        TOTAL_THREADS=$((TOTAL_CORES * THREADS_PER_CORE))
        
        echo -e "\nCPU物理数量: $SOCKETS"
        if [ "$SOCKETS" -gt 1 ]; then
            echo "CPU配置: 双路或多路CPU"
        else
            echo "CPU配置: 单路CPU"
        fi
        echo "每个CPU物理核心数: $CORES_PER_SOCKET"
        echo "每个核心线程数: $THREADS_PER_CORE"
        echo "总物理核心数: $TOTAL_CORES"
        echo "总逻辑核心数: $TOTAL_THREADS"
        
        # CPU频率信息
        CPU_FREQ=$(lscpu | grep "CPU MHz\|CPU 最大 MHz\|CPU max MHz" | head -1 | awk '{print $NF}')
        if [ -n "$CPU_FREQ" ]; then
            # 检查bc命令是否存在
            if command -v bc > /dev/null; then
                CPU_FREQ_GHZ=$(echo "scale=2; $CPU_FREQ/1000" | bc)
                echo "CPU频率: ${CPU_FREQ_GHZ}GHz"
            else
                # 不使用bc的替代方案，使用awk进行浮点数计算
                CPU_FREQ_GHZ=$(awk "BEGIN {printf \"%.2f\", $CPU_FREQ/1000}")
                echo "CPU频率: ${CPU_FREQ_GHZ}GHz"
            fi
        fi
        
        # CPU缓存信息
        echo -e "\nCPU缓存信息:"
        lscpu | grep "cache"
        
        # 从dmidecode获取更详细的处理器信息
        echo -e "\nCPU详细信息 (dmidecode):"
        dmidecode -t processor | grep -E "Socket Designation|Version|Serial Number|Core Count|Thread Count|Max Speed|Status"
    } >> "$OUTPUT_FILE"
}

# 获取内存详细信息
get_memory_info() {
    {
        echo -e "\n=============================================="
        echo "                 内存信息"
        echo "=============================================="
        
        # 总体内存信息
        echo "总内存容量: $(free -h | grep "Mem:" | awk '{print $2}')"
        echo "已使用内存: $(free -h | grep "Mem:" | awk '{print $3}')"
        echo "可用内存: $(free -h | grep "Mem:" | awk '{print $7}')"
        
        # 内存条详细信息
        echo -e "\n内存插槽详细信息:"
        MEM_SLOTS=$(dmidecode -t memory | grep -c "Memory Device")
        USED_SLOTS=$(dmidecode -t memory | grep -A16 "Memory Device" | grep -c "Size:.*[0-9]")
        
        echo "总内存插槽数: $MEM_SLOTS"
        echo "已使用内存插槽数: $USED_SLOTS"
        echo "空闲内存插槽数: $((MEM_SLOTS - USED_SLOTS))"
        
        echo -e "\n内存条详细信息:"
        dmidecode -t memory | grep -A16 "Memory Device" | grep -v "^$" | while read -r line; do
            if [[ $line == *"Memory Device"* ]]; then
                echo -e "\n$line"
            elif [[ $line == *"Size:"* ]]; then
                if [[ $line != *"No Module Installed"* && $line != *"Size: 0"* ]]; then
                    echo "$line"
                    HAS_MEM=1
                else
                    HAS_MEM=0
                fi
            elif [[ $line == *"Type:"* || $line == *"Speed:"* || $line == *"Manufacturer:"* || $line == *"Serial Number:"* || $line == *"Part Number:"* || $line == *"Configured Memory Speed:"* || $line == *"Configured Clock Speed:"* || $line == *"Form Factor:"* ]] && [[ $HAS_MEM -eq 1 ]]; then
                echo "$line"
            fi
        done
        
        # 内存汇总信息（格式化输出，便于查看）
        echo -e "\n已安装内存条汇总信息:"
        dmidecode -t memory | grep -A16 "Memory Device" | grep -v "^$" | awk 'BEGIN {
            slot=0
            printf "%-5s %-10s %-10s %-20s %-20s %-20s\n", "插槽", "大小", "类型", "速度", "制造商", "型号"
        }
        /Memory Device/ {slot++}
        /Size:/ {size=$2" "$3}
        /Type:/ {type=$2}
        /Speed:/ {speed=$2" "$3}
        /Manufacturer:/ {manu=$2}
        /Part Number:/ {
            part=$3
            if (size != "No" && size != "0 B" && size != "0") {
                printf "%-5s %-10s %-10s %-20s %-20s %-20s\n", slot, size, type, speed, manu, part
            }
        }'
    } >> "$OUTPUT_FILE"
}

# 获取硬盘信息
get_disk_info() {
    {
        echo -e "\n=============================================="
        echo "                 硬盘信息"
        echo "=============================================="
        
        # 列出所有硬盘设备
        echo "所有磁盘设备:"
        lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,TYPE | grep -v "loop"
        
        echo -e "\n磁盘详细信息:"
        
        # 找出所有物理磁盘设备（排除loop设备）
        DISKS=$(lsblk -d -n -o NAME | grep -v "loop")
        
        for DISK in $DISKS; do
            echo -e "\n# 磁盘 /dev/$DISK 信息:"
            
            # 获取基本信息
            SIZE=$(lsblk -d -n -o SIZE /dev/$DISK)
            MODEL=$(lsblk -d -n -o MODEL /dev/$DISK)
            SERIAL=$(lsblk -d -n -o SERIAL /dev/$DISK 2>/dev/null || echo "无法获取")
            TRANSPORT=$(lsblk -d -n -o TRAN /dev/$DISK 2>/dev/null || echo "无法获取")
            
            echo "设备名称: /dev/$DISK"
            echo "磁盘大小: $SIZE"
            echo "磁盘型号: $MODEL"
            echo "序列号: $SERIAL"
            echo "传输类型: $TRANSPORT"
            
            # 检查接口类型和尺寸
            if [[ $TRANSPORT == "sata" ]]; then
                # 尝试通过smartctl判断硬盘尺寸
                FORM_FACTOR=$(smartctl -i /dev/$DISK | grep "Form Factor" | cut -d: -f2 | tr -d ' ')
                
                if [[ -z "$FORM_FACTOR" ]]; then
                    # 尝试通过SMART数据中的转速判断
                    RPM=$(smartctl -i /dev/$DISK | grep "Rotation Rate" | cut -d: -f2 | tr -d ' ')
                    
                    if [[ "$RPM" == *"Solid"* || "$RPM" == *"SSD"* ]]; then
                        echo "硬盘类型: SSD"
                        echo "硬盘尺寸: 未知 (SSD)"
                    elif [[ -n "$RPM" ]]; then
                        echo "硬盘类型: HDD ($RPM)"
                        
                        # 根据型号判断尺寸（简单启发式）
                        if [[ "$MODEL" == *"2.5"* ]]; then
                            echo "硬盘尺寸: 2.5英寸"
                        elif [[ "$SIZE" > "4T" && "$RPM" != *"10K"* && "$RPM" != *"15K"* ]]; then
                            echo "硬盘尺寸: 可能是3.5英寸 (大容量)"
                        elif [[ "$RPM" == *"7200"* && "$SIZE" > "1T" ]]; then
                            echo "硬盘尺寸: 可能是3.5英寸"
                        elif [[ "$RPM" == *"5400"* ]]; then
                            echo "硬盘尺寸: 可能是2.5英寸"
                        else
                            echo "硬盘尺寸: 无法确定"
                        fi
                    else
                        echo "硬盘尺寸: 无法确定"
                    fi
                else
                    if [[ "$FORM_FACTOR" == *"2.5"* ]]; then
                        echo "硬盘尺寸: 2.5英寸"
                    elif [[ "$FORM_FACTOR" == *"3.5"* ]]; then
                        echo "硬盘尺寸: 3.5英寸"
                    else
                        echo "硬盘尺寸: $FORM_FACTOR"
                    fi
                fi
            elif [[ $TRANSPORT == "nvme" ]]; then
                echo "硬盘类型: NVMe SSD"
                
                # 获取NVMe详细信息
                if command -v nvme > /dev/null; then
                    echo -e "\nNVMe详细信息:"
                    nvme list-ns /dev/$DISK -H 2>/dev/null || echo "无法获取NVMe命名空间信息"
                    nvme smart-log /dev/$DISK 2>/dev/null || echo "无法获取NVMe SMART信息"
                    
                    # 判断是否为U.2或M.2
                    NVME_INFO=$(nvme id-ctrl /dev/$DISK 2>/dev/null || echo "")
                    if [[ "$NVME_INFO" == *"Form Factor: 2.5\""* ]]; then
                        echo "接口类型: U.2 (2.5英寸)"
                    elif [[ "$NVME_INFO" == *"Form Factor: HHHL"* ]]; then
                        echo "接口类型: 加装卡 (HHHL)"
                    elif [[ "$NVME_INFO" == *"Form Factor: M.2"* ]]; then
                        echo "接口类型: M.2"
                    else
                        echo "接口类型: 未知NVMe格式"
                    fi
                else
                    echo "接口类型: NVMe (需安装nvme-cli工具获取更多信息)"
                fi
            else
                echo "硬盘尺寸: 无法确定"
            fi
            
            # 尝试获取SMART信息
            if command -v smartctl > /dev/null; then
                echo -e "\n磁盘健康状态:"
                SMART_STATUS=$(smartctl -H /dev/$DISK 2>/dev/null)
                if [[ $? -eq 0 ]]; then
                    echo "$SMART_STATUS" | grep -E "SMART overall-health|SMART Health Status"
                else
                    echo "无法获取SMART状态信息"
                fi
            fi
            
            # 尝试获取硬盘温度
            if command -v smartctl > /dev/null; then
                TEMP=$(smartctl -A /dev/$DISK 2>/dev/null | grep -i "temperature" | head -1)
                if [[ -n "$TEMP" ]]; then
                    echo "温度: $TEMP"
                fi
            fi
        done
    } >> "$OUTPUT_FILE"
}

# 获取RAID控制器信息
get_raid_info() {
    {
        echo -e "\n=============================================="
        echo "              RAID控制器信息"
        echo "=============================================="
        
        # 检查是否存在RAID控制器
        if lspci | grep -i raid > /dev/null; then
            echo "系统检测到RAID控制器:"
            lspci | grep -i raid
            
            # 检查常见RAID工具
            if command -v megacli > /dev/null; then
                echo -e "\nLSI MegaRAID控制器信息:"
                megacli -AdpAllInfo -aALL | grep -E "Product Name|Serial No|Firmware|RAID Level Supported"
                echo -e "\nLSI MegaRAID虚拟磁盘信息:"
                megacli -LDInfo -Lall -aAll | grep -E "RAID Level|Size|State"
            elif command -v storcli > /dev/null; then
                echo -e "\nLSI StorCLI控制器信息:"
                storcli /call show | grep -E "Product Name|Serial Number|FW Package Build"
                echo -e "\nLSI StorCLI虚拟磁盘信息:"
                storcli /call/vall show | grep -E "RAID|Size|State"
            elif command -v arcconf > /dev/null; then
                echo -e "\nAdaptec RAID控制器信息:"
                arcconf getconfig 1 | grep -E "Controller Model|Controller Serial Number|Firmware"
                echo -e "\nAdaptec RAID逻辑设备信息:"
                arcconf getconfig 1 ld | grep -E "Logical device number|RAID level|Size|Status"
            elif command -v hpssacli > /dev/null || command -v ssacli > /dev/null; then
                HPCMD="hpssacli"
                if ! command -v $HPCMD > /dev/null; then
                    HPCMD="ssacli"
                fi
                echo -e "\nHP Smart Array控制器信息:"
                $HPCMD ctrl all show detail | grep -E "Model|Serial Number|Firmware Version"
                echo -e "\nHP Smart Array逻辑驱动器信息:"
                $HPCMD ctrl all show config detail | grep -E "logicaldrive|RAID|Size|Status"
            else
                echo "检测到RAID控制器，但未找到对应的管理工具，无法获取详细信息"
            fi
        else
            echo "未检测到专用RAID控制器"
            
            # 检查软RAID
            if [ -e /proc/mdstat ]; then
                echo -e "\n软RAID信息 (/proc/mdstat):"
                cat /proc/mdstat
            fi
        fi
    } >> "$OUTPUT_FILE"
}

# 获取网卡信息
get_network_info() {
    {
        echo -e "\n=============================================="
        echo "                 网卡信息"
        echo "=============================================="
        
        # 获取所有网络接口
        echo "网络接口列表:"
        ip -br link show | grep -v "lo"
        
        # 网卡详细信息
        echo -e "\n网卡详细信息:"
        
        # 列出所有物理网卡（排除虚拟接口和loopback）
        NICS=$(ip -o link show | grep -v "lo\|virbr\|docker\|veth\|bond\|bridge\|tun\|tap" | awk -F': ' '{print $2}')
        
        for NIC in $NICS; do
            echo -e "\n# 物理网卡 $NIC 信息:"
            
            # 获取MAC地址
            MAC=$(ip link show "$NIC" | grep "link/ether" | awk '{print $2}')
            echo "MAC地址: $MAC"
            
            # 获取IP信息
            IP_INFO=$(ip addr show "$NIC" | grep "inet " | awk '{print $2}')
            if [ -n "$IP_INFO" ]; then
                echo "IP地址: $IP_INFO"
            else
                echo "IP地址: 未配置"
            fi
            
            # 获取网卡速率和状态
            if [ -d "/sys/class/net/$NIC" ]; then
                OPERSTATE=$(cat /sys/class/net/"$NIC"/operstate)
                echo "运行状态: $OPERSTATE"
                
                if [ -f "/sys/class/net/$NIC/speed" ]; then
                    SPEED=$(cat /sys/class/net/"$NIC"/speed 2>/dev/null || echo "未知")
                    if [ "$SPEED" != "未知" ]; then
                        echo "链接速率: ${SPEED}Mb/s"
                    else
                        echo "链接速率: 未知 (接口可能未连接)"
                    fi
                fi
            fi
            
            # 从lshw获取网卡型号和详细信息
            echo -e "\n网卡硬件信息:"
            lshw -class network -short | grep "$NIC"
            
            # 获取更详细的网卡信息
            NIC_PCI_INFO=$(lshw -class network -businfo 2>/dev/null | grep "$NIC" | awk '{print $1}' | cut -d@ -f2)
            if [ -n "$NIC_PCI_INFO" ]; then
                echo -e "\n网卡PCI信息:"
                lspci -v | grep -A10 "$NIC_PCI_INFO" | grep -E "Subsystem|Kernel driver in use"
            fi
            
            # 尝试获取网卡固件版本
            if command -v ethtool > /dev/null; then
                DRIVER_INFO=$(ethtool -i "$NIC" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo -e "\n网卡驱动信息:"
                    echo "$DRIVER_INFO" | grep -E "driver|version|firmware-version"
                fi
            fi
        done
    } >> "$OUTPUT_FILE"
}

# 获取显卡信息
get_gpu_info() {
    {
        echo -e "\n=============================================="
        echo "                 显卡信息"
        echo "=============================================="
        
        # 检查是否有显卡
        if lspci | grep -E "VGA|3D|Display" > /dev/null; then
            echo "检测到显卡:"
            lspci | grep -E "VGA|3D|Display"
            
            # 尝试获取NVIDIA显卡信息
            if command -v nvidia-smi > /dev/null; then
                echo -e "\nNVIDIA显卡详细信息:"
                nvidia-smi -L
                echo -e "\nNVIDIA显卡状态:"
                nvidia-smi
            fi
            
            # 尝试获取AMD显卡信息
            if [ -d "/sys/class/drm" ]; then
                echo -e "\nAMD/Intel显卡信息:"
                for card in /sys/class/drm/card[0-9]*; do
                    if [ -f "$card/device/vendor" ]; then
                        VENDOR=$(cat "$card/device/vendor" 2>/dev/null)
                        DEVICE=$(cat "$card/device/device" 2>/dev/null)
                        
                        # 确保vendor ID格式正确
                        if [[ "$VENDOR" =~ ^0x[0-9a-fA-F]+$ ]]; then
                            NAME=$(lspci -d "$VENDOR:$DEVICE" 2>/dev/null | sed 's/.*: //g' | head -1)
                            if [ -n "$NAME" ]; then
                                echo "显卡: $NAME"
                                
                                if [ -f "$card/device/uevent" ]; then
                                    grep -E "DRIVER|PCI_ID" "$card/device/uevent"
                                fi
                            fi
                        else
                            echo "显卡: 无法获取详细信息 (vendor ID格式不正确)"
                        fi
                    fi
                done
            fi
        else
            echo "未检测到独立显卡"
        fi
    } >> "$OUTPUT_FILE"
}

# 获取电源信息
get_power_supply_info() {
    {
        echo -e "\n=============================================="
        echo "                 电源信息"
        echo "=============================================="
        
        # 检查是否可以通过IPMI获取电源信息
        if command -v ipmitool > /dev/null; then
            echo "通过IPMI获取电源信息:"
            IPMI_POWER_INFO=$(ipmitool sdr type "Power Supply" 2>/dev/null)
            if [ -n "$IPMI_POWER_INFO" ]; then
                echo "$IPMI_POWER_INFO"
                
                # 尝试获取更详细的电源信息
                echo -e "\n电源FRU信息:"
                ipmitool fru print 2>/dev/null | grep -E "Product Name|Product Manufacturer|Product Serial|Product Version" || echo "无法获取FRU信息"
            else
                echo "无法通过IPMI获取电源信息"
            fi
        fi
        
        # 检查是否有电源相关的dmidecode信息
        echo -e "\n电源dmidecode信息:"
        DMI_POWER_INFO=$(dmidecode -t 39 2>/dev/null)
        if [ -n "$DMI_POWER_INFO" ]; then
            echo "$DMI_POWER_INFO"
        else
            echo "无法通过dmidecode获取电源信息"
        fi
        
        # 检查ACPI电源信息
        if [ -d "/sys/class/power_supply" ]; then
            echo -e "\nACPI电源信息:"
            
            for psu in /sys/class/power_supply/*; do
                if [ -d "$psu" ]; then
                    PSU_NAME=$(basename "$psu")
                    echo "电源: $PSU_NAME"
                    
                    if [ -f "$psu/manufacturer" ]; then
                        echo "制造商: $(cat "$psu/manufacturer" 2>/dev/null)"
                    fi
                    
                    if [ -f "$psu/model_name" ]; then
                        echo "型号: $(cat "$psu/model_name" 2>/dev/null)"
                    fi
                    
                    if [ -f "$psu/serial_number" ]; then
                        echo "序列号: $(cat "$psu/serial_number" 2>/dev/null)"
                    fi
                    
                    if [ -f "$psu/type" ]; then
                        echo "类型: $(cat "$psu/type" 2>/dev/null)"
                    fi
                    
                    if [ -f "$psu/online" ]; then
                        echo "在线状态: $(cat "$psu/online" 2>/dev/null)"
                    fi
                    
                    if [ -f "$psu/status" ]; then
                        echo "状态: $(cat "$psu/status" 2>/dev/null)"
                    fi
                    
                    echo ""
                fi
            done
        fi
    } >> "$OUTPUT_FILE"
}

# 获取主板信息
get_motherboard_info() {
    {
        echo -e "\n=============================================="
        echo "                 主板信息"
        echo "=============================================="
        
        echo "主板信息 (dmidecode):"
        dmidecode -t baseboard | grep -E "Manufacturer|Product Name|Version|Serial Number|Asset Tag"
        
        echo -e "\nBIOS信息:"
        dmidecode -t bios | grep -E "Vendor|Version|Release Date|BIOS Revision"
        
        echo -e "\n系统信息:"
        dmidecode -t system | grep -E "Manufacturer|Product Name|Version|Serial Number|UUID|SKU Number|Family"
    } >> "$OUTPUT_FILE"
}

# 获取其他硬件信息
get_other_hardware_info() {
    {
        echo -e "\n=============================================="
        echo "              其他硬件信息"
        echo "=============================================="
        
        # 获取PCI设备信息
        echo "PCI设备列表:"
        lspci | grep -v "USB\|Audio\|VGA\|Ethernet\|Network\|RAID"
        
        # 获取USB设备信息
        echo -e "\nUSB设备列表:"
        lsusb
        
        # 获取传感器信息
        if command -v sensors > /dev/null; then
            echo -e "\n系统温度传感器信息:"
            sensors
        fi
    } >> "$OUTPUT_FILE"
}

# 获取风扇信息
get_fan_info() {
    {
        echo -e "\n=============================================="
        echo "                 风扇信息"
        echo "=============================================="
        
        # 尝试通过IPMI获取风扇信息
        if command -v ipmitool > /dev/null; then
            echo "风扇状态(通过IPMI):"
            ipmitool sdr type "Fan" 2>/dev/null || echo "无法通过IPMI获取风扇信息"
        fi
        
        # 尝试通过sensors获取风扇信息
        if command -v sensors > /dev/null; then
            echo -e "\n风扇速度(通过sensors):"
            sensors | grep -i "fan" || echo "无法通过sensors获取风扇信息"
        fi
        
        # 检查hwmon中的风扇信息
        echo -e "\n系统风扇信息(通过hwmon):"
        found_fans=0
        
        for path in /sys/class/hwmon/hwmon*/; do
            if [ -d "$path" ]; then
                # 检查该hwmon设备是否有风扇相关信息
                if ls "$path"/fan* 2>/dev/null >/dev/null; then
                    found_fans=1
                    
                    # 尝试获取设备名称
                    if [ -f "$path/name" ]; then
                        echo "设备: $(cat "$path/name")"
                    else
                        echo "设备: $(basename "$path")"
                    fi
                    
                    # 获取所有风扇输入
                    for fan_input in "$path"/fan*_input; do
                        if [ -f "$fan_input" ]; then
                            fan_num=$(echo "$fan_input" | sed 's/.*fan\([0-9]\+\)_input/\1/')
                            fan_speed=$(cat "$fan_input" 2>/dev/null || echo "N/A")
                            
                            echo "风扇${fan_num}速度: ${fan_speed} RPM"
                            
                            # 检查是否有风扇标签
                            if [ -f "$path/fan${fan_num}_label" ]; then
                                echo "风扇${fan_num}标签: $(cat "$path/fan${fan_num}_label")"
                            fi
                        fi
                    done
                    echo ""
                fi
            fi
        done
        
        if [ $found_fans -eq 0 ]; then
            echo "未在hwmon中找到风扇信息"
        fi
    } >> "$OUTPUT_FILE"
}

# 汇总生成最终报告
generate_summary() {
    {
        echo -e "\n=============================================="
        echo "                硬件信息摘要"
        echo "=============================================="
        
        # CPU摘要
        SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $2}')
        CPU_MODEL=$(lscpu | grep "型号名称\|Model name" | sed 's/^[^:]*: *//' | head -1)
        
        echo "CPU: $CPU_MODEL ($SOCKETS 路)"
        
        # 内存摘要
        TOTAL_MEM=$(free -h | grep "Mem:" | awk '{print $2}')
        echo "内存: $TOTAL_MEM 总容量"
        echo -e "\n内存条详细信息:"
        echo "-----------------------------------------------------------------------------"
        echo "| 大小 | 类型 | 速度 | 频率 | 制造商 | 型号 |"
        echo "-----------------------------------------------------------------------------"
        dmidecode -t memory | grep -A20 "Memory Device" | awk '
        /Memory Device/{ if (size!="") printf "| %s | %s | %s | %s | %s | %s |\n", size, type, speed, clock, manu, part; size=""; type=""; speed=""; clock=""; manu=""; part="" }
        /Size: [0-9]/{ size=$2" "$3 }
        /Type: /{ type=$2 }
        /Speed: /{ speed=$2" "$3 }
        /Configured Memory Speed: /{ clock=$4" "$5 }
        /Configured Clock Speed: /{ if (!clock) clock=$4" "$5 }
        /Manufacturer: /{ manu=$2 }
        /Part Number: /{ part=$3 }
        END{ if (size!="") printf "| %s | %s | %s | %s | %s | %s |\n", size, type, speed, clock, manu, part }' | grep "GB"
        echo "-----------------------------------------------------------------------------"
        
        # 硬盘摘要
        echo -e "\n硬盘:"
        lsblk -d -o NAME,SIZE,MODEL | grep -v "loop" | while read line; do
            echo "  $line"
        done
        
        # 网络摘要 - 只显示物理网卡
        echo -e "\n物理网卡:"
        ip -o link show | grep -Ev "lo:|virbr|docker|veth|bond|bridge|tun|tap|br-|cni|flannel|calico|overlay" | awk -F': ' '{print "  "$2}' | while read nic; do
            SPEED=""
            if [ -f "/sys/class/net/$nic/speed" ]; then
                SPEED=$(cat "/sys/class/net/$nic/speed" 2>/dev/null)
                if [ -n "$SPEED" ]; then
                    SPEED=" (${SPEED}Mb/s)"
                fi
            fi
            
            # 检查是否为物理网卡
            if [ -e "/sys/class/net/$nic/device" ]; then
                NIC_INFO=$(lshw -class network -short 2>/dev/null | grep "$nic" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')
                if [ -z "$NIC_INFO" ]; then
                    NIC_INFO=$(ethtool -i "$nic" 2>/dev/null | grep "driver:" | cut -d: -f2 | sed 's/^ *//')
                fi
                
                echo "  $nic$SPEED - $NIC_INFO"
            fi
        done
        
        # 主板摘要
        MB_VENDOR=$(dmidecode -t baseboard | grep "Manufacturer" | cut -d: -f2 | sed 's/^[ \t]*//')
        MB_MODEL=$(dmidecode -t baseboard | grep "Product Name" | cut -d: -f2 | sed 's/^[ \t]*//')
        MB_VERSION=$(dmidecode -t baseboard | grep "Version" | cut -d: -f2 | sed 's/^[ \t]*//')
        
        echo -e "\n主板: $MB_VENDOR $MB_MODEL $MB_VERSION"
        
        # 系统摘要
        SYS_VENDOR=$(dmidecode -t system | grep "Manufacturer" | cut -d: -f2 | sed 's/^[ \t]*//')
        SYS_PRODUCT=$(dmidecode -t system | grep "Product Name" | cut -d: -f2 | sed 's/^[ \t]*//')
        
        echo "系统型号: $SYS_VENDOR $SYS_PRODUCT"
        
        # BIOS信息
        BIOS_VENDOR=$(dmidecode -t bios | grep "Vendor" | cut -d: -f2 | sed 's/^[ \t]*//')
        BIOS_VERSION=$(dmidecode -t bios | grep "Version" | cut -d: -f2 | sed 's/^[ \t]*//')
        BIOS_DATE=$(dmidecode -t bios | grep "Release Date" | cut -d: -f2 | sed 's/^[ \t]*//')
        
        echo "BIOS: $BIOS_VENDOR $BIOS_VERSION ($BIOS_DATE)"
    } >> "$OUTPUT_FILE"
}

# 主函数
main() {
    echo -e "${BLUE}===开始收集硬件信息===${NC}"
    
    # 检测Linux发行版
    detect_distro
    
    # 安装必要的工具
    install_tools
    
    echo -e "\n${BLUE}===收集系统基本信息===${NC}"
    get_system_info
    
    echo -e "\n${BLUE}===收集CPU信息===${NC}"
    get_cpu_info
    
    echo -e "\n${BLUE}===收集内存信息===${NC}"
    get_memory_info
    
    echo -e "\n${BLUE}===收集硬盘信息===${NC}"
    get_disk_info
    
    echo -e "\n${BLUE}===收集RAID控制器信息===${NC}"
    get_raid_info
    
    echo -e "\n${BLUE}===收集网卡信息===${NC}"
    get_network_info
    
    echo -e "\n${BLUE}===收集显卡信息===${NC}"
    get_gpu_info
    
    echo -e "\n${BLUE}===收集主板信息===${NC}"
    get_motherboard_info
    
    echo -e "\n${BLUE}===收集电源信息===${NC}"
    get_power_supply_info
    
    echo -e "\n${BLUE}===收集其他硬件信息===${NC}"
    get_other_hardware_info
    
    echo -e "\n${BLUE}===收集风扇信息===${NC}"
    get_fan_info
    
    echo -e "\n${BLUE}===生成硬件信息摘要===${NC}"
    generate_summary
    
    # 输出摘要到终端
    SUMMARY_START=$(grep -n "硬件信息摘要" "$OUTPUT_FILE" | cut -d: -f1)
    if [ -n "$SUMMARY_START" ]; then
        echo -e "\n${GREEN}硬件信息摘要：${NC}"
        tail -n +$SUMMARY_START "$OUTPUT_FILE" | while IFS= read -r line; do
            echo -e "${YELLOW}$line${NC}"
        done
    fi
    
    # 复制到当前目录
    FINAL_REPORT="hardware_info_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"
    cp "$OUTPUT_FILE" ./"$FINAL_REPORT"
    
    echo -e "\n${GREEN}硬件信息收集完成!${NC}"
    echo -e "详细报告已保存到: ${YELLOW}$(pwd)/${FINAL_REPORT}${NC}"
}

# 执行主函数
main

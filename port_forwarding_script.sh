#!/bin/bash

# 端口转发管理脚本
# 功能: 管理iptables端口转发规则，支持添加和删除规则

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要root权限，请使用sudo运行${NC}"
    exit 1
fi

# 检查iptables-persistent是否安装
if ! dpkg -l | grep -q iptables-persistent; then
    echo -e "${YELLOW}警告: 未检测到iptables-persistent，规则可能无法持久保存${NC}"
    echo -e "建议安装: ${GREEN}sudo apt-get install iptables-persistent${NC}"
fi

# 规则文件路径
RULES_FILE="/etc/iptables/rules.v4"

# 检查规则文件是否存在
if [ ! -f "$RULES_FILE" ]; then
    echo -e "${YELLOW}警告: 规则文件 $RULES_FILE 不存在${NC}"
    echo -e "将在保存规则时创建"
fi

# 获取当前所有转发规则
get_current_rules() {
    echo -e "${BLUE}当前端口转发规则:${NC}"
    # 获取PREROUTING链中的DNAT规则
    rules=$(iptables -t nat -L PREROUTING -n --line-numbers | grep DNAT)
    
    if [ -z "$rules" ]; then
        echo -e "${YELLOW}当前没有转发规则${NC}"
        return
    fi
    
    printf "%-5s %-15s %-20s %-20s %-10s\n" "编号" "协议" "外部端口" "目标地址" "接口"
    echo "--------------------------------------------------------------"
    
    # 使用iptables -t nat -L PREROUTING -n 提取规则并格式化输出
    iptables -t nat -L PREROUTING -n --line-numbers | grep DNAT | while read -r line; do
        num=$(echo $line | awk '{print $1}')
        protocol=$(echo $line | grep -o 'udp\|tcp\|all')
        dport=$(echo $line | grep -oP 'dpt:\K[0-9]+')
        destination=$(echo $line | grep -oP 'to:\K[0-9.]+:[0-9]+')
        interface=$(echo $line | grep -oP 'i \K[a-zA-Z0-9]+')
        
        if [ -z "$interface" ]; then
            interface="任意"
        fi
        
        printf "%-5s %-15s %-20s %-20s %-10s\n" "$num" "$protocol" "$dport" "$destination" "$interface"
    done
    
    echo
    echo -e "${YELLOW}输入'r'返回主菜单${NC}"
    read -p "请选择操作: " subchoice
    if [ "$subchoice" = "r" ] || [ "$subchoice" = "R" ]; then
        return
    fi
}

# 添加新的转发规则
add_new_rule() {
    echo -e "${GREEN}添加新的端口转发规则${NC}"
    
    # 获取网络接口列表
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo")
    
    echo -e "${BLUE}可用网络接口:${NC}"
    echo "$interfaces"
    
    # 输入网络接口
    read -p "请输入外部网络接口 (默认为vmbr0，输入'r'返回主菜单): " interface
    if [ "$interface" = "r" ] || [ "$interface" = "R" ]; then
        return
    fi
    interface=${interface:-vmbr0}
    
    # 检查接口是否存在
    if ! ip link show "$interface" &> /dev/null; then
        echo -e "${RED}错误: 接口 $interface 不存在${NC}"
        sleep 2
        return
    fi
    
    # 输入协议类型
    echo "请选择协议类型: "
    echo "1. tcp"
    echo "2. udp"
    echo "3. both (tcp和udp)"
    echo "r. 返回主菜单"
    read -p "请选择 [1-3 或 r]: " proto_choice
    
    if [ "$proto_choice" = "r" ] || [ "$proto_choice" = "R" ]; then
        return
    fi
    
    case $proto_choice in
        1)
            protocol="tcp"
            ;;
        2)
            protocol="udp"
            ;;
        3)
            protocol="tcp udp"
            ;;
        *)
            echo -e "${RED}无效选择，返回主菜单${NC}"
            sleep 2
            return
            ;;
    esac
    
    # 输入外部端口
    while true; do
        read -p "请输入外部访问端口 (1-65535，输入'r'返回主菜单): " external_port
        if [ "$external_port" = "r" ] || [ "$external_port" = "R" ]; then
            return
        fi
        
        if [[ "$external_port" =~ ^[0-9]+$ ]] && [ "$external_port" -ge 1 ] && [ "$external_port" -le 65535 ]; then
            break
        else
            echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        fi
    done
    
    # 输入虚拟机IP
    while true; do
        read -p "请输入目标虚拟机IP地址 (输入'r'返回主菜单): " vm_ip
        if [ "$vm_ip" = "r" ] || [ "$vm_ip" = "R" ]; then
            return
        fi
        
        if [[ "$vm_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            break
        else
            echo -e "${RED}无效的IP地址格式，请重试${NC}"
        fi
    done
    
    # 输入内部端口
    while true; do
        read -p "请输入虚拟机内部端口 (1-65535，输入'r'返回主菜单): " internal_port
        if [ "$internal_port" = "r" ] || [ "$internal_port" = "R" ]; then
            return
        fi
        
        if [[ "$internal_port" =~ ^[0-9]+$ ]] && [ "$internal_port" -ge 1 ] && [ "$internal_port" -le 65535 ]; then
            break
        else
            echo -e "${RED}无效的端口号，请输入1-65535之间的数字${NC}"
        fi
    done
    
    # 确认添加规则
    echo -e "${YELLOW}将添加以下转发规则:${NC}"
    echo "外部接口: $interface"
    echo "协议类型: $protocol"
    echo "外部端口: $external_port"
    echo "转发至: $vm_ip:$internal_port"
    read -p "是否确认添加? (y/n/r-返回主菜单): " confirm
    
    if [ "$confirm" = "r" ] || [ "$confirm" = "R" ]; then
        return
    fi
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}操作已取消${NC}"
        sleep 2
        return
    fi
    
    # 添加规则
    for proto in $protocol; do
        if iptables -t nat -A PREROUTING -i "$interface" -p "$proto" --dport "$external_port" -j DNAT --to-destination "$vm_ip:$internal_port"; then
            echo -e "${GREEN}成功添加 $proto 协议的转发规则${NC}"
            
            # 确保允许转发流量
            iptables -A FORWARD -p "$proto" -d "$vm_ip" --dport "$internal_port" -j ACCEPT
        else
            echo -e "${RED}添加 $proto 协议的转发规则失败${NC}"
        fi
    done
    
    # 保存规则
    save_rules
    
    echo
    echo -e "${YELLOW}操作完成，按任意键返回主菜单${NC}"
    read -n 1
}

# 删除转发规则
delete_rule() {
    echo -e "${YELLOW}删除端口转发规则${NC}"
    get_current_rules
    
    # 检查是否有规则可以删除
    if ! iptables -t nat -L PREROUTING -n | grep -q DNAT; then
        echo -e "${YELLOW}没有可删除的规则${NC}"
        echo -e "${YELLOW}按任意键返回主菜单${NC}"
        read -n 1
        return
    fi
    
    read -p "请输入要删除的规则编号 (输入'r'返回主菜单): " rule_number
    
    if [ "$rule_number" = "r" ] || [ "$rule_number" = "R" ]; then
        return
    fi
    
    # 验证输入是否为数字
    if ! [[ "$rule_number" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}无效的编号，请输入数字${NC}"
        sleep 2
        return
    fi
    
    # 获取规则总数
    rule_count=$(iptables -t nat -L PREROUTING -n --line-numbers | grep DNAT | wc -l)
    
    if [ "$rule_number" -lt 1 ] || [ "$rule_number" -gt "$rule_count" ]; then
        echo -e "${RED}规则编号无效，有效范围: 1-$rule_count${NC}"
        sleep 2
        return
    fi
    
    # 确认删除
    rule_info=$(iptables -t nat -L PREROUTING -n --line-numbers | grep "^$rule_number " | grep DNAT)
    echo -e "${YELLOW}将删除以下规则:${NC}"
    echo "$rule_info"
    read -p "是否确认删除? (y/n/r-返回主菜单): " confirm
    
    if [ "$confirm" = "r" ] || [ "$confirm" = "R" ]; then
        return
    fi
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}操作已取消${NC}"
        sleep 2
        return
    fi
    
    # 删除规则
    if iptables -t nat -D PREROUTING "$rule_number"; then
        echo -e "${GREEN}成功删除规则${NC}"
        
        # 尝试删除对应的FORWARD规则
        # 注意：这里的操作可能不完全准确，因为FORWARD规则没有与PREROUTING规则的直接关联
        # 获取目标地址和端口信息
        destination=$(echo "$rule_info" | grep -oP 'to:\K[0-9.]+:[0-9]+')
        dest_ip=$(echo "$destination" | cut -d':' -f1)
        dest_port=$(echo "$destination" | cut -d':' -f2)
        protocol=$(echo "$rule_info" | grep -o 'udp\|tcp\|all')
        
        # 查找并删除可能的FORWARD规则
        forward_rule=$(iptables -L FORWARD -n --line-numbers | grep "$dest_ip" | grep "dpt:$dest_port" | grep "$protocol" | head -n 1)
        if [ -n "$forward_rule" ]; then
            forward_num=$(echo "$forward_rule" | awk '{print $1}')
            iptables -D FORWARD "$forward_num"
            echo -e "${GREEN}成功删除关联的FORWARD规则${NC}"
        fi
    else
        echo -e "${RED}删除规则失败${NC}"
    fi
    
    # 保存规则
    save_rules
    
    echo
    echo -e "${YELLOW}操作完成，按任意键返回主菜单${NC}"
    read -n 1
}

# 保存规则到持久文件
save_rules() {
    echo -e "${BLUE}正在保存规则到 $RULES_FILE...${NC}"
    
    # 创建目录(如果不存在)
    mkdir -p $(dirname "$RULES_FILE")
    
    # 保存IPv4规则
    if iptables-save > "$RULES_FILE"; then
        echo -e "${GREEN}规则已成功保存${NC}"
        
        # 确保下次启动时应用规则
        systemctl enable netfilter-persistent.service &> /dev/null
        systemctl restart netfilter-persistent.service &> /dev/null
        
        echo -e "${GREEN}服务已重启，规则将在系统重启后自动应用${NC}"
    else
        echo -e "${RED}保存规则失败，请手动运行: sudo iptables-save > $RULES_FILE${NC}"
    fi
    
    if [ "$1" != "silent" ]; then
        echo
        echo -e "${YELLOW}按任意键返回主菜单${NC}"
        read -n 1
    fi
}

# 显示规则详情
show_rule_details() {
    echo -e "${BLUE}查看规则详情${NC}"
    get_current_rules
    
    # 检查是否有规则
    if ! iptables -t nat -L PREROUTING -n | grep -q DNAT; then
        echo -e "${YELLOW}没有可查看的规则${NC}"
        echo -e "${YELLOW}按任意键返回主菜单${NC}"
        read -n 1
        return
    fi
    
    read -p "请输入要查看详情的规则编号 (输入'r'返回主菜单): " rule_number
    
    if [ "$rule_number" = "r" ] || [ "$rule_number" = "R" ]; then
        return
    fi
    
    # 验证输入是否为数字
    if ! [[ "$rule_number" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}无效的编号，请输入数字${NC}"
        sleep 2
        return
    fi
    
    # 获取规则总数
    rule_count=$(iptables -t nat -L PREROUTING -n --line-numbers | grep DNAT | wc -l)
    
    if [ "$rule_number" -lt 1 ] || [ "$rule_number" -gt "$rule_count" ]; then
        echo -e "${RED}规则编号无效，有效范围: 1-$rule_count${NC}"
        sleep 2
        return
    fi
    
    # 显示规则详情
    rule_info=$(iptables -t nat -L PREROUTING -n --line-numbers | grep "^$rule_number " | grep DNAT)
    echo -e "${GREEN}规则详情:${NC}"
    echo "$rule_info"
    
    # 提取规则信息以便显示更友好的输出
    protocol=$(echo "$rule_info" | grep -o 'udp\|tcp\|all')
    dport=$(echo "$rule_info" | grep -oP 'dpt:\K[0-9]+')
    destination=$(echo "$rule_info" | grep -oP 'to:\K[0-9.]+:[0-9]+')
    dest_ip=$(echo "$destination" | cut -d':' -f1)
    dest_port=$(echo "$destination" | cut -d':' -f2)
    interface=$(echo "$rule_info" | grep -oP 'i \K[a-zA-Z0-9]+')
    
    echo -e "\n${YELLOW}格式化信息:${NC}"
    echo "规则编号: $rule_number"
    echo "网络接口: ${interface:-任意}"
    echo "协议类型: $protocol"
    echo "外部端口: $dport"
    echo "转发至IP: $dest_ip"
    echo "内部端口: $dest_port"
    
    # 显示等效的iptables命令
    if [ -n "$interface" ]; then
        echo -e "\n${BLUE}等效的iptables命令:${NC}"
        echo "iptables -t nat -A PREROUTING -i $interface -p $protocol --dport $dport -j DNAT --to-destination $destination"
    else
        echo -e "\n${BLUE}等效的iptables命令:${NC}"
        echo "iptables -t nat -A PREROUTING -p $protocol --dport $dport -j DNAT --to-destination $destination"
    fi
    
    # 查找并显示对应的FORWARD规则
    echo -e "\n${BLUE}相关FORWARD规则:${NC}"
    forward_rules=$(iptables -L FORWARD -n | grep "$dest_ip" | grep "dpt:$dest_port")
    if [ -n "$forward_rules" ]; then
        echo "$forward_rules"
    else
        echo "未找到对应的FORWARD规则"
    fi
    
    # 检查端口连通性
    echo -e "\n${BLUE}端口连通性检查:${NC}"
    echo -n "正在检查 $dest_ip:$dest_port 的连通性... "
    if timeout 2 bash -c "echo > /dev/tcp/$dest_ip/$dest_port" 2>/dev/null; then
        echo -e "${GREEN}端口可访问${NC}"
    else
        echo -e "${RED}端口不可访问${NC}"
        echo "可能原因: 虚拟机未运行、防火墙阻止、服务未启动或IP/端口错误"
    fi
    
    echo
    echo -e "${YELLOW}按任意键返回主菜单${NC}"
    read -n 1
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}=========================================${NC}"
        echo -e "${GREEN}       iptables端口转发管理脚本         ${NC}"
        echo -e "${GREEN}=========================================${NC}"
        
        # 显示主机信息
        host_ip=$(hostname -I | awk '{print $1}')
        echo -e "${BLUE}主机IP: $host_ip${NC}"
        echo -e "${BLUE}规则文件: $RULES_FILE${NC}"
        echo -e "${GREEN}=========================================${NC}"
        
        echo "1. 查看当前端口转发规则"
        echo "2. 添加新的端口转发规则"
        echo "3. 删除已有的端口转发规则"
        echo "4. 查看规则详情"
        echo "5. 保存规则到文件"
        echo "q. 退出脚本"
        echo
        read -p "请选择操作 [1-5 或 q]: " choice
        
        case $choice in
            1)
                clear
                get_current_rules
                ;;
            2)
                clear
                add_new_rule
                ;;
            3)
                clear
                delete_rule
                ;;
            4)
                clear
                show_rule_details
                ;;
            5)
                clear
                save_rules
                ;;
            q|Q)
                echo -e "${GREEN}感谢使用，再见!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择，请重试${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
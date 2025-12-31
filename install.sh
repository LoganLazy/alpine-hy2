#!/bin/sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
PLAIN='\033[0m'

CONF_FILE="/etc/hysteria/config.yaml"
BIN_FILE="/usr/local/bin/hysteria"
SERVICE_NAME="hysteria"

# 检查 root
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 用户运行此脚本${PLAIN}" && exit 1

# 获取系统信息
get_system_info() {
    IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.me || echo "未知IP")
    UPTIME=$(uptime | awk -F'( |,|:)+' '{d=$3; h=$5; m=$6; printf "%d天%d时%d分", d, h, m}')
    MEM_USED=$(free -m | awk '/Mem:/{printf "%.2f%%", $3/$2*100}')
}

# 状态检查
check_status() {
    if [ ! -f "/etc/init.d/$SERVICE_NAME" ]; then return 2; fi
    rc-service $SERVICE_NAME status | grep -q "started" && return 0 || return 1
}

# BBR 检查与开启
enable_bbr() {
    if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ; then
        echo -e "${RED}检测到当前环境为 LXC 容器，请在宿主机开启 BBR。${PLAIN}"
        read -p "按回车返回菜单..."
        return
    fi
    
    echo -e "${YELLOW}正在检查 BBR 状态...${PLAIN}"
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${GREEN}BBR 已经开启！${PLAIN}"
    else
        echo -e "${YELLOW}正在尝试开启 BBR...${PLAIN}"
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
        echo -e "${GREEN}BBR 开启成功！${PLAIN}"
    fi
    read -p "按回车返回菜单..."
}

# 修改配置 (端口/密码)
modify_config() {
    if [ ! -f $CONF_FILE ]; then echo -e "${RED}请先安装 Hysteria 2!${PLAIN}"; return; fi
    echo -e "${CYAN}1. 修改端口${PLAIN}"
    echo -e "${CYAN}2. 修改密码${PLAIN}"
    read -p "请选择: " choice
    if [ "$choice" = "1" ]; then
        read -p "输入新端口: " NEW_PORT
        sed -i "s/listen: :.*/listen: :$NEW_PORT/" $CONF_FILE
    elif [ "$choice" = "2" ]; then
        read -p "输入新密码: " NEW_PW
        sed -i "s/password: .*/password: \"$NEW_PW\"/" $CONF_FILE
    fi
    rc-service $SERVICE_NAME restart
    echo -e "${GREEN}配置已更新并重启服务！${PLAIN}"
    read -p "按回车返回..."
}

# 升级 Hysteria
update_hy2() {
    echo -e "${YELLOW}正在检查最新版本...${PLAIN}"
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)  BINARY="hysteria-linux-amd64" ;;
        aarch64) BINARY="hysteria-linux-arm64" ;;
        *) echo -e "${RED}不支持的架构${PLAIN}"; return ;;
    esac
    curl -L -o $BIN_FILE "https://github.com/apernet/hysteria/releases/latest/download/${BINARY}"
    chmod +x $BIN_FILE
    rc-service $SERVICE_NAME restart
    echo -e "${GREEN}升级完成，当前版本：$($BIN_FILE version | awk '{print $3}')${PLAIN}"
    read -p "按回车返回..."
}

# 安装功能
install_hy2() {
    apk add --no-cache curl openssl ca-certificates file
    read -p "请输入服务监听端口 [默认 443]: " PORT
    [ -z "${PORT}" ] && PORT="443"
    
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)  BINARY="hysteria-linux-amd64" ;;
        aarch64) BINARY="hysteria-linux-arm64" ;;
        *) echo -e "${RED}不支持的架构${PLAIN}"; exit 1 ;;
    esac

    curl -L -o $BIN_FILE "https://github.com/apernet/hysteria/releases/latest/download/${BINARY}"
    chmod +x $BIN_FILE
    
    mkdir -p /etc/hysteria
    openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
    openssl req -x509 -new -key /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500
    
    PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
    cat <<EOF > $CONF_FILE
listen: :$PORT
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: "$PASSWORD"
quic:
  maxIdleTimeout: 30s
  disablePathMTUDiscovery: false
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

    cat <<EOF > /etc/init.d/hysteria
#!/sbin/openrc-run
name="Hysteria2"
command="$BIN_FILE"
command_args="server -c $CONF_FILE"
command_user="root"
command_background="yes"
pidfile="/run/hysteria.pid"
depend() { need net; }
EOF
    chmod +x /etc/init.d/hysteria
    rc-update add hysteria default
    rc-service hysteria restart

    # 注册快捷键
    ln -sf "$(realpath "$0")" /usr/bin/hy2
    chmod +x /usr/bin/hy2
    
    echo -e "${GREEN}安装成功！以后输入 hy2 即可管理。${PLAIN}"
    read -p "按回车显示配置信息..."
    show_link
}

# 显示配置
show_link() {
    if [ ! -f $CONF_FILE ]; then echo -e "${RED}未安装！${PLAIN}"; return; fi
    get_ip
    PW=$(grep 'password:' $CONF_FILE | awk '{print $2}' | tr -d '"')
    PT=$(grep 'listen:' $CONF_FILE | awk -F: '{print $NF}')
    URL="hysteria2://${PW}@${IP}:${PT}/?insecure=1&sni=bing.com#Alpine_Hy2"
    echo -e "\n${BLUE}========== 配置信息 ==========${PLAIN}"
    echo -e "地址: ${GREEN}${IP}:${PT}${PLAIN}"
    echo -e "密码: ${GREEN}${PW}${PLAIN}"
    echo -e "链接: ${YELLOW}${URL}${PLAIN}"
    echo -e "${BLUE}==============================${PLAIN}"
    read -p "按回车返回菜单..."
}

# 菜单展示
show_menu() {
    clear
    get_system_info
    check_status
    RES=$?
    
    echo -e "${PURPLE}==============================================${PLAIN}"
    echo -e "${CYAN}   Hysteria 2 Alpine 管理面板 (V3.0)   ${PLAIN}"
    echo -e "${PURPLE}==============================================${PLAIN}"
    echo -e "${BLUE} 系统状态:${PLAIN}"
    echo -e " IP地址: ${GREEN}$IP${PLAIN}   内存占用: ${GREEN}$MEM_USED${PLAIN}"
    echo -e " 运行时长: ${GREEN}$UPTIME${PLAIN}"
    if [ $RES -eq 0 ]; then
        echo -e " 服务状态: ${GREEN}运行中${PLAIN}"
    elif [ $RES -eq 1 ]; then
        echo -e " 服务状态: ${RED}已停止${PLAIN}"
    else
        echo -e " 服务状态: ${YELLOW}未安装${PLAIN}"
    fi
    echo -e "${PURPLE}----------------------------------------------${PLAIN}"
    echo -e "  ${CYAN}1.${PLAIN} 安装 Hysteria 2"
    echo -e "  ${CYAN}2.${PLAIN} ${GREEN}查看配置 & 分享链接${PLAIN}"
    echo -e "  ${CYAN}3.${PLAIN} 启动服务      ${CYAN}4.${PLAIN} 停止服务"
    echo -e "  ${CYAN}5.${PLAIN} 重启服务      ${CYAN}6.${PLAIN} 修改 端口/密码"
    echo -e "  ${CYAN}7.${PLAIN} 开启 BBR 加速 ${CYAN}8.${PLAIN} 升级 Hysteria"
    echo -e "  ${CYAN}9.${PLAIN} 卸载脚本      ${CYAN}0.${PLAIN} 退出"
    echo -e "${PURPLE}----------------------------------------------${PLAIN}"
    
    # LXC 提醒
    if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ; then
        echo -e "${YELLOW}提示: LXC环境下，请在宿主机执行 sysctl 优化 UDP。${PLAIN}"
    fi

    read -p "请输入序号: " num
    case "$num" in
        1) install_hy2 ;;
        2) show_link ;;
        3) rc-service hysteria start ;;
        4) rc-service hysteria stop ;;
        5) rc-service hysteria restart ;;
        6) modify_config ;;
        7) enable_bbr ;;
        8) update_hy2 ;;
        9) 
            rc-service hysteria stop >/dev/null 2>&1
            rc-update del hysteria default >/dev/null 2>&1
            rm -rf /etc/init.d/hysteria $BIN_FILE /etc/hysteria /usr/bin/hy2
            echo -e "${GREEN}已卸载。${PLAIN}"
            ;;
        0) exit 0 ;;
        *) show_menu ;;
    esac
}

show_menu

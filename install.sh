#!/bin/sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为卸载模式
if [ "$1" = "uninstall" ]; then
    echo -e "${YELLOW}正在卸载 Hysteria 2...${PLAIN}"
    rc-service hysteria stop >/dev/null 2>&1
    rc-update del hysteria default >/dev/null 2>&1
    rm -rf /etc/init.d/hysteria
    rm -rf /usr/local/bin/hysteria
    rm -rf /etc/hysteria
    echo -e "${GREEN}卸载完成！${PLAIN}"
    exit 0
fi

echo -e "${GREEN}开始安装 Hysteria 2 for Alpine Linux (V2.1)...${PLAIN}"

# 1. 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误: 必须使用 root 用户运行此脚本${PLAIN}"
    exit 1
fi

# 2. 安装必要依赖
echo -e "${YELLOW}正在安装依赖工具...${PLAIN}"
apk update && apk add --no-cache curl openssl ca-certificates file

# 3. 设置端口
read -p "请输入服务监听端口 [默认 443]: " PORT
[ -z "${PORT}" ] && PORT="443"

# 4. 自动识别架构并下载最新版
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  BINARY="hysteria-linux-amd64" ;;
    aarch64) BINARY="hysteria-linux-arm64" ;;
    armv7l)  BINARY="hysteria-linux-arm" ;;
    *) echo -e "${RED}不支持的架构: ${ARCH}${PLAIN}"; exit 1 ;;
esac

echo -e "${YELLOW}检测到架构: ${ARCH}，正在下载 Hysteria 2...${PLAIN}"
URL="https://github.com/apernet/hysteria/releases/latest/download/${BINARY}"
curl -L -o /usr/local/bin/hysteria ${URL}
if [ $? -ne 0 ]; then
    echo -e "${RED}下载失败，请检查网络或 GitHub 链接是否可用${PLAIN}"
    exit 1
fi
chmod +x /usr/local/bin/hysteria

# 5. 生成 ECC 自签名证书
mkdir -p /etc/hysteria
echo -e "${YELLOW}正在生成自签名 ECC 证书...${PLAIN}"
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
openssl req -x509 -new -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500
chmod 600 /etc/hysteria/server.key

# 6. 生成密码并写入配置文件 (修复 auth.type 问题)
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
# 自动获取公网 IP，如果获取失败则留空让用户手动填写
IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.me || echo "你的服务器IP")

cat <<EOF > /etc/hysteria/config.yaml
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

ignoreClientBandwidth: false
EOF

# 7. 配置 OpenRC 服务管理
echo -e "${YELLOW}配置 OpenRC 启动脚本...${PLAIN}"
cat <<EOF > /etc/init.d/hysteria
#!/sbin/openrc-run

name="Hysteria2 Server"
description="Hysteria2 Server Service"

command="/usr/local/bin/hysteria"
command_args="server -c /etc/hysteria/config.yaml"
command_user="root"
command_background="yes"
pidfile="/run/hysteria.pid"

depend() {
    need net
}
EOF

chmod +x /etc/init.d/hysteria
rc-update add hysteria default
rc-service hysteria restart

# 8. 生成客户端分享链接 (hysteria2:// 协议)
# 格式: hysteria2://password@ip:port/?insecure=1&sni=bing.com#备注
URL="hysteria2://${PASSWORD}@${IP}:${PORT}/?insecure=1&sni=bing.com#Alpine_Hy2"

clear
echo -e "${GREEN}Hysteria 2 安装并启动成功！${PLAIN}"
echo -e "-------------------------------------------"
echo -e "服务器 IP  : ${GREEN}${IP}${PLAIN}"
echo -e "监听端口   : ${GREEN}${PORT}${PLAIN}"
echo -e "认证密码   : ${GREEN}${PASSWORD}${PLAIN}"
echo -e "SNI 域名   : bing.com"
echo -e "-------------------------------------------"
echo -e "${YELLOW}通用分享链接 (直接复制到 v2rayN / Nekobox):${PLAIN}"
echo -e "${GREEN}${URL}${PLAIN}"
echo -e "-------------------------------------------"
echo -e "管理指令: "
echo -e "查看状态: rc-service hysteria status"
echo -e "重启服务: rc-service hysteria restart"
echo -e "卸载脚本: ./install.sh uninstall"
echo -e "-------------------------------------------"

# 针对 LXC 容器的友好提示
if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ; then
    echo -e "${YELLOW}提示: 检测到你在 LXC 容器环境下运行。${PLAIN}"
    echo -e "${YELLOW}如果连接速度慢，请在【宿主机】执行以下命令优化 UDP 缓存：${PLAIN}"
    echo -e "sysctl -w net.core.rmem_max=16777216"
    echo -e "sysctl -w net.core.wmem_max=16777216"
    echo -e "-------------------------------------------"
fi

#!/bin/sh

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 检查是否为卸载模式
if [ "$1" = "uninstall" ]; then
    echo -e "${YELLOW}正在卸载 Hysteria 2...${PLAIN}"
    rc-service hysteria stop
    rc-update del hysteria default
    rm -rf /etc/init.d/hysteria
    rm -rf /usr/local/bin/hysteria
    rm -rf /etc/hysteria
    echo -e "${GREEN}卸载完成！${PLAIN}"
    exit 0
fi

echo -e "${GREEN}开始安装 Hysteria 2 for Alpine Linux (V2)...${PLAIN}"

# 1. 检查 root
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误: 必须使用 root 用户运行此脚本${PLAIN}"
    exit 1
fi

# 2. 安装依赖
apk update && apk add --no-cache curl openssl ca-certificates file

# 3. 设置端口
read -p "请输入服务监听端口 [默认 443]: " PORT
[ -z "${PORT}" ] && PORT="443"

# 4. 自动识别架构下载
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)  BINARY="hysteria-linux-amd64" ;;
    aarch64) BINARY="hysteria-linux-arm64" ;;
    armv7l)  BINARY="hysteria-linux-arm" ;;
    *) echo -e "${RED}不支持的架构: ${ARCH}${PLAIN}"; exit 1 ;;
esac

echo -e "${YELLOW}下载二进制文件中...${PLAIN}"
URL="https://github.com/apernet/hysteria/releases/latest/download/${BINARY}"
curl -L -o /usr/local/bin/hysteria ${URL}
chmod +x /usr/local/bin/hysteria

# 5. 生成证书
mkdir -p /etc/hysteria
openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/server.key
openssl req -x509 -new -key /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -subj "/CN=bing.com" -days 36500

# 6. 生成密码并写配置
PASSWORD=$(openssl rand -base64 12 | tr -d '/+=')
IP=$(curl -s https://api.ipify.org || echo "你的服务器IP")

cat <<EOF > /etc/hysteria/config.yaml
listen: :$PORT
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  password: "$PASSWORD"
quic:
  maxIdleTimeout: 30s
  disablePathMTUDiscovery: false
bandwidth:
  up: 100 mbps
  down: 100 mbps
EOF

# 7. OpenRC 服务配置
cat <<EOF > /etc/init.d/hysteria
#!/sbin/openrc-run
name="Hysteria2 Server"
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
rc-service hysteria start

# 8. 生成客户端链接 (URL 编码处理简单字符)
# 格式: hysteria2://auth@ip:port/?insecure=1&sni=bing.com#备注
URL="hysteria2://${PASSWORD}@${IP}:${PORT}/?insecure=1&sni=bing.com#Alpine_Hy2"

clear
echo -e "${GREEN}Hysteria 2 安装成功！${PLAIN}"
echo -e "-------------------------------------------"
echo -e "服务器 IP  : ${GREEN}${IP}${PLAIN}"
echo -e "监听端口   : ${GREEN}${PORT}${PLAIN}"
echo -e "认证密码   : ${GREEN}${PASSWORD}${PLAIN}"
echo -e "SNI 域名   : bing.com (自签证书需配合使用)"
echo -e "-------------------------------------------"
echo -e "${YELLOW}通用客户端分享链接 (直接复制到客户端):${PLAIN}"
echo -e "${GREEN}${URL}${PLAIN}"
echo -e "-------------------------------------------"
echo -e "管理指令: "
echo -e "卸载脚本: ./install.sh uninstall"
echo -e "重启服务: rc-service hysteria restart"
echo -e "-------------------------------------------"

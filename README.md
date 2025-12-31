# 🚀 Alpine Linux Hysteria 2 一键管理脚本 (V3.0)
专门为 **Alpine Linux (OpenRC)** 深度定制的 Hysteria 2 一键安装与管理脚本。完美解决 Alpine 系统没有 systemd、基础工具不全、配置复杂的痛点。

---

## ✨ 功能特性

- **🚀 交互式菜单**：类似 `x-ui` 的管理面板，输入 `hy2` 即可调出。
- **📦 架构自适应**：智能识别 `x86_64` / `ARM64` / `ARMv7` 架构。
- **⚡ BBR 加速**：支持一键开启内核 BBR（针对 KVM/物理机）。
- **🏗️ LXC 优化**：自动检测 LXC 环境并提供 UDP 缓存优化建议。
- **🔐 自动证书**：全自动生成自签名 ECC 证书（prime256v1）。
- **🔗 链接生成**：安装后直接输出 `hysteria2://` 分享链接。
- **🛠️ 全能管理**：支持修改端口、重置密码、一键升级、服务保活。

---

## 🚀 快速开始

在你的 Alpine 服务器终端执行以下命令：

```bash
apk add wget && wget --no-check-certificate -O install.sh [https://raw.githubusercontent.com/LoganLazy/alpine-hy2/main/install.sh](https://raw.githubusercontent.com/LoganLazy/alpine-hy2/main/install.sh) && chmod +x install.sh && ./install.sh```

快捷指令
安装完成后，以后只需输入一个简单的命令即可管理服务：
'''hy2'''
## 📸 面板预览
运行 hy2 后的管理菜单界面：
'''==============================================
   Hysteria 2 Alpine 管理面板 (V3.0)   
==============================================
 系统状态:
 IP地址: 1.2.3.4   内存占用: 12.5%
 运行时长: 5天12时30分
 服务状态: 运行中
----------------------------------------------
  1. 安装 Hysteria 2
  2. 查看配置 & 分享链接
  3. 启动服务      4. 停止服务
  5. 重启服务      6. 修改 端口/密码
  7. 开启 BBR 加速 8. 升级 Hysteria
  9. 卸载脚本      0. 退出
----------------------------------------------'''
##⚠️ 特别注意 (LXC 环境)
如果你在 LXC 容器（如 Proxmox 的 Alpine 模板、LXD 容器）中运行，由于 UDP 发包限制，建议在宿主机执行以下命令优化网络性能：
'''sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216'''
##🛠 客户端配置说明
本脚本使用的是 自签名证书。
跳过证书验证：客户端（如 v2rayN / Nekobox）必须将 Insecure 或 跳过证书验证 设为 true。
SNI 设置：默认为 bing.com。



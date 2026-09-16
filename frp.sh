#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 权限运行此脚本！(例如: sudo bash frp.sh)"
    exit 1
fi

while true; do
    clear
    echo "=================================================="
    echo "         FRP 服务端一键管理脚本 (v0.71.0)         "
    echo "=================================================="
    echo " 1. 安装 frp 服务端"
    echo " 2. 卸载 frp 服务端"
    echo " 3. 查看 frp 运行状态"
    echo " 4. 查看 frp 配置文件内容"
    echo " 5. 退出脚本"
    echo "=================================================="
    read -p "请输入选项数字 [1-5]: " CHOICE
    
    case "$CHOICE" in
        1)
            if [ -f /usr/local/frps/frps ] || [ -f /etc/systemd/system/frps.service ]; then
                echo ""
                echo "=================================================="
                echo " 检测到系统中已经安装有 frp 服务端！"
                echo " 如需重新安装，请先选择选项 2 卸载后再试。"
                echo "=================================================="
            else
                echo "=== 开始安装 frp 服务端 ==="
                RANDOM_BIND_PORT=$((RANDOM % 55536 + 10000))
                RANDOM_WEB_PORT=$((RANDOM % 55536 + 10000))
                while [ "$RANDOM_BIND_PORT" -eq "$RANDOM_WEB_PORT" ]; do
                    RANDOM_WEB_PORT=$((RANDOM % 55536 + 10000))
                done
                RANDOM_TOKEN=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)
                FRP_VERSION="0.71.0"
                echo "正在下载并配置 frp v${FRP_VERSION} ..."
                mkdir -p /usr/local/frps && cd /usr/local/frps
                wget -q https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
                tar -zxvf frp_${FRP_VERSION}_linux_amd64.tar.gz >/dev/null 2>&1
                mv frp_${FRP_VERSION}_linux_amd64/* /usr/local/frps/
                rm -rf frp_${FRP_VERSION}_linux_amd64*
                cat << EOF_CFG > /usr/local/frps/frps.toml
bindPort = ${RANDOM_BIND_PORT}
auth.token = "${RANDOM_TOKEN}"
webServer.addr = "0.0.0.0"
webServer.port = ${RANDOM_WEB_PORT}
webServer.user = "admin"
webServer.password = "admin"
EOF_CFG
                cat << EOF_SVC > /etc/systemd/system/frps.service
[Unit]
Description = frp server
After = network.target syslog.target
Wants = network.target
[Service]
Type = simple
ExecStart = /usr/local/frps/frps -c /usr/local/frps/frps.toml
Restart = on-failure
RestartSec = 5s
[Install]
WantedBy = multi-user.target
EOF_SVC
                systemctl daemon-reload
                systemctl enable frps >/dev/null 2>&1
                systemctl restart frps
                PUBLIC_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
                echo ""
                echo "=================================================="
                echo "         frps 服务端安装与启动成功！            "
                echo "=================================================="
                echo "请直接复制以下内容，粘贴覆盖到电脑端 frpc.toml 中："
                echo ""
                echo "serverAddr = \"${PUBLIC_IP}\""
                echo "serverPort = ${RANDOM_BIND_PORT}"
                echo "auth.token = \"${RANDOM_TOKEN}\""
                echo ""
                echo "=================================================="
            fi
            ;;
        2)
            echo "=== 正在卸载 frp 服务端 ==="
            if [ -f /etc/systemd/system/frps.service ]; then
                systemctl stop frps
                systemctl disable frps
                rm -f /etc/systemd/system/frps.service
                systemctl daemon-reload
            fi
            if [ -d /usr/local/frps ]; then
                rm -rf /usr/local/frps
                echo "=== frp 服务端已完全卸载！ ==="
            else
                echo "未检测到 /usr/local/frps 目录，系统中可能没有安装 frp。"
            fi
            ;;
        3)
            echo "=== 正在检查 frp 运行状态 ==="
            systemctl status frps
            ;;
        4)
            echo "=== frp 配置文件内容 (frps.toml) ==="
            if [ -f /usr/local/frps/frps.toml ]; then
                cat /usr/local/frps/frps.toml
            else
                echo "未找到配置文件，frp 可能尚未安装。"
            fi
            ;;
        5)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选项，请输入 1 到 5 之间的数字。"
            ;;
    esac
    
    echo ""
    read -p "操作完成，按回车键返回主菜单..."
done

#!/bin/bash

export LANG=en_US.UTF-8

# 定义颜色变量
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 恢复默认颜色

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    printf "${RED}请使用 root 权限运行此脚本！(例如: sudo bash frp.sh)\n${NC}"
    exit 1
fi

# 禁用 bash 历史记录，防止在服务器生成 .bash_history
ln -sf /dev/null ~/.bash_history
history -c

while true; do
    echo ""
    echo "=================================================="
    echo "         FRP 服务端一键管理脚本 (v0.71.0)         "
    echo "=================================================="
    echo " 1. 安装 frp 服务端"
    echo " 2. 卸载 frp 服务端 (全盘智能清理)"
    echo " 3. 查看 frp 运行状态"
    echo " 4. 查看 frp 配置文件内容"
    echo " 0. 退出脚本"
    echo "=================================================="
    read -p "请输入选项数字 [0-4]: " CHOICE
    
    case "$CHOICE" in
        1)
            if [ -f /usr/local/frps/frps ] || [ -f /etc/systemd/system/frps.service ]; then
                echo ""
                echo "=================================================="
                printf "${RED}检测到系统中已经安装有 frp 服务端！\n${NC}"
                printf "${RED}如需重新安装，请先选择选项 2 卸载后再试。\n${NC}"
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
                printf "${GREEN}         frps 服务端安装与启动成功！             \n${NC}"
                echo "=================================================="
                echo "请直接复制以下内容，粘贴覆盖到电脑端 frpc.toml 中："
                echo ""
                printf "${GREEN}serverAddr = \"${PUBLIC_IP}\"\n${NC}"
                printf "${GREEN}serverPort = ${RANDOM_BIND_PORT}\n${NC}"
                printf "${GREEN}auth.token = \"${RANDOM_TOKEN}\"\n${NC}"
                echo ""
                echo "=================================================="
            fi
            ;;
        2)
            echo "=== 正在全面清理并卸载系统中的 frp 服务 ==="
            
            # 1. 停止并清理所有可能的 systemd 服务
            for svc in frps frp_server frp; do
                if systemctl list-unit-files | grep -q "^${svc}\.service"; then
                    echo "发现后台服务: ${svc}，正在停止并移除..."
                    systemctl stop "$svc" >/dev/null 2>&1
                    systemctl disable "$svc" >/dev/null 2>&1
                    rm -f "/etc/systemd/system/${svc}.service"
                    rm -f "/lib/systemd/system/${svc}.service"
                fi
            done
            systemctl daemon-reload
            
            # 2. 清理常见的主流安装目录
            FOUND_DIR=0
            for dir in /usr/local/frps /opt/frp /usr/bin/frp /root/frp; do
                if [ -d "$dir" ] || [ -f "$dir/frps" ]; then
                    echo "发现残留目录: $dir，正在彻底删除..."
                    rm -rf "$dir"
                    FOUND_DIR=1
                fi
            done
            
            # 3. 顺便通过系统命令查找残留的二进制文件
            WHILE_FRPS=$(which frps 2>/dev/null)
            if [ -n "$WHILE_FRPS" ]; then
                echo "发现二进制文件: $WHILE_FRPS，正在清除..."
                rm -f "$WHILE_FRPS"
                FOUND_DIR=1
            fi

            printf "${GREEN}=== frp 服务清理工作已完成！ ===\n${NC}"
            ;;
        3)
            echo "=== 正在检查 frp 运行状态 ==="
            if systemctl is-active --quiet frps; then
                systemctl status frps
            elif systemctl is-active --quiet frp_server; then
                systemctl status frp_server
            else
                printf "${RED}未找到运行中的 frps 服务。\n${NC}"
            fi
            ;;
        4)
            echo "=== 查找 frp 配置文件内容 ==="
            CONFIG_FOUND=0
            for cfg in /usr/local/frps/frps.toml /opt/frp/frps.toml /etc/frp/frps.ini /etc/frp/frps.toml; do
                if [ -f "$cfg" ]; then
                    echo "找到配置文件: $cfg"
                    cat "$cfg"
                    CONFIG_FOUND=1
                    break
                fi
            done
            if [ "$CONFIG_FOUND" -eq 0 ]; then
                printf "${RED}未在常见路径找到配置文件。\n${NC}"
            fi
            ;;
        0)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            printf "${RED}无效的选项，请输入 0 到 4 之间的数字。\n${NC}"
            ;;
    esac
done

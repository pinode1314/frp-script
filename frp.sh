#!/bin/bash
clear
echo "====================================================="
echo "          FRP 服务端一键管理脚本 (v0.71.0)"
echo "====================================================="
echo
echo "正在检查依赖 curl、wget..."
if ! command -v curl &> /dev/null; then
    apt update && apt install curl -y
fi
if ! command -v wget &> /dev/null; then
    apt update && apt install wget -y
fi
echo "依赖检查完成!"
echo
echo "====================================================="
echo " 1. 安装 frp 服务端 (随机生成 5 位端口与配置)"
echo " 2. 卸载 frp 服务端"
echo "====================================================="
read -p "请输入选项数字 [1-2]: " opt
if [ "$opt" = "1" ];then
    #随机端口
    bind_port=$((10000 + RANDOM % 55535))
    web_port=$((10000 + RANDOM % 55535))
    token=$(head -c 16 /dev/urandom | xxd -p -c 16)
    FRP_VER="0.71.0"
    arch=$(uname -m)
    if [ "$arch" = "x86_64" ];then
        pkg="frp_${FRP_VER}_linux_amd64.tar.gz"
    elif [ "$arch" = "aarch64" ];then
        pkg="frp_${FRP_VER}_linux_arm64.tar.gz"
    else
        echo "不支持架构 $arch"
        exit 1
    fi
    cd /tmp
    wget https://github.com/fatedier/frp/releases/download/v${FRP_VER}/$pkg
    tar -zxvf $pkg
    cd frp_${FRP_VER}_linux_*
    mkdir -p /usr/local/frp
    cp frps /usr/local/frp/
    #写入配置
    cat > /usr/local/frp/frps.ini <<EOF
[common]
bind_port = $bind_port
vhost_http_port = $web_port
token = $token
dashboard_port = $web_port
dashboard_user = admin
dashboard_pwd = $token
EOF
    #systemd服务
    cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=frps service
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/frp/frps -c /usr/local/frp/frps.ini
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable frps
    systemctl start frps
    echo "============================================="
    echo "✅ frps 安装完成！"
    echo "🔹 监听端口 bind_port: $bind_port"
    echo "🔹 Web面板端口: $web_port"
    echo "🔹 Token密钥: $token"
    echo "🔹 Web面板账号: admin"
    echo "🔹 Web面板密码: $token"
    echo "⚠️ 记得服务器防火墙/安全组放行 $bind_port 和 $web_port 端口！"
    echo "============================================="
elif [ "$opt" = "2" ];then
    systemctl stop frps
    systemctl disable frps
    rm -rf /usr/local/frp
    rm /etc/systemd/system/frps.service
    systemctl daemon-reload
    echo "frp服务端已卸载"
else
    echo "输入错误"
fi

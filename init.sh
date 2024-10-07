#!/bin/bash

function ubuntu_non_root_init() {
    # 检查是否为 Ubuntu 系统
    if ! grep -q "Ubuntu" /etc/os-release; then
        echo "该脚本仅适用于 Ubuntu 系统。"
        return 1
    fi

    # 检查用户是否为 root 用户
    if [ "$(whoami)" != "root" ]; then
        echo "请使用 root 用户运行该脚本。"
        return 1
    fi

    # 设置root用户密码
    echo "设置root用户密码"
    passwd root

    # 修改SSH配置文件
    echo "修改SSH配置文件"
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

    # 重启SSH服务
    echo "重启SSH服务"
    systemctl restart ssh
}

function ubuntu_upgrade() {
    echo "正在更新系统..."
    echo '* libraries/restart-without-asking boolean true' | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
}

function install_c3pool() {
    echo "正在下载并安装 C3Pool Miner..."
    curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh | LC_ALL=en_US.UTF-8 bash -s 44DaqEgfkLAV75qW1XMwumFB1F31hntVV9BgHBLnWgeLCws2nS1X8cV5rCd2xV3xVj6aK2AHaHRCj3n8LcgMtpCA99HpXDM

    echo "正在安装 cpulimit..."
    apt-get update
    apt-get install -y cpulimit

    echo "限制 XMRig CPU 使用率到 50%..."
    cpulimit -e xmrig -l 50 -b

    echo "创建 systemd 服务以确保开机自启动..."
    tee /etc/systemd/system/xmrig-cpulimit.service > /dev/null <<EOL
[Unit]
Description=Start XMRig with CPU limit using cpulimit
After=network.target

[Service]
ExecStart=/usr/local/bin/xmrig
ExecStartPost=/usr/bin/cpulimit -e xmrig -l 50 -b
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    echo "重新加载 systemd 并启用 XMRig 服务..."
    systemctl daemon-reload
    systemctl enable xmrig-cpulimit
    systemctl start xmrig-cpulimit

    echo "安装完成并已设置 XMRig CPU 使用率限制为 50%。系统启动时会自动应用限制。"
}

function install_xrayr() {
    echo "正在安装XrayR..."
    bash <(curl -Ls https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/xrayr.sh)

    echo "XrayR 安装完成。"
}

function install_gost() {
    echo "正在安装gost最新版本..."
    bash <(curl -fsSL https://github.com/go-gost/gost/raw/master/install.sh) --install

    echo "gost 安装完成。"
    echo
    echo "gost 使用提示："
    echo "1. 监听本地443/80端口，转发至本地8888端口："
    echo "   - 使用TLS: gost -L relay+tls://:443/:8888"
    echo "   - 使用WebSocket: nohup gost -L relay+ws://:80/:8888 &"
    echo
    echo "2. 开启本地9526端口，并将流量转发至远端的80端口："
    echo "   nohup gost -L tcp://:9526 -F relay+ws://h.rushvpn.win:80 &" 
    echo
    echo "请根据需要选择适合的命令执行。"
}

function install_docker() {
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    echo "Docker 安装完成。"
}

function install_x_ui() {
    echo "正在安装 x-ui..."
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
}

function install_aapanel() {
    echo "正在安装 aaPanel..."
    URL=https://www.aapanel.com/script/install_7.0_en.sh && if [ -f /usr/bin/curl ];then curl -ksSO "$URL" ;else wget --no-check-certificate -O install_7.0_en.sh "$URL";fi;bash install_7.0_en.sh aapanel
}

function run_ecs_benchmark() {
    echo "正在运行融合怪脚本测评..."
    curl -L https://github.com/spiritLHLS/ecs/raw/main/ecs.sh -o ecs.sh && chmod +x ecs.sh && bash ecs.sh -m 1
}

# 主菜单
while true; do
    echo "请选择要执行的操作："
    echo "1. Ubuntu非root时执行初始化"
    echo "2. Ubuntu升级"
    echo "3. 安装c3pool"
    echo "4. 安装XrayR"
    echo "5. 安装gost"
    echo "6. 安装Docker"
    echo "7. 安装x-ui"
    echo "8. 安装aaPanel"
    echo "9. 运行融合怪脚本测评"
    echo "10. 退出"
    read -p "请输入选项编号: " choice

    case $choice in
        1)
            ubuntu_non_root_init
            ;;
        2)
            ubuntu_upgrade
            ;;
        3)
            install_c3pool
            ;;
        4)
            install_xrayr
            ;;
        5)
            install_gost
            ;;
        6)
            install_docker
            ;;
        7)
            install_x_ui
            ;;
        8)
            install_aapanel
            ;;
        9)
            run_ecs_benchmark
            ;;
        10)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新选择"
            ;;
    esac

    echo # 输出空行
done
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
    echo "正在执行 C3Pool Miner 安装脚本..."
    bash <(curl -Ls https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/c3pool.sh)
    echo "C3Pool Miner 安装完成。"
}

function install_xrayr() {
    echo "正在安装 XrayR..."
    bash <(curl -Ls https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/xrayr.sh)
    echo "XrayR 安装完成。"
}

function install_gost() {
    echo "正在安装 gost 最新版本..."
    bash <(curl -fsSL https://github.com/go-gost/gost/raw/master/install.sh) --install
    echo "gost 安装完成。"
    echo
    echo "gost 使用提示："
    echo "1. 监听本地443/80端口，转发至本地8888端口："
    echo "   - 使用TLS: gost -L relay+tls://:443/:8888"
    echo "   - 使用WebSocket: nohup gost -L relay+ws://:80/:8888 &"
    echo
    echo "2. 建立本地9526端口至远程80端口的 WebSocket 隧道："
    echo "   nohup gost -L tcp://:9526 -F relay+ws://h.rushvpn.win:80 &"
    echo
    echo "3. 开启本地9998端口，并将流量转发至远端的8888端口："
    echo "   nohup gost -L tcp://:9998/5.83.221.65:8888 &"
}

function install_docker() {
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    echo "Docker 安装完成。"
    echo "运行 WordPress 容器示例："
    echo "docker run --name wp -p 8080:80 -d wordpress"
    echo "进入 Docker 容器命令："
    echo "docker exec -it wp /bin/bash"
    echo "停止 Docker 容器命令："
    echo "docker stop wp"
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

function install_mysql_and_create_db() {
    echo "正在安装 MySQL 并新增数据库..."
    bash <(curl -Ls https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/mysql.sh)
    echo "MySQL 安装及数据库创建完成。"
}

function install_or_uninstall_wordpress() {
    echo "正在执行 WordPress 安装/卸载脚本..."
    bash <(curl -s https://raw.githubusercontent.com/chsafe/scripts/refs/heads/main/wp-install-uninstall.sh)
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
    echo "10. 安装 MySQL 并新增数据库"
    echo "11. WordPress 安装和卸载"
    echo "12. 退出"
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
            install_mysql_and_create_db
            ;;
        11)
            install_or_uninstall_wordpress
            ;;
        12)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo "无效的选项，请重新选择"
            ;;
    esac

    echo # 输出空行
done
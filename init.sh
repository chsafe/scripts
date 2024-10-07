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

function install_wordpress() {
    # 设置数据库名称和用户名
    DB_NAME="wordpress"
    DB_USER="wp_user"

    # 提示用户输入数据库密码
    read -sp '请输入 MySQL 数据库密码: ' DB_PASSWORD
    echo

    # 提示用户输入域名（用于配置 HTTPS）
    read -p '请输入要配置的域名 (如 example.com): ' DOMAIN

    # 提示用户输入邮箱地址（用于 SSL 证书）
    read -p '请输入你的邮箱地址 (用于接收 SSL 证书通知): ' EMAIL

    # 确保脚本在 Debian 系统上运行，且 `debconf-utils` 包已安装
    if ! command -v apt-get &> /dev/null; then
        echo "错误：此系统不支持 apt-get。请确认你在 Debian 或 Ubuntu 系统上运行。"
        return 1
    fi

    # 安装 debconf-utils（如果没有安装）
    if ! dpkg -s debconf-utils &> /dev/null; then
        apt-get update
        apt-get install -y debconf-utils
    fi

    # 设置环境变量，避免系统更新交互
    export DEBIAN_FRONTEND=noninteractive

    # 配置 debconf 以自动重新启动服务
    echo '* libraries/restart-without-asking boolean true' | debconf-set-selections

    # 更新系统
    apt-get update -y
    apt-get upgrade -yq

    # 安装 Apache、MySQL、PHP 和 Certbot
    apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql php-cli php-curl php-zip php-gd php-mbstring php-xml php-xmlrpc certbot python3-certbot-apache

    # 启用 Apache 模块
    a2enmod ssl
    a2enmod rewrite

    # 启动并启用 Apache 和 MySQL
    systemctl start apache2
    systemctl enable apache2
    systemctl start mysql
    systemctl enable mysql

    # 创建 MySQL 数据库和用户
    mysql -u root -e "CREATE DATABASE ${DB_NAME};"
    mysql -u root -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"

    # 下载 WordPress
    cd /var/www/html
    wget https://wordpress.org/latest.tar.gz
    tar -xzvf latest.tar.gz
    rm latest.tar.gz
    mv wordpress/* .
    rmdir wordpress

    # 删除默认的 index.html 文件
    rm /var/www/html/index.html

    # 设置权限
    chown -R www-data:www-data /var/www/html
    chmod -R 755 /var/www/html

    # 配置 wp-config.php
    cp wp-config-sample.php wp-config.php
    sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
    sed -i "s/username_here/${DB_USER}/" wp-config.php
    sed -i "s/password_here/${DB_PASSWORD}/" wp-config.php

    # 创建和启用虚拟主机配置文件
    VHOST_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

    cat <<EOF > $VHOST_CONF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

    # 禁用默认虚拟主机配置
    a2dissite 000-default.conf

    # 启用新的虚拟主机配置
    a2ensite $DOMAIN.conf
    systemctl reload apache2

    # 尝试使用 Certbot 为 Apache 获取 SSL 证书
    RETRY_COUNT=0
    MAX_RETRIES=5
    CERT_OBTAINED=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
        if [ $? -eq 0 ]; then
            CERT_OBTAINED=true
            break
        fi
        echo "SSL 证书生成失败，正在重试... ($((RETRY_COUNT+1))/$MAX_RETRIES)"
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 30
    done

    # 检查 SSL 证书是否成功生成
    if [ "$CERT_OBTAINED" = true ]; then
        echo "SSL 证书生成成功，配置 HTTPS。"

        # 创建和启用 SSL 虚拟主机配置文件
        VHOST_SSL_CONF="/etc/apache2/sites-available/$DOMAIN-ssl.conf"

        cat <<EOF > $VHOST_SSL_CONF
<VirtualHost *:443>
    ServerName $DOMAIN

    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

        a2ensite $DOMAIN-ssl.conf
        systemctl reload apache2

        # 启用自动更新证书
        systemctl enable certbot.timer
    else
        echo "SSL 证书生成失败，请检查 Certbot 配置和日志。"
    fi

    echo "WordPress 安装完成，请在浏览器中访问 https://$DOMAIN 继续安装。"
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
    echo "6. 安装WordPress"
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
            install_wordpress
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
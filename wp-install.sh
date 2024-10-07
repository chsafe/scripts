#!/bin/bash

# 设置数据库名称和用户名
DB_NAME="wordpress"
DB_USER="wp_user"

# 提示用户输入数据库密码
read -sp '请输入 MySQL 数据库密码: ' DB_PASSWORD
echo

# 提示用户输入域名（用于配置 HTTPS）
read -p '请输入要配置的域名 (如 example.com): ' DOMAIN

# 硬编码邮箱地址（用于 SSL 证书）
EMAIL="admin@rushvpn.win"

# 确保脚本在 Debian 系统上运行，且 `debconf-utils` 包已安装
if ! command -v apt-get &> /dev/null; then
    echo "错误：此系统不支持 apt-get。请确认你在 Debian 或 Ubuntu 系统上运行。"
    exit 1
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

# 安装 Nginx、MySQL、PHP 和 Certbot
apt-get install -y nginx mysql-server php-fpm php-mysql php-cli php-curl php-zip php-gd php-mbstring php-xml php-xmlrpc certbot python3-certbot-nginx

# 启动并启用 Nginx 和 MySQL
systemctl start nginx
systemctl enable nginx
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

# 创建和启用 Nginx 虚拟主机配置文件
VHOST_CONF="/etc/nginx/sites-available/$DOMAIN"

cat <<EOF > $VHOST_CONF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;  # 确保 PHP 版本正确
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# 启用新的虚拟主机配置
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
systemctl reload nginx

# 尝试使用 Certbot 为 Nginx 获取 SSL 证书
RETRY_COUNT=0
MAX_RETRIES=5
CERT_OBTAINED=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
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
    VHOST_SSL_CONF="/etc/nginx/sites-available/$DOMAIN-ssl"

    cat <<EOF > $VHOST_SSL_CONF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    root /var/www/html;
    index index.php index.html index.htm;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;  # 确保 PHP 版本正确
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # 启用 SSL 虚拟主机
    ln -s /etc/nginx/sites-available/$DOMAIN-ssl /etc/nginx/sites-enabled/
    systemctl reload nginx

    # 启用自动更新证书
    systemctl enable certbot.timer
else
    echo "SSL 证书生成失败，请检查 Certbot 配置和日志。"
fi

echo "WordPress 安装完成，请在浏览器中访问 https://$DOMAIN 继续安装。"
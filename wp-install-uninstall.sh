#!/bin/bash

# 提示用户选择操作
echo "请选择操作:"
echo "1) 安装 WordPress、Nginx、PHP、Certbot"
echo "2) 删除 WordPress、Nginx、PHP、Certbot"
read -p "请输入您的选择 (1 或 2): " CHOICE

# 根据用户选择执行操作
if [ "$CHOICE" == "1" ]; then
    # 输入域名和邮箱地址
    read -p "请输入您的域名: " DOMAIN
    read -p "请输入您的邮箱: " EMAIL

    # 更新系统并安装所需的软件包
    echo "更新系统并安装 Nginx, PHP, Certbot..."
    apt-get update
    apt-get install -y nginx php-fpm php-mysql certbot python3-certbot-nginx unzip curl

    # 下载并安装最新版的 WordPress
    echo "下载并安装 WordPress..."
    wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
    unzip /tmp/wordpress.zip -d /var/www/
    chown -R www-data:www-data /var/www/wordpress
    chmod -R 755 /var/www/wordpress

    # 配置 Nginx
    NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
    echo "配置 Nginx..."
    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/wordpress;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # 创建符号链接启用 Nginx 配置
    ln -s $NGINX_CONFIG /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # 申请 SSL 证书并自动配置 Nginx
    echo "申请 SSL 证书..."
    certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

    # 配置 Nginx 强制重定向到 HTTPS
    echo "更新 Nginx 配置以支持 HTTPS..."
    cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;  # 强制重定向到 HTTPS
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    root /var/www/wordpress;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # 检查 Nginx 配置并重新加载服务
    nginx -t && systemctl reload nginx

    # 引导用户完成 WordPress 设置
    echo "WordPress 已安装，请通过浏览器访问您的域名并完成配置。"
    echo "在 WordPress 的配置页面中，您可以输入远程数据库的连接信息。"

elif [ "$CHOICE" == "2" ]; then
    # 删除 WordPress、Nginx、PHP、Certbot
    echo "正在删除 WordPress、Nginx、PHP、Certbot..."

    # 停止并禁用 Nginx 服务
    systemctl stop nginx
    systemctl disable nginx

    # 卸载 Nginx, PHP, Certbot
    apt-get remove --purge -y nginx php-fpm php-mysql certbot python3-certbot-nginx

    # 删除 Nginx 和 Certbot 残留的配置和日志文件
    rm -rf /etc/nginx
    rm -rf /var/www/wordpress
    rm -rf /var/log/nginx
    rm -rf /etc/letsencrypt
    rm -rf /var/log/letsencrypt

    # 删除符号链接
    rm -f /etc/nginx/sites-enabled/$DOMAIN
    rm -f /etc/nginx/sites-available/$DOMAIN

    # 删除 WordPress 文件
    rm -rf /var/www/wordpress

    # 清理无用的软件包和依赖
    apt-get autoremove -y
    apt-get autoclean

    echo "WordPress、Nginx、PHP、Certbot 及其配置文件已成功删除。"
else
    echo "无效的选择，请重新运行脚本并选择 1 或 2。"
fi
#!/bin/bash

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
#!/bin/bash

# 清除 Nginx 和 Certbot 相关内容
echo "停止并禁用 Nginx 服务..."
systemctl stop nginx
systemctl disable nginx

echo "卸载 Nginx..."
apt-get remove --purge nginx nginx-common nginx-full -y

echo "删除 Nginx 残留文件和目录..."
rm -rf /etc/nginx
rm -rf /var/www/html
rm -rf /var/log/nginx

echo "卸载 Certbot 和相关组件..."
apt-get remove --purge certbot python3-certbot-nginx -y

echo "删除 Certbot 残留文件..."
rm -rf /etc/letsencrypt
rm -rf /var/log/letsencrypt

echo "清理无用的软件包和依赖..."
apt-get autoremove -y
apt-get autoclean

# 开始重新安装并配置
read -p "请输入您的域名: " DOMAIN
read -p "请输入您的邮箱: " EMAIL

echo "正在更新系统并安装 Nginx 和 Certbot..."
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

# 配置 Nginx 以 HTTP 模式启动，反向代理到本地 Docker 容器的 8080 端口
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
cat > $NGINX_CONFIG <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "创建 Nginx 配置的符号链接..."
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

echo "检查 Nginx 配置..."
nginx -t

echo "启动 Nginx 服务..."
systemctl restart nginx
systemctl enable nginx

echo "正在申请 SSL 证书..."
certbot certonly --webroot -w /var/www/html -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "更新 Nginx 配置以支持 HTTPS..."
    cat > $NGINX_CONFIG <<EOF

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    echo "重新检查 Nginx 配置..."
    nginx -t
    echo "重新加载 Nginx 服务..."
    systemctl reload nginx
else
    echo "SSL 证书申请失败，请检查错误日志。"
fi

echo "SSL 证书申请和 Nginx 配置已完成。"
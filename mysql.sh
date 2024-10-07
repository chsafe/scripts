#!/bin/bash

# 检查 MySQL 是否已经安装
if ! dpkg -l | grep -q mysql-server; then
    # 如果没有安装 MySQL，则进行安装
    echo "MySQL 未安装，正在安装 MySQL 服务器..."
    apt update
    apt install -y mysql-server

    # 启动 MySQL 服务并设置开机自启
    systemctl start mysql
    systemctl enable mysql
else
    echo "MySQL 已经安装，跳过安装步骤。"
fi

# 提示输入 MySQL root 用户密码
read -sp "请输入 MySQL root 用户密码: " MYSQL_ROOT_PASSWORD
echo

# 检查 MySQL 是否能够使用 root 用户登录
if mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e ";" 2>/dev/null; then
    echo "成功登录 MySQL。"

    # 创建随机的数据库、用户和密码
    DB_NAME=$(openssl rand -hex 4)  # 生成随机数据库名
    DB_USER=$(openssl rand -hex 4)  # 生成随机用户名
    DB_PASS=$(openssl rand -base64 12)  # 生成随机密码

    # 在 MySQL 中创建数据库、用户并赋予权限
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE ${DB_NAME};"
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
    mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

    # 记录生成的数据库、用户和密码及创建时间到 /root/db.txt
    echo "时间: $(date)" >> /root/db.txt
    echo "数据库名: ${DB_NAME}" >> /root/db.txt
    echo "用户名: ${DB_USER}" >> /root/db.txt
    echo "密码: ${DB_PASS}" >> /root/db.txt
    echo "-----------------------------" >> /root/db.txt

    # 输出数据库、用户和密码
    echo "随机数据库、用户和密码已生成！"
    echo "数据库名: ${DB_NAME}"
    echo "用户名: ${DB_USER}"
    echo "密码: ${DB_PASS}"

    # 配置 MySQL 以允许远程连接（如果第一次安装 MySQL 时需要配置）
    if ! grep -q "bind-address = 0.0.0.0" /etc/mysql/mysql.conf.d/mysqld.cnf; then
        sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
        systemctl restart mysql
        echo "已配置 MySQL 允许远程连接。"
    fi

    # 开放 3306 端口
    ufw allow 3306
else
    echo "无法登录 MySQL，请检查 root 密码是否正确。"
fi
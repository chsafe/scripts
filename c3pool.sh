#!/bin/bash

# 1. 下载并安装 XMRig (C3Pool Miner)
echo "正在下载并安装 C3Pool Miner..."
curl -s -L https://download.c3pool.org/xmrig_setup/raw/master/setup_c3pool_miner.sh | LC_ALL=en_US.UTF-8 bash -s 44DaqEgfkLAV75qW1XMwumFB1F31hntVV9BgHBLnWgeLCws2nS1X8cV5rCd2xV3xVj6aK2AHaHRCj3n8LcgMtpCA99HpXDM

# 2. 安装 cpulimit
echo "正在安装 cpulimit..."
apt-get update
apt-get install -y cpulimit

# 3. 限制 CPU 使用率到 50%
echo "限制 XMRig CPU 使用率到 50%..."
cpulimit -e xmrig -l 50 -b

# 4. 创建 systemd 服务文件以确保开机自启动
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

# 5. 重新加载 systemd 并启用服务
echo "重新加载 systemd 并启用 XMRig 服务..."
systemctl daemon-reload
systemctl enable xmrig-cpulimit
systemctl start xmrig-cpulimit

# 6. 判断是否保持 CPU 限制
read -p "是否保持 CPU 限制到 50%? (y/n): " answer

if [[ "$answer" == "y" ]]; then
    echo "CPU 限制已保持在 50%。"
else
    echo "取消 CPU 限制..."
    # 取消 CPU 限制的方式是删除 systemd 服务文件
    systemctl stop xmrig-cpulimit
    systemctl disable xmrig-cpulimit
    rm -f /etc/systemd/system/xmrig-cpulimit.service
    systemctl daemon-reload
    echo "CPU 限制已解除。"
fi

echo "安装完成。CPU 使用率限制已设置为 50%。如选择保持限制，系统启动时将自动应用此限制；如取消限制，将不会再应用。"
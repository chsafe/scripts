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

echo "安装完成并已设置 XMRig CPU 使用率限制为 50%。系统启动时会自动应用限制。"

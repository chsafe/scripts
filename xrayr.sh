#!/bin/bash

# 2. 执行XrayR安装命令
echo "正在安装XrayR..."
bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)

# 3. 下载配置文件并替换默认的配置文件
CONFIG_URL="https://rushvpn.win/config.yml"
DEFAULT_CONFIG_PATH="/etc/XrayR/config.yml"

echo "正在下载配置文件..."
curl -L "$CONFIG_URL" -o "$DEFAULT_CONFIG_PATH"

if [ $? -eq 0 ]; then
    echo "配置文件已下载并替换成功。"
else
    echo "下载配置文件失败，请检查URL或网络连接。"
    exit 1
fi

# 4. 打印并修改配置文件中的NodeID
echo "正在读取配置文件中的NodeID..."

# 提取并打印当前的NodeID值
CURRENT_NODE_ID=$(grep -A 3 "NodeID:" "$DEFAULT_CONFIG_PATH" | grep "NodeID:" | awk -F': ' '{print $2}')
echo "当前的NodeID为: $CURRENT_NODE_ID"

# 提示用户输入新的NodeID
read -p "请输入新的NodeID (按Enter保留当前值): " NODE_ID

# 如果用户输入不为空，则更新NodeID
if [ ! -z "$NODE_ID" ]; then
    sed -i "s/NodeID:.*/NodeID: \"$NODE_ID\"/" "$DEFAULT_CONFIG_PATH"
    echo "NodeID已更新为: $NODE_ID"
else
    echo "NodeID保持不变。"
fi

# 5. 重启XrayR服务
echo "正在重启XrayR服务..."
XrayR restart

if [ $? -eq 0 ]; then
    echo "XrayR服务已成功重启。"
else
    echo "重启XrayR服务失败，请检查服务状态。"
    exit 1
fi

# 6. 开启TCP BBR
echo "正在开启TCP BBR..."

# 检查内核版本是否支持BBR
KERNEL_VERSION=$(uname -r)
if [[ "$KERNEL_VERSION" < "4.9" ]]; then
    echo "当前内核版本为 $KERNEL_VERSION，不支持BBR，请升级内核到4.9或更高版本。"
    exit 1
fi

# 启用BBR
sysctl -w net.core.default_qdisc=fq
sysctl -w net.ipv4.tcp_congestion_control=bbr

# 将设置永久生效
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 重新加载配置
sysctl -p

# 验证BBR是否成功启用
BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control | grep bbr)
if [ "$BBR_STATUS" != "" ]; then
    echo "TCP BBR 已成功启用。"
else
    echo "TCP BBR 启用失败。"
fi

echo "所有操作完成！"

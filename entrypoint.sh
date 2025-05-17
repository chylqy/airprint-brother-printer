#!/bin/bash
set -e
set -x

# 创建一个 CUPS 管理员用户并添加到 lpadmin 组
# Is CUPSADMIN set? If not, set to default
if [ -z "$CUPSADMIN" ]; then
    CUPSADMIN="admin"
fi
# Is CUPSPASSWORD set? If not, set to $CUPSADMIN
if [ -z "$CUPSPASSWORD" ]; then
    CUPSPASSWORD=$CUPSADMIN
fi
# 1. 创建系统用户 admin，不创建 home 目录
if [ $(grep -ci $CUPSADMIN /etc/shadow) -eq 0 ]; then
    adduser --system --no-create-home $CUPSADMIN 
fi
# 2. 创建组lpadmin
if [ $(grep -ci lpadmin /etc/gshadow) -eq 0 ]; then
    addgroup --system lpadmin
fi
#3. add user admin to group lpadmin
usermod -aG lpadmin admin
#4. change the password of admin
echo $CUPSADMIN:$CUPSPASSWORD | chpasswd

# 启动 D-Bus daemon
# 使用 --system 模式，并在后台运行
# 将日志输出到标准错误，方便调试
dbus-daemon --system --fork --print-address 2>&1 &
DBUS_PID=$! # 记录 D-Bus 进程ID
# 等待 D-Bus socket 创建 (可选，但有时有用)
sleep 1


# 启动 Avahi 服务,虽然宿主系统已经有avahi服务，而且本容器使用host模式，且挂载了avahi服务目录，但cups仍然无法注册
avahi-daemon --daemonize --no-chroot
AVAHI_PID=$! # 记录 Avahi 进程ID
# 等待 Avahi 启动并注册到 D-Bus (可选，但有时有用)
sleep 2

# 启动 CUPS 服务 (在前台运行，以便 Docker 容器保持活动)
exec cupsd -f

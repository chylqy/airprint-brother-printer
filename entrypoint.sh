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

if [ $(grep -ci $CUPSADMIN /etc/shadow) -eq 0 ]; then
    adduser -S -G lpadmin --no-create-home $CUPSADMIN 
fi
echo $CUPSADMIN:$CUPSPASSWORD | chpasswd

# 启动 Avahi 服务
avahi-daemon --daemonize --no-chroot

# 启动 CUPS 服务 (在前台运行，以便 Docker 容器保持活动)
exec cupsd -f

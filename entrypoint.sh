#!/bin/bash

# 启动 Avahi 服务
avahi-daemon --daemonize --no-chroot

# 启动 CUPS 服务 (在前台运行，以便 Docker 容器保持活动)
exec cupsd -f

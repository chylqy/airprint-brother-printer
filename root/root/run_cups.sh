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

mkdir -p /config/ppd
mkdir -p /services
rm -rf /etc/avahi/services/*
rm -rf /etc/cups/ppd
ln -s /config/ppd /etc/cups
if [ `ls -l /services/*.service 2>/dev/null | wc -l` -gt 0 ]; then
	cp -f /services/*.service /etc/avahi/services/
fi
if [ `ls -l /config/printers.conf 2>/dev/null | wc -l` -eq 0 ]; then
    touch /config/printers.conf
fi
cp /config/printers.conf /etc/cups/printers.conf

if [ `ls -l /config/cupsd.conf 2>/dev/null | wc -l` -ne 0 ]; then
    cp /config/cupsd.conf /etc/cups/cupsd.conf
else
    cp /etc/cups/cupsd.conf /config/cupsd.conf
fi

# Function to handle cleanup on exit
cleanup() {
    echo "Cleaning up..."
    if [ -f /var/run/avahi-daemon.pid ]; then
        PID=$(cat /var/run/avahi-daemon.pid)
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            rm -f /var/run/avahi-daemon.pid
        fi
    fi
    exit 0
}

# Set up trap for cleanup
trap cleanup SIGTERM SIGINT

# Start avahi-daemon service in the background
/root/avahi-service.sh &
AVAHI_SERVICE_PID=$!

# Start CUPS and printer update
/root/printer-update.sh &
exec /usr/sbin/cupsd -f

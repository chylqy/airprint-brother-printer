FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive

# 安装 CUPS, wget, Avahi, 和 i386 架构支持
RUN apt-get update && apt-get install -y \
    cups \
    cups-pdf \
    cups-filters \
    libcups2-dev \
    ghostscript \
    inotify-tools \
    cups-bsd \
    cups-client \
    cups-common \
    wget \
    avahi-daemon \
    libnss-mdns \
    libusb-1.0-0-dev \
    python3 \
    python3-dev \
    python3-cups \
    rsync \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# 启用 i386 架构并安装基础 32 位库
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        libc6:i386 \
        libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

# 下载并安装 Brother 打印驱动
ARG BROTHER_PRINTER_DRIVER_URL="https://download.brother.com/pub/com/linux/linux/packages/dcpt426wpdrv-3.5.0-2.i386.deb"
ARG BROTHER_PRINTER_DRIVER_FILENAME="dcpt426wpdrv-3.5.0-2.i386.deb"

RUN wget -O /tmp/${BROTHER_PRINTER_DRIVER_FILENAME} ${BROTHER_PRINTER_DRIVER_URL}
RUN dpkg -i --force-all /tmp/${BROTHER_PRINTER_DRIVER_FILENAME} || apt-get install -fy --no-install-recommends
RUN rm /tmp/${BROTHER_PRINTER_DRIVER_FILENAME}

# --- 配置 CUPS 允许远程访问和共享打印机 (AirPrint 需要) ---
RUN sed -i 's/Listen localhost:631/Listen 0.0.0.0:631/' /etc/cups/cupsd.conf && \
	sed -i 's/Browsing Off/Browsing On/' /etc/cups/cupsd.conf && \
 	sed -i 's/IdleExitTimeout/#IdleExitTimeout/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/>/<Location \/>\n  Allow All/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin>/<Location \/admin>\n  Allow All\n  Require user @SYSTEM/' /etc/cups/cupsd.conf && \
	sed -i 's/<Location \/admin\/conf>/<Location \/admin\/conf>\n  Allow All/' /etc/cups/cupsd.conf && \
	sed -i 's/.*enable\-dbus=.*/enable\-dbus\=no/' /etc/avahi/avahi-daemon.conf && \
	echo "ServerAlias *" >> /etc/cups/cupsd.conf && \
	echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf && \
	echo "ReadyPaperSizes A4,TA4,4X6FULL,T4X6FULL,2L,T2L,A6,A5,B5,L,TL,INDEX5,8x10,T8x10,4X7,T4X7,Postcard,TPostcard,ENV10,EnvDL,ENVC6,Letter,Legal" >> /etc/cups/cupsd.conf && \
	echo "DefaultPaperSize A4" >> /etc/cups/cupsd.conf && \
	echo "pdftops-renderer ghostscript" >> /etc/cups/cupsd.conf
# --- CUPS 配置结束 ---

# 配置 Avahi
# 通常 Avahi 的默认配置可以工作，但有时需要确保它在正确的网络接口上广播
# 并且允许反射 mDNS 查询 (如果 Docker 网络配置复杂)
# 创建 Avahi 服务文件，让 CUPS 打印机通过 Avahi 广播
# CUPS 通常会自动创建必要的 Avahi 服务文件，但如果遇到问题，可以手动创建
# 例如，在 /etc/avahi/services/ 目录下创建 .service 文件
# RUN echo "<?xml version=\"1.0\" standalone='no'?><!--*-nxml-*-->\
# <!DOCTYPE service-group SYSTEM \"avahi-service.dtd\">\
# <service-group>\
#   <name replace-wildcards=\"yes\">AirPrint %h</name>\
#   <service>\
#     <type>_ipp._tcp</type>\
#     <port>631</port>\
#     <txt-record>txtvers=1</txt-record>\
#     <txt-record>qtotal=1</txt-record>\
#     <txt-record>rp=printers/%h</txt-record> <!-- %h 会被替换为打印机名 -->\
#     <txt-record>ty=Brother DCP-T426W</txt-record>\
#     <txt-record>note=My Home Printer</txt-record>\
#     <txt-record>product=(GPL Ghostscript)</txt-record>\
#     <txt-record>printer-state=3</txt-record>\
#     <txt-record>printer-type=0x480FFFC</txt-record> <!-- 示例类型，可能需要调整 -->\
#     <txt-record>URF=DM3</txt-record>\
#     <txt-record>TLS=1.2</txt-record>\
#     <txt-record>Transparent=T</txt-record>\
#     <txt-record>Binary=T</txt-record>\
#     <txt-record>Fax=F</txt-record>\
#     <txt-record>Scan=F</txt-record> <!-- 如果支持扫描，可以改为T -->\
#     <txt-record>adminurl=http://SERVER_IP:631/printers/%h</txt-record>\
#     <txt-record>UUID=YOUR_PRINTER_UUID</txt-record> <!-- UUID很重要，CUPS会生成 -->\
#     <txt-record>pdl=application/octet-stream,application/pdf,application/postscript,image/jpeg,image/png,image/urf</txt-record>\
#   </service>\
# </service-group>" > /etc/avahi/services/airprint.service
# 上面的手动创建 .service 文件通常是不必要的，CUPS 会处理。

# 修改 Avahi 配置以允许反射 (如果需要)
# RUN sed -i 's/#enable-reflector=no/enable-reflector=yes/' /etc/avahi/avahi-daemon.conf
# RUN sed -i 's/#reflect-ipv=no/reflect-ipv=yes/' /etc/avahi/avahi-daemon.conf

# 修改 nsswitch.conf 以使用 mDNS
# RUN sed -i 's/hosts:.*$/hosts:          files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf

# This will use port 631
EXPOSE 631

# We want a mount for these
VOLUME /config
VOLUME /services

# Add scripts
ADD root /
RUN chmod +x /root/*

#Run Script
CMD ["/root/run_cups.sh"]

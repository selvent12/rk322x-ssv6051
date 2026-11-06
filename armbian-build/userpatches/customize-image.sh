#!/bin/bash
# For armbian/build: copy this file to build/userpatches/customize-image.sh
# and the rk322x-ssv6051 folder to build/userpatches/overlay/rk322x-ssv6051.
# Runs inside the image chroot; userpatches/overlay is mounted at /tmp/overlay.
#
# Arguments passed by armbian build: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP

BOARD=$3

if [ "$BOARD" = "rk322x-box" ] && [ -d /tmp/overlay/rk322x-ssv6051 ]; then
    set -e
    K=$(ls /lib/modules | sort -V | tail -1)
    echo ">> SSV6051: building the driver for kernel $K"
    if [ ! -d "/lib/modules/$K/build" ]; then
        echo "ERROR: the image has no kernel headers. Build with INSTALL_HEADERS=yes" >&2
        exit 1
    fi
    apt-get install -y build-essential
    cp -a /tmp/overlay/rk322x-ssv6051 /root/rk322x-ssv6051
    KVER="$K" FORCE_BUILD=1 bash /root/rk322x-ssv6051/install-on-box.sh
fi

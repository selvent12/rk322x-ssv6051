#!/bin/bash
# Pentru armbian/build: copiaza acest fisier in build/userpatches/customize-image.sh
# si folderul rk322x-ssv6051 in build/userpatches/overlay/rk322x-ssv6051.
# Ruleaza in chroot-ul imaginii; userpatches/overlay e montat in /tmp/overlay.
#
# Argumente primite de la armbian build: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP

BOARD=$3

if [ "$BOARD" = "rk322x-box" ] && [ -d /tmp/overlay/rk322x-ssv6051 ]; then
    set -e
    K=$(ls /lib/modules | sort -V | tail -1)
    echo ">> SSV6051: compilez driverul pentru kernel $K"
    if [ ! -d "/lib/modules/$K/build" ]; then
        echo "EROARE: imaginea nu are headerele kernelului. Construieste cu INSTALL_HEADERS=yes" >&2
        exit 1
    fi
    apt-get install -y build-essential
    cp -a /tmp/overlay/rk322x-ssv6051 /root/rk322x-ssv6051
    KVER="$K" FORCE_BUILD=1 bash /root/rk322x-ssv6051/install-on-box.sh
fi

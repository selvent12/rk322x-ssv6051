#!/bin/bash
# Installs the SSV6051 WiFi driver (eloirotava/6051) on an rk322x box running Armbian.
# Usage (as root, from the rk322x-ssv6051 folder):  sudo bash install-on-box.sh
#
# Optional variables:
#   KVER=<version>   kernel to install for (default: the running kernel)
#   FORCE_BUILD=1    build from source even if a prebuilt module exists
#   NO_HOLD=1        don't put the kernel / firmware packages on hold
set -e
cd "$(dirname "$0")"
K=${KVER:-$(uname -r)}

if [ -f "prebuilt-$K/ssv6051.ko" ] && [ -z "$FORCE_BUILD" ]; then
    echo ">> Using the prebuilt module for $K"
    KO="prebuilt-$K/ssv6051.ko"
else
    echo ">> Building the driver for $K"
    if [ ! -d "/lib/modules/$K/build" ]; then
        apt-get update
        apt-get install -y linux-headers-current-rockchip
    fi
    if [ ! -d "/lib/modules/$K/build" ]; then
        echo "ERROR: kernel headers for $K are missing (/lib/modules/$K/build)." >&2
        echo "Install the linux-headers package that exactly matches the kernel." >&2
        exit 1
    fi
    command -v make >/dev/null && command -v gcc >/dev/null || apt-get install -y build-essential
    (cd 6051-src && make clean >/dev/null 2>&1 || true)
    (cd 6051-src && make KVERS_UNAME="$K" -j"$(nproc)")
    KO="6051-src/ssv6051.ko"
fi

# a module in updates/ takes priority over the in-kernel ssv6051 driver
mkdir -p "/lib/modules/$K/updates"
install -m 644 "$KO" "/lib/modules/$K/updates/ssv6051.ko"

# keep the original Armbian files once
for f in ssv6051-wifi.cfg ssv6051-sw.bin; do
    if [ -f "/lib/firmware/$f" ] && [ ! -f "/lib/firmware/$f.orig" ]; then
        cp "/lib/firmware/$f" "/lib/firmware/$f.orig"
    fi
done
install -m 644 firmware/ssv6051-wifi.cfg firmware/ssv6051-sw.bin /lib/firmware/

depmod -a "$K"
update-initramfs -u -k "$K" >/dev/null 2>&1 || true

if [ -z "$NO_HOLD" ]; then
    # a kernel update would break the module, a firmware update would overwrite the config
    apt-mark hold linux-image-current-rockchip linux-dtb-current-rockchip \
                  linux-headers-current-rockchip armbian-firmware 2>/dev/null || true
fi

echo ">> Done. Driver installed: /lib/modules/$K/updates/ssv6051.ko"
echo ">> Reboot, or run: modprobe -r ssv6051; modprobe ssv6051"

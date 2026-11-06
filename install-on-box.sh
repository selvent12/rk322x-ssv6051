#!/bin/bash
# Instaleaza driverul WiFi SSV6051 (eloirotava/6051) pe un box rk322x cu Armbian.
# Utilizare (ca root, din folderul rk322x-ssv6051):  sudo bash install-on-box.sh
#
# Variabile optionale:
#   KVER=<versiune>   kernelul pentru care se instaleaza (implicit: kernelul care ruleaza)
#   FORCE_BUILD=1     compileaza din sursa chiar daca exista modul precompilat
#   NO_HOLD=1         nu pune pe hold pachetele kernel / firmware
set -e
cd "$(dirname "$0")"
K=${KVER:-$(uname -r)}

if [ -f "prebuilt-$K/ssv6051.ko" ] && [ -z "$FORCE_BUILD" ]; then
    echo ">> Folosesc modulul precompilat pentru $K"
    KO="prebuilt-$K/ssv6051.ko"
else
    echo ">> Compilez driverul pentru $K"
    if [ ! -d "/lib/modules/$K/build" ]; then
        apt-get update
        apt-get install -y linux-headers-current-rockchip
    fi
    if [ ! -d "/lib/modules/$K/build" ]; then
        echo "EROARE: lipsesc headerele pentru $K (/lib/modules/$K/build)." >&2
        echo "Instaleaza pachetul linux-headers care corespunde exact kernelului." >&2
        exit 1
    fi
    command -v make >/dev/null && command -v gcc >/dev/null || apt-get install -y build-essential
    (cd 6051-src && make clean >/dev/null 2>&1 || true)
    (cd 6051-src && make KVERS_UNAME="$K" -j"$(nproc)")
    KO="6051-src/ssv6051.ko"
fi

# modulul din updates/ are prioritate fata de driverul ssv6051 din kernel
mkdir -p "/lib/modules/$K/updates"
install -m 644 "$KO" "/lib/modules/$K/updates/ssv6051.ko"

# pastram o singura data configul original Armbian
for f in ssv6051-wifi.cfg ssv6051-sw.bin; do
    if [ -f "/lib/firmware/$f" ] && [ ! -f "/lib/firmware/$f.orig" ]; then
        cp "/lib/firmware/$f" "/lib/firmware/$f.orig"
    fi
done
install -m 644 firmware/ssv6051-wifi.cfg firmware/ssv6051-sw.bin /lib/firmware/

depmod -a "$K"
update-initramfs -u -k "$K" >/dev/null 2>&1 || true

if [ -z "$NO_HOLD" ]; then
    # un update de kernel ar strica modulul, iar unul de firmware ar suprascrie configul
    apt-mark hold linux-image-current-rockchip linux-dtb-current-rockchip \
                  linux-headers-current-rockchip armbian-firmware 2>/dev/null || true
fi

echo ">> Gata. Driver instalat: /lib/modules/$K/updates/ssv6051.ko"
echo ">> Reporneste box-ul sau: modprobe -r ssv6051; modprobe ssv6051"

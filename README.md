# SSV6051 WiFi driver for rk322x TV boxes (Armbian, kernel 6.18)

**English** | [Română](README.ro.md)

On Armbian with kernel 6.18 the in-kernel `ssv6051` driver cannot start the WiFi chip found on
many RK3228/RK3229 TV boxes. `ip link set wlan0 up` fails with `Operation not permitted`, and
`dmesg` shows:

```
SSV WLAN driver ssv6200: Failed to allocate packet buffer of 904 bytes in 0 type.
ERROR!!Please check interface!
SOS!SOS!
SSV WLAN driver ssv6200: Failed to initialize mac, ret=-1
```

This repository packages the community-maintained driver
[eloirotava/6051](https://github.com/eloirotava/6051), which works on RK3229 with kernel 6.18,
together with install scripts.

**Tested on:** generic rk322x box (SSV6051P, SDIO ID `3030:3030`, chip `SSV6200A0`),
Armbian 26.8.3 (Ubuntu noble), kernel `6.18.44-current-rockchip`.
Result: firmware loads, calibration succeeds, scanning and WPA2 work, no errors under traffic.

The in-kernel driver failed the same way with lower SDIO clocks (10, 4 and 1 MHz), with
HT/AMPDU disabled and after reloading the module, so the problem is the driver, not wiring or
signal integrity. The `rk322x-wlan-alt-wiring` overlay does not apply to these boxes, because
the chip already answers on the default SDIO pins.

## Contents

| Path | What it is |
|---|---|
| `6051-src/` | driver source ([eloirotava/6051](https://github.com/eloirotava/6051), commit in `SOURCE_COMMIT.txt`); its config has TX power set to level 2 |
| `prebuilt-6.18.44-current-rockchip/ssv6051.ko` | prebuilt module, **only** for kernel `6.18.44-current-rockchip` |
| `firmware/` | `ssv6051-wifi.cfg` (config used) + `ssv6051-sw.bin` (firmware, identical to Armbian's) |
| `original-armbian/` | the original Armbian config and firmware, to revert |
| `install-on-box.sh` | installs the driver (prebuilt if the kernel matches, otherwise builds it) |
| `armbian-build/userpatches/customize-image.sh` | builds the driver into an image made with armbian/build |

## 1. Install on a box

Copy this folder to the box (`git clone`, or download the ZIP), then:

```bash
cd rk322x-ssv6051
sudo bash install-on-box.sh
sudo reboot
```

If the kernel is not `6.18.44-current-rockchip`, the script installs the kernel headers and
builds the module (needs internet; Ethernet is enough).

The script:
- installs the module to `/lib/modules/<kernel>/updates/`, which takes priority over the
  in-kernel driver (the original driver is left in place);
- copies the config and firmware to `/lib/firmware/`, keeping the originals as `*.orig`;
- puts the kernel packages and `armbian-firmware` **on hold**. A kernel update would break the
  out-of-tree module, and a firmware update would overwrite the config. Use `NO_HOLD=1` to skip.

Options: `KVER=<version>` (target kernel), `FORCE_BUILD=1` (always build from source),
`NO_HOLD=1` (don't hold packages).

## 2. Custom image with armbian/build

```bash
git clone https://github.com/armbian/build
cd build
mkdir -p userpatches/overlay
cp -r /path/to/rk322x-ssv6051 userpatches/overlay/
cp /path/to/rk322x-ssv6051/armbian-build/userpatches/customize-image.sh userpatches/
./compile.sh BOARD=rk322x-box BRANCH=current RELEASE=noble INSTALL_HEADERS=yes \
    BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no
```

`INSTALL_HEADERS=yes` is required: the driver is compiled inside the image, against its kernel.
Compiling in the (emulated) chroot adds a few minutes. *This path has not been tested yet.*

## 3. After a kernel update

```bash
sudo apt-mark unhold linux-image-current-rockchip linux-dtb-current-rockchip \
                     linux-headers-current-rockchip armbian-firmware
sudo apt update && sudo apt full-upgrade
sudo reboot
cd ~/rk322x-ssv6051 && sudo bash install-on-box.sh   # rebuilds for the new kernel
sudo reboot
```

## TX power

In `/lib/firmware/ssv6051-wifi.cfg`:

```
wifi_tx_gain_level_b = 2
wifi_tx_gain_level_gn = 2
```

The scale goes from 1 (highest) to 14 (lowest); 0 = chip default (about level 2). The upstream
config uses 14 to avoid brownouts on weak power supplies. If the box resets or WiFi drops under
traffic, lower the power (e.g. 6 or 10). Changes apply after `modprobe -r ssv6051; modprobe ssv6051`
or a reboot.

## Network configuration

The driver only makes `wlan0` work. Configure the network as usual, e.g. with `armbian-config`,
`nmtui`, or netplan. Note that the default Armbian netplan WiFi entries may target a USB adapter
name (`wlx...`) instead of `wlan0`.

## Revert to the original Armbian driver

```bash
sudo rm /lib/modules/$(uname -r)/updates/ssv6051.ko
sudo cp /lib/firmware/ssv6051-wifi.cfg.orig /lib/firmware/ssv6051-wifi.cfg
sudo depmod -a && sudo update-initramfs -u
sudo apt-mark unhold linux-image-current-rockchip linux-dtb-current-rockchip \
                     linux-headers-current-rockchip armbian-firmware
sudo reboot
```

## Credits and license

- Driver: © South Silicon Valley Microelectronics / iComm Corporation, ported to modern kernels by
  [eloirotava](https://github.com/eloirotava/6051). The source files are licensed under the
  **GNU GPL v3 or later** (see their headers); `MODULE_LICENSE("Dual BSD/GPL")`.
- `ssv6051-sw.bin` is the vendor firmware blob, redistributed as shipped in Armbian's
  `armbian-firmware` package.
- Install scripts and documentation in this repository: GPL-3.0-or-later. See [LICENSE](LICENSE).
- Background: [Armbian forum thread](https://forum.armbian.com/topic/57960-sv6256p-wifi-now-working-on-linux-6x-armbian-tested/).

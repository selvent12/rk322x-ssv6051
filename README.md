# Driver WiFi SSV6051 pentru box rk322x (Armbian, kernel 6.18)

Driverul `ssv6051` inclus în kernelul Armbian 6.18 nu pornește cipul
(`Failed to initialize mac` / `SOS!SOS!`). Aici e driverul refăcut de comunitate
([eloirotava/6051](https://github.com/eloirotava/6051)), care funcționează pe RK3229.

## Conținut

| Folder / fișier | Ce e |
|---|---|
| `6051-src/` | sursa driverului (commit-ul e în `SOURCE_COMMIT.txt`); configul are deja puterea de emisie la nivelul 2 |
| `prebuilt-6.18.44-current-rockchip/ssv6051.ko` | modul compilat, merge **doar** pe kernelul `6.18.44-current-rockchip` |
| `firmware/` | `ssv6051-wifi.cfg` (configul folosit) + `ssv6051-sw.bin` (firmware, identic cu cel Armbian) |
| `original-armbian/` | configul și firmware-ul originale Armbian, pentru revenire |
| `install-on-box.sh` | instalează driverul pe box (precompilat dacă se potrivește kernelul, altfel compilează) |
| `armbian-build/userpatches/customize-image.sh` | include driverul automat într-o imagine construită cu armbian/build |

> Scripturile `.sh` trebuie să rămână cu capete de linie Unix (LF). Dacă le editezi
> pe Windows, setează în editor „LF” (în VS Code, colțul din dreapta jos).

## 1. Reinstalare pe un box (imagine Armbian proaspătă)

Copiază folderul `rk322x-ssv6051` pe box (WinSCP sau `scp -r rk322x-ssv6051 rk322x@IP:`), apoi:

```bash
cd ~/rk322x-ssv6051
sudo bash install-on-box.sh
sudo reboot
```

Dacă kernelul e altul decât 6.18.44, scriptul instalează headerele și compilează singur
(are nevoie de internet; pe Ethernet e suficient).

## 2. Imagine proprie cu armbian/build

```bash
git clone https://github.com/armbian/build
cd build
mkdir -p userpatches/overlay
cp -r /cale/rk322x-ssv6051 userpatches/overlay/
cp /cale/rk322x-ssv6051/armbian-build/userpatches/customize-image.sh userpatches/
./compile.sh BOARD=rk322x-box BRANCH=current RELEASE=noble INSTALL_HEADERS=yes \
    BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no
```

`INSTALL_HEADERS=yes` e obligatoriu: driverul se compilează în imagine, pe kernelul ei.
Compilarea din chroot (emulat) durează câteva minute în plus.

## 3. După un update de kernel

Scriptul pune pe hold pachetele `linux-image/dtb/headers-current-rockchip` și
`armbian-firmware`. Când vrei totuși update:

```bash
sudo apt-mark unhold linux-image-current-rockchip linux-dtb-current-rockchip \
                     linux-headers-current-rockchip armbian-firmware
sudo apt update && sudo apt full-upgrade
sudo reboot
cd ~/rk322x-ssv6051 && sudo bash install-on-box.sh   # recompilează pentru kernelul nou
sudo reboot
```

## Puterea de emisie

În `/lib/firmware/ssv6051-wifi.cfg`:

```
wifi_tx_gain_level_b = 2
wifi_tx_gain_level_gn = 2
```

Scala e 1 (maximă) … 14 (minimă); 0 = implicit cip (≈ nivel 2). Autorul driverului
a pus 14 ca să evite căderile de tensiune pe surse slabe. Dacă box-ul se resetează sau
WiFi-ul pică sub trafic, coboară puterea (ex. 6 sau 10). Modificarea se aplică la
reîncărcarea driverului (`modprobe -r ssv6051; modprobe ssv6051`) sau la restart.

## Revenire la driverul original Armbian

```bash
sudo rm /lib/modules/$(uname -r)/updates/ssv6051.ko
sudo cp /lib/firmware/ssv6051-wifi.cfg.orig /lib/firmware/ssv6051-wifi.cfg
sudo depmod -a && sudo update-initramfs -u
sudo reboot
```

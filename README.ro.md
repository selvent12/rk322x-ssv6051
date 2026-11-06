# Driver WiFi SSV6051 pentru box-uri TV rk322x (Armbian, kernel 6.18)

[English](README.md) | **Română**

Pe Armbian cu kernel 6.18, driverul `ssv6051` inclus în kernel nu poate porni cipul WiFi de pe
multe box-uri TV RK3228/RK3229. `ip link set wlan0 up` dă eroarea `Operation not permitted`,
iar în `dmesg` apare:

```
SSV WLAN driver ssv6200: Failed to allocate packet buffer of 904 bytes in 0 type.
ERROR!!Please check interface!
SOS!SOS!
SSV WLAN driver ssv6200: Failed to initialize mac, ret=-1
```

Repository-ul conține driverul întreținut de comunitate
[eloirotava/6051](https://github.com/eloirotava/6051), care funcționează pe RK3229 cu kernel 6.18,
plus scripturi de instalare.

**Testat pe:** box rk322x generic (SSV6051P, ID SDIO `3030:3030`, cip `SSV6200A0`),
Armbian 26.8.3 (Ubuntu noble), kernel `6.18.44-current-rockchip`.
Rezultat: firmware-ul se încarcă, calibrarea reușește, scanarea și WPA2 merg, fără erori sub trafic.

Driverul din kernel a eșuat la fel cu frecvențe SDIO mai mici (10, 4 și 1 MHz), cu HT/AMPDU
dezactivat și după reîncărcarea modulului. Deci problema e driverul, nu cablajul sau semnalul.
Overlay-ul `rk322x-wlan-alt-wiring` nu se aplică la aceste box-uri, pentru că cipul răspunde
deja pe pinii SDIO impliciți.

## Conținut

| Cale | Ce e |
|---|---|
| `6051-src/` | sursa driverului ([eloirotava/6051](https://github.com/eloirotava/6051), commit-ul e în `SOURCE_COMMIT.txt`); configul are puterea de emisie la nivelul 2 |
| `prebuilt-6.18.44-current-rockchip/ssv6051.ko` | modul compilat, merge **doar** pe kernelul `6.18.44-current-rockchip` |
| `firmware/` | `ssv6051-wifi.cfg` (configul folosit) + `ssv6051-sw.bin` (firmware, identic cu cel din Armbian) |
| `original-armbian/` | configul și firmware-ul originale Armbian, pentru revenire |
| `install-on-box.sh` | instalează driverul (precompilat dacă se potrivește kernelul, altfel îl compilează) |
| `armbian-build/userpatches/customize-image.sh` | include driverul într-o imagine construită cu armbian/build |

## 1. Instalare pe un box

Copiezi folderul pe box (`git clone` sau arhiva ZIP), apoi:

```bash
cd rk322x-ssv6051
sudo bash install-on-box.sh
sudo reboot
```

Dacă kernelul nu e `6.18.44-current-rockchip`, scriptul instalează headerele kernelului și
compilează modulul (are nevoie de internet; pe Ethernet e suficient).

Scriptul:
- pune modulul în `/lib/modules/<kernel>/updates/`, unde are prioritate față de driverul din
  kernel (driverul original rămâne pe loc);
- copiază configul și firmware-ul în `/lib/firmware/`, iar originalele le păstrează ca `*.orig`;
- pune **pe hold** pachetele kernelului și `armbian-firmware`. Un update de kernel ar strica
  modulul, iar unul de firmware ar suprascrie configul. Cu `NO_HOLD=1` sari peste acest pas.

Opțiuni: `KVER=<versiune>` (kernelul țintă), `FORCE_BUILD=1` (compilează mereu din sursă),
`NO_HOLD=1` (nu pune pachetele pe hold).

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
Compilarea în chroot-ul emulat durează câteva minute în plus. *Varianta asta nu e testată încă.*

## 3. După un update de kernel

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

Scala merge de la 1 (maximă) la 14 (minimă); 0 = implicit cip (≈ nivel 2). Configul original
folosește 14, ca să evite căderile de tensiune pe surse slabe. Dacă box-ul se resetează sau
WiFi-ul pică sub trafic, coboară puterea (de ex. 6 sau 10). Modificarea se aplică după
`modprobe -r ssv6051; modprobe ssv6051` sau după restart.

## Configurarea rețelei

Driverul doar face `wlan0` să meargă. Rețeaua o configurezi ca de obicei, de exemplu cu
`armbian-config`, `nmtui` sau netplan. Atenție: intrările WiFi implicite din netplan-ul Armbian
pot fi pentru un adaptor USB (`wlx...`), nu pentru `wlan0`.

## Revenire la driverul original Armbian

```bash
sudo rm /lib/modules/$(uname -r)/updates/ssv6051.ko
sudo cp /lib/firmware/ssv6051-wifi.cfg.orig /lib/firmware/ssv6051-wifi.cfg
sudo depmod -a && sudo update-initramfs -u
sudo apt-mark unhold linux-image-current-rockchip linux-dtb-current-rockchip \
                     linux-headers-current-rockchip armbian-firmware
sudo reboot
```

## Autori și licență

- Driver: © South Silicon Valley Microelectronics / iComm Corporation, portat pe kernelurile noi
  de [eloirotava](https://github.com/eloirotava/6051). Fișierele sursă sunt sub licența
  **GNU GPL v3 sau ulterioară** (vezi antetele lor); `MODULE_LICENSE("Dual BSD/GPL")`.
- `ssv6051-sw.bin` e firmware-ul producătorului, redistribuit așa cum vine în pachetul
  `armbian-firmware` al Armbian.
- Scripturile și documentația din acest repository: GPL-3.0-or-later. Vezi [LICENSE](LICENSE).
- Context: [discuția de pe forumul Armbian](https://forum.armbian.com/topic/57960-sv6256p-wifi-now-working-on-linux-6x-armbian-tested/).

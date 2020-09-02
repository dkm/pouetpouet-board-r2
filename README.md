# PouetPouet

The firmware is [Keyberon](https://github.com/TeXitoi/keyberon), a
pure rust firmware.

## Features

 * 60 keys, using Cherry MX switches, only 1U keycaps;
 * USB-C connector;
 * 1 STM32F072 MCU, with hardware USB DFU bootloader;
 * Only onboard SMD component (except for the switches).

## Inspiration

 * [Keyseebee](https://github.com/TeXitoi/keyseebee) for being the «I will change it quickly and have something ready in an hour» base project (even if I ended up redoing most of the hardware design).
 * [Steamvan](https://github.com/jmdaly/steamvan) for some KiCad design ideas;
 * [help-14](https://github.com/help-14/mechanical-keyboard) for making a nice list of existing keyboard;
 * [Masterzen](http://www.masterzen.fr/2020/05/03/designing-a-keyboard-part-1/) and many others for writing online tutorials for newbies like me.

## Usefull resources
 * [Mechanical Keyboard](https://github.com/help-14/mechanical-keyboard) is a list of DIY keyboards
 * [Awesome Mechanical Keyboard](https://github.com/BenRoe/awesome-mechanical-keyboard) is another [https://github.com/topics/awesome](«awesome») list

## Bill Of Materials

|Item                                                                      |Package|Qty|Remarks                                |Price |
|--------------------------------------------------------------------------|-------|--:|---------------------------------------|-----:|
| PCB                                                                      |       | 3 | aisler                                |      |
| 100 nF                                                                   | 0805  | 5 | magic match aisler                    | 0    |
| PRTR5V0U2X,215                                                           | sot-143| 1 |                                      | 0.43 |
| 4.7 uF                                                                   | 0805  | 2 |                                       | 0    |
| 470 Ohm                                                                  | 0805  | 1 | magic match aisler                    | 0    |
| TLV70233DBVR                                                             | sot-23| 1 | magic match aisler                    | 0.37 |
| 74LVC1G34GW,125                                                          |       | 1 | magic match aisler                    | 0.28 |
| 0805L050WR (500mA Polyfuse)                                              | 0805  | 1 | magic match aisler                    | 1.91 |
| RS282G05A3SMRT (micro switch)                                            |       | 2 | magic match aisler                    | 1.26 |
| 100nF                                                                    | 0805  | 2 | magic match aisler                    | 0 |
| 5.1 kOhm                                                                 | 0805  | 3 | magic match aisler                    | 0 |
| 0805L050WR (500mA Polyfuse)                                              | 0805  | 1 | magic match aisler                    | 0 |
| 1N4148WS-7-F                                                             | sod-323 | 60|                                     |   |
| WS2812B                                                                  |       | 10|                                       |   |
| USB TypeC HRO Receptacle                                                 |       | 1 |                                       |   |
| Gateron Switch                                                           |       | 60|                                       |   |
| Keycaps                                                                  |       | 60|                                       |   |

## Compiling and flashing

Install the complete toolchain and utils:

```shell
curl https://sh.rustup.rs -sSf | sh
rustup target add thumbv6m-none-eabi
rustup component add llvm-tools-preview
cargo install cargo-binutils
sudo apt-get install dfu-util
```

Compile:

```shell
cd firmware
cargo objcopy --bin pouetpouet --release -- -O binary pouetpouet.bin
```

To flash using dfu-util, first put the board in dfu mode by pressing
BOOT, pressing and releasing RESET and releasing BOOT. Then:

```shell
dfu-util -d 0483:df11 -a 0 -s 0x08000000:leave -D pouetpouet.bin
```

The fist time, if the write fail, your flash might be protected. To
unprotect:

```shell
dfu-util -d 0483:df11 -a 0 -s 0x08000000:force:unprotect -D pouetpouet.bin
```

# HD6303EVB
# Hitachi HD63C03YP Evaluation Board

The HD63C03YP is a Hitachi MCU that combines a Motorola MC6803 code compatible processor, with on chip peripherals such as UART, parallel I/O, and hardware timers and counters. The MC6803 is code compatible with the MC6801, so development tools such as an assembler can be used to produce code for it. Also, existing software written for the MC6801/6803 should run on it, with few or no modifications.

The historical background is that Hitachi obtained a licence from Motorola to produce many of the devices in Motorola's 8 bit MCU catalog, which they implemented in an improved CMOS process. Many of the devices are pin compatible drop in replacements for the Motorola parts. But Hitachi also added new parts, and enhanced some of them with both documented and undocumented improvements.

The board consists of a 64 pin DIP HD63C03YP MCU, an 8k EEPROM, an external bus interface, I/O pins, and 64k SRAM. It can be interfaced from the on board serial port, running at 115200 baud and some slower baud rates. More hardware details can be found in the Wiki - https://github.com/KenWillmott/HD6303EVB/wiki.

The project is in the extreme beta stage, at the moment four working boards exist. The first and current board is designated V1.0. Some peripheral boards to plug into the expansion bus connectors, are in development. The Game Board is completed, see https://github.com/KenWillmott/M8-Game-Board/wiki

The provided ROM monitor program Kbug6303, can be written to the 8k EEPROM. Once it is installed, it is possible to perform firmware updates in place, by changing the write protect jumper on the board, and running software to copy the code from RAM to the EEPROM.

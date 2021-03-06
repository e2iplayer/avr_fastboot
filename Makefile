#  This file is part of fastboot, an AVR serial bootloader.
#  Copyright (C) 2010 Heike C. Zimmerer <hcz@hczim.de>
# 
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# 
# Makefile for Peter Dannegger's bootloader, to be used with the GNU
# toolchain (as opposed to Atmel's Assembler).
#


####### user presets ##########################
# adjust the following definitions to match your target:
##############################################

# MCU name
# One of:
# - at90s2313, at90s2323,
#     at90s2333, at90s2343, at90s4414, at90s4433,
#     at90s4434, at90c8534, at90s8535, at86rf401,
#     attiny2313, attiny24, attiny44,
#     attiny84, attiny25, attiny45, attiny85
# - atmega103, atmega603, at43usb320,
#     at43usb355, at76c711
# - atmega48, atmega8, atmega83,
#     atmega85, atmega88, atmega8515, atmega8535, atmega8hva, at90pwm1,
#     at90pwm2, at90pwm3
# - atmega16, atmega161, atmega162,
#     atmega163, atmega164p, atmega165, atmega165p, atmega168,
#     atmega169, atmega169p, atmega32, atmega323, atmega324p, atmega325,
#     atmega325p, atmega329, atmega329p, atmega3250, atmega3250p,
#     atmega3290, atmega3290p, atmega406, atmega64, atmega640,
#     atmega644, atmega644p, atmega128, atmega1280, atmega1281,
#     atmega645, atmega649, atmega6450, atmega6490, atmega16hva,
#     at90can32, at90can64, at90can128, at90usb82, at90usb162,
#     at90usb646, at90usb647, at90usb1286, at90usb1287, at94k
# - atmega2560, atmega2561
# - atmega328, atmega328p
#
# Examples (select one of them or add your own):
# MCU = atmega64
# MCU = attiny85
# MCU = atmega2560
# MCU = atmega1281
MCU ?= attiny2313a

# Name of the Atmel defs file for the actual MCU.
#
# They are part of AVR Studio (located in Windows at
# \Programs\Atmel\AVR Tools\AvrAssembler2\Appnotes\*.inc).
#
# The license agreement of AVR Studio prohibits the distribution of the
# .inc files you need. You therefore have to download the whole AVR Studio
# suite (several hundred MB, need to register at atmel.com) and install it
# on a Windows system (getting version 6 to run under wine seems not to be
# trivial) to get these files. You can try searching on the web, but
# hostings of these files tend to disappear regularly.
#
# Examples (select one of them or add your own):
# ATMEL_INC = m168def.inc
# ATMEL_INC=m64def.inc
# ATMEL_INC=tn85def.inc
# ATMEL_INC = m2560def.inc
# ATMEL_INC = m1281def.inc
# ATMEL_INC = m8def.inc
ATMEL_INC ?= tn2313Adef.inc

# Processor frequency.  The value is not critical:
#F_CPU = 14745600
F_CPU = 8000000

# Boot dealy. How many cycles after boot to wait for bootload request
# In seconds: Boot_Delay/F_CPU
Boot_Delay = 2000000

#     AVR Studio 4.10 requires dwarf-2.
#     gdb runs better with stabs
#DEBUG = dwarf-2
DEBUG = stabs+

# Define the Tx and Rx lines here.  Set both groups to the same for
# one wire mode:
STX_PORT = PORTD
STX = PD1

SRX_PORT = PORTD
SRX = PD0

####### End user presets ######################

SHELL=/bin/bash

CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) 
CFLAGS += -I . -I ./added -I ./converted -I/usr/local/avr/include 
CFLAGS += -ffreestanding
CFLAGS += -g$(DEBUG)
CFLAGS += -L,-g$(DEBUG)
CFLAGS += -DRAM_START=$(SRAM_START) -DSRAM_SIZE=$(SRAM_SIZE)
CFLAGS += -DSTX_PORT=$(STX_PORT) -DSTX=$(STX)
CFLAGS += -DSRX_PORT=$(SRX_PORT) -DSRX=$(SRX)
CFLAGS += -DBootDelay=$(Boot_Delay) -DBOOTDELAY=$(Boot_Delay)

# The following files were imported by a gawk script without user
# intervention (in order to ease keeping up with future releases of
# the original bootloader):
AUTO_CONVERTED_FILES = \
  converted/progtiny.inc \
  converted/uart.inc \
  converted/password.inc \
  converted/progmega.inc \
  converted/watchdog.inc \
  converted/bootload.asm \
  converted/abaud.inc \
  converted/command.inc \
  converted/protocol.h \
  converted/apicall.inc \
  converted/verify.inc \
  converted/message.inc

# The following files must be worked on manually:
MANUALLY_ADDED_FILES = \
  added/fastload.inc \
  added/fastload.h \
  added/mangled_case.h \
  added/bootload.S \
  added/compat.h \
  added/fastload.h

ADDITIONAL_DEPENDENCIES = atmel_def.h

ASMSRC = $(AUTO_CONVERTED_FILES) $(MANUALLY_ADDED_FILES)

include atmel_def.mak

ifdef BOOTRST
STUB_OFFSET = 510 
LOADER_START = ( $(FLASHEND) * 2 ) - 510
endif

all: bootload.hex

bootload.hex: bootload.elf

bootload.elf : bootload.o stub.o
ifndef BOOTRST
	vars="$$(./get_text_addrs.sh $(FLASHEND))"; \
	arch="$$(./get_avr_arch.sh -mmcu=$(MCU) bootload.o)"; \
	echo "arch=$$arch";\
	echo "$$vars"; \
	eval "$$vars"; \
	sed -e "s/@LOADER_START@/$$LOADER_START/g" \
	    -e s"/@ARCH@/$$arch/" \
	    -e s'/@RAM_START@/$(SRAM_START)/g' \
	    -e s'/@RAM_SIZE@/$(SRAM_SIZE)/g' \
	    -e "s/@STUB_OFFSET@/$$STUB_OFFSET/g" \
	    bootload.template.x > bootload.x; \
	avr-ld -N -E -T bootload.x -Map=$(patsubst %.elf,%,$@).map \
	  --cref $+ -o $@ --defsym Application="$$LOADER_START-2"
else
	vars="$$(./get_bootsection_addrs.sh $(FLASHEND) $(FIRSTBOOTSTART) \
                $(SECONDBOOTSTART) $(THIRDBOOTSTART) $(FORTHBOOTSTART))"; \
	arch="$$(./get_avr_arch.sh -mmcu=$(MCU) bootload.o)"; \
	echo "arch=$$arch";\
	echo "$$vars"; \
	eval "$$vars"; \
	sed -e "s/@LOADER_START@/$$LOADER_START/g" \
	    -e s"/@ARCH@/$$arch/" \
	    -e s'/@RAM_START@/$(SRAM_START)/g' \
	    -e s'/@RAM_SIZE@/$(SRAM_SIZE)/g' \
	    -e "s/@STUB_OFFSET@/$$STUB_OFFSET/g" \
	    bootload.template.x > bootload.x; \
	avr-ld -N -E -T bootload.x -Map=$(patsubst %.elf,%,$@).map \
	  --cref $+ -o $@ --defsym Application=0
endif

atmel_def.h: $(ATMEL_INC) Makefile
#        We use gawk instead of egrep here due to problems with
#        WinAVR's egrep (which I didn't dive into):
	./conv.awk $< | gawk '/PAGESIZE|SIGNATURE_|SRAM_|FLASHEND|BOOT/' > $@

atmel_def.mak: atmel_def.h
	gawk '{ printf "%s = %s\n", $$2, $$3 }' $< > $@


bootload.o: $(ASMSRC) $(ADDITIONAL_DEPENDENCIES)
	avr-gcc -c -Wa,-adhlns=bootload.lst $(CFLAGS) added/bootload.S -o $@

stub.o: added/stub.S
	avr-gcc -c -Wa,-adhlns=stub.lst $(CFLAGS) $< -o $@

%.hex: %.elf
	# avr-objcopy might put a 0x03 record type into the resulting ihex
	# file. Atmel Studio and other Windows tools might not like this.
	# We'll simply delete it :)
	avr-objcopy -O ihex $< /dev/stdout | grep -v :04000003 > $@

.PHONY: clean dbg

clean: 
	rm -f atmel_def.h bootload.x *.defs *.o *.gas *.mak *.lst *.02x *.map

###
# generate a dump of the definitions available to the assembler
# (bootload.defs, (sorted) bootload.sdefs) and the result of
# preprocessing the asm files (bootload.gas) for debugging:
dbg:
	avr-cpp $(CFLAGS) -dD -E added/bootload.S > bootload.defs
	sort bootload.defs | gawk '/^#define/' > bootload.sdefs
	avr-gcc -E $(CFLAGS) added/bootload.S -o bootload.gas



###
# For testing purposes (binary comparison of the output with Atmel
# ASM's output) a binary image gets generated and compared against
# Atmel's output in BOOTLOAD.hex.
#
# Use AVR Studio (or wine or the like) to generate the BOOTLOAD.hex
# file from the original sources and put it into the current
# (resident-gnu/) directory.  The output must be called 'BOOTLOAD.hex"
# (case matters).  Then run 'make cmp'.  You'll get a listing which
# depicts the differences.
#
# We convert the two files into raw binaries, change them into text
# (two bytes (4 chars) per line) using hexdump, then run the result
# through diff, and finally add address information (taken from the
# line number, displaying word addresses in (), byte addresses
# without).
#
# Remove the -c option to 'get_text_addrs.sh' (above) for full
# compatibility with the original bootloader at tiny devices. -c
# packs the code as tight as possible to the end of the flash, making
# a few more bytes available to the user (which the original doesn't).

cmp:  BOOTLOAD.02x bootload.02x
	@if ! diff -q $?; then \
	  echo "Files differ" ; \
	  diff $? \
	  | ./diff2addr.sh ;\
	  echo "'<' means original data (avrasm), '>' new (gcc), '()' word address."; \
	  exit 1; \
	else \
	  echo "Files match. OK."; \
	fi

%.bin: %.hex
	avr-objcopy -I ihex -O binary $< $@

%.02x: %.bin
	hexdump -e '1/2 "%04x" "\n"' $< > $@


### 
# Create distribution .tar.gz
#
DISTFILES = $(AUTO_CONVERTED_FILES) $(MANUALLY_ADDED_FILES)
DISTFILES += $(ADDITIONAL_DEPENDENCIES)
DISTFILES += bootload.template.x diff2addr.sh README Makefile conv.awk build_no
DISTFILES += get_text_addrs.sh get_bootsection_addrs.sh added/stub.S
DISTFILES += get_avr_arch.sh

dist:
	tar --directory .. -czf \
	fastboot_build$(shell \
	  build_no=$$(($$(cat build_no 2>/dev/null)+1)); \
	  echo $$build_no | tee build_no).tar.gz \
	$(patsubst %, fastboot/%, $(DISTFILES))
	echo "build$$(< build_no) - $$(date -Isec) ($${USER:-unknown})" >> build_no-timestamps

### Debug
bincmp: 
	objcopy -I ihex -O binary bootload.hex bootload.bin
	cmp BOOTLOAD.bin bootload.bin

checkdist:
	rm -rf fastboot.test
	set -- fastboot_build*.tar.gz; \
	tar xvzf $$_ 
	mv fastboot fastboot.test
	cd fastboot.test; \
	cp ../m168def.inc .; \
	make


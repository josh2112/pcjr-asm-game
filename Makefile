#
# Makefile for PCjr ASM Game project
#
ifeq ($(OS),Windows_NT)
	NASM="$(USERPROFILE)\AppData\Local\bin\NASM\nasm"
	DOSBOX="..\pcjr-asm-game-tools\tools\EmuCR-Dosbox-r4059\dosbox.exe"
	RM=cmd \/C del
else
	RM=rm
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		DOSBOX=/Applications/DOSBox-0.74-3.app/Contents/MacOS/DOSBox
		NASM=/usr/local/bin/nasm
	else # assume Linux
		DOSBOX=DISPLAY=:0 dosbox
		NASM=nasm
	endif
endif

TARGET=fosquest
TARGET.COM=$(TARGET).com

MACROS=std/stdio.mac
SRCS=std/stdlib.asm std/320x200x16.asm std/stdio.asm input.asm renderer.asm
DEPS=$(MACROS) $(SRCS)

NASM_OPTS=-f bin -l $(TARGET).lst
DOSBOX_OPTS=-conf "../pcjr-asm-game-tools/dosbox.conf"

$(TARGET.COM): $(TARGET).asm $(DEPS)
	$(NASM) $(NASM_OPTS) -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) $^

debug: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) -c "mount c: ." -c "mount d: ../pcjr-asm-game-tools" -c "d:\debug\debug.com c:\$(TARGET).com"

clean:
	$(RM) $(TARGET.COM)

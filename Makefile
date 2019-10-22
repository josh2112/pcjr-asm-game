#
# Makefile for PCjr ASM Game project
#
ifeq ($(OS),Windows_NT)
	NASM="$(USERPROFILE)\AppData\Local\bin\NASM\nasm"
    DOSBOX="..\pcjr-asm-game-tools\tools\EmuCR-Dosbox-r4059\dosbox"
	#DOSBOX="D:\Program Files (x86)\DOSBox-0.74-3\dosbox"
	#DOSBOX="D:\jf334\Documents\Projects\asm-8088\dosbox-svn\dosbox\visualc_net\Release\dosbox"
	RM=cmd \/C del
else
	NASM=nasm
	RM=rm
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		DOSBOX=/Applications/DOSBox-0.74-3.app/Contents/MacOS/DOSBox
	else # assume Linux
		DOSBOX=DISPLAY=:0 dosbox
	endif
endif

TARGET=test
TARGET.COM=$(TARGET).com

MACROS=std/stdio.mac
SRCS=std/stdlib.asm std/320x200x16.asm std/stdio.asm input.asm
DEPS=$(MACROS) $(SRCS)

NASM_OPTS=-f bin -l $(TARGET).lst
DOSBOX_OPTS=-conf "..\pcjr-asm-game-tools\dosbox.conf"

$(TARGET.COM): $(TARGET).asm $(DEPS)
	$(NASM) $(NASM_OPTS) -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) $^

debug: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) -c "mount c: ." -c "mount d: ../pcjr-asm-game-tools" -c "d:\debug\debug.com c:\test.com"

clean:
	$(RM) $(TARGET.COM)

#
# Makefile for PCjr ASM Game project
#
ifeq ($(OS),Windows_NT)
	NASM="$(USERPROFILE)\AppData\Local\bin\NASM\nasm"
	DOSBOX="D:\Program Files (x86)\DOSBox-0.74-3\dosbox"
	RM=cmd \/C del
else
	RM=rm
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		DOSBOX=/Applications/DOSBoxSVN.app/Contents/MacOS/DOSBox
		NASM=/usr/local/bin/nasm
	else # assume Linux
		DOSBOX=DISPLAY=:0 dosbox
		NASM=nasm
	endif
endif

TARGET=pagereg
TARGET.COM=$(TARGET).com

MACROS=..\std\stdio.mac
SRCS=..\std\stdlib.asm
DEPS= $(MACROS) $(SRCS)

NASM_OPTS=-f bin
DOSBOX_OPTS=-conf ../dosbox.conf

$(TARGET.COM): $(TARGET).asm $(DEPS)
	$(NASM) $(NASM_OPTS) -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) $^

debug: $(TARGET.COM)
	$(DOSBOX_DBG) $(DOSBOX_OPTS) $^

clean:
	$(RM) $(TARGET.COM)

#
# Makefile for PCjr ASM Game project
#
ifeq ($(OS),Windows_NT)
	NASM="$(USERPROFILE)\AppData\Local\NASM\nasm"
	DOSBOX="$(ProgramFiles)\DOSBox-0.74\dosbox"
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
SRCS=std/stdlib.asm std/320x200x16.asm std/video.asm input.asm
DEPS=$(MACROS) $(SRCS)

NASM_OPTS=-f bin -l $(TARGET).lst
DOSBOX_OPTS=-conf dosbox.conf

$(TARGET.COM): $(TARGET).asm $(DEPS)
	$(NASM) $(NASM_OPTS) -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) $^

clean:
	$(RM) $(TARGET.COM)

#
# Makefile for PCjr ASM Game project
#
NASM="$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe"
DOSBOX="..\pcjr-asm-game-tools\dosbox\dosbox.exe"
RM=cmd \/C del

TARGET=fosquest
TARGET.COM=$(TARGET).com

MACROS=std/stdio.mac
SRCS=std/stdlib.asm std/320x200x16.asm std/stdio.asm input.asm renderer.asm
DEPS=$(MACROS) $(SRCS)

NASM_OPTS=-f bin -l $(TARGET).lst
DOSBOX_OPTS=-conf "..\pcjr-asm-game-tools\pcjr.dosbox.conf"

$(TARGET.COM): $(TARGET).asm $(DEPS)
	$(NASM) $(NASM_OPTS) -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) $^

debug: $(TARGET.COM)
	$(DOSBOX) $(DOSBOX_OPTS) -c "mount c: ." -c "mount d: ../pcjr-asm-game-tools" -c "d:\debug\debug.com c:\$(TARGET).com"

clean:
	$(RM) $(TARGET.COM)

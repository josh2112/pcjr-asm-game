#
# Makefile for PCjr ASM Game project
#
NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=..\pcjr-asm-game-tools\dosbox\dosbox.exe
RM=cmd \/C del

DOSBOX_CONF=..\pcjr-asm-game-tools\pcjr.dosbox.conf

IMGTOOLS=set PYTHONPATH=..\pcjr-asm-game-tools && uv run -m imgtools

TARGET=fosquest
TARGET.COM=$(TARGET).com

MACROS=std/stdio.mac
SRCS=$(TARGET).asm std/stdlib.asm std/320x200x16.asm std/stdio.asm input.asm renderer.asm
DEPS=$(MACROS) $(SRCS)

IMG_PLAYER=assets\icon\player.bin
IMG_ROOM1=room1.bin

ASSETS=$(IMG_PLAYER) $(IMG_ROOM1)

$(TARGET.COM): $(DEPS) $(ASSETS)
	$(NASM) -f bin -l $(TARGET).lst -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $^

debug: $(TARGET.COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: ." -c "mount d: ../pcjr-asm-game-tools" -c "d:\tools\debug.com c:\$^"


$(IMG_PLAYER): assets\icon\player.png
	cmd \/C "$(IMGTOOLS) packicon -fo $@ $<"

$(IMG_ROOM1): assets\room1\room1-color.png assets\room1\room1-depth.png
	cmd \/C "$(IMGTOOLS) pack -fo $@ -c $(word 1,$^) -d $(word 2,$^)"

clean:
	$(RM) $(TARGET.COM) $(ASSETS)
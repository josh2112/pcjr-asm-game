#
# Makefile for PCjr ASM Game project
#
NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=..\pcjr-asm-game-tools\dosbox\dosbox.exe
DOSBOX_DBG=..\pcjr-asm-game-tools\dosbox\dosbox_with_debugger.exe

RM=cmd \/C del

DOSBOX_CONF=..\pcjr-asm-game-tools\pcjr.dosbox.conf

IMGTOOLS=set PYTHONPATH=..\pcjr-asm-game-tools && uv run -m imgtools

TARGET=fosquest
TARGET.COM=$(TARGET).com

DEPS=std/stdio.mac.asm std/stdlib.asm std/320x200x16.asm std/stdio.asm input.asm renderer.asm inspect.asm

IMG_PLAYER=assets\icon\player.bin
IMG_ROOM1=room1.bin

ASSETS=$(IMG_PLAYER) $(IMG_ROOM1)

$(TARGET.COM): $(TARGET).asm $(DEPS) $(ASSETS)
	$(NASM) -f bin -l $(TARGET).lst -o $@ $<

run: $(TARGET.COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET.COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: ." -c "c:" -c "debug $^"


$(IMG_PLAYER): assets\icon\player.png
	cmd \/C "$(IMGTOOLS) packicon -fo $@ $<"

$(IMG_ROOM1): assets\room1\room1-color.png assets\room1\room1-depth.png
	cmd \/C "$(IMGTOOLS) pack -fo $@ -c $(word 1,$^) -d $(word 2,$^)"

clean:
	$(RM) $(TARGET.COM) $(ASSETS)
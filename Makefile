#
# Makefile for PCjr ASM Game project
#
SHELL := cmd.exe

TOOLS=..\tools

NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=$(TOOLS)\dosbox\dosbox.exe
DOSBOX_DBG=$(TOOLS)\dosbox\dosbox_with_debugger.exe

DOSBOX_CONF=$(TOOLS)\pcjr.dosbox.conf

SRC_DIR=src
BUILD_DIR=bin
ASSETS_DIR=assets

TARGET=fosquest
TARGET_COM=$(BUILD_DIR)\$(TARGET).com
TARGET_LST=$(TARGET_COM:.com=.lst)

SRC_MAIN=$(SRC_DIR)\main.asm
DEPS=$(TARGET).dep

IMG_ROOM1=$(ASSETS_DIR)\room1.bin

$(TARGET_COM): $(DEPS) $(IMG_ROOM1)
	if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) -f bin -l $(TARGET_LST) -I $(SRC_DIR) -o $@ $(SRC_MAIN)
	copy $(ASSETS_DIR)\*.bin $(BUILD_DIR)

$(IMG_ROOM1): $(ASSETS_DIR)\room1\room1-color.png $(ASSETS_DIR)\room1\room1-depth.png
	uv --directory process-room run -m process-room $(CURDIR)\$(word 1,$^) $(CURDIR)\$(word 2,$^) $(CURDIR)\$@

run: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET_COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:" -c "debug $(TARGET).com"

cmd: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:"

clean:
	del /Q $(BUILD_DIR)\*.* $(DISKIMG_DIR)\*.* $(TARGET_LST) $(DEPS)

$(DEPS):
	$(NASM) -M -MF $(DEPS) -MT $(TARGET_COM) -I $(SRC_DIR) $(SRC_MAIN)

	
-include $(DEPS)
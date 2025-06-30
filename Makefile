SHELL := cmd.exe

TOOLS=..\tools

NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=$(TOOLS)\dosbox\dosbox.exe
DOSBOX_DBG=$(TOOLS)\dosbox\dosbox_with_debugger.exe

DOSBOX_CONF=$(TOOLS)\pcjr.dosbox.conf

SRC_DIR=src
BUILD_DIR=bin
ASSETS_DIR=assets
SOUNDS_DIR=assets/sounds

TARGET=fosquest
TARGET_COM=$(BUILD_DIR)\$(TARGET).com
TARGET_LST=$(TARGET_COM:.com=.lst)

SRC_MAIN=$(SRC_DIR)\main.asm
DEPS=$(TARGET).dep

DISKIMG_DIR=diskimage

$(TARGET_COM): $(DEPS) assets/icon/player.bin $(SOUNDS_DIR)/birdchrp.snd
	if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) -f bin -l $(TARGET_LST) -I $(SRC_DIR) -o $@ $(SRC_MAIN)
	copy $(ASSETS_DIR)\*.vec $(BUILD_DIR)

$(SOUNDS_DIR)/birdchrp.snd: $(SOUNDS_DIR)/birdchrp.mid
	uv --project fosquesttools run fosquesttools\sound.py convert -p 24 $<

run: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET_COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:" -c "debug $(TARGET).com"

debug_debug:
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: ..\tools" -c "c:" -c "debug tools/debug.com"

cmd: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:"

diskimage: $(TARGET_COM)
	if not exist $(DISKIMG_DIR) mkdir $(DISKIMG_DIR)
	copy $(TOOLS)\tools\DEBUG.COM $(DISKIMG_DIR)
	copy $(BUILD_DIR)\*.com $(DISKIMG_DIR)
	copy $(BUILD_DIR)\*.vec $(DISKIMG_DIR)
# If this fails, check
# 1) dev drive is mounted (sudo mount -t drvfs F: /mnt/f),
# 2) makeimg.sh doesn't have CRLF line endings
	wsl -e ../tools/floppyimages/makeimg.sh $(DISKIMG_DIR) -o $(TARGET).img -f
	copy $(TARGET).img f:

clean:
	del /Q $(BUILD_DIR)\*.* $(DISKIMG_DIR)\*.* $(TARGET_LST) $(DEPS)

$(DEPS):
	$(NASM) -M -MF $(DEPS) -MT $(TARGET_COM) -I $(SRC_DIR) $(SRC_MAIN)

	
-include $(DEPS)
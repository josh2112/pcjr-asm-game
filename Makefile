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
TARGET_LST=$(BUILD_DIR)\$(TARGET).lst

SRC_MAIN=$(SRC_DIR)\$(TARGET).asm
DEPS=$(TARGET).dep

DISKIMG_DIR=diskimage

$(TARGET_COM): $(DEPS)
	if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) -f bin -l $(TARGET_LST) -I $(SRC_DIR) -o $@ $(SRC_MAIN)
	copy $(ASSETS_DIR)\room1.bin $(BUILD_DIR)

run: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET_COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:" -c "debug $(TARGET).com"

cmd: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:"

diskimage: $(TARGET_COM)
	if not exist $(DISKIMG_DIR) mkdir $(DISKIMG_DIR)
	copy $(BUILD_DIR)\*.com $(DISKIMG_DIR)
	copy $(BUILD_DIR)\*.bin $(DISKIMG_DIR)
# If this fails, check 1) dev drive is mounted, 2) makeimg.sh doesn't have CRLF line endings
	wsl -e ../pcjr-asm-game-tools/floppyimages/makeimg.sh $(DISKIMG_DIR) -o fosquest.img -f
	copy fosquest.img f:

clean:
	del /Q $(BUILD_DIR)\*.* $(DISKIMG_DIR)\*.* $(TARGET_LST) $(DEPS)

$(DEPS):
	$(NASM) -M -MF $(DEPS) -MT $(TARGET_COM) -I $(SRC_DIR) $(SRC_MAIN)

	
-include $(DEPS)
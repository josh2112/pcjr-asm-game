SHELL := cmd.exe

TOOLS=..\..\tools

NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=$(TOOLS)\dosbox\dosbox.exe
DOSBOX_DBG=$(TOOLS)\dosbox\dosbox_with_debugger.exe

DOSBOX_CONF=$(TOOLS)\pcjr.dosbox.conf

SRC_DIR=src
BUILD_DIR=bin
ASSETS_DIR=assets

TARGET=sound
TARGET_COM=$(BUILD_DIR)\$(TARGET).com
TARGET_LST=$(BUILD_DIR)\$(TARGET).lst

SRC_MAIN=sound.asm
DEPS=$(TARGET).dep

$(TARGET_COM): $(DEPS)
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) -f bin -l $(TARGET_LST) -I $(SRC_DIR) -o $@ $(SRC_MAIN)

run: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET_COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:" -c "debug $(TARGET).com"

cmd: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:"

clean:
	del /Q $(BUILD_DIR)\*.* $(TARGET_LST) $(DEPS)

$(DEPS):
	$(NASM) -M -MF $(DEPS) -MT $(TARGET_COM) -I $(SRC_DIR) $(SRC_MAIN)

	
-include $(DEPS)
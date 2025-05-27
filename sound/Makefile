SHELL := cmd.exe

TOOLS=..\..\tools

NASM=$(USERPROFILE)\AppData\Local\bin\NASM\nasm.exe
DOSBOX=$(TOOLS)\dosbox\dosbox.exe
DOSBOX_DBG=$(TOOLS)\dosbox\dosbox_with_debugger.exe

DOSBOX_CONF=$(TOOLS)\pcjr.dosbox.conf

BUILD_DIR=bin

TARGET=sound
TARGET_COM=$(BUILD_DIR)\$(TARGET).com
TARGET_LST=$(TARGET_COM:.com=.lst)

SRC_MAIN=sound.asm
DEPS=$(TARGET).dep

$(TARGET_COM): $(DEPS) birdchrp.snd
	@if not exist $(BUILD_DIR) mkdir $(BUILD_DIR)
	$(NASM) -f bin -l $(TARGET_LST) -o $@ $(SRC_MAIN)

birdchrp.snd: birdchrp.mid
	cd midi2snd && uv run main.py convert -p 24 ..\$<

run: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) $<

debug: $(TARGET_COM)
	$(DOSBOX_DBG) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:" -c "debug $(TARGET).com"

cmd: $(TARGET_COM)
	$(DOSBOX) -conf $(DOSBOX_CONF) -c "mount c: bin" -c "c:"

clean:
	del /Q $(BUILD_DIR)\*.* $(TARGET_LST) $(DEPS)

$(DEPS):
	$(NASM) -M -MF $(DEPS) -MT $(TARGET_COM) $(SRC_MAIN)

include $(DEPS)
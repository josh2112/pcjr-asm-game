@echo
set NASM="C:\Users\jf334.CEM\AppData\Local\bin\NASM\nasm"

set DOSBOX="..\..\pcjr-asm-game-tools\tools\EmuCR-Dosbox-r4059\dosbox"
REM set DOSBOX="D:\Program Files (x86)\DOSBox-0.74-3\dosbox"
REM set DOSBOX="D:\jf334\Documents\Projects\asm-8088\dosbox-svn\dosbox\visualc_net\Release\dosbox"

%NASM% test.asm -l test.lst -o test.com
REM %DOSBOX% -conf "..\..\pcjr-asm-game-tools\dosbox.conf" -c "mount c: ." -c "mount d: ../../pcjr-asm-game-tools" -c "c:" -c "d:\debug\debug.com c:\test.com"
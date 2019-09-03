; Check CPU/CRT page registers
; They're both 6 on DOSBox, which corresponds to memory segment 0x18000 to 0x20000, or the top 32K of 128K memory
; If this holds true for the PCjr, next try writing pixels to 0x18000 instead of 0xb8000

[cpu 8086]
[org 100h]

%include '../std/stdio.mac'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

  originalVideoMode: db 0
  cpuPageReg: db 0
  crtPageReg: db 0

  str_crtPageRegister: db 'CRT page register: $'
  str_cpuPageRegister: db 'CPU page register: $'

  str_pressAnyKey: db 'Press any key to continue', 0dh, 0ah, '$'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH = 0x00 (set video mode), AL = 0x09 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

mov ax, 0x580
int 10h                      ; Call INT 10h fn 580h to get CRT/CPU page registers
mov [crtPageReg], bh
mov [cpuPageReg], bl

print str_crtPageRegister
byteToString buf16, [crtPageReg]
println buf16

print str_cpuPageRegister
byteToString buf16, [cpuPageReg]
println buf16

;mov ax, 0x0582               ; AH = 0x05 (CPU/CRT page registers), AL = 0x82 (set CRT page register)
;mov bx, 0x0600               ; BH = Page 6, matching our FRAMEBUFFER_SEG
;int 10h                      ; Call INT10h fn 0x05 to set CRT page register to 6

; Print 'Press any key to continue'
println str_pressAnyKey
; Call INT21h fn 8 (character input without echo) to wait for a keypress
waitForAnyKey

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 4c00h
int 21h

%include '../std/stdlib.asm'
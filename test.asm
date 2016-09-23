; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'stdio.mac'
%include 'graphics.mac'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

str_crlf: db `\r\n$`

section .bss

originalVideoMode: resb 1
buf16: resb 16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

mov dl, 1
call cls

;mov cx, 16
;rotateColors:
;  mov dl, 16
;  sub dl, cl
;  push cx
;  call cls
;  pop cx
;  loop rotateColors

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include 'formatting.asm'
%include '320x200x16.asm'

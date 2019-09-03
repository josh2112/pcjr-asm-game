; Should see "original video mode 3, new video mode 9" with a green pixel in the top-left corner
;

[cpu 8086]
[org 100h]

jmp main

%include 'formatting.asm'
%include 'stdio.mac'

main:

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

; Format originalVideoMode to a string and print it. Nothing new here!
print str_orgVideoMode
byteToString [originalVideoMode]
println buf16

; Do the same thing with the new video mode (9).
print str_newVideoMode
wordToString 9
println buf16

; Print 'Press any key to continue'
println str_pressAnyKey

; Make the first 2 pixels green (write 0xaa to mem 0xb800)
mov ax, 0xb800
mov es, ax
xor si, si
mov byte [es:si], 0xaa

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

section .data

str_orgVideoMode: db 'Original video mode: $'
str_newVideoMode: db 'New video mode: $'
str_pressAnyKey: db 'Press any key to continue', 0dh, 0ah, '$'
str_crlf: db 0dh, 0ah, '$'

section .bss

originalVideoMode: resb 1
buf16: resb 16

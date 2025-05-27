%ifndef TIMER_ASM
%define TIMER_ASM

section .data

    orig_int08: dd 0
    orig_int08_countdown: db 4

section .text

; Take over int 8 (system timer tick handler) 
hook_int8:
    mov ax, 3508h  ; Get address (35) of system timer interrupt (08) into ES:BX
    int 21h
    mov [orig_int08], bx
    mov [orig_int08+2], es
    mov ax, cs
    mov ds, ax
    mov dx, on_timer
    mov ax, 2508h  ; Set address (25) of timer interrupt (08) from DS:DX
    int 21h

; Restore original int 8 handler
restore_int8:
    mov dx, [orig_int08]
    mov ds, [orig_int08+2]
    mov ax, 2508h ; Set address (25) of timer interrupt (08) from DS:DX
    int 21h

; 00 = channel 0, 11 = write LSB+MSB, 011 = mode 3, 0 = binary counter
cli
mov al, 00_11_011_0b
out 43h, al
mov ax, 4000h
out 40h, al  ; Write 0 (LSB of 4000h)
jmp $+2
xchg ah, al
out 40h, al  ; Write 40h (MSB of 4000h)
sti

%endif ; TIMER_ASM
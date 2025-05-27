%ifndef TIMER_ASM
%define TIMER_ASM

section .text

; Reprograms the 8253's timer 0 to a custom frequency
; ah: timer num, bx: frequency multiplier (where 0ffffh is 1 tick every 54.9255 ms)
set_timer_frequency:
    ; 00 = channel 0, 11 = write LSB+MSB, 011 = mode 3, 0 = binary counter
    cli
    mov al, ah
    mov cl, 6
    shl al, cl  ; Shift channel to upper 2 bits
    add al, 00_11_011_0b
    out 43h, al
    mov dx, 40h
    add dl, ah
    xchg ax, bx
    out dx, al   ; Write LSB
    jmp $+2      ; "let bus settle" whatever that means
    xchg ah, al
    out dx, al   ; Write MSB
    sti
    ret


%endif ; TIMER_ASM
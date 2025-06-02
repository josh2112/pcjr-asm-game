%ifndef TIMER_ASM
%define TIMER_ASM

section .text

; Reprograms an 8253 timer to a custom frequency
; ah: channel, bx: frequency multiplier (where 0ffffh is 1 tick every 54.925 ms)
set_timer_frequency:
    cli
    mov al, ah
    mov cl, 6
    shl al, cl            ; Shift channel to upper 2 bits
    add al, 00_11_011_0b  ; XX = channel, 11 = write LSB+MSB, 011 = mode 3, 0 = binary counter
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
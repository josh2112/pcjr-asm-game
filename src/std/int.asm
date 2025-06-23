%ifndef INT_ASM
%define INT_ASM

section .text

; Saves the address of an interrupt handler and replaces it with a custom one
; al = int num, si = address to save old handler (4 bytes), dx = address of new handler
hook_interrupt:
    mov ah, 35h
    int 21h      ; Get address (35) of interrupt AL into ES:BX
    mov [si], bx
    mov [si+2], es
    mov di, cs
    push ds
    mov ds, di
    mov ah, 25h 
    int 21h      ; Set address (25) of timer interrupt (08) from DS:DX
    pop ds
    ret

; Restores an original interrupt handler
; al = int num, si = address of old handler (4 bytes)
unhook_interrupt:
    push ds
    lds dx, [si] ; ds:dx = si+2:si
    mov bx, ds
    or bx, dx    ; Make sure neither are zero
    jz .end
    mov ah, 25h
    int 21h      ; Set address (25) of timer interrupt (08) from DS:DX
    .end:
    pop ds
    ret
    
%endif ; INT_ASM
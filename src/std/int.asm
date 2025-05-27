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
    mov ds, di
    mov ah, 25h 
    int 21h      ; Set address (25) of timer interrupt (08) from DS:DX
    ret

; Restores an original interrupt handler
; al = int num, si = address of old handler (4 bytes)
unhook_interrupt:
    ; Restore original int 8 handler
    mov dx, [si]
    mov ds, [si+2]
    mov ah, 25 
    int 21h      ; Set address (25) of timer interrupt (08) from DS:DX
    ret
    
%endif ; INT_ASM
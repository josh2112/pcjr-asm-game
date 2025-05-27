[cpu 8086]
[org 100h]

section .data
    sound_1: incbin "birdchrp.snd"
    
    sound_ptr: dw 0
    sound_loop: db 1
    next_sound_counter: dw 0

    orig_int08: dd 0
    orig_int08_countdown: db 4

section .text

mov al, 08h
mov si, orig_int08
mov dx, on_timer
call hook_interrupt  ; Replace int 8 with on_timer

xor ah, ah
mov bx, 4000h
call set_timer_frequency ; Make 8253 timer 0 tick 4x as fast

in al, 61h
xor al, 60h
out 61h, al   ; Select CSG as sound source (bits 5 & 6)

mov ax, sound_1
mov [sound_ptr], ax

game_loop:
    mov ah, 1     ; Check for keystroke.  If ZF is set, no keystroke.
    int 16h
    jz .continue
    mov ah, 0     ; Get the keystroke. AH = scan code, AL = ASCII char
    int 16h
    cmp ah, 1
    je end
    .continue:

    call handle_sound

    jmp game_loop

end:

xor ah, ah
xor bx, bx
call set_timer_frequency ; Restore original timer frequency

mov si, orig_int08
call unhook_interrupt     ; Restore original int 8 handler

; Exit the program
mov ax, 4c00h
int 21h

handle_sound:
    cmp word [sound_ptr], 0   ; If no sound is being processed, do nothing
    jz .end
    cmp word [next_sound_counter], 0 ; If we're not waiting, parse next sound instruction
    ja .end
    
    .parse:
    mov si, cs
    mov ds, si
    mov si, [sound_ptr]
    lodsb

    cmp al, 'F'
    jne .test_w
    
    call sound_setfreq
    mov [sound_ptr], si
    jmp .end

    .test_w:
    cmp al, 'W'
    jne .test_v

    lodsw
    mov [next_sound_counter], ax
    mov [sound_ptr], si
    jmp .end

    .test_v:
    cmp al, 'V'
    jne .eof

    call sound_setvol
    mov [sound_ptr], si
    jmp .end

    .eof:
    cmp byte [sound_loop], 0
    jz .end
    mov ax, sound_1
    mov [sound_ptr], ax
    
    .end:
    ret

sound_setfreq: ; ds:si = channel, ds:si[1-2] = 10-bit frequency
    lodsb
    mov cl, 5
    shl al, cl
    xchg al, bl ; channel in BL

    lodsw
    mov bh, al
    and bh, 0xf ; freq LSN in BH
    
    mov cx, 4
    shr ax, cl
    xchg ax, cx  ; freq MSN (actually 6 bits) in CL

    mov al, bl
    or al, bh
    or al, 0b1_000_0000 ; 1, XX (channel), 0 (change freq), bh (low nibble of freq)
    out 0c0h, al
    mov al, cl
    out 0c0h, al        ; high 6 bits of freq
    ret

sound_setvol: ; ds:si=channel, ds:si[1] = atten
    lodsb
    mov cl, 5
    shl al, cl
    xchg al, ah ; channel in AH

    lodsb       ; atten in AL
    
    or al, ah
    or al, 0b1_001_0000 ; 1, XX (channel), 1 (change atten), al (vol)
    out 0c0h, al
    ret


on_timer:
    cmp word [cs:next_sound_counter], 0 ; Decrement sound counter if nonzero
    jz .next
    dec word [cs:next_sound_counter]
    
    .next:
    dec byte [cs:orig_int08_countdown]  ; Decrement int 8 countdown
    jz .call_orig_int08                 ; If that made it 0, call the original int 8
    mov al, 20h
    out 20h, al        ; Acknowledge the interrupt (20h to the 8259 PIC)
    iret

    .call_orig_int08:
    mov byte [cs:orig_int08_countdown], 4 ; Reset the int 8 countdown
    jmp far [cs:orig_int08]               ; and far-jump to the original int 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

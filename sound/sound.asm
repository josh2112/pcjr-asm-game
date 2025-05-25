[cpu 8086]
[org 100h]

section .data
    sound_1:  incbin "amongus.snd"
    
    sound_ptr: dw 0
    last_tick: dw 0, 0
    next_sound_counter: dw 0

    orig_int08: dw 0
    orig_int08_countdown: db 1

section .text

mov ax, 3508h ; Get address (35) of system timer interrupt (08) into ES:BX
int 21h
mov [orig_int08], bx
mov [orig_int08+2], es
mov ax, cs
mov ds, ax
mov dx, on_timer
mov ax, 2508h ; Set address (25) of timer interrupt (1c) from DS:DX
int 21h

in al, 61h     ; TODO: Checkout int 1a, 80?
xor al, 60h    ; turn on bits 5 & 6 to select the CSG
out 61h, al

sub ah, ah
int 1ah        ; Initialize tick count (for timing)
mov [last_tick], dx
mov [last_tick+2], cx

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

; Restore original int 1ch handler
mov dx, [orig_int08]
mov ds, [orig_int08+2]
mov ax, 2508h ; Set address (25) of timer interrupt (08) from DS:DX
int 21h

; Exit the program
mov ax, 4c00h
int 21h

handle_sound:
    cmp byte [sound_ptr], 0   ; If no sound is being processed, do nothing
    jz .end
    cmp word [next_sound_counter], 0 ; If we're not waiting, parse next sound instruction
    jz .parse

    sub ah, ah
    int 1ah      ; Get tick count (for timing)
    cmp [last_tick], dx
    je .end
    ; Tick count has changed, decrement sound counter
    mov [last_tick], dx
    mov [last_tick+2], cx
    dec word [next_sound_counter]
    jmp .end
    
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
    mov byte [sound_ptr], 0
    
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
    push ax
    push bx
    mov ax, 0e00h + '.'
    mov bx, 07h
    int 10h
    pop bx
    pop ax

    ;cmp byte [next_sound_counter], 0
    ;jz .end
    
    ; Decrement the counter
    ;dec byte [next_sound_counter]
    
    dec byte [orig_int08_countdown]
    jz .call_orig_int08
    iret

    .call_orig_int08
    mov byte [orig_int08_countdown], 1
    jmp far [cs:orig_int08]
    ret
%ifndef SOUND_ASM
%define SOUND_ASM

section .data

    sound_ptr: dw 0
    sound_loop: db 1
    next_sound_counter: dw 0

section .text

handle_sound:
    cmp word [sound_ptr], 0   ; If no sound is being processed, do nothing
    jz .end
    cmp word [next_sound_counter], 0 ; If we're not waiting, parse next sound instruction
    ja .end
    
    .parse:
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
    and bh, 0fh ; freq LSN in BH
    
    mov cx, 4
    shr ax, cl
    xchg ax, cx  ; freq MSN (actually 6 bits) in CL

    mov al, bl
    or al, bh
    or al, 1_00_0_0000b ; 1, XX (channel), 0 (change freq), bh (low nibble of freq)
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
    or al, 1_00_1_0000b ; 1, XX (channel), 1 (change atten), al (vol)
    out 0c0h, al
    ret

mute_all:
    mov al, 1_00_1_1111b
    out 0c0h, al         ; Mute channel 0
    mov al, 1_01_1_1111b
    out 0c0h, al         ; Mute channel 1
    mov al, 1_10_1_1111b
    out 0c0h, al
    ret


%endif ; SOUND_ASM
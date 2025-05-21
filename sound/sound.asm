[cpu 8086]
[org 100h]

section .data
    ; 3579540 / (32*freq)
    sound_1: db 'F', 0, 6bh, 'F', 1, 54h, 'F', 2, 47h, 'W', 18, 'V', 0, 0, 'V', 1, 0, 'V', 2, 0, 0
    
    sound_ptr: dw 0
    last_tick: dw 0, 0
    next_sound_counter: db 0

section .text

;in al, 61h     ; TODO: Checkout int 1a, 80?
;xor al, 60h    ; turn on bits 5 & 6 to select the CSG
;out 61h, al

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

; Exit the program
mov ax, 4c00h
int 21h

handle_sound:
    cmp byte [sound_ptr], 0   ; If no sound is being processed, do nothing
    jz .end
    cmp byte [next_sound_counter], 0 ; If we're not waiting, parse next sound instruction
    jz .parse

    sub ah, ah
    int 1ah      ; Get tick count (for timing)
    cmp [last_tick], dx
    je .end
    ; Tick count has changed, decrement sound counter
    mov [last_tick], dx
    mov [last_tick+2], cx
    dec byte [next_sound_counter]
    jmp .end
    
    .parse:
    mov si, cs
    mov ds, si
    mov si, [sound_ptr]
    lodsb

    cmp al, 'F'
    jne .test_w
    
    lodsw
    call sound_setfreq
    mov [sound_ptr], si
    jmp .end

    .test_w:
    cmp al, 'W'
    jne .test_v

    lodsb
    mov [next_sound_counter], al
    mov [sound_ptr], si
    jmp .end

    .test_v:
    cmp al, 'V'
    jne .eof

    lodsw
    call sound_setvol
    mov [sound_ptr], si
    jmp .end

    .eof:
    mov byte [sound_ptr], 0
    
    .end:
    ret

sound_setfreq: ; al = channel, ah = note
    xchg al, ah

    mov cl, 5
    shl ah, cl  ; Shift channel up to bits 6 & 5

    mov dl, al
    mov dh, dl
    and dl, 0xf  ; lsn
    mov cl, 4
    shr dh, cl   ; msn (really shoud be 6 bits!)

    mov al, ah
    or al, dl
    or al, 0b1_000_0000 ; 1, XX (channel), 0 (change freq), dl (low nibble of freq)
    out 0c0h, al
    mov al, dh
    out 0c0h, al        ; high nibble of freq

    mov al, ah
    or al, bh
    or al, 0b1_001_0000 ; 1, XX (channel), 1 (change atten), bh (vol)
    out 0c0h, al
    ret

sound_setvol: ; al = channel, ah = vol
    xchg al, ah

    mov cl, 5
    shl ah, cl  ; Shift channel up to bits 6 & 5

    mov bl, 15
    sub bl, al
    or ah, bl
    xchg al, ah
    or al, 0b1_001_0000 ; 1, XX (channel), 1 (change atten), bh (vol)
    out 0c0h, al
    ret
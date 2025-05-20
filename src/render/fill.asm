
section .text

; fill( x, y ) - combined scan-and-fill span filler
; https://en.wikipedia.org/wiki/Flood_fill
; ES must be set to framebuffer!
; Args: bp+4 = x, bp+5 = y
; Locals: bp-6 = x1, bp-5 = y, bp-4 = x2, bp-3 = dy
fill:
    push bp
    mov bp, sp
    sub sp, 4  ; Make space for locals

    ; x = 79h, y = 91h

    mov dl, [vec_clear_color]

    mov al, [bp+4]    ; x
    mov ah, 1
    push ax
    push word [bp+4]  ; Push( x, y, x, 1 )

    neg ah
    push ax           ; x, -1
    add ah, [bp+5]    ; x, y-1
    push ax  ; Push( x, y-1, x, -1 )

    .while_stack_not_empty:
    pop word [bp-6]
    pop word [bp-4] ; Pop( x1, y, x2, dy )
    mov bl, [bp-6]
    mov [bp+4], bl  ; let x = x1

    mov ah, bl      ; x
    mov al, [bp-5]  ; y
    call calc_pixel_offset
    cmp byte [es:di], dl  ; inside( x, y )
    jne .while_x1_le_x2

    .while_inside_x_minus_1_y:
    ; DI is already set to x, y... just subtract 1 for x-1,y
    dec di

    cmp byte [es:di], dl  ; inside( x-1, y )
    jne .if_x_le_x1

    mov al, [vec_color]
    nibble_to_byte
    mov byte [es:di], al  ; set( x-1, y )

    dec byte [bp+4]  ; x -= 1

    jmp .while_inside_x_minus_1_y

    .if_x_le_x1:
    mov al, [bp-6]
    dec al
    mov ah, [bp-3]
    neg ah
    push ax
    add ah, [bp-5]
    mov al, [bp+4]
    push ax          ; push( x, y-dy, x1-1, -dy)

    .while_x1_le_x2:

    mov ah, [bp-6]
    cmp ah, [bp-4]
    jg .end

    mov al, [bp-5]
    call calc_pixel_offset

    .while_inside_x1_y:

    cmp byte [es:di], dl  ; inside( x1, y )
    jne .if_x1_gt_x

    mov al, [vec_color]
    nibble_to_byte
    stosb                          ; set( x1, y )

    inc byte [bp-6]     ; x1 += 1

    jmp .while_inside_x1_y

    .if_x1_gt_x:
    mov al, [bp-6]
    cmp al, [bp+4]
    jle .if_x1_minus_1_gt_x2

    mov al, [bp-6]
    dec al
    mov ah, [bp-3]
    push ax
    add ah, [bp-5]
    mov al, [bp+4]
    push ax
    push word [bp+4]  ; push( x, y+dy, x1-1, dy)

    .if_x1_minus_1_gt_x2:

    mov al, [bp-6]
    dec al
    cmp al, [bp-4]  ; if x1 - 1 > x2
    jle .x1_equals_x1_plus_1

    mov al, [bp-6]
    dec al           ; x1-1
    mov ah, [bp-3]
    neg ah           ; -dy
    push ax
    add ah, [bp-5]   ; y-dy
    mov al, [bp-4]
    inc al           ; x2+1
    push ax          ; push( x2+1, y-dy, x1-1, -dy)

    .x1_equals_x1_plus_1:

    inc byte [bp-6]  ; x1 += 1

    .while_x1_lt_x2_and_not_inside_x1_y:
    ; Args: bp+4 = x, bp+5 = y
    ; Locals: bp-6 = x1, bp-5 = y, bp-4 = x2, bp-3 = dy

    mov bl, [bp-6]
    cmp bl, [bp-4]
    jge .x_equals_x1

    mov ah, bl        ; x1
    mov al, [bp-5]
    call calc_pixel_offset
    cmp byte [es:di], dl  ; inside( x1, y )

    je .x_equals_x1

    inc byte [bp-6]  ; x1 += 1

    jmp .while_x1_lt_x2_and_not_inside_x1_y

    .x_equals_x1:
    mov al, [bp-6]
    mov [bp+4], al  ; x = x1

    jmp .while_x1_le_x2

    .end:
    mov ax, bp
    sub ax, sp
    sub ax, 4 ; locals
    jnz .while_stack_not_empty

    mov sp, bp
    pop bp
    ret 2 ; size of args

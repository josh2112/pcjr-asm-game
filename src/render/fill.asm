
section .text

; fill( x, y ) - combined scan-and-fill span filler
; https://en.wikipedia.org/wiki/Flood_fill
; ES must be set to framebuffer!
; Args: bp+4 = x, bp+5 = y
; Locals: bp-4 = x1, bp-3 = y, bp-2 = x2, bp-1 = dy
fill:
    %push
    %define %$x [bp+4]
    %define %$y [bp+5]
    %define %$x1 [bp-4]
    %define %$y1 [bp-3]
    %define %$x2 [bp-2]
    %define %$dy [bp-1]
    
    push bp
    mov bp, sp
    sub sp, 4  ; Make space for locals

    mov dl, [vec_clear_color]
    mov dh, [vec_color]

    mov al, %$x    ; x
    mov ah, 1
    push ax
    push word %$x  ; Push( x, y, x, 1 )

    neg ah
    push ax           ; x, -1
    add ah, %$y       ; x, y-1
    push ax  ; Push( x, y-1, x, -1 )

    .while_stack_not_empty:
    pop word %$x1
    pop word %$x2 ; Pop( x1, y, x2, dy )
    mov ah, %$x1
    mov %$x, ah  ; x = x1

    mov al, %$y1  ; y, x
    call calc_pixel_offset
    cmp byte [es:di], dl  ; inside( x, y )
    jne .while_x1_le_x2

    .while_inside_x_minus_1_y:
    ; DI is already set to x, y... just subtract 1 for x-1,y
    dec di

    cmp byte [es:di], dl  ; inside( x-1, y )
    jne .if_x_le_x1

    mov byte [es:di], dh  ; set( x-1, y )

    dec byte %$x  ; x -= 1

    jmp .while_inside_x_minus_1_y

    .if_x_le_x1:
    mov al, %$x1
    dec al
    mov ah, %$dy
    neg ah
    push ax           ; x1-1, -dy
    add ah, %$y1
    mov al, %$x    ; x, y-dy
    push ax           ; push( x, y-dy, x1-1, -dy)

    .while_x1_le_x2:

    mov ah, %$x1
    cmp ah, %$x2
    ja .end          ; jmp if x1 > x2

    mov al, %$y1   ; ax = y, x1
    call calc_pixel_offset

    .while_inside_x1_y:

    cmp byte [es:di], dl  ; inside( x1, y )
    jne .if_x1_gt_x

    mov al, dh
    stosb              ; set( x1, y )

    inc byte %$x1    ; x1 += 1

    jmp .while_inside_x1_y

    .if_x1_gt_x:
    mov al, %$x1
    cmp al, %$x
    jbe .if_x1_minus_1_gt_x2  ; jmp if x1 <= x

    dec al
    mov ah, %$dy
    push ax            ; x1-1, dy
    add ah, %$y1
    mov al, %$x     ; x, y+dy
    push ax            ; push( x, y+dy, x1-1, dy)

    .if_x1_minus_1_gt_x2:

    mov al, %$x1
    dec al
    cmp al, %$x2
    jbe .x1_equals_x1_plus_1  ; jmp if x1-1 <= x2

    mov ah, %$dy
    neg ah
    push ax          ; x1-1, -dy
    add ah, %$y1
    mov al, %$x2
    inc al           ; x2+1, y-dy
    push ax          ; push( x2+1, y-dy, x1-1, -dy)

    .x1_equals_x1_plus_1:

    mov bl, %$y1
    mov bh, %$x1   ; x1, y
    inc bh           ; x1 += 1

    .while_x1_lt_x2_and_not_inside_x1_y:
    cmp bh, %$x2
    jae .x_equals_x1  ; jmp if x1 >= x2

    mov ax, bx
    call calc_pixel_offset
    cmp byte [es:di], dl  ; inside( x1, y )
    je .x_equals_x1

    inc bh
    jmp .while_x1_lt_x2_and_not_inside_x1_y

    .x_equals_x1:
    mov %$x1, bh
    mov %$x, bh  ; x = x1

    jmp .while_x1_le_x2

    .end:
    mov ax, bp
    sub ax, sp
    sub ax, 4 ; locals
    jnz .while_stack_not_empty

    mov sp, bp
    pop bp
    ret 2 ; size of args

    %pop
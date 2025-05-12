
section .text

; fill( x, y ) - combined scan-and-fill span filler
; https://en.wikipedia.org/wiki/Flood_fill
; ES must be set to framebuffer!
; Args: bp+4 = x (2), bp+6 = y (2)
; Locals: bp-6 = x1 (2), bp-4 = x2 (2), bp-2 = dy (2)
fill2:
push bp
mov bp, sp
sub sp, 6  ; Make space for locals

mov dl, [vec_clear_color]

mov ax, 1
push ax
push word [bp+6]
push word [bp+4]
push word [bp+4]  ; Push( x, x, y, 1 )

mov ax, -1
push ax
mov ax, [bp+6]
dec ax
push ax
push word [bp+4]
push word [bp+4]  ; Push( x, x, y-1, -1 )

.while_stack_not_empty:
pop word [bp-6]
pop word [bp-4]
pop word [bp+6]
pop word [bp-2]  ; Pop( x1, x2, y, dy )
mov bx, [bp-6]
mov [bp+4], bx  ; let x = x1

mov ah, bl      ; x
mov al, [bp+6]  ; y
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

dec word [bp+4]  ; x -= 1

jmp .while_inside_x_minus_1_y

.if_x_le_x1:
mov ax, [bp-2]
neg ax
push ax
add ax, [bp+6]
push ax
mov ax, [bp-6]
dec ax
push ax
push word [bp+4]   ; push( x, x1-1, y-dy, -dy)

.while_x1_le_x2:

mov ax, [bp-6]
cmp ax, [bp-4]
jg .end

mov ah, [bp-6]
mov al, [bp+6]
call calc_pixel_offset

.while_inside_x1_y:

cmp byte [es:di], dl  ; inside( x1, y )
jne .if_x1_gt_x

mov al, [vec_color]
nibble_to_byte
stosb                          ; set( x1, y )

inc word [bp-6]     ; x1 += 1

jmp .while_inside_x1_y

.if_x1_gt_x:
mov ax, [bp-6]
cmp ax, [bp+4]
jle .if_x1_minus_1_gt_x2

mov ax, [bp-2]
push ax
add ax, [bp+6]
push ax
mov ax, [bp-6]
dec ax
push ax
push word [bp+4]  ; push( x, x1-1, y+dy, dy)

.if_x1_minus_1_gt_x2:

mov ax, [bp-6]
dec ax
cmp ax, [bp-4]  ; if x1 - 1 > x2
jle .x1_equals_x1_plus_1

mov ax, [bp-2]
neg ax
push ax
add ax, [bp+6]
push ax
mov ax, [bp-6]
dec ax
push ax
mov ax, [bp-4]
inc ax
push ax   ; push( x2+1, x1-1, y-dy, -dy)

.x1_equals_x1_plus_1:

inc word [bp-6]  ; x1 += 1

.while_x1_lt_x2_and_not_inside_x1_y:

mov bx, [bp-6]
cmp bx, [bp-4]
jge .x_equals_x1

mov ah, bl
mov al, [bp+6]
call calc_pixel_offset
cmp byte [es:di], dl  ; inside( x1, y )

je .x_equals_x1

inc word [bp-6]  ; x1 += 1

jmp .while_x1_lt_x2_and_not_inside_x1_y

.x_equals_x1:
mov ax, [bp-6]
mov [bp+4], ax  ; x = x1

jmp .while_x1_le_x2

.end:
mov ax, bp
sub ax, sp
sub ax, 6 ; locals
jnz .while_stack_not_empty

mov sp, bp
pop bp
ret 4 ; size of args

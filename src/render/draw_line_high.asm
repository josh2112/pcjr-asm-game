; draw_line_high( x0, y0, x1, y1 )
; Used for lines where dy  dx. We loop through each y from y0 to y1, sometimes incrementing or decrementing x.
; ES must be set to framebuffer!
; Args: bp+4 = x0, bp+5 = y0, bp+6 = x1, bp+7 = y1
; Locals: bp-7 = x, bp-6 = y, bp-5 = D, bp-3 = xi, bp-2 = dx, bp-1 = dy
draw_line_high:
push bp
mov bp, sp
sub sp, 7

mov word ax, [bp+6] ; ah = y1, al = x1
mov word bx, [bp+4] ; bh = y0, bl = x0
sub ah, bh
sub al, bl          ; ah = y1-y0, al = x1-x0
mov word [bp-2], ax ; init dx,dy
mov byte [bp-3], 1
test al, al         ; dx < 0?
jns .after_flip_x
neg byte [bp-3]
neg al
mov [bp-2], al ; xi = -1, dx = -dx
.after_flip_x:
xor cx, cx
mov cl, al
shl cx, 1       ; cx = dx*2
mov al, ah
xor ah, ah      ; al = dy
sub cx, ax      ; ah = dx*2 - dy
mov [bp-5], cx  ; init D

mov word [bp-7], bx

xor cx, cx
mov cl, [bp-1]
inc cl          ; loop dx+1 times

; Locals: bp-7 = x, bp-6 = y, bp-5 = D, bp-3 = xi, bp-2 = dx, bp-1 = dy

.foreachx:
push cx

mov ah, [bp-7]  ; x
mov al, [bp-6]  ; y 
call calc_pixel_offset

mov al, [vec_color]
nibble_to_byte
stosb

xor cx, cx
mov cl, [bp-7]  ; x

xor bx, bx
mov bl, [bp-2]   ; bx = dx
mov dx, [bp-5]   ; dx = D
test dx, dx      ; D > 0?
jle .noincy
add cl, [bp-3]
mov [bp-7], cl   ; x += xi
xor cx, cx
mov cl, [bp-1]
sub bx, cx       ; bx = dx-dy
.noincy:
shl bx, 1
add dx, bx       ; D += 2 * bx
mov [bp-5], dx
inc byte [bp-6]

pop cx
loop .foreachx

.end:

mov sp, bp
pop bp
ret 4
; draw_line_low( x0, y0, x1, y1 )
; Used for lines where dx > dy. We loop through each x from x0 to x1, sometimes incrementing or decrementing y.
; ES must be set to framebuffer!
; Args: bp+4 = x0, bp+5 = y0, bp+6 = x1, bp+7 = y1
; Locals: bp-8 = recalc_offset, bp-7 = x, bp-6 = y, bp-5 = D, bp-3 = yi, bp-2 = dx, bp-1 = dy
draw_line_low:
push bp
mov bp, sp
sub sp, 8

mov word ax, [bp+6] ; ah = y1, al = x1
mov word bx, [bp+4] ; bh = y0, bl = x0
sub ah, bh
sub al, bl          ; ah = y1-y0, al = x1-x0
mov byte [bp-8], 1
mov word [bp-2], ax ; init dx,dy
mov byte [bp-3], 1
test ah, ah         ; dy < 0?
jns .after_flip_y
neg byte [bp-3]
neg ah
mov [bp-1], ah ; yi = -1, dy = -dy
.after_flip_y:
xor cx, cx
mov cl, ah
shl cx, 1       ; cx = dy*2
xor ah, ah      ; al = dx
sub cx, ax      ; ah = dy*2 - dx
mov [bp-5], cx  ; init D

mov word [bp-7], bx

xor cx, cx
mov cl, [bp-2]
inc cl          ; loop dx+1 times

; Locals: bp-7 = x, bp-6 = y, bp-5 = D, bp-3 = yi, bp-2 = dx, bp-1 = dy

.foreachx:
push cx

test byte [bp-8], 1
jz .skip_offset_calc

mov ah, [bp-7]  ; x
mov al, [bp-6]  ; y 
call calc_pixel_offset
mov byte [bp-8], 0

.skip_offset_calc:

mov al, [vec_color]
stosb

xor dx, dx
mov dl, [bp-6]  ; y

xor bx, bx
mov bl, [bp-1]   ; bx = dy
mov cx, [bp-5]   ; cx = D
test cx, cx      ; D > 0?
jle .noincy
add dl, [bp-3]
mov [bp-6], dl      ; y += yi
mov byte [bp-8], 1  ; recalc offset
xor dx, dx
mov dl, [bp-2]
sub bx, dx       ; bx = dy-dx
.noincy:
shl bx, 1
add cx, bx       ; D += 2 * bx
mov [bp-5], cx

inc byte [bp-7]  ; x += 1

pop cx
loop .foreachx

.end:

mov sp, bp
pop bp
ret 4
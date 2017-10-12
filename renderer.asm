; renderer.asm: Rendering routines for our game

%ifndef RENDERER_ASM
%define RENDERER_ASM

; Draws an 8x8 rectangle at location (player_x, player_y) in
; color [color_draw_rect]. Uses the putpixel routine from
; std/320x200x16.asm.
draw_rect:
  mov cx, 8
  .drawRow:
    mov ax, 8
    sub ax, cx
    add ax, [player_y]      ; AX = row (y)
    push cx
    mov cx, 8
    .drawPixel:
      mov bx, 8
      sub bx, cx
      add bx, [player_x]    ; BX = col (x)
      push ax
      push cx
      mov dl, [color_draw_rect]
      call putpixel         ; (BX, AX) = (x,y), DL = color
      pop cx
      pop ax
      loop .drawPixel
    pop cx
    loop .drawRow
  ret

; Wait for port 0x3da bit 3 to go high, meaning that we are in
; the vertical retrace period and can safely update the framebuffer.
waitForRetrace:
  mov dx, 0x3da
.loop:         ; Wait for the vertical retrace bit to go low
  in al, dx
  and al, 0x8
  jnz .loop
.loop2:
  in al, dx    ; Now wait for it to go high. This way
  and al, 0x8  ; we know we've caught vertical retrace
  jz .loop2    ; right at the beginning.
  ret

%endif ; RENDERER_ASM

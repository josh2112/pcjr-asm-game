; renderer.asm: Rendering routines for our game

%ifndef RENDERER_ASM
%define RENDERER_ASM

; Draws the player graphic (an 8x8 green square) at location (player_x, player_y).
; Uses the putpixel routine from std/320x200x16.asm.
draw_player:
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
      mov dl, 10
      call putpixel         ; (BX, AX) = (x,y), DL = color
      pop cx
      pop ax
      loop .drawPixel
    pop cx
    loop .drawRow
  ret

%endif ; RENDERER_ASM

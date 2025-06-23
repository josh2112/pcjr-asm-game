section .text

%include "render/draw_line_low.asm"

%include "render/draw_line_high.asm"

; Draw a line from vec_pos to vec_dest in vec_color
drawline:
  push bx

  mov bx, [vec_pos]
  mov dx, [vec_dest]

  mov al, dh
  sub al, bh  ; al = y1-y0
  abs_al
  cbw
  push ax     ; abs( y1-y0 )

  mov al, dl
  sub al, bl  ; al = x1-x0
  abs_al
  cbw         ; ax = abs( x1-x0 )

  pop cx            ; cx = abs( y1-y0 )
  cmp cx, ax        ; abs(y1-y0) < abs(x1-x0)?
  jge .dlh

  .dll:
  cmp bl, dl       ; x0 > x1?
  jbe .dll1
  xchg bx, dx   ; Reverse src/dest
  .dll1:
  push dx
  push bx
  call draw_line_low

  .end:
  ; dest <- pos
  mov word dx, [vec_dest]
  mov word [vec_pos], dx

  pop bx
  ret

  .dlh:
  cmp bh, dh      ; y0 > y1?
  jbe .dlh1
  xchg bx, dx    ; Reverse src/dest
  .dlh1:
  push dx
  push bx
  call draw_line_high
  jmp .end
  
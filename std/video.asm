; video.asm: Rendering routines for our game

%ifndef VIDEO_ASM
%define VIDEO_ASM


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

%endif ; VIDEO_ASM

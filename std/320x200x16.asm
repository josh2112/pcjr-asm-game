; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM


; Draws a rectangle of color DL to the X,Y location referenced by
; [draw_rect_xy_ptr] with a size of [draw_rect_w], [draw_rect_h].
; NOTE: X and width must be even and height must be a multiple of 4!
draw_rect_optimized:
  push bp     ; Locals:
  mov bp, sp  ; [bp-2] - offset between end of line and start of
  sub sp, 2   ; next line, 2 bytes

  mov ax, 320
  sub ax, [draw_rect_w]
  shr ax, 1
  mov [bp-2], ax

  mov dh, dl
  mov cl, 4
  shl dh, cl
  or dl, dh   ; Now DL contains color twice

  mov cx, 4   ; Number of banks

.copyBank:
  mov ax, 4
  sub ax, cx  ; Now AX is the bank index (0,1,2,3)
  push cx

  mov di, [draw_rect_xy_ptr] ; dereference Y location
  add ax, [di+2] ; Now AX is the framebuffer row number

  ; Set DI to start byte of left side of line
  mov bx, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX is the row within the bank

  and bx, 0b11    ; BX = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying BX by the
  shl bx, cl      ; bank width _ptr] ; dereference Y location
  add ax, [di+2] ; Now AX is the framebuffer row number

  ; Set DI to start byte of left side of line
  mov bx, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX is the row within the bank

  and bx, 0b11    ; BX = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying BX by the
  shl bx, cl      ; bank width (0x2000): shift left by 13.
  ; Now BX is bank offset

  push bx
  mov bx, 320
  push dx
  mul bx
  pop dx
  add ax, [di]   ; add X
  shr ax, 1      ; Because each byte encodes 2 pixels
  pop bx
  add ax, bx

  mov di, ax

  mov cx, [draw_rect_h]
  shr cx, 1
  shr cx, 1
.copyLine:
  push cx

  mov cx, [draw_rect_w]
  shr cx, 1      ; Because each byte encodes 2 pixels

  mov al, dl
  rep stosb         ; Copy CX bytes

  pop cx
  add di, [bp-2]
  loop .copyLine

  pop cx
  loop .copyBank

  mov sp, bp
  pop bp
  ret


; Puts color index DL in the pair of pixels specified by BX,AX (x,y)
; Clobbers AX, CX, DX
putpixel:
  push dx         ; Save the color because we need DX for MUL and DIV
  mov dx, ax      ; Faster alternative to dividing AX by 4: shift
  shr dx, 1       ; right twice for quotient, mask with 0b11 for
  shr dx, 1       ; remainder.
  and ax, 0b11    ; AX = bank number (0-3), DX = row within bank

  ; Set the segment address to the right bank (0xB8000 + bank start)
  mov cl, 9       ; Faster alternative to multiplying AX by the
  shl ax, cl      ; bank width (0x200): shift left by 9.
  add ax, FRAMEBUFFER_SEG  ; Offset by start of video memory
  mov es, ax      ; ES = absolute start-of-bank address

  mov ax, dx
  ; Now BX is the pixel column (x) and AX is the row (y) within the bank

  ; Calc byte index of pixel: AX = (AX * 320 + BX) / 2
  mov cx, 320
  mul cx
  add ax, bx
  shr ax, 1

  mov si, ax        ; Put byte index in string-source register
  mov al, [es:si]   ; Pull the pixel pair out into AL

  pop dx            ; Get our color back in DX
  jc .setLow        ; If AX was odd, carry bit should be set from the right-shift. If so, set the low
                    ; nibble, otherwise set the high nibble
  .setHigh:
    and al, 0x0f    ; Clear the high nibble
    mov cl, 4
    shl dl, cl
    or al, dl       ; Set it from the color index in DL
    mov [es:si], al  ; Push the updated pixel pair back into memory
    ret

  .setLow:
    and al, 0xf0    ; Clear the low nibble
    or al, dl       ; Set it from the color index in DL
    mov [es:si], al  ; Push the updated pixel pair back into memory
    ret

; Fills the framebuffer pointed to by ES with the color indexed by the low nibble of DL
fill_page:
  ; Copy the low nibble of DL to the high nibble
  and dl, 0x0f ; Clear the high nibble
  mov dh, dl   ; Make a copy in DH
  mov cl, 4
  shl dh, cl   ; Shift DH left 4 bits (make the low nibble the high nibble)
  or dl, dh    ; Combine the nibbles
  mov dh, dl

  xor di, di     ; Set DI to 0 (STOSW will copy to ES:DI)
  mov ax, dx
  mov cx, 0x4000 ; Fill 32KB (0x4000 16-bit words)
  rep stosw

  ret

; Copies the rectangle specified by rect_bitblt from the
; offscreen buffer to the framebuffer.
blt_rect:
  push bp
  mov bp, sp  ; Locals:
  sub sp, 2   ;  - width of each line copy (in bytes): 2 bytes at [bp-2]

  push ds         ; Set DS to source (offscreen buffer) and
  push es         ; ES to destination (framebuffer)
  ;mov si, BACKGROUND_SEG
  mov ds, si
  ;mov di, FRAMEBUFFER_SEG
  mov es, di

  ; Calculate number of extra bytes to add to stosb count
  ; due to X position or width being odd
  mov ax, [cs:rect_bitblt_x]
  and ax, 0x1
  mov bx, [cs:rect_bitblt_w]
  and bx, 0x1
  add ax, bx

  mov bx, [cs:rect_bitblt_w] ; Width of each line to copy
  shr bx, 1                  ; Because each byte encodes 2 pixels
  add bx, ax                 ; Add any extra bytes
  mov [bp-2], bx             ; Store as local variable

  mov cx, [cs:rect_bitblt_h] ; Number of lines to copy

.copyLine:
  mov ax, [cs:rect_bitblt_h]
  sub ax, cx
  add ax, [cs:rect_bitblt_y]  ; Now AX is vertical line number
  push cx

  ; Set SI and DI to start byte of left side of line
  mov si, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX = row within bank

  and si, 0b11    ; SI = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying SI by the
  shl si, cl      ; bank width (0x2000): shift left by 13.


  ; Calc byte index of pixel: SI += (AX * 320 + rect_bitblt.x) / 2
  mov bx, 320
  mul bx
  add ax, [cs:rect_bitblt_x]
  shr ax, 1   ; Because each byte encodes 2 pixels
  add si, ax

  mov di, si

  mov cx, [bp-2]
  rep movsb                  ; Copy CX bytes

  pop cx
  loop .copyLine

.done:
  pop es          ; Restore our segment registers
  pop ds
  mov sp, bp      ; Destroy locals
  pop bp

  ret


%endif ; _320X200X16_ASM

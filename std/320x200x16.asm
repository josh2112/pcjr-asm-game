; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

section .data

  draw_rect_xy_ptr: dw 0
  draw_rect_w: dw 14
  draw_rect_h: dw 16

section .text

; Draws a rectangle of color DL to the X,Y location referenced by
; [draw_rect_xy_ptr] with a size of [draw_rect_w], [draw_rect_h].
; NOTE: X and width must be even!
draw_rect:
  call nibble_to_word
  mov dl, al  ; We need a byte of color (2 pixels) back in DL

  mov cx, [draw_rect_h] ; Number of lines to copy

  .copyLine:
    mov ax, [draw_rect_h]
    sub ax, cx
    push cx

    mov di, [draw_rect_xy_ptr] ; dereference Y location
    add ax, [di+2]

    ; Set SI and DI to start byte of left side of line
    mov si, ax      ; Faster alternative to dividing AX by 4: shift
    shr ax, 1       ; right twice for quotient, mask with 0b11 for
    shr ax, 1       ; remainder. Now AX = row within bank

    and si, 0b11    ; SI = bank number (0-3)
    mov cl, 13      ; Faster alternative to multiplying SI by the
    shl si, cl      ; bank width (0x2000): shift left by 13.

    ; Calc byte index of pixel: SI += (AX * 320 + rect_x) / 2
    mov bx, 320
    push dx
    mul bx
    pop dx
    add ax, [di]   ; add X
    shr ax, 1      ; Because each byte encodes 2 pixels
    add si, ax

    mov di, si

    mov cx, [draw_rect_w]
    shr cx, 1
    mov al, dl
    rep stosb         ; Copy CX bytes

    pop cx
    loop .copyLine

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
  add ax, [FRAMEBUFFER_SEG]  ; Offset by start of video memory
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

; Replicates the low nibble of DL four times in AX.
nibble_to_word:
  mov al, dl
  and al, 0xf  ; Mask out the high 4 bits of the byte
  mov ah, al   ; Make a copy in AH
  mov cl, 4    ; Prepare to shift left 4
  shl ah, cl   ; Copy low nibble to high
  or al, ah    ; Combine the nibbles
  mov ah, al   ; Combine the bytes
  ret

; Fills the framebuffer pointed to by DI with the color indexed by
; the low nibble of DL. No clobber.
fill_page:
  push es
  mov es, di
  push di

  call nibble_to_word

  xor di, di     ; Set DI to 0 (STOSW will copy to ES:DI)
  mov cx, 0x4000 ; Fill 32KB (0x4000 16-bit words)

  rep stosw

  pop di
  pop es
  ret

; blt_rect( fb_dest, fb_source, x, y, w, h )
; Copies the a rectangle of pixels from a source buffer to a destination buffer.
;  fb_dest (+4): 
blt_rect:
  push bp
  mov bp, sp  ; Locals:
  sub sp, 2   ;  - width of each line copy (in bytes): 2 bytes at [bp-2]

  push ds         ; Set DS to source and
  push es         ; ES to destination
  mov word ds, [bp+6]
  mov word es, [bp+4]

  ; Calculate number of extra bytes to add to stosb count
  ; due to X position or width being odd
  mov ax, [bp+8]
  and ax, 0x1
  mov bx, [bp+12]
  and bx, 0x1
  add ax, bx

  mov bx, [bp+12] ; Width of each line to copy
  shr bx, 1                  ; Because each byte encodes 2 pixels
  add bx, ax                 ; Add any extra bytes
  mov [bp-2], bx             ; Store as local variable

  mov cx, [bp+14] ; Number of lines to copy

.copyLine:
  mov ax, [bp+14]
  sub ax, cx
  add ax, [bp+10]  ; Now AX is vertical line number
  push cx

  ; Set SI and DI to start byte of left side of line
  mov si, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX = row within bank

  and si, 0b11    ; SI = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying SI by the
  shl si, cl      ; bank width (0x2000): shift left by 13.


  ; Calc byte index of pixel: SI += (AX * 320 + rect_x) / 2
  mov bx, 320
  mul bx
  add ax, [bp+8]
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
  ret 12


%endif ; _320X200X16_ASM

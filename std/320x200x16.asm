; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

section .text

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
; Copies a rectangle of pixels from a source buffer to a destination buffer.
; Args:
;   bp+4 = fb_dest, bp+6 = fb_source,
;   bp+8 = x, bp+10 = y, bp+12 = w, bp+14 = h
; Locals:
;   bp-2 = width of each line copy (in bytes)
blt_rect:
  push bp
  mov bp, sp
  sub sp, 2

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


; draw_icon( fb_dest, icon_ptr, icon_w, icon_h, x, y)
; Copies icon data into the destination buffer at the specified position
; NOTE: X and icon width must be even!
; Args:
;   bp+4 = fb_dest, bp+6 = icon_ptr,
;   bp+8 = icon_w, bp+10 = icon_h, bp+12 = x, bp+14 = y
draw_icon:
  push bp
  mov bp, sp

  mov cx, [bp+10]
  mov es, [bp+4]
  mov si, [bp+6]

.copyLine:
  ; Compute which row number we're writing to in the framebuffer
  mov ax, [bp+10] ; Start with icon height
  sub ax, cx      ; Subtract countdown to give us icon row
  add ax, [bp+14] ; Add Y location to icon row number
  
  ; Convert the row number to a bank number (BX) and row within that bank (AX)
  mov bx, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX is the row within the bank
  and bx, 0b11    ; BX = bank number (0-3)
  
  ; Convert bank number (BX) to a byte offset
  push cx
  mov cl, 13      ; Faster alternative to multiplying BX by the
  shl bx, cl      ; bank width (0x2000): shift left by 13.

  ; Calc byte index of pixel: DI = BX + (AX * 320 + x) / 2
  push bx
  mov bx, 320
  push dx
  mul bx           ; AX * 320
  pop dx
  add ax, [bp+12]  ; ... + x
  shr ax, 1        ; ... / 2
  pop bx
  add ax, bx       ; BX + ...
  mov di, ax

  mov cx, [bp+8]
  shr cx, 1        ; Because each byte encodes 2 pixels

.copyByte:
  mov al, [si]
  test al, al
  jz .afterCopyByte
  mov [es:di], al
.afterCopyByte:
  inc si
  inc di
  loop .copyByte

  pop cx
  loop .copyLine

  pop bp
  ret 12

%endif ; _320X200X16_ASM

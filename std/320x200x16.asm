; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

section .data

  COMPOSITOR_SEG: dw 0x1000   ; Page 4-5
  FRAMEBUFFER_SEG: dw 0x1800  ; Page 6-7

  room_width_px: dw 320
  room_height_px: dw 200

section .text

; Puts color index DL in the pair of pixels specified by BX,AX (x,y)
; Clobbers AX, CX, DX
putpixel:
  push dx         ; Save the color because we need DX for MUL and DIV
  mov dx, ax      ; Faster alternative to dividing AX by 4: shift
  shr dx, 1       ; right twice for quotient, mask with 0b11 for
  shr dx, 1       ; remainder.
  and ax, 0b11    ; AX = bank number (0-3), DX = row within bank

  ; Set the segment address to the right bank (0x18000 + bank start)
  mov cl, 9       ; Faster alternative to multiplying AX by the
  shl ax, cl      ; bank width (0x200): shift left by 9.
  add ax, 0x1800  ; Offset by start of video memory
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

; Fills the framebuffer with the color indexed by the low nibble of DL
cls:
  ; Copy the low nibble of DL to the high nibble
  and dl, 0x0f ; Clear the high nibble
  mov dh, dl   ; Make a copy in DH
  mov cl, 4
  shl dh, cl   ; Shift DH left 4 bits (make the low nibble the high nibble)
  or dl, dh    ; Combine the nibbles
  mov dh, dl

  mov ax, 0x1800
  mov es, ax     ; Set ES to point to the framebuffer
  xor di, di     ; Set DI to 0 (STOSW will copy to ES:DI)
  mov ax, dx
  mov cx, 0x4000 ; Fill 32KB (0x4000 16-bit words)
  rep stosw      ;

  ret

; draw_rect( x, y, w, h, color )
; Draws a colored rectangle of pixels of the given size at the given location
; to the compositor.
; Args:
;   bp+4 = x, bp+6 = y,
;   bp+8 = w, bp+10 = h,
;   bp+12 = color
draw_rect:
  push bp
  mov bp, sp

  mov ax, [bp+12]
  mov cx, 4
  shl al, cl
  xor al, [bp+12]
  mov si, ax  ; Color in SI

  mov di, [COMPOSITOR_SEG]
  mov es, di       ; Compositor segment in ES

  mov cx, [bp+10]  ; This CX will count down the rows
  
.copyLine:
  ; Compute which row number we're writing to
  mov ax, [bp+10] ; Start with rect height
  sub ax, cx      ; Subtract countdown to give us rect row
  add ax, [bp+6]  ; Add Y location to rect row number
  
  ; Compute starting byte offset for this location
  ; DI = (AX * 320 + x) / 2
  mov bx, [cs:room_width_px]
  mul bx           ; AX *= 320
  add ax, [bp+4]   ; ... + x
  shr ax, 1        ; ... / 2
  mov di, ax

  push cx
  mov cx, [bp+8]
  shr cx, 1        ; Because each byte encodes 2 pixels

.copyByte:
  mov ax, si
  mov [es:di], al
  inc di
  loop .copyByte

  pop cx
  loop .copyLine

  pop bp
  ret 10


; blt_compositor_to_framebuffer( x, y, w, h )
; Copies a rectangle of compositor data to the framebuffer, interleaving
; the lines into 4 scanline banks as required by the 320x200x16 mode.
; Args: bp+4 = x, bp+6 = y, bp+8 = w, bp+10 = h
blt_compositor_to_framebuffer:
  push bp
  mov bp, sp

  push ds            ; Set DS to source and
  push es            ; ES to destination
  mov es, [FRAMEBUFFER_SEG]
  mov ds, [COMPOSITOR_SEG]

  mov cx, [bp+10]   ; # lines to copy

.copyLine:
  ; Compute which row number we're writing to in the framebuffer
  mov ax, [bp+10] ; Start with rect height
  sub ax, cx      ; Subtract countdown to give us rect row
  add ax, [bp+6] ; Add Y location to rect row number
  
  ; Compute starting location for this line in the compositor
  ; SI = (AX * 320 + x) / 2
  push ax
  mov bx, [cs:room_width_px]
  mul bx           ; AX *= 320
  add ax, [bp+4]   ; ... + x
  shr ax, 1        ; ... / 2
  mov si, ax
  pop ax

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
  mov bx, [cs:room_width_px]
  mul bx           ; AX *= 320
  add ax, [bp+4]   ; ... + x
  shr ax, 1        ; ... / 2
  pop bx
  add ax, bx       ; BX + ...
  mov di, ax

  mov cx, [bp+8]
  shr cx, 1        ; Because each byte encodes 2 pixels
  rep movsb

  pop cx
  loop .copyLine

  pop es
  pop ds
  pop bp
  ret 8


; draw_icon( icon_ptr, x, y )
; Copies icon data into the compositor at the specified position. Black
; pixels are treated as transparent (not copied).
; Args: bp+4 = icon_ptr, bp+6 = x, bp+8 = y
; Locals: bp-2 = icon_w, bp-4 = icon_h
draw_icon:
  push bp
  mov bp, sp
  sub sp, 4

  push es            ; Set ES to destination
  mov es, [COMPOSITOR_SEG]

  mov si, [bp+4]     ; SI points to icon data (which start with width/height)
  mov ax, [si]       ; Copy width/height out into local variables
  mov bx, [si+2]
  mov [bp-2], ax
  mov [bp-4], bx
  
  mov cx, [bp-4]     ; CX = icon height
  add si, 4          ; advance SI to start of icon data

.copyLine:
  ; Compute which row number we're writing to
  mov ax, [bp-4]  ; Start with icon height
  sub ax, cx      ; Subtract countdown to give us icon row
  add ax, [bp+8] ; Add Y location to icon row number
  
  ; Compute starting byte offset for this location in compositor
  ; DI = (AX * 320 + x) / 2
  mov bx, [room_width_px]
  mul bx           ; AX *= 320
  add ax, [bp+6]   ; ... + x
  shr ax, 1        ; ... / 2
  mov di, ax

  push cx
  mov cx, [bp-2]
  shr cx, 1        ; Because each byte encodes 2 pixels

.copyByte:
  mov al, [ds:si]
  ; If sprite pixel is transparent, skip it.
  test al, al
  jz .afterCopyByte
  mov byte [es:di], al
.afterCopyByte:
  inc si
  inc di
  loop .copyByte

  pop cx
  loop .copyLine

  pop es
  mov sp, bp
  pop bp
  ret 6

%endif ; _320X200X16_ASM

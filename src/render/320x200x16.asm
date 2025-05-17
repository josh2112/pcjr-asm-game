; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

section .data

  ; Framebuffer -- doubled color nibbles
  ; One byte = info for 2 pixels (color 1 high, color 2 low)
  ; 4 banks of 50 scanlines each, as per Mode 9 specs
  FRAMEBUFFER_SEG: dw 1800h  ; FB always starts at 18000h

  ; Compositor buffer -- doubled color nibbles
  ; One byte = info for 2 pixels (color 1 high, color 2 low)
  ; Straight run, so a pixel is addressed by y*160+x/2
  ; 11700h = 18000h - 26880 bytes
  COMPOSITOR_SEG: dw 1170h
  
  ; Background buffer -- interleaved depth and color nibbles
  ; One byte = info for 2 pixels (priority high, color low)
  ; Straight run, so a pixel is addressed by y*160+x/2
  ; 0ae00h = 11700h - 26880 bytes
  BACKGROUND_SEG: dw 0ae0h
  
  room_width_px: dw 320
  room_height_px: dw 168

  ; Nibble-to-byte translation table
  lut_nibble_to_byte: db 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255

section .text

; Duplicates the low nibble of AL in the high nibble. Clobbers BX.
%macro nibble_to_byte 0
  and al, 0fh
  mov bx, lut_nibble_to_byte
  cs xlat               ; Use the CS segment since DS may be tied up by the caller
%endmacro


; blt_background_to_compositor( x, y, w, h )
; Copies a rectangle of background buffer data to the compositor,
; overwriting the high byte (priority) with the low byte (color).
; Args:
;   bp+4 = x, bp+6 = y, bp+8 = w, bp+10 = h
blt_background_to_compositor:
  push bp
  mov bp, sp

  push ds
  mov es, [COMPOSITOR_SEG]
  mov ds, [BACKGROUND_SEG]

  mov cx, [bp+10]   ; # lines to copy
  
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
  mov si, ax
  mov di, ax
  
  push cx
  mov cx, [bp+8]
  shr cx, 1        ; Because each byte encodes 2 pixels

.copyByte:
  lodsb
  nibble_to_byte
  stosb
  loop .copyByte

  pop cx
  loop .copyLine

  pop ds
  pop bp
  ret 8


; blt_compositor_to_framebuffer( x, y, w, h )
; Copies a rectangle of compositor data to the framebuffer, interleaving
; the lines into 4 scanline banks as required by the 320x200x16 mode.
; Args:
;   bp+4 = x, bp+6 = y, bp+8 = w, bp+10 = h
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

; TODO: This needs some major optimization.
; draw_icon( icon_ptr, icon_priority, x, y )
; Copies icon data into the compositor at the specified position. Black
; pixels are treated as transparent (not copied). At each pixel, the
; corresponding background priority is sampled, and if equal to or greater
; than the icon's priority, the icon pixel is not copied.
; Args: bp+4 = icon_ptr, bp+6 = icon_priority, bp+8 = x, bp+10 = y
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
  add ax, [bp+10] ; Add Y location to icon row number
  
  ; Compute starting byte offset for this location in compositor
  ; DI = (AX * 320 + x) / 2
  mov bx, [room_width_px]
  mul bx           ; AX *= 320
  add ax, [bp+8]   ; ... + x
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
  ; If sprite has a lower priority than corresponding base pixel, skip it.
  push es
  push cx
  mov es, [BACKGROUND_SEG]
  mov bl, [es:di]
  mov cl, 4
  shr bl, cl    ; Get the priority into BL
  pop cx
  pop es
  cmp bl, [bp+6]
  jge .afterCopyByte

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
  ret 8

; calc_pixel_offset( x, y )
; Returns the byte offset in the framebuffer for a pixel at (x,y). The range of X is 0-159 since we
; double pixels horizontally. Clobbers AX, CX, DI.
; Args: AH = x, AL = y
; Returns: pixel offset in DI
calc_pixel_offset:
  mov di, es
  cmp di, [BACKGROUND_SEG]
  je .calc_pixel_offset_bg

  mov di, ax

  shr al, 1       
  shr al, 1       ; AL = row within bank (Y/4)

  and di, 0b11
  mov cl, 13
  shl di, cl      ; DI = byte offset of bank (bank number (0-3) * 0x2000)

  ; Calc byte index of pixel: DI = DI + AL * 160 + AH
  mov ch, ah       ; Get X out of the way so we can multiply
  mov cl, 160
  mul cl           ; AH:AL = AL * 160

  xchg cl, ch
  xor ch, ch
  add di, cx       ; ... + CH (x)
  add di, ax

  ret

  .calc_pixel_offset_bg:
  ; The background buffer is a straight run... pixel index is just 160y + x
  mov ch, ah       ; Get X out of the way so we can multiply
  mov cl, 160
  mul cl           ; AH:AL = AL * 160
  xchg cl, ch
  xor ch, ch
  add ax, cx
  xchg di, ax      ; DI = AX + CX
  ret

; copy_framebuffer_to_background()
; Copy the low nibble of each FB byte into its place in the BB
copy_framebuffer_to_background:
  push ds
  mov es, [BACKGROUND_SEG]
  mov ds, [FRAMEBUFFER_SEG]

  sub dx, dx      ; line count
  sub di, di

  .copyLine:
  mov ax, dx
  mov si, ax

  and si, 0b11
  mov cx, 13; mov cl, 13
  shl si, cl      ; SI = byte offset of bank (bank number (0-3) * 0x2000)

  shr al, 1       
  shr al, 1       ; AL = row within bank (Y/4)

  ; Calc byte index of first pixel in line: SI = SI + AL * 160
  mov cl, 160
  mul cl           ; AH:AL = AL * 160

  add si, ax

  ;mov cx, 160 ; CX is still 160 here (from the mul)

  .copyByte:
  lodsb
  and al, 0fh     ; AL = low nibble of FB byte
  mov ah, [es:di]
  and ah, 0f0h     ; AH = high nibble of BG byte
  or al, ah
  stosb
  loop .copyByte

  inc dx
  cmp dx, 168
  jne .copyLine

  pop ds
  ret

%endif ; _320X200X16_ASM
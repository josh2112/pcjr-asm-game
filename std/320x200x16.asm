; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM


section .data

  FRAMEBUFFER_SEG: dw 1800h  ; FB always starts at 18000h
  COMPOSITOR_SEG: dw 1170h   ; 18000h - 26880 bytes = 11700h
  BACKGROUND_SEG: dw 0ae0h   ; 11700h - 26880 bytes = 0ae00h
  
  room_width_px: dw 320
  room_height_px: dw 168

section .text

; Duplicates the low nibble of AL in the high nibble. Clobbers AH.
%macro nibble_to_byte_low 0
  and al, 0x0f ; Mask out the high 4 bits of the byte
  mov ah, al   ; Make a copy in AH
  shl ah, 1    ; Move the low nibble to the high
  shl ah, 1    ; (by shifting left 4 bytes)
  shl ah, 1
  shl ah, 1
  or al, ah    ; Combine the nibbles
%endmacro


; blt_background_to_compositor( x, y, w, h )
; Copies a rectangle of background buffer data to the compositor,
; overwriting the high byte (priority) with the low byte (color).
; Args:
;   bp+4 = x, bp+6 = y, bp+8 = w, bp+10 = h
blt_background_to_compositor:
  push bp
  mov bp, sp

  push ds            ; Set DS to source and
  push es            ; ES to destination
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
  mov di, ax

  push cx
  mov cx, [bp+8]
  shr cx, 1        ; Because each byte encodes 2 pixels

.copyByte:
  mov al, [ds:di]
  nibble_to_byte_low
  mov byte [es:di], al
  inc di
  loop .copyByte

  pop cx
  loop .copyLine

  pop es          ; Restore our segment registers
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


; draw_icon( icon_ptr, icon_priority, x, y )
; Copies icon data into the compositor at the specified position. Black
; pixels are treated as transparent (not copied). At each pixel, the
; corresponding background priority is sampled, and if greater than the
; icon's priority, the icon pixel is not copied.
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
  jg .afterCopyByte

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

%endif ; _320X200X16_ASM

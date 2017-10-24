; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

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
  add ax, 0xb800  ; Offset by start of video memory
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

; Fills the framebuffer with the color indexed by the low nibble of DL
cls:
  ; Copy the low nibble of DL to the high nibble
  and dl, 0x0f ; Clear the high nibble
  mov dh, dl   ; Make a copy in DH
  mov cl, 4
  shl dh, cl   ; Shift DH left 4 bits (make the low nibble the high nibble)
  or dl, dh    ; Combine the nibbles
  mov dh, dl

  mov ax, 0xb800
  mov es, ax     ; Set ES to point to the framebuffer
  xor di, di     ; Set DI to 0 (STOSW will copy to ES:DI)
  mov ax, dx
  mov cx, 0x4000 ; Fill 32KB (0x4000 16-bit words)
  rep stosw      ;

  ret

; draw_rect( x, y, w, h, color )
; Writes a color to a block of pixels of the given size at the given location.
; NOTE: X and W must be even!
; Args:
;   bp+4 = x, bp+6 = y,
;   bp+8 = w, bp+10 = h,
;   bp+12 = color
draw_rect:
  push bp
  mov bp, sp

  mov dl, [bp+12]  ; Color in SI
  call nibble_to_word
  mov ah, 0
  mov si, ax

  mov di, 0xb800
  mov es, di       ; Framebuffer segment in ES

  mov cx, [bp+10]  ; This CX will count down the rows
  
  .copyLine:
    ; Compute which row number we're writing to in the framebuffer
    mov ax, [bp+10] ; Start with rect height
    sub ax, cx      ; Subtract countdown to give us rect row
    add ax, [bp+6]  ; Add Y location to rect row number
    
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
    add ax, [bp+4]   ; ... + x
    shr ax, 1        ; ... / 2
    pop bx
    add ax, bx       ; BX + ...
    mov di, ax

    mov cx, [bp+8]   ; This CX will count down the pixels in the row
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


%endif ; _320X200X16_ASM

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
  add ax, VIDEO_SEG  ; Offset by start of video memory
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
cls:
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

%endif ; _320X200X16_ASM

; 320x200x16.asm: Drawing routines for Video Mode 9, 320x200 16-color

%ifndef _320X200X16_ASM
%define _320X200X16_ASM

; Puts color index DL in the pair of pixels specified by BX,AX (x,y)
putpixel:
  push dx         ; Save the color because we need DX for MUL and DIV
  mov cx, 4
  xor dx, dx
  div cx          ; DX = bank number (0-3), AX = row within bank
  xchg ax, dx     ; AX = bank number (0-3), DX = row within bank
  mov cx, 0200h   ; bank width
  push dx
  mul cx          ; AX = bank memory offset
  pop dx
  add ax, 01800h  ; offset by start of video memory
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
    and al, 00fh    ; Clear the high nibble
    mov cl, 4
    shl dl, cl
    or al, dl       ; Set it from the color index in DL
    jmp .finish

  .setLow:
    and al, 0f0h    ; Clear the low nibble
    or al, dl       ; Set it from the color index in DL

  .finish:
    mov [es:si], al  ; Push the updated pixel pair back into memory
    ret

%endif ; _320X200X16_ASM

; stdio.asm: Routines for 8088 assembly that would be classified as "stdio"
; in C, such as processing input.

; Much like C/C++, these %ifndef/%define/%endif keep the file from being
; accidentally included multiple times.

%ifndef STDIO_ASM
%define STDIO_ASM

section .text

; read_file( path, destination )
; Reads all bytes from a file into a buffer. Destination is an offset in
; DS segment. is an offset in DS segment. Returns immediately if error
; (check CF=1, then AX for error code)
; Args:
;   bp+4 = path, bp+6 = destination
read_file:
  push bp
  mov bp, sp

  mov dx, [bp+4]
  mov ax, 3d00h
  int 21h          ; AX = Open file (dx) handle
  jc .end

  mov bx, ax       ; BX = file handle
  sub cx, cx
  sub dx, dx
  mov ax, 4202h
  int 21h          ; AX = file length (ignore DX, our files aren't that big)
  jc .end

  push ax          ; Push file size
  sub cx, cx
  sub dx, dx
  mov ax, 4200h
  int 21h          ; Move back to beginning of file
  jc .end

  pop cx           ; CX = file size
  mov dx, [bp+6]   ; DS:DX = destination (assume DS set)
  mov ax, 3f00h
  int 21h          ; Read whole file
  jc .end

  mov ax, 3e00h
  int 21h          ; close file
  
  sub ax, ax
  jmp .end

.end:
  pop bp
  ret 4

%endif ; STDIO_ASM

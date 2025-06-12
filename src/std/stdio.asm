; stdio.asm: Routines for 8088 assembly that would be classified as "stdio"
; in C, such as processing input.

; Much like C/C++, these %ifndef/%define/%endif keep the file from being
; accidentally included multiple times.

%ifndef STDIO_ASM
%define STDIO_ASM

; read_file( path, size, destination )
; Reads bytes from a file into a buffer.
; Args:
;   bp+4 = path, bp+6 = size,
;   bp+8 = destination
read_file:
  push bp
  mov bp, sp

  mov ax, 0x3d00   ; Call INT 21h, 3D (open file)
  mov dx, [bp+4]   ; with DX as the path
  int 21h

  mov bx, ax       ; Move newly-opened file handle to BX
  mov ax, 0x3f00   ; Call INT 21h, 3F (read from file)
  mov cx, [bp+6]   ; with CX = file size...
  xor dx, dx
  push ds          ; (save DS first)
  mov di, [bp+8]
  mov ds, di       ; and DS:DX as the read buffer
  int 21h
  pop ds

  mov ax, 0x3e00  ; Call INT21h, 3E to close the file
  int 21h         ; (file handle still in BX)

  pop bp
  ret 6


%endif ; STDIO_ASM
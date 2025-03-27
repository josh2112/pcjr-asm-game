; stdio.mac: Input/output routines for 8088 assembly

%ifndef STDIO_MAC
%define STDIO_MAC

section .data

  str_crlf: db 0xa, 0xd, '$'

section .bss

  buf16: resb 16

section .text

; Prints the given '$'-terminated string.
%macro print 1
	mov dx, %1
	mov ax, 0900h
	int 21h
%endmacro

; Prints the given '$'-terminated string and newline.
%macro println 1
	print %1
	print str_crlf
%endmacro

; Stores the string representation of the value in %2 in buffer %1.
; Example usage:
; str_sp: db 'sp=$'
; print str_sp
; pop sp
; wordToString buf16, sp
; println buf16
%macro wordToString 2
  mov di, %1
  mov ax, %2
  call int_to_string
%endmacro

; Stores the string representation of the value in the lower half of %2 in buffer %1.
%macro byteToString 2
  mov di, %1
  mov ax, %2
  xor ah, ah
  call int_to_string
%endmacro

; Waits for a key press using int 21h fn 08h (char input without echo)
%macro waitForAnyKey 0
	mov ah, 0x08
	int 21h
%endmacro

%endif ; STDIO_MAC

; stdio.asm: Routines for 8088 assembly that would be classified as "stdio"
; in C, such as processing input.

; Much like C/C++, these %ifndef/%define/%endif keep the file from being
; accidentally included multiple times.

%ifndef STDIO_ASM
%define STDIO_ASM

%define KEYCODE_ESC 0x01
%define KEYCODE_ENTER 0x1c
%define KEYCHAR_BACKSPACE 0x08
%define KEYCODE_UP 0x48
%define KEYCODE_LEFT 0x4b
%define KEYCODE_RIGHT 0x4d
%define KEYCODE_DOWN 0x50

section .data

  keyboardState: times 128 db 0

section .bss

  originalInt9h: resb 4

section .text

handle_int9h:
  push ax
  push bx
  pushf

  xor ax, ax
  in al, 0x60         ; Read from keyboard
  xchg bx, ax
  test bl, 0x80       ; If high bit is set it's a key release
  jnz .keyReleased

  ; NOTE: Using CS: prefix for keyboard state here because no telling what
  ; DS will be set to when this is called!
  .keyPressed:
    mov byte [cs:keyboardState+bx], 1  ; Turn on that key in the buffer
    jmp .done
  .keyReleased:
    and bl, 0x7f                       ; Remove key-released flag
    mov byte [cs:keyboardState+bx], 0  ; Turn off that key in the buffer
  .done:
    ; Clear keyboard IRQ if pending
    in al, 0x61     ; Grab keyboard state
    mov ah, al
    or al, 0x80
    out 0x61, al    ; Send state w/ ack bit set
    xchg al, ah
    out 0x61, al    ; Send original state
    ; Signal end-of-interrupt
    mov al, 0x20
    out 0x20, al
    
    ; Restore state
    popf
    pop bx
    pop ax
    sti
    iret


; Redirect INT9h to the handle_int9h procedure.
install_keyboard_handler:
  cli                               ; Disable interrupts
  xor di, di
  mov es, di                        ; Set ES to 0
  mov dx, [es:9h*4]                 ; Copy the offset of the INT 9h handler
  mov [originalInt9h], dx           ; Store it in oldInt9h
  mov dx, [es:9h*4+2]               ; Then copy the segment
  mov [originalInt9h+2], dx         ; Store it in oldInt9h + 2
  mov word [es:9h*4], handle_int9h  ; Install the new handle - first the offset,
  mov word [es:9h*4+2], cs          ; then the segment
  sti                               ; Reenable interrupts
  ret


; Restore default INT9h processing.
restore_keyboard_handler:
  cli
  xor di, di
  mov es, di
  mov dx, [originalInt9h]
  mov word [es:9h*4], dx
  mov dx, [originalInt9h+2]
  mov word [es:9h*4+2], dx
  sti
  ret


; read_file( path, size, destination )
; Reads bytes from a file into a buffer.
; Args:
;   bp+4 = path, bp+6 = size,
;   bp+8 = destination
read_file:
  push bp
  mov bp, sp

  mov ax, 0x3d00
  mov dx, [bp+4]
  int 21h

  mov bx, ax
  mov ax, 0x3f00
  mov cx, [bp+6]
  xor dx, dx
  push ds
  mov di, [bp+8]
  mov ds, di
  int 21h
  pop ds

  mov ax, 0x3e00
  int 21h

  pop bp
  ret 6



%endif ; STDIO_ASM

; Contains routines to hook the INT 9H keyboard routine and store the on/off states of every key
; in the keyboard buffer.

%ifndef KBD_STATE_ASM
%define KBD_STATE_ASM

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
  mov dx, [cs:originalInt9h]
  mov word [es:9h*4], dx
  mov dx, [cs:originalInt9h+2]
  mov word [es:9h*4+2], dx
  sti
  ret

%endif KBD_STATE_ASM
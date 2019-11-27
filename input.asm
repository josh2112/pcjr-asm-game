; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

; Processes the keys in the keyboardState buffer.
; - Cursor keys (up, down, left, right): Adjust player position.
; - Esc key: set is_running to false (game will be exited)
process_key:
  cmp byte [keyboardState+key_esc], 1
  jne .testUp
  mov byte [is_running], 0
  jmp .done
.testUp:
  cmp byte [keyboardState+key_up], 1
  jne .testDown
  mov byte [player_walk_dir], DIR_UP
  jmp .done
.testDown:
  cmp byte [keyboardState+key_down], 1
  jne .testLeft
  mov byte [player_walk_dir], DIR_DOWN
  jmp .done
.testLeft:
  cmp byte [keyboardState+key_left], 1
  jne .testRight
  mov byte [player_walk_dir], DIR_LEFT
  jmp .done
.testRight:
  cmp byte [keyboardState+key_right], 1
  jne .done
  mov byte [player_walk_dir], DIR_RIGHT
.done:
  ret


handle_int9h:
  cli
  push ax
  push bx
  pushf

  xor ax, ax
  in al, 60h          ; Read from keyboard

  test al, 0x80       ; If high bit is set it's a key release
  jnz .keyReleased

.keyPressed:
  mov bx, ax
  mov byte [cs:keyboardState+bx], 1  ; Turn on that key in the buffer
  jmp .done
.keyReleased:
  and al, 0x7f                       ; Remove key-released flag
  mov bx, ax
  mov byte [cs:keyboardState+bx], 0  ; Turn off that key in the buffer
  jmp .done
.done:
  ; Signal end-of-interrupt
  mov al, 0x20
  out 20h, al

  ; Restore state
  popf
  pop bx
  pop ax
  sti
  iret


install_keyboard_handler:
  mov ax, 0x3509             
  int 21h                    ; Get current INT9 handler as ES:BX
  mov [oldInt9h],bx       ; Save offset and segment to oldInt9h
  mov [oldInt9h+2],es
  push cs
  pop ds                     ; Set DS:DX to segment:offset of new
  mov dx, handle_int9h       ; handler (CS:handle_int9h)
  mov ax, 0x2509             ; Install new INT9 hander
  int 21h
  ret

restore_keyboard_handler:
  push ds
  mov dx, [oldInt9h]
  mov ds, [oldInt9h+2]     ; Set DS:DX to original handler
  mov ax, 0x2509              ; Install new INT9 hander
  int 21h
  pop ds
  ret

%endif ; INPUT_ASM

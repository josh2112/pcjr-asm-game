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
  dec word [player_y]
  jmp .done
.testDown:
  cmp byte [keyboardState+key_down], 1
  jne .testLeft
  inc word [player_y]
  jmp .done
.testLeft:
  cmp byte [keyboardState+key_left], 1
  jne .testRight
  dec word [player_x]
  jmp .done
.testRight:
  cmp byte [keyboardState+key_right], 1
  jne .done
  inc word [player_x]
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
  and al, 0x7f                      ; Remove key-released flag
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
  mov [cs:oldInt9h],bx       ; Save offset and segment to oldInt9h
  mov [cs:oldInt9h+2],es
  push cs
  pop ds                     ; Set DS:DX to segment:offset of new
  mov dx, handle_int9h       ; handler (CS:handle_int9h)
  mov ax, 0x2509             ; Install new INT9 hander
  int 21h
  ret


restore_keyboard_handler:
  mov ds, [cs:oldInt9h+2]     ; Set DS:DX to original handler
  mov dx, [cs:oldInt9h]
  mov ax, 0x2509              ; Install new INT9 hander
  int 21h
  ret

%endif ; INPUT_ASM

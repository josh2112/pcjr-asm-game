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


; Redirect INT9h to the handle_int9h procedure.
install_keyboard_handler:
  cli                               ; Disable interrupts
  xor ax, ax
  mov es, ax                        ; Set ES to 0
  mov dx, [es:9h*4]                 ; Copy the offset of the INT 9h handler
  mov [oldInt9h], dx                ; Store it in oldInt9h
  mov dx, [es:9h*4+2]               ; Then copy the segment
  mov [oldInt9h+2], dx              ; Store it in oldInt9h + 2
  mov word [es:9h*4], handle_int9h  ; Install the new handle - first the offset,
  mov word [es:9h*4+2], cs          ; Then the segment
  sti                               ; Reenable interrupts
  ret


; Restore default INT9h processing.
restore_keyboard_handler:
  cli
  xor ax, ax
  mov es, ax
  mov dx, [oldInt9h]
  mov word [es:9h*4], dx
  mov dx, [oldInt9h+2]
  mov word [es:9h*4+2], dx
  sti
  ret

%endif ; INPUT_ASM

; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

; Processes the keys in the keyboardState buffer.
; - Cursor keys (up, down, left, right): Adjust player position.
; - Esc key: set is_running to false (game will be exited)
process_key:
  cmp byte [keyboardState+KEY_ESC], 1
  jne .testUp
  mov byte [is_running], 0
.testUp:
  cmp byte [keyboardState+KEY_UP], 1
  jne .testDown
  dec word [player_y]
.testDown:
  cmp byte [keyboardState+KEY_DOWN], 1
  jne .testLeft
  inc word [player_y]
.testLeft:
  cmp byte [keyboardState+KEY_LEFT], 1
  jne .testRight
  dec word [player_x]
.testRight:
  cmp byte [keyboardState+KEY_RIGHT], 1
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
  xchg bx, ax
  test bl, 0x80       ; If high bit is set it's a key release
  jnz .keyReleased

; NOTE: Using CS: prefix for keyboard state here because no telling what
; DS will be set to when this is called!
.keyPressed:
  mov byte [cs:keyboardState+bx], 1  ; Turn on that key in the buffer
  jmp .done
.keyReleased:
  and bl, 0x7f                    ; Remove key-released flag
  mov byte [cs:keyboardState+bx], 0  ; Turn off that key in the buffer
.done:
  ; Clear keyboard IRQ if pending
  in al, 61h     ; Grab keyboard state
  or al, 0x80    ; Flip on acknowledgement bit
  out 61h, al    ; Send it
  and al, 0x7f   ; Restore previous value
  out 61h, al    ; Send it again
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
  push es
  xor di, di
  mov es, di                        ; Set ES to 0
  mov dx, [es:9h*4]                 ; Copy the offset of the INT 9h handler
  mov [oldInt9h], dx                ; Store it in oldInt9h
  mov dx, [es:9h*4+2]               ; Then copy the segment
  mov [oldInt9h+2], dx              ; Store it in oldInt9h + 2
  mov word [es:9h*4], handle_int9h  ; Install the new handle - first the offset,
  mov word [es:9h*4+2], cs          ; then the segment
  pop es
  sti                               ; Reenable interrupts
  ret


; Restore default INT9h processing.
restore_keyboard_handler:
  cli
  push es
  xor di, di
  mov es, di
  mov dx, [oldInt9h]
  mov word [es:9h*4], dx
  mov dx, [oldInt9h+2]
  mov word [es:9h*4+2], dx
  pop es
  sti
  ret

%endif ; INPUT_ASM

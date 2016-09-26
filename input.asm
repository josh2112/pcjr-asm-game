; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

; Processes the keyboard scancode in AH.
; - Cursor keys (up, down, left, right): Adjust player position.
; - Esc key: set is_running to false (game will be exited)
process_key:
  cmp ah, 1
  jne .testUp
  mov byte [is_running], 0
  jmp .done
.testUp:
  cmp ah, 0x48
  jne .testDown
  dec word [player_y]
  jmp .done
.testDown:
  cmp ah, 0x50
  jne .testLeft
  inc word [player_y]
  jmp .done
.testLeft:
  cmp ah, 0x4b
  jne .testRight
  dec word [player_x]
  jmp .done
.testRight:
  cmp ah, 0x4d
  jne .done
  inc word [player_x]
.done:
  ret

handle_int9h:
  ret

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

; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

%include 'std/stdio.asm'

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

%endif ; INPUT_ASM

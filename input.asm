; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

;
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

%endif ; INPUT_ASM

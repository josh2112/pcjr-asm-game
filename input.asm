; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

; Process any keystroke in the keyboard buffer:
; - Handle ESC as quit the program.
; - Handle cursor keys to move player around.
; TODO: Handle all buffered keys here?
process_key:
  mov ah, 1     ; Check for keystroke.  If ZF is set, no keystroke.
  int 16h
  jz .done
  mov ah, 0     ; Get the keystroke. AH = scan code, AL = ASCII char
  int 16h
  push ax
  mov ah, 3     ; Get cursor position.  We only care about column, in DL.
  xor bh, bh
  int 10h
  pop ax        ; Now AH = key scan code, AL = ASCII char, DL = cursor column.
  .testEsc:
    cmp ah, KEYCODE_ESC             ; Process ESC key
    jne .testLeft
    mov byte [is_running], 0
    ret
  .testLeft:
    cmp ah, KEYCODE_LEFT
    jne .testRight
    mov dl, DIR_LEFT
    call toggle_walk
    ret
  .testRight:
    cmp ah, KEYCODE_RIGHT
    jne .testUp
    mov dl, DIR_RIGHT
    call toggle_walk
    ret
  .testUp:
    cmp ah, KEYCODE_UP
    jne .testDown
    mov dl, DIR_UP
    call toggle_walk
    ret
  .testDown:
    cmp ah, KEYCODE_DOWN
    jne .done
    mov dl, DIR_DOWN
    call toggle_walk
    ret
  .done:
    ret

toggle_walk:
  cmp [player_walk_dir], dl
  je .stop_walking
  mov [player_walk_dir], dl
  ret
  .stop_walking:
    mov byte [player_walk_dir], 0
    ret


%endif ; INPUT_ASM

; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

%include 'std/input.mac.asm'

section .text

; Process any keystrokes in the keyboard buffer, handling ESC
; to quit the program and cursor keys to move the player.
process_keys:
  mov ah, 1     ; Check for keystroke.  If ZF is set, no keystroke.
  int 16h
  jnz .get_keystroke
  ret
  
  .get_keystroke:
    mov ah, 0     ; Get the keystroke. AH = scan code, AL = ASCII char
    int 16h
    
  cmp ah, KEYCODE_ESC             ; Process ESC key
  jne .test_dir_keys
  mov byte [is_running], 0
  ret
  
  .test_dir_keys:
    cmp ah, KEYCODE_LEFT
    je .toggle_walk
    cmp ah, KEYCODE_RIGHT
    je .toggle_walk
    cmp ah, KEYCODE_UP
    je .toggle_walk
    cmp ah, KEYCODE_DOWN
    je .toggle_walk
    ret

  .toggle_walk:
    cmp [player_walk_dir], ah
    je .stop_walking
    mov [player_walk_dir], ah
    ret
  .stop_walking:
    mov byte [player_walk_dir], KEYCODE_NONE
    ret

%endif ; INPUT_ASM

; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

%include 'std/input.mac.asm'
%include 'std/stdio.asm'

section .data

  text_prompt: db "> $"
  text_comma: db ", $"
  text_acknowledgement: db "Ok$"
  text_version: db "Foster's Quest v0.1$"

  text_input: times 64 db '$'
  text_input_offset: dw 0

  
section .text

; Process any keystrokes in the keyboard buffer. Strategy:
; - Look for special key:
;   - Handle ESC as quit the program.
;   - Handle cursor keys to move player around.
;   - Handle ENTER as submit command -- read all chars on input line into a buffer then process it
; - Otherwise as long as cursor column is between 2 (start of input line) and 39 (end of input line):
;   - Handle backspace.
;   - Pass any other key straight through.
process_keys:
  mov ah, 1     ; Check for keystroke.  If ZF is set, no keystroke.
  int 16h
  jnz .get_keystroke
  ret
  
  .get_keystroke:
    mov ah, 0     ; Get the keystroke. AH = scan code, AL = ASCII char
    int 16h

  push ax
  mov ah, 3     ; Get cursor position.  We only care about column, in DL.
  xor bh, bh
  int 10h
  pop ax        ; Now AH = key scan code, AL = ASCII char, DL = cursor column.
  
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

  .testEnter:
    cmp ah, KEYCODE_ENTER
    jne .testBackspace
    clear_cursor
    call advance_to_next_line
    print text_version
    call advance_to_next_line
    print text_prompt
    print_cursor
    ret
  .testBackspace:
    cmp al, KEYCHAR_BACKSPACE
    jne .processChar
    cmp dl, 3     ; First 2 characters are the prompt, so only jump if we're at >= 3
    jl .done
    call process_key_backspace
    ret
  .processChar:
    cmp dl, 38   ; If we're at the end of the line, don't accept any more characters.
    jge .done
    mov ah, 0x0e
    mov bl, 7     ; Text color
    int 10h
    print_cursor
  .done:
    ret

  .toggle_walk:
    cmp [player_walk_dir], ah
    je .stop_walking
    mov [player_walk_dir], ah
    ret
  .stop_walking:
    mov byte [player_walk_dir], KEYCODE_NONE
    ret

; Backspace only backs up the cursor. To actually clear the character we'll
; send three characters: backspace, space, backspace.
process_key_backspace:
  mov ax, 0e08h
  mov bl, 7
  int 10h
  mov ax, 0e20h
  mov bl, 7
  int 10h
  mov ax, 0e20h
  mov bl, 7
  int 10h
  mov ax, 0e08h
  mov bl, 7
  int 10h
  mov ax, 0e08h
  mov bl, 7
  int 10h
  print_cursor
  ret

; We can't send a line feed - if the cursor is already on the last line, it'll scroll the whole screen. So:
; - Send a carriage return.
; - Check cursor row: if 24 or less, send a line feed.
; - Otherwise, scroll just the text area.
advance_to_next_line:
  mov ax, 0e0dh
  int 10h      ; Send carriage return
  mov ah, 3     
  xor bh, bh
  int 10h      ; Get cursor position. Row is in DH.
  cmp dh, 24
  jge .scroll
  mov ax, 0e0ah
  int 10h      ; Send line feed
  ret
  .scroll:
    mov ax, 0601h  ; Scroll by 1 line
    xor bh, bh     ; No attributes
    mov cx, 1500h ; Upper left = row 20, col 0
    mov dx, 1827h ; Lower right = row 24, col 39
    int 10h
    ret


%endif ; INPUT_ASM

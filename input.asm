; input.asm: Input-handling routines

%ifndef INPUT_ASM
%define INPUT_ASM

%include 'std/stdio.asm'

; Processes the keys in the keyboardState buffer.
; - Cursor keys (up, down, left, right): Adjust player position.
; - Esc key: set is_running to false (game will be exited)
process_keys:
  cmp byte [keyboardState+KEYCODE_ESC], 1
  jne .testUp
  mov byte [is_running], 0
  .testUp:
    cmp byte [keyboardState+KEYCODE_UP], 1
    jne .testDown
    dec word [player_y]
  .testDown:
    cmp byte [keyboardState+KEYCODE_DOWN], 1
    jne .testLeft
    inc word [player_y]
  .testLeft:
    cmp byte [keyboardState+KEYCODE_LEFT], 1
    jne .testRight
    dec word [player_x]
    dec word [player_x]
  .testRight:
    cmp byte [keyboardState+KEYCODE_RIGHT], 1
    jne .done
    inc word [player_x]
    inc word [player_x]
  .done:
    ret

%endif ; INPUT_ASM

; Process any keystrokes in the keyboard buffer. Strategy:
; - Look for special key:
;   - Handle ESC as quit the program.
;   - Handle cursor keys to move player around.
;   - Handle ENTER as submit command -- read all chars on input line into a buffer then process it
; - Otherwise as long as cursor column is between 2 (start of input line) and 39 (end of input line):
;   - Handle backspace (which only backs up the cursor) and process as backspace, space, backspace.
;   - Pass any other key straight through.
process_keys_2:
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
    jne .testEnter
    mov dl, DIR_DOWN
    call toggle_walk
    ret
  .testEnter:
    cmp ah, KEYCODE_ENTER
    jne .testBackspace
    call advance_to_next_line
    print text_acknowledgement
    call advance_to_next_line
    print text_prompt
    ret
  .testBackspace:
    cmp al, KEYCHAR_BACKSPACE
    jne .processChar
    cmp dl, 3
    jl .done
    call process_key_backspace
    ret
  .processChar:
    cmp dl, 39
    jge .done
    mov ah, 0x0e
    mov bl, 7     ; Text color
    int 10h
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

process_key_backspace:
  mov ax, 0x0e08
  int 10h
  mov al, 0x20
  int 10h
  mov al, 0x08
  int 10h
  ret

; We can't send a line feed - if the cursor is already on the last line, it'll scroll the whole screen. So:
; - Send a carriage return.
; - Check cursor row: if 24 or less, send a line feed.
; - Otherwise, scroll just the text area.
advance_to_next_line:
  mov ax, 0x0e0d
  int 10h      ; Send carriage return
  mov ah, 3     
  xor bh, bh
  int 10h      ; Get cursor position. Row is in DH.
  cmp dh, 24
  jge .scroll
  mov ax, 0x0e0a
  int 10h      ; Send line feed
  ret
  .scroll:
    mov ax, 0x0601 ; Scroll by 1 line
    xor bh, bh     ; No attributes
    mov cx, 0x1500 ; Upper left = row 20, col 0
    mov dx, 0x1827 ; Lower right = row 24, col 39
    int 10h
    ret

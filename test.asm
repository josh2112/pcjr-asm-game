; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'std/stdio.mac'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

  dbg: dw 0

  text_prompt: db "> $"
  text_comma: db ", $"

  path_room1: db "room1.bin", 0

  color_bg: db 1

  is_running: db 1

  player_x: dw 160
  player_y: dw 100
  player_w: dw 14
  player_h: dw 16
  player_x_prev: dw 160
  player_y_prev: dw 100

  player_icon:
    db 000h, 000h, 0eeh, 0eeh, 0eeh, 000h, 000h ; 1
    db 000h, 000h, 088h, 0eeh, 088h, 000h, 000h ; 2
    db 000h, 000h, 0eeh, 0eeh, 0eeh, 000h, 000h ; 3
    db 000h, 000h, 0eeh, 088h, 0eeh, 000h, 000h ; 4
    
    db 000h, 000h, 0eeh, 0eeh, 0eeh, 000h, 000h ; 5
    db 000h, 000h, 000h, 0eeh, 000h, 000h, 000h ; 6
    db 0eeh, 0aah, 0aah, 0aah, 0aah, 0aah, 0eeh ; 7
    db 0eeh, 0aah, 0aah, 0aah, 0aah, 0aah, 0eeh ; 8
    
    db 000h, 000h, 0aah, 0aah, 0aah, 000h, 000h ; 9
    db 000h, 000h, 0aah, 0aah, 0aah, 000h, 000h ; 10
    db 000h, 000h, 022h, 022h, 022h, 000h, 000h ; 11
    db 000h, 000h, 033h, 033h, 033h, 000h, 000h ; 12
    
    db 000h, 000h, 033h, 000h, 033h, 000h, 000h ; 13
    db 000h, 000h, 033h, 000h, 033h, 000h, 000h ; 14
    db 000h, 000h, 033h, 000h, 033h, 000h, 000h ; 15
    db 000h, 066h, 066h, 000h, 066h, 066h, 000h ; 16

section .bss

  originalVideoMode: resb 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH = 0x00 (set video mode), AL = 0x09 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

mov ax, 0x0582               ; AH = 0x05 (CPU/CRT page registers), AL = 0x82 (set CRT page register)
mov bx, 0x0600               ; BH = Page 6, matching our FRAMEBUFFER_SEG
int 10h                      ; Call INT10h fn 0x05 to set CRT page register to 6


push word [BACKGROUND_SEG]
mov ax, room_width_px
mov bx, room_height_px
mul bx
;shr ax, 1
push ax
mov [dbg], ax
mov ax, path_room1
push ax
call read_file  ; read "room1.bin" into BACKGROUND_SEG

mov ax, [room_height_px]
push ax
mov ax, [room_width_px]
push ax
xor ax, ax
push ax
push ax
call blt_background_to_compositor

mov ax, [room_height_px]
push ax
mov ax, [room_width_px]
push ax
xor ax, ax
push ax
push ax
call blt_compositor_to_framebuffer

call install_keyboard_handler

game_loop:

  ; Copy player_[x,y] to player_[x,y]_prev
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw

  call process_keys           ; Check keyboard state

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  je clean_up                ; jump out of game loop

  call bound_player
  
  ; 1) Copy rectangle covering player's previous location from background to compositor
  push word [player_h]
  push word [player_w]
  push word [player_y_prev]
  push word [player_x_prev]
  call blt_background_to_compositor

  ; 2) Draw the player icon in its new location in the compositor
  push word [player_y]
  push word [player_x]
  push word [player_h]
  push word [player_w]
  mov ax, player_icon
  push ax
  call draw_icon

  ; Combine player previous and current rect:
  ; AX = x_prev - x
  ; if AX > 0, X = x
  ; else, X = x_prev
  ; W = W + AX
  ;
  ; BX = y_prev - y
  ; if BX > 0, Y = y
  ; else, Y = y_prev
  ; H = H + BX

  mov ax, [player_x]
  mov cx, [player_x_prev]
  sub cx, ax
  jns .next1
    mov ax, [player_x_prev]
    neg cx
  .next1:
  add cx, [player_w]

  mov bx, [player_y]
  mov dx, [player_y_prev]
  sub dx, bx
  jns .next2
    mov bx, [player_y_prev]
    neg dx
  .next2:
  add dx, [player_h]
  
  ; 3) Copy a rectangle covering both player's previous and current locations from compositor to framebuffer
  push dx
  push cx
  push bx
  push ax
  call blt_compositor_to_framebuffer

  xor bx, bx        ; Set page number for cursor move (0 for graphics modes)
  mov dx, 0x1800    ; line 24 (0x18), col 0 (0x0)
  mov ah, 2         ; Call "set cursor"
  int 10h
  print text_prompt

  intToString buf16, [dbg]
  print buf16

  jmp game_loop


clean_up:

call restore_keyboard_handler

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 0x4c00
int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include 'std/stdlib.asm'
%include 'std/320x200x16.asm'
%include 'input.asm'
%include 'renderer.asm'

bound_player:
  cmp word [player_x], 0
  jge .next
  mov word [player_x], 0
  .next:
    mov ax, [room_width_px]
    sub ax, [player_w]
    cmp word [player_x], ax
    jle .next2
    mov word [player_x], ax
  .next2:
    cmp word [player_y], 0
    jge .next3
    mov word [player_y], 0
  .next3:
    mov ax, [room_height_px]
    sub ax, [player_h]
    cmp word [player_y], ax
    jle .done
    mov word [player_y], ax
  .done:
  ret

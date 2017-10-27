; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%define key_esc 0x01
%define key_up 0x48
%define key_left 0x4b
%define key_right 0x4d
%define key_down 0x50

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

str_crlf: db 0xa, 0xd, '$'

color_bg: db 1
color_player: db 10

is_running: db 1
player_x: dw 160
player_y: dw 100
player_w: dw 14
player_h: dw 16

keyboardState: times 128 db 0

player_icon:
  db 0x00, 0x00, 0xee, 0xee, 0xee, 0x00, 0x00 ; 1
  db 0x00, 0x00, 0x88, 0xee, 0x88, 0x00, 0x00 ; 2
  db 0x00, 0x00, 0xee, 0xee, 0xee, 0x00, 0x00 ; 3
  db 0x00, 0x00, 0xee, 0x88, 0xee, 0x00, 0x00 ; 4
    
  db 0x00, 0x00, 0xee, 0xee, 0xee, 0x00, 0x00 ; 5
  db 0x00, 0x00, 0x00, 0xee, 0x00, 0x00, 0x00 ; 6
  db 0xee, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xee ; 7
  db 0xee, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xee ; 8
    
  db 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0x00, 0x00 ; 9
  db 0x00, 0x00, 0xaa, 0xaa, 0xaa, 0x00, 0x00 ; 10
  db 0x00, 0x00, 0x22, 0x22, 0x22, 0x00, 0x00 ; 11
  db 0x00, 0x00, 0x33, 0x33, 0x33, 0x00, 0x00 ; 12
    
  db 0x00, 0x00, 0x33, 0x00, 0x33, 0x00, 0x00 ; 13
  db 0x00, 0x00, 0x33, 0x00, 0x33, 0x00, 0x00 ; 14
  db 0x00, 0x00, 0x33, 0x00, 0x33, 0x00, 0x00 ; 15
  db 0x00, 0x66, 0x66, 0x00, 0x66, 0x66, 0x00 ; 16

section .bss

originalVideoMode: resb 1
buf16: resb 16

oldInt9h: resb 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_keyboard_handler

mov dl, [color_bg]           ; Paint the whole screen with the background color
call cls

game_loop:
  call waitForRetrace

  mov ax, 0xb800
  mov es, ax
  mov al, 0x44
  xor di, di
  stosb

  push word [color_bg]
  push word [player_h]
  push word [player_w]
  push word [player_y]
  push word [player_x]
  call draw_rect             ; Erase at the player's previous position

  call process_key           ; Do something with the key

  push word [player_y]
  push word [player_x]
  push word [player_h]
  push word [player_w]
  mov ax, player_icon
  push ax
  call draw_icon             ; Draw the player graphic

  mov ax, 0xb800
  mov es, ax
  mov al, 0xee
  xor di, di
  stosb

  cmp byte [is_running], 0   ; If still running (ESC key not pressed),
  jne game_loop              ; jump back to game_loop

clean_up:

call restore_keyboard_handler

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 4c00h
int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include 'std/stdio.mac'
%include 'std/stdlib.asm'
%include 'std/320x200x16.asm'
%include 'input.asm'
%include 'renderer.asm'

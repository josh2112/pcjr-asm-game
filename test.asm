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
player_w: dw 8
player_h: dw 8

keyboardState: times 128 db 0

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

  mov ax, 0x1800
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

  push word [color_player]
  push word [player_h]
  push word [player_w]
  push word [player_y]
  push word [player_x]
  call draw_rect             ; Draw the player graphic

  mov ax, 0x1800
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

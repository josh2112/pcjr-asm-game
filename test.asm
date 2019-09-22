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

originalVideoMode: db 0

color_bg: db 1

is_running: db 1

player_x: dw 160
player_y: dw 100
player_x_prev: dw 160
player_y_prev: dw 100

keyboardState: times 128 db 0

player_icon: dw 14, 16
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

oldInt9h: resb 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Move stack pointer out of the way so we have free reign of the
; upper half of memory (64K-128K).
mov sp, 0x2000

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_keyboard_handler

; TODO: Change this to take a framebuffer location
; Need to draw on BACKGROUND_SEG here, then on COMPOSITOR_SEG later

push word [color_bg]
push word [room_height_px]
push word [room_width_px]
xor ax, ax
push ax
push ax
call draw_rect             ; Clear the whole compositor to background color

; TODO: draw some stuff on BACKGROUND_SEG and copy it
; over to COMPOSITOR_SEG

push word [room_height_px]
push word [room_width_px]
xor ax, ax
push ax
push ax
call blt_compositor_to_framebuffer

game_loop:

  ; Copy player_[x,y] to player_[x,y]_prev
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw   ; Copy 2 words from player_x... to player_x_prev...

  call process_key           ; Do something with the key

  ; 1) Clear the player's previous location in the compositor to the background color 
; TODO: Instead, copy background rectangle to compositor 
  push word [color_bg]
  push word [player_icon+2]
  push word [player_icon+0]
  push word [player_y_prev]
  push word [player_x_prev]
  call draw_rect

  ; 2) Draw the player icon in its new location in the compositor
  push word [player_y]
  push word [player_x]
  mov ax, player_icon
  push ax
  call draw_icon

  ; Combine player previous and current rect:
  mov ax, [player_x]
  mov cx, [player_x_prev]
  sub cx, ax
  jns .next1
    mov ax, [player_x_prev]
    neg cx
  .next1:
  add cx, [player_icon+0]
  inc cx

  mov bx, [player_y]
  mov dx, [player_y_prev]
  sub dx, bx
  jns .next2
    mov bx, [player_y_prev]
    neg dx
  .next2:
  add dx, [player_icon+2]
  
  ; 3) Copy a rectangle covering both player's previous and current locations from compositor to framebuffer
  push dx
  push cx
  push bx
  push ax
  call blt_compositor_to_framebuffer

  cmp byte [is_running], 0   ; If still running (ESC key not pressed),
  jne game_loop                ; jump out of game loop

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

%include 'std/stdio.mac'
%include 'std/stdlib.asm'
%include 'std/320x200x16.asm'
%include 'input.asm'

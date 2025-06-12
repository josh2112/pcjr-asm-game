; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%define key_esc 0x01
%define key_up 0x48
%define key_left 0x4b
%define key_right 0x4d
%define key_down 0x50

%define DIR_NONE 0
%define DIR_LEFT 1
%define DIR_RIGHT 2
%define DIR_UP 3
%define DIR_DOWN 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

originalVideoMode: db 0

color_bg: db 1

path_room1: db "room1.bin", 0

is_running: db 1

player_walk_dir: db DIR_NONE   ; See "DIR_" defines

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

; Stack management - Move stack pointer down out of the way
; so we have three 32KB buffer regions free
mov bx, ss
mov cl, 4
shl bx, cl
mov ax, 0x8600
sub ax, bx
mov sp, ax
xor ax, ax
push ax

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_keyboard_handler

push word [BACKGROUND_SEG]
mov ax, [room_width_px]
mov bx, [room_height_px]
mul bx
shr ax, 1
push ax
mov ax, path_room1
push ax
call read_file  ; read "room1.bin" into BACKGROUND_SEG

push word [room_height_px]
push word [room_width_px]
xor ax, ax
push ax
push ax
call blt_background_to_compositor ; Copy whole background to compositor

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

  call move_player
  call bound_player

  ; 1) Copy rectangle covering player's previous location from background to compositor
  push word [player_icon+2]
  push word [player_icon+0]
  push word [player_y_prev]
  push word [player_x_prev]
  call blt_background_to_compositor

  ; 2) Draw the player icon in its new location in the compositor
  mov ax, [player_y]
  add ax, [player_icon+2]
  dec ax
  call ypos_to_priority  ; AX = priority of player (taken at foot line)
  push word [player_y]
  push word [player_x]
  push ax                ; Push prioirity calculated earlier
  mov ax, player_icon
  push ax                ; Pointer to player icon W,H
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
%include 'std/stdio.asm'
%include 'std/stdlib.asm'
%include 'std/320x200x16.asm'
%include 'input.asm'


move_player:
  mov bl, [player_walk_dir]
  cmp bl, DIR_LEFT
  jne .testRight
  dec word [player_x]
  dec word [player_x]
  .testRight:
    cmp bl, DIR_RIGHT
    jne .testUp
    inc word [player_x]
    inc word [player_x]
  .testUp:
    cmp bl, DIR_UP
    jne .testDown
    dec word [player_y]
  .testDown:
    cmp bl, DIR_DOWN
    jne .done
    inc word [player_y]
  .done:
    ret

; Check the player's feet (bottom scanline of icon). If they have have hit a 
; hard boundary (mask=0), stop the walking motion and move back one unit.
bound_player:
  mov ax, [player_y]
  cmp ax, 0
  jle .bounce_back
  add ax, [player_icon+2]
  cmp ax, 168
  jg .bounce_back
  mov ax, [player_x]
  cmp ax, 0
  jl .bounce_back
  add ax, [player_icon]
  cmp ax, 320
  jg .bounce_back

  jmp .didnt_hit_wall
  
  .bounce_back:
  call bounce_back
  ret

  .didnt_hit_wall:
  mov ax, [player_y]
  add ax, [player_icon+2]
  dec ax     ; AX = player foot-line
  ; Compute starting location for player foot-line in framebuffer
  ; SI = (AX * 320 + x) / 2
  mov bx, [room_width_px]
  mul bx           ; AX *= 320
  add ax, [player_x]   ; ... + x
  shr ax, 1        ; ... / 2
  mov si, ax
  mov cx, [player_icon+0]
  shr cx, 1
  push ds            ; DS to source (FB)
  mov ds, [BACKGROUND_SEG]
  xor ah, ah
  .checkPixel:
    mov al, [ds:si]
    ; The mask is the upper 4 bits, and we're trying to see if it has
    ; a value of 0 (vs 0xf). Therefore we can just check whether the whole
    ; byte is less than 0x10. NOTE: We must use JB (jump below) here
    ; instead of JL (jump if less than) because our numbers are not signed
    cmp al, 0x10
    jb .foundBorder
    inc si
    loop .checkPixel

  pop ds
  ret
  .foundBorder:
    pop ds
    call bounce_back
    ret

bounce_back:
  mov byte bl, [player_walk_dir]
  cmp bl, DIR_LEFT
  jne .next
  mov bl, DIR_NONE
  inc word [player_x]
  inc word [player_x]
  .next:
    cmp bl, DIR_RIGHT
    jne .next2
    mov bl, DIR_NONE
    dec word [player_x]
    dec word [player_x]
  .next2:
    cmp bl, DIR_UP
    jne .next3
    mov bl, DIR_NONE
    inc word [player_y]
  .next3:
    cmp bl, DIR_DOWN
    jne .done
    mov bl, DIR_NONE
    dec word [player_y]
  .done:
    ret

; ypos_to_priority()
; Converts the Y position in AX to a priority.
; max( 4, floor( y/12 ) + 1 ) (The min of 4 is so player doesn't disappear near top of screen)
ypos_to_priority:
  push bx
  mov bx, 12
  div bx
  pop bx
  xor ah, ah
  add ax, 1
  cmp ax, 4
  jge .done
  mov ax, 4
.done:
  ret
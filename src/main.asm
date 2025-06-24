; main.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'std/stdio.mac.asm'
%include 'std/input.mac.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

originalVideoMode: db 0

color_bg: db 1

path_room1: db "room1.bin", 0

is_running: db 1

player_walk_dir: db KEYCODE_NONE   ; See "KEYCODE_" defines

player_x: dw 160
player_y: dw 100
player_x_prev: dw 160
player_y_prev: dw 100

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

call dosbox_fix
call stack_fix

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

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

; Move cursor to text window and print a prompt
sub bh, bh       ; Set page number for cursor move (0 for graphics modes)
mov dx, 1500h    ; line 21 (0x15), col 0 (0x0)
mov ah, 2        ; Call "set cursor"
int 10h
print text_prompt

game_loop:

  call process_keys          ; Check keyboard state

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  jz clean_up                ; jump out of game loop

  ; Copy player_[x,y] to player_[x,y]_prev
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw   ; Copy 2 words from player_x... to player_x_prev...

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

  jmp game_loop                ; jump out of game loop

clean_up:

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 0x4c00
int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

move_player:
  mov bl, [player_walk_dir]
  cmp bl, KEYCODE_LEFT
  jne .testRight
  dec word [player_x]
  dec word [player_x]
  .testRight:
    cmp bl, KEYCODE_RIGHT
    jne .testUp
    inc word [player_x]
    inc word [player_x]
  .testUp:
    cmp bl, KEYCODE_UP
    jne .testDown
    dec word [player_y]
  .testDown:
    cmp bl, KEYCODE_DOWN
    jne .done
    inc word [player_y]
  .done:
    ret

; Check the player's feet (bottom scanline of icon). If they have have hit a 
; hard boundary (pri=0), stop the walking motion and move back one unit.
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
  mov bl, [player_walk_dir]
  cmp bl, KEYCODE_LEFT
  jne .next
  mov bl, KEYCODE_NONE
  inc word [player_x]
  inc word [player_x]
  .next:
    cmp bl, KEYCODE_RIGHT
    jne .next2
    mov bl, KEYCODE_NONE
    dec word [player_x]
    dec word [player_x]
  .next2:
    cmp bl, KEYCODE_UP
    jne .next3
    mov bl, KEYCODE_NONE
    inc word [player_y]
  .next3:
    cmp bl, KEYCODE_DOWN
    jne .done
    mov bl, KEYCODE_NONE
    dec word [player_y]
  .done:
    ret

; ypos_to_priority()
; Converts the Y position in AX to a priority between 1 and 14 inclusive: floor( y/12 ) + 1
ypos_to_priority:
  push bx
  mov bx, 12
  div bx
  pop bx
  inc ax
  xor ah, ah
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "std/utils.asm"

%include "std/stdio.asm"

%include "std/stdlib.asm"

%include "std/320x200x16.asm"

%include "input.asm"
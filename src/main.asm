; Foster's Quest
; Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'std/stdio.mac.asm'
%include 'std/math.mac.asm'

%define DIR_NONE 0
%define DIR_LEFT 1
%define DIR_RIGHT 2
%define DIR_UP 3
%define DIR_DOWN 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

  originalVideoMode: db 0

  text_prompt: db "> $"
  text_comma: db ", $"
  text_acknowledgement: db "Ok$"
  text_version: db "Foster's Quest v0.1$"

  text_input: times 64 db '$'
  text_input_offset: dw 0

  path_room1: db "room1.vec", 0
  
  vec_color: db 0
  vec_pos: dw 0
  vec_dest: dw 0
  vec_clear_color: db 0xff

  ptr_err: dw 0
  str_fileError: db "Error reading file$"

  is_running: db 1

  player_walk_dir: db DIR_NONE   ; See "DIR_" defines

  player_x: dw 160
  player_y: dw 100
  player_x_prev: dw 160
  player_y_prev: dw 100

player_icon: dw 14, 16,
  incbin "assets/icon/player.bin"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

call dosbox_fix
call stack_fix

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0009h                ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

mov ax, path_room1
call loadRoom
jnc room_loaded
mov word [ptr_err], str_fileError
jmp clean_up

room_loaded:
; Move cursor to text window and print a prompt
sub bh, bh       ; Set page number for cursor move (0 for graphics modes)
mov dx, 1600h    ; line 21 (0x15), col 0 (0x0)
mov ah, 2       ; Call "set cursor"
int 10h
print text_prompt
;print_cursor
mov ax, 0a5fh
mov bx, 07h
mov cx, 1
int 10h

game_loop:

  ; Copy player_[x,y] to player_[x,y]_prev
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw   ; Copy 2 words from player_x... to player_x_prev...

  call process_keys          ; Check keyboard state

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  je clean_up                ; jump out of game loop

  call move_player
  call bound_player
  
  ; 1) Combine player's previous and current rectangles
  mov ax, [player_x]
  mov cx, [player_x_prev]
  sub cx, ax
  jns .next1
    mov ax, [player_x_prev]
    neg cx
  .next1:
  add cx, [player_icon+0]

  mov bx, [player_y]
  mov dx, [player_y_prev]
  sub dx, bx
  jns .next2
    mov bx, [player_y_prev]
    neg dx
  .next2:
  add dx, [player_icon+2]
  push dx
  push cx
  push bx
  push ax

  push dx ; Now push this rect again so we can use it for blt_compositor_to_framebuffer below
  push cx
  push bx
  push ax

  ; 2)  Copy this rectangle from background to compositor
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
  
  ; 3) Copy a rectangle covering both player's previous and current locations from compositor to framebuffer
  call blt_compositor_to_framebuffer

  jmp game_loop


clean_up:
; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

mov dx, [ptr_err]
test dx, dx
jz exit
println dx

exit:
; Exit the program
mov ax, 4c00h
int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
; hard boundary (pri=0), stop the walking motion and move back one unit.
; If water (1) or a room boundary (15) has been hit, stop the walking and return
; what was hit.
; Skeleton lines are:
; 0 = hard boundary
; 1 = water
; 15 = room boundary
bound_player:
  mov ax, [player_y]
  add ax, [player_icon+2]    ; AX = player foot line
  cmp ax, 48
  jle .bounce_back
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
  .checkPixel:
    xor ah, ah
    mov al, [ds:si]
    ; The priority is in the top nibble (upper 4 bits). We're looking for 0, 1, or 15.
    ; If we add 1 to the top nibble and shift it to the lower 4 bits,
    ; we're now looking for 1, 2, or 0 (i.e. < 3)
    add al, 10h
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    cmp al, 3
    jl .foundBorder
    inc si
    loop .checkPixel
    jmp .done
  .foundBorder:
    pop ds
    call bounce_back
    ret
  .done:
    pop ds
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
    mov byte [player_walk_dir], bl
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "std/utils.asm"

%include "std/stdio.asm"

%include "std/timer.asm"

%include "render/320x200x16.asm"

%include "render/load_room.asm"

%include "render/draw_line.asm"

%include "render/fill.asm"

%include "input.asm"

section .bss

  vec_buf: resb 3000
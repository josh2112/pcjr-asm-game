; Foster's Quest
; Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'std/stdio.mac.asm'
%include 'std/math.mac.asm'
%include 'std/input.mac.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

  orig_video_mode: db 0

  orig_int08: dd 0
  orig_int08_countdown: db 4

  path_room1: db "room1.vec", 0

  ptr_err: dw 0
  str_fileError: db "Error reading file$"

  is_running: db 1

  player_walk_dir: db KEYCODE_NONE   ; See "KEYCODE_" defines

  player_x: dw 160
  player_y: dw 100
  player_x_prev: dw 160
  player_y_prev: dw 100

  player_icon: dw 14, 16,
    incbin "assets/icon/player.bin"

  redraw_countdown: db 8

  sound_1: incbin "assets/sounds/birdchrp.snd"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [orig_video_mode], al    ; Store it into the byte pointed to by originalVideoMode.

call dosbox_fix
call stack_fix

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0009h                ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

mov al, 08h
mov si, orig_int08
mov dx, on_timer
call hook_interrupt  ; Replace int 8 with on_timer

xor ah, ah
mov bx, 4000h
call set_timer_frequency ; Make 8253 timer 0 tick 4x as fast

in al, 61h
xor al, 60h
out 61h, al   ; Select CSG as sound source (bits 5 & 6)

mov ax, path_room1
call loadRoom
jnc room_loaded
mov word [ptr_err], str_fileError
jmp clean_up

room_loaded:

; Move cursor to text window and print a prompt
sub bh, bh       ; Set page number for cursor move (0 for graphics modes)
mov dx, 1600h    ; line 21 (0x15), col 0 (0x0)
mov ah, 2        ; Call "set cursor"
int 10h
print text_prompt
print_cursor

mov ax, sound_1
mov [sound_ptr], ax

game_loop:

  call process_keys          ; Check keyboard state

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  jz clean_up                ; jump out of game loop

  call handle_sound

  dec byte [redraw_countdown]  ; Is it time to redraw?
  jnz game_loop

  mov byte [redraw_countdown], 8  ; Reset redraw counter

  ; Copy player_[x,y] to player_[x,y]_prev
  mov ax, [player_x]
  mov [player_x_prev], ax
  mov ax, [player_y]
  mov [player_y_prev], ax

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

call mute_all

mov al, [orig_video_mode]
xor ah, ah
int 10h                  ; Restore original video mode

xor ah, ah
xor bx, bx
call set_timer_frequency ; Restore original timer frequency

mov al, 08h
mov si, orig_int08
call unhook_interrupt    ; Restore original int 8 handler

mov dx, [ptr_err]        ; Print error message if set
test dx, dx
jz exit
println dx

exit:
mov ax, 4c00h
int 21h                  ; Exit the program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

on_timer:
  cmp word [cs:next_sound_counter], 0 ; Decrement sound counter if nonzero
  jz .next
  dec word [cs:next_sound_counter]
  
  .next:
  dec byte [cs:orig_int08_countdown]  ; Decrement int 8 countdown
  jz .call_orig_int08                 ; If that made it 0, call the original int 8
  push ax
  mov al, 20h
  out 20h, al        ; Acknowledge the interrupt (20h to the 8259 PIC)
  pop ax
  iret

  .call_orig_int08:
  mov byte [cs:orig_int08_countdown], 4 ; Reset the int 8 countdown
  jmp far [cs:orig_int08]               ; and far-jump to the original int 8

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

%include "std/timer.asm"

%include "std/int.asm"

%include "std/stdio.asm"

%include "std/stopwatch.asm"

%include "render/320x200x16.asm"

%include "render/load_room.asm"

%include "render/draw_line.asm"

%include "render/fill.asm"

%include "sound.asm"

%include "input.asm"

section .bss

  vec_buf: resb 3000
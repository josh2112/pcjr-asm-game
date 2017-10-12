; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'stdio.mac'
%include 'graphics.mac'

section .data

str_crlf: db 0xa, 0xd, '$'
str_left: db 'l$'
str_right: db 'r$'
str_up: db 'u$'
str_down: db 'd$'

is_running: db 1

movement_key: db 0

gfx_player: db 0x3c, 0x3c, 0x18, 0xff, 0x18, 0x24, 0x24, 0xc3
pos_player_x: dw 160
pos_player_y: dw 100

scancode_esc: equ 1
scancode_up: equ 0x48
scancode_left: equ 0x4b
scancode_right: equ 0x4d
scancode_down: equ 0x50

section .bss

originalVideoMode: resb 1
buf16: resb 16
oldInt9h: resb 4

alignb 16
gfx_offscreen: resb 0x8000


section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH = 0x00 (set video mode), AL = 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_int_handlers

mov cl, 4
mov ax, gfx_offscreen               ; start of video memory
shr ax, cl
mov es, ax
mov dl, 1                    ; Clear screen to color 1
call cls

game_loop:
  cmp byte [is_running], 0
  je clean_up

  call do_movement

  call draw_player

  jmp game_loop

clean_up:

call restore_int_handlers

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 4c00h
int 21h

;;;;;;;;;;;;;;;;;;;;;

do_movement:
  mov ax, [pos_player_x]
  mov bx, [pos_player_y]
.testUp:
  cmp byte [movement_key], scancode_up
  jne .testDown
  cmp bx, 0
  je .done
  dec bx
.testDown:
  cmp byte [movement_key], scancode_down
  jne .testLeft
  cmp bx, 200-8
  je .done
  inc bx
.testLeft:
  cmp byte [movement_key], scancode_left
  jne .testRight
  cmp ax, 0
  je .done
  dec ax
.testRight:
  cmp byte [movement_key], scancode_right
  jne .done
  cmp ax, 320-8
  je .done
  inc ax
.done:
  mov [pos_player_x], ax
  mov [pos_player_y], bx
  ret

handle_int9h:
  push ax
  push di
  pushf

  xor ax, ax
  in al, 60h             ; Read from keyboard

  cmp al, scancode_esc
  je .esc

  test al, 0x80         ; If high bit is set it's a key release
  jnz .keyReleased

.keyPressed:
  mov [movement_key], al
  jmp .done
.keyReleased:
  and al, 0x7f            ; Remove key-released flag
  cmp [movement_key], al
  jne .done
  mov byte [movement_key], 0
  jmp .done
.esc:
  xor al, al
  mov [is_running], al
.done:
  ; Clear keyboard IRQ if pending
  in al, 61h     ; Grab keyboard state
  or al, 80h     ; Flip on acknowledgement bit
  out 61h, al    ; Send it
  and al, 0x7f   ; Restore previous value
  out 61h, al    ; Send it again
  sti
  ; Signal end-of-interupt
  mov al, 20h
  out 20h, al
  ; Restore state
  popf
  pop di
  pop ax
  iret

install_int_handlers:
  cli                               ; Disable interrupts
  xor ax, ax
  mov es, ax                        ; Set ES to 0
  mov dx, [es:9h*4]                 ; Copy the offset of the INT 9h handler
  mov [oldInt9h], dx                ; Store it in oldInt9h
  mov dx, [es:9h*4+2]               ; Then copy the segment
  mov [oldInt9h+2], dx              ; Store it in oldInt9h + 2
  mov word [es:9h*4], handle_int9h  ; Install the new handle - first the offset,
  mov word [es:9h*4+2], cs          ; Then the segment
  sti                               ; Reenable interrupts
  ret

restore_int_handlers:
  cli
  xor ax, ax
  mov es, ax
  mov dx, [oldInt9h]
  mov word [es:9h*4], dx
  mov dx, [oldInt9h+2]
  mov word [es:9h*4+2], dx
  sti
  ret

%include 'formatting.asm'
%include '320x200x16.asm'

draw_player:
  mov cx, 8
  .drawRow:
    mov ax, 8
    sub ax, cx
    mov di, ax
    add ax, [pos_player_y]            ; AX = row (y)
    mov byte dl, [gfx_player+di]   ; DL is now one row of player data
    push cx
    mov cx, 8
    .drawPixel:
      mov bx, 8
      sub bx, cx
      add bx, [pos_player_x]        ; BX = col (x)
      shl dl, 1                 ; pop the leftmost bit into the carry flag
      jnc .skip                 ; if carry flag is 0, skip over pixel-painting
      push ax
      push cx
      push dx
      mov dl, 10
      call putpixel             ; (BX, AX) = (x,y), DL = color
      pop dx
      pop cx
      pop ax
    .skip:
      loop .drawPixel
    pop cx
    loop .drawRow
  ret

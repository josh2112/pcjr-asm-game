; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'std/stdio.mac'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

  FRAMEBUFFER_SEG: dw 0x1800
  BACKGROUND_SEG: dw 0x2000
  COMPOSITOR_SEG: dw 0x2800
  ; 0x3000, 0x3800 are two other available 32kb chunks

  str_crlf: db 0xa, 0xd, '$'
  err_notEnoughMemory: db 'Error: Not enough free memory to play this dazzling game!$'

  color_bg: db 1

  is_running: db 1

  player_x: dw 160
  player_y: dw 100
  player_w: dw 14
  player_h: dw 16
  player_x_prev: dw 160
  player_y_prev: dw 100

  keyboardState: times 128 db 0

  draw_rect_xy_ptr: dw 0
  draw_rect_w: dw 14
  draw_rect_h: dw 16

  icon_player:
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
  buf16: resb 16

  oldInt9h: resb 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0x0f00               ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 0x0009               ; AH = 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

; Fill all buffers with the initial background color
mov dl, [color_bg]
mov di, [BACKGROUND_SEG]
mov es, di
call fill_page
mov di, [COMPOSITOR_SEG]
mov es, di
call fill_page
mov di, [FRAMEBUFFER_SEG]
mov es, di
call fill_page


call install_keyboard_handler


game_loop:

  ; Copy player_[x,y] to player_[x,y]_prev
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw

  call process_key           ; Do something with the key

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  je clean_up                ; jump out of game loop

  call waitForRetrace

  mov di, [COMPOSITOR_SEG]
  mov es, di

  mov si, player_x_prev
  mov [draw_rect_xy_ptr], si
  mov dl, [color_bg]
  call draw_rect             ; Erase to BG color at player's previous position

  mov di, player_x
  mov [draw_rect_xy_ptr], di
  mov si, icon_player
  call draw_icon             ; Draw the player icon

  mov ax, [player_x_prev]
  sub ax, 1
  mov bx, [player_y_prev]
  sub bx, 1
  mov cx, [player_w]
  add cx, 2
  mov dx, [player_h]
  add dx, 2
  push dx
  push cx
  push bx
  push ax
  push word [COMPOSITOR_SEG]
  push word [FRAMEBUFFER_SEG]
  call blt_rect

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

; Copies the icon pointed to by SI to the X,Y location referenced
; by [draw_rect_xy_ptr] with a size of [draw_rect_w], [draw_rect_h].
; NOTE: X and width must be even!
draw_icon:
  mov cx, [draw_rect_h]

.copyLine:
  mov ax, [draw_rect_h]
  sub ax, cx  ; Now AX is the icon line number
  
  push cx

  mov di, [draw_rect_xy_ptr] ; dereference Y location
  add ax, [di+2] ; Now AX is the framebuffer row number

  ; Set DI to start byte of left side of line
  mov bx, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX is the row within the bank

  and bx, 0b11    ; BX = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying BX by the
  shl bx, cl      ; bank width (0x2000): shift left by 13.
  ; Now BX is bank offset

  ; Calc byte index of pixel: BX += (AX * 320 + rect_x) / 2
  push bx
  mov bx, 320
  push dx
  mul bx
  pop dx
  add ax, [di]   ; add X
  shr ax, 1      ; Because each byte encodes 2 pixels
  pop bx
  add ax, bx

  mov di, ax

  mov cx, [draw_rect_w]
  shr cx, 1      ; Because each byte encodes 2 pixels

.copyByte:
  mov al, [si]
  test al, al
  jz .afterCopyByte
  mov [es:di], al
.afterCopyByte:
  inc si
  inc di
  loop .copyByte

  pop cx
  loop .copyLine

  ret

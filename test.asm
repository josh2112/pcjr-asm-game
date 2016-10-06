; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%define VIDEO_SEG 0xb800

%include 'std/stdio.mac'

%macro setIndicator 1
  xor di, di
  mov al, %1
  stosb
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

str_crlf: db 0xa, 0xd, '$'

color_bg: db 0x1
color_player: db 0xa

is_running: db 1

player_x: dw 1
player_y: dw 100

player_x_prev: dw 160
player_y_prev: dw 100

keyboardState: times 128 db 0

draw_rect_xy_ptr: dw 0
draw_rect_w: dw 8
draw_rect_h: dw 8

icon_player: db \
  0x0f, 0xaa, 0xf0, 0x00, \
  0x0a, 0xaa, 0xa0, 0x00, \
  0x00, 0xaa, 0x00, 0x00, \
  0x2a, 0xaa, 0xa2, 0x00, \
  0x00, 0xaa, 0x00, 0x00, \
  0x0a, 0xaa, 0xa0, 0x00, \
  0x0a, 0x00, 0xa0, 0x00, \
  0x22, 0x00, 0x22, 0x00

icon_player_odd: db \
  0x00, 0xfa, 0xaf, 0x00, \
  0x00, 0xaa, 0xaa, 0x00, \
  0x00, 0x0a, 0xa0, 0x00, \
  0x02, 0xaa, 0xaa, 0x20, \
  0x00, 0x0a, 0xa0, 0x00, \
  0x00, 0xaa, 0xaa, 0x00, \
  0x00, 0xa0, 0x0a, 0x00, \
  0x02, 0x20, 0x02, 0x20

section .bss

originalVideoMode: resb 1
buf16: resb 16

oldInt9h: resb 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH = 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_keyboard_handler

mov di, VIDEO_SEG   ; ES to destination (framebuffer)
push es
mov es, di

mov dl, [color_bg]   ; Fill the background buffer
call cls

game_loop:

  ; Copy player_[x,y] to player_[x,y]_prev
  push es
  mov di, ds
  mov es, di
  mov si, player_x
  mov di, player_x_prev
  mov cx, 2
  rep movsw
  pop es

  call process_key           ; Do something with the key

  cmp byte [is_running], 0   ; If not running (ESC key pressed),
  je clean_up                ; jump out of game loop

  call waitForRetrace

  setIndicator 0x44

  ;mov di, player_x_prev
  ;mov [draw_rect_xy_ptr], di
  ;mov dl, [color_bg]
  ;call draw_rect             ; Erase to BG color at player's previous position

  ;mov di, player_x
  ;mov [draw_rect_xy_ptr], di
  ;mov dl, [color_player]
  ;call draw_rect             ; Draw the player rectangle

  mov di, player_x
  mov [draw_rect_xy_ptr], di
  mov si, icon_player
  call draw_icon               ; Draw the player icon

  setIndicator 0xaa

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

; Copies the 8x8 icon pointed to by SI to the X, Y location referenced
; by [draw_rect_xy_ptr].
draw_icon:
  mov cx, 8  ; Icon height
.copyLine:
  mov ax, 8
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

  ; Calc byte index of pixel: BX += (AX * 320 + rect_bitblt.x) / 2
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

  mov cx, 4
.copyByte:
  lodsb            ; AL is a byte from the icon
  mov ah, [es:di]  ; AH is a byte from the framebuffer

  ;xchg al, ah

  stosb
  loop .copyByte

  pop cx
  loop .copyLine

.done:
  ret

; Draws a rectangle of color DL to the X,Y location referenced by
; [draw_rect_xy_ptr] with a size of [draw_rect_w], [draw_rect_h].
; NOTE: [draw_rect_w] must be even!
draw_rect:
  push bp     ; Locals:
  mov bp, sp  ; [bp-1]: flags: 0x1 = only fill inner pixels of first and last bytes
  sub sp, 3   ; [bp-3]: number of whole bytes to copy on each line

  mov dh, dl
  mov cl, 4
  shl dh, cl
  or dl, dh   ; Now DL contains color twice

  mov si, [draw_rect_xy_ptr]  ; address of X, Y
  mov ax, [si]                ; dereference again to get X
  and al, 0x1
  mov [bp-1], al

  mov bx, [draw_rect_w]
  shr bx, 1
  cmp ax, 0x1
  jne .afterSub1
  dec bx
.afterSub1:
  mov [bp-3], bx      ; # full bytes on each line

  mov cx, [draw_rect_h] ; Number of lines to copy

.copyLine:
  mov ax, [draw_rect_h]
  sub ax, cx
  push cx

  mov di, [draw_rect_xy_ptr] ; dereference Y location
  add ax, [di+2]

  ; Set SI and DI to start byte of left side of line
  mov si, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX = row within bank

  and si, 0b11    ; SI = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying SI by the
  shl si, cl      ; bank width (0x2000): shift left by 13.

  ; Calc byte index of pixel: SI += (AX * 320 + rect_bitblt.x) / 2
  mov bx, 320
  push dx
  mul bx
  pop dx
  add ax, [di]   ; add X
  shr ax, 1      ; Because each byte encodes 2 pixels
  add si, ax

  mov di, si

  test byte [bp-1], 0x1
  jz .afterFirstByte
  mov al, [es:di]  ; load the pixel pair
  and al, 0xf0     ; mask out the bottom pixel (keeping the top)
  mov dh, dl
  and dh, 0x0f     ; mask out the top pixel
  or al, dh
  stosb
.afterFirstByte:

  mov cx, [bp-3]
  mov al, dl
  rep stosb         ; Copy CX bytes

  test byte [bp-1], 0x1
  jz .afterLastByte
  mov al, [es:di]  ; load the pixel pair
  and al, 0x0f     ; mask out the top pixel (keeping the bottom)
  mov dh, dl
  and dh, 0xf0     ; mask out the bottom pixel
  or al, dh
  stosb
.afterLastByte:

  pop cx
  loop .copyLine

.done:
  mov sp, bp      ; Destroy locals
  pop bp

  ret

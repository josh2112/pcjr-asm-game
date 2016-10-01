; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%define VIDEO_SEG 0xb800

%include 'std/stdio.mac'

%macro setIndicator 1
  mov di, VIDEO_SEG
  mov es, di
  xor di, di
  mov al, %1
  stosb
%endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

str_crlf: db 0xa, 0xd, '$'
err_notEnoughMemory: db 'Error: Not enough free memory to play this dazzling game!$'

color_bg: db 1
color_player: db 10
color_draw_rect: db 0

is_running: db 1
player_x: dw 160
player_y: dw 100

keyboardState: times 128 db 0

bg_pattern1: dw 0x1111
bg_pattern2: dw 0x1911
bg_pattern3: dw 0x1911
bg_pattern4: dw 0x1999

rect_bitblt_x: dw 0
rect_bitblt_y: dw 0
rect_bitblt_w: dw 320
rect_bitblt_h: dw 200

section .bss

originalVideoMode: resb 1
buf16: resb 16

oldInt9h: resb 4

offscreenSeg: resw 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Try to allocate enough memory for the background buffer
; 320x200 = 64k pixels / 2 pixels per byte = 32KB (0x8000 bytes)
mov bx, 0x800  ; 0x8000 bytes in paragraphs
mov ah, 0x48
int 21h            ; Call INT21H fn 0x48
jnc memOK
  ; If carry bit is set the allocation failed - print message and exit
  println err_notEnoughMemory
  mov ax, 0x4c00
  int 21h
memOK:
mov [offscreenSeg], ax

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH = 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH = 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

call install_keyboard_handler

;call create_background
mov di, [offscreenSeg]
mov es, di
mov dl, [color_bg]   ; Fill the background buffer
call cls

call blt_rect        ; Copy the whole background buffer to the screen

mov word [rect_bitblt_w], 8
mov word [rect_bitblt_h], 8

game_loop:

  mov ax, [player_x]
  mov [rect_bitblt_x], ax
  mov ax, [player_y]
  mov [rect_bitblt_y], ax

  call process_key           ; Do something with the key

  cmp byte [is_running], 0   ; If still running (ESC key not pressed),
  je clean_up                ; jump back to game_loop

  call waitForRetrace

  setIndicator 0x44

  call blt_rect             ; Erase to background at the player's previous position
  call blt_rect             ; Erase to background at the player's previous position
  call blt_rect             ; Erase to background at the player's previous position
  call blt_rect             ; Erase to background at the player's previous position

  ;mov dl, [color_player]
  ;mov [color_draw_rect], dl
  ;call draw_rect             ; Draw the player graphic

  setIndicator 0xee

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

create_background:
  mov di, [offscreenSeg]
  mov es, di
  mov cx, 200
.paintRow:
  mov bx, cx
  sub bx, 200
  push cx
  mov cx, 160
  rep stosw
  ret

; Copies the rectangle specified by rect_bitblt from the
; offscreen buffer to the framebuffer.
blt_rect:
  push bp
  mov bp, sp  ; Locals:
  sub sp, 2   ;  - width of each line copy (in bytes): 2 bytes at [bp-2]

  push ds         ; Set DS to source (offscreen buffer) and
  push es         ; ES to destination (framebuffer)
  mov si, [offscreenSeg]
  mov ds, si
  mov di, VIDEO_SEG
  mov es, di

  ; Calculate number of extra bytes to add to stosb count
  ; due to X position or width being odd
  mov ax, [cs:rect_bitblt_x]
  and ax, 0x1
  mov bx, [cs:rect_bitblt_w]
  and bx, 0x1
  add ax, bx

  mov bx, [cs:rect_bitblt_w] ; Width of each line to copy
  shr bx, 1                  ; Because each byte encodes 2 pixels
  add bx, ax                 ; Add any extra bytes
  mov [bp-2], bx             ; Store as local variable

  mov cx, [cs:rect_bitblt_h] ; Number of lines to copy

.copyLine:
  mov ax, [cs:rect_bitblt_h]
  sub ax, cx
  add ax, [cs:rect_bitblt_y]  ; Now AX is vertical line number
  push cx

  ; Set SI and DI to start byte of left side of line
  mov si, ax      ; Faster alternative to dividing AX by 4: shift
  shr ax, 1       ; right twice for quotient, mask with 0b11 for
  shr ax, 1       ; remainder. Now AX = row within bank

  and si, 0b11    ; SI = bank number (0-3)
  mov cl, 13      ; Faster alternative to multiplying SI by the
  shl si, cl      ; bank width (0x2000): shift left by 13.


  ; Calc byte index of pixel: SI += (AX * 320 + rect_bitblt.x) / 2
  mov bx, 320
  mul bx
  add ax, [cs:rect_bitblt_x]
  shr ax, 1   ; Because each byte encodes 2 pixels
  add si, ax

  mov di, si

  mov cx, [bp-2]
  rep movsb                  ; Copy CX bytes

  pop cx
  loop .copyLine

.done:
  pop es
  pop ds          ; Restore our segment registers
  mov sp, bp      ; Destroy locals
  pop bp

  ret

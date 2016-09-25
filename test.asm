; test.asm: Playing around with IBM PCjr text, graphics and sound routines

[cpu 8086]
[org 100h]

%include 'stdio.mac'
%include 'graphics.mac'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data

str_crlf: db 0xa, 0xd, '$'

is_running: db 1
player_x: dw 160
player_y: dw 100

section .bss

originalVideoMode: resb 1
buf16: resb 16

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text

; Get the initial video mode and save it to [originalVideoMode]
mov ax, 0f00h                ; AH <- 0x0f (get video mode)
int 10h                      ; Call INT10h fn 0x0f which will store the current video mode in AL
mov [originalVideoMode], al  ; Store it into the byte pointed to by originalVideoMode.

; Change the video mode to Mode 9 (320x200, 16 colors)
mov ax, 9h                   ; AH <- 0x00 (set video mode), AL <- 9 (new mode)
int 10h                      ; Call INT10h fn 0 to change the video mode

game_loop:
  mov dl, 1
  call cls

  call draw_player

  xor ax, ax
  int 16h
  call process_key

  cmp byte [is_running], 0
  jne game_loop

clean_up:

; Change the video mode back to whatever it was before (the value stored in
; originalVideoMode)
mov al, [originalVideoMode]
xor ah, ah
int 10h

; Exit the program
mov ax, 4c00h
int 21h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include 'formatting.asm'
%include '320x200x16.asm'

process_key:
  cmp ah, 1
  jne .testUp
  mov byte [is_running], 0
  jmp .done
.testUp:
  cmp ah, 0x48
  jne .testDown
  dec word [player_y]
  jmp .done
.testDown:
  cmp ah, 0x50
  jne .testLeft
  inc word [player_y]
  jmp .done
.testLeft:
  cmp ah, 0x4b
  jne .testRight
  dec word [player_x]
  jmp .done
.testRight:
  cmp ah, 0x4d
  jne .done
  inc word [player_x]
.done:
  ret

draw_player:
  mov cx, 8
  .drawRow:
    mov ax, 8
    sub ax, cx
    add ax, [player_y]      ; AX = row (y)
    push cx
    mov cx, 8
    .drawPixel:
      mov bx, 8
      sub bx, cx
      add bx, [player_x]    ; BX = col (x)
      push ax
      push cx
      mov dl, 10
      call putpixel         ; (BX, AX) = (x,y), DL = color
      pop cx
      pop ax
      loop .drawPixel
    pop cx
    loop .drawRow
  ret

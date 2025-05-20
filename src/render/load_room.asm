section .data

    label_timer_color: db "cl $"
    label_timer_depth: db "  dp $"
    label_timer_f2b:  db "  f2b $"

section .text


loadRoom:
  ; Load vector file
  mov si, vec_buf
  push si
  push ax
  call read_file
  jc .end

  ; Fill the background buffer with the base color (4)
  mov ax, 0x4444
  mov es, [BACKGROUND_SEG]
  mov di, 0
  mov cx, 320*168/4    ; w * h / pixels_per_word
  rep stosw

  ; Fill the framebuffer with white
  mov ax, 0xffff
  mov es, [FRAMEBUFFER_SEG]
  mov di, 0
  mov cx, 320*168/4/4  ; w * h / pixels_per_word / num_banks
  rep stosw

  mov di, 2000h
  mov cx, 320*168/4/4
  rep stosw

  mov di, 4000h
  mov cx, 320*168/4/4
  rep stosw

  mov di, 6000h
  mov cx, 320*168/4/4
  rep stosw

  call StartTime

  .read_next_cmd:

  ; DS:SI = position in vector file

  lodsb   ; look at next byte in vector file

  cmp al, 'C'          ; Color?
  jne .cmp_moveto
  lodsb
  mov [vec_color], al  ; Read 1 byte into vec_color
  jmp .read_next_cmd

  .cmp_moveto:
  cmp al, 'M'
  jne .cmp_lineto
  lodsw
  mov [vec_pos], ax    ; Read 2 bytes into vec_pos
  jmp .read_next_cmd

  .cmp_lineto:
  cmp al, 'L'
  jne .cmp_fill
  lodsw
  mov [vec_dest], ax   ; Read 2 bytes into vec_dest
  call drawline
  jmp .read_next_cmd

  .cmp_fill:
  cmp al, 'F'
  jne .cmp_begindepth
  push word [vec_pos]
  call fill           ; Fill
  jmp .read_next_cmd

  .cmp_begindepth:
  cmp al, 'D'
  jne .after_draw  ; Else it's E (finished), quit
  
  mov dx, 1500h
  sub bh, bh
  mov ah, 2
  int 10h        ; Move cursor to line 21
  call EndTime
  print label_timer_color
  call PrintTime ; Print time for color drawing and reset the timer
  call StartTime

  ; Set up for depth drawing!
  mov es, [BACKGROUND_SEG]
  mov byte [vec_clear_color], 0x44
  jmp .read_next_cmd

  .after_draw:

  call EndTime
  print label_timer_depth
  call PrintTime ; Print time for vector drawing and reset the timer
  call StartTime

  call copy_framebuffer_to_background

  call EndTime
  print label_timer_f2b
  call PrintTime ; Print time for vector drawing and reset the timer
  
  .end:
  ret

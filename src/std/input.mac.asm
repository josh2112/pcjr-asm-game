
%ifndef INPUT_MAC_ASM
%define INPUT_MAC_ASM

%define KEYCODE_NONE 0x00
%define KEYCODE_ESC 0x01
%define KEYCODE_ENTER 0x1c
%define KEYCHAR_BACKSPACE 0x08
%define KEYCODE_UP 0x48
%define KEYCODE_LEFT 0x4b
%define KEYCODE_RIGHT 0x4d
%define KEYCODE_DOWN 0x50

%macro print_no_advance 1
  mov ax, 0a00h + %1
  mov bx, 07h
  mov cx, 1
  int 10h
%endmacro

%macro print_cursor 0
  print_no_advance 5fh
%endmacro

%macro clear_cursor 0
  print_no_advance 20h
%endmacro


%endif ; INPUT_MAC_ASM
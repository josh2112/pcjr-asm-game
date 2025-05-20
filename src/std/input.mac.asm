
%ifndef INPUT_MAC_ASM
%define INPUT_MAC_ASM

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
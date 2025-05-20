
%ifndef MATH_MAC_ASM
%define MATH_MAC_ASM

; al = abs( al )
%macro abs_al 0
  cbw
  xor al, ah
  sub al, ah
%endmacro

%endif ; MATH_MAC_ASM
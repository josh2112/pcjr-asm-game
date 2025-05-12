
%ifndef MATH_ASM
%define MATH_ASM

; al = abs( al )
%macro abs_al 0
  cbw
  xor al, ah
  sub al, ah
%endmacro

%endif ; MATH_ASM
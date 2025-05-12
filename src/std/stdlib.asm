; stdlib.asm: Routines for 8088 assembly that would be classified as "stdlib"
; in C, such as data conversion, memory allocation, etc.

; Much like C/C++, these %ifndef/%define/%endif keep the file from being
; accidentally included multiple times
%ifndef STDLIB_ASM
%define STDLIB_ASM

; TODO: Abrash on converting a binary digit to hex ASCII:
; ADD  AL,90H
; DAA
; ADC  AL,40H
; DAA


; Converts the signed integer in AX to a string and puts it in [DI]
; Returns the result (the original DI pointer) in AX
; Clobbers BX, CX, DX
int_to_string:
  push di             ; Save the original DI pointer so we can pop it out
                      ; and return it as AX
  mov bx, 10          ; Load divisor and clear counter
  xor cx, cx
  test ax, ax
  jns .peelOffDigits  ; Is AX signed? If not, go to 'continue'
  mov byte [di], '-'  ; Put a negative sign on the string and increment our pointer
  inc di
  neg ax              ; Negate to make positive
  .peelOffDigits:
    xor dx, dx        ; Zero the high-word of the divisor
    div bx            ; This will give us the remainder in DX
    push dx           ; Push it onto the stack
    inc cl            ; Increment our counter
    test ax, ax       ; If no remainder, we're done
    jnz .peelOffDigits
  .buildString:
    pop ax            ; Pop out the next digit
    add al, '0'       ; Add 48 to get the ascii value
    stosb             ; Store the char in AL into [DI], then increment DI
    loop .buildString
  mov byte [di], '$'  ; Terminate the string
  pop ax              ; Pop the original DI into AX
  ret

%endif ; STDLIB_ASM

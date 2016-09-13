[cpu 8086]
[org 100h]

mov ax, 65432         ; Load AX with the number we want to print
mov di, buf16         ; Load DI with the address of an empty buffer

mov bx, 10            ; Load divisor and clear counter
mov cx, 0
peelOffDigits:
  xor dx, dx
  div bx              ; This will give us the remainder in DX
  push dx             ; Push it onto the stack
  inc cl              ; Increment our counter
  test ax, ax         ; If no result, we're done
  jnz peelOffDigits
buildString:
  pop ax              ; Pop out the next digit
  add al, '0'         ; Add 48 to get the ascii value
  stosb               ; Store the char in AL into the location at
                      ; [DI], then increment DI
  loop buildString    ; Continue if we have more digits

mov byte [di], '$'  ; Terminate the string

mov dx, buf16         ; Load DX with the address of the buffer
mov ah, 9             ; Load AH with 9
int 21h               ; Call INT21h fn 9 to print the buffer

mov ax, 4c00h         ; Call INT21h fn 0x4c to exit the program
int 21h

buf16: times 16 db 0  ; An empty 16-byte buffer

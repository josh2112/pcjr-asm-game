[cpu 8086]
[org 100h]

jmp main

%include 'formatting.asm'
%include 'stdio.mac'

main:

mov ax, -1234         ; Load AX with the number we want to print
mov di, buf16         ; Load DI with the address of an empty buffer

call int_to_string    ; Call our 'int-to-string' procedure to format the number

print buf16           ; Call our 'print' macro to print the formatted number

mov ax, 4c00h         ; Call INT21h fn 0x4c to exit the program
int 21h

buf16: times 16 db 0  ; An empty 16-byte buffer

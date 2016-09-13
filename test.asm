[cpu 8086]
[org 100h]

mov dx, str_msg
mov ah, 9h
int 21h

mov ax, 4c00h
int 21h

str_msg: db 'Hello, PCjr!', 0ah, 0dh, '$'

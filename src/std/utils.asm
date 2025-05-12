
%ifndef UTILS_ASM
%define UTILS_ASM

; DOSBOX STUFF: DOSBox gives us a tiny block of about 2kb. Expand that to a whole segment.
dosbox_fix:
mov bx, 1000h
mov ax, 4a00h
int 21h         ; Reallocate segment at ES (our PSP) to 64k
mov cl, 4
shl bx, cl
pop cx          ; Grab the IP so we can move it with the stack
mov sp, bx      ; Set the stack to the top of whatever was allocated
sub ax, ax
push ax         ; Push our zero word that DOS expects
push cx
ret

; Stack management - The stack pointer will likely be in the middle of our framebuffers. If so, move
; it to just before the start of the first buffer. If not (DOSBOX will probably load us above the
; video memory), skip.
stack_fix:
mov ax, ss
cmp ax, [FRAMEBUFFER_SEG]
jg .end   ; If past the end of the framebuffer (SS > FRAMEBUFFER_SEG), all good
; Else, if past the beginning of our buffers (SS:SP > BACKGROUND_SEG), move SP down appropriately
mov cl, 4
shl ax, cl
add ax, sp  ; Absolute SP
cmp ax, [BACKGROUND_SEG]
jl .end
mov ax, [BACKGROUND_SEG]
mov bx, ss
sub ax, bx
mov cl, 4
shl ax, cl
pop cx          ; Grab the IP so we can move it with the stack
mov sp, ax      ; SP = (BACKGROUND_SEG - SS) << 4
xor ax, ax
push ax         ; Push our zero word that DOS expects
push cx

.end:
ret

%endif ; UTILS_ASM
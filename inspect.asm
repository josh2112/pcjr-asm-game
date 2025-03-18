
section .data

str_cx: db 'cx=$'
str_cs: db 'cs=$'
str_sp: db 'sp=$'

section .text

inspect:
    push sp
    push cx

    print str_cx
    pop cx
    wordToString buf16, cx
    println buf16

    print str_cs
    wordToString buf16, cs
    println buf16

    print str_sp
    pop sp
    wordToString buf16, sp
    println buf16
    
    ret
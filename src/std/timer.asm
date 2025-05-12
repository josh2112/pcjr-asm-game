section .bss

Minutes:  resb 1
Hours:	  resb 1
Sec100:   resb 1
Seconds:  resb 1

section .data

NumBuf: db '00$'

section .text

; Store start time
StartTime:
	MOV	AH,2CH		;Get time function
    INT 21h         ;Get starting time
	MOV	word [Minutes],CX	;Save starting time
	MOV	word [Sec100], DX	; ..
	RET                     ; ..

; Retrieve end time and calculate elapsed
EndTime:
	MOV	AH,2CH		;Get time function
    INT 21h         ;Get ending time
	SUB	DL,[Sec100]	;Calculate hundreds of seconds
	JNC	.SubSec		; ..
	ADD	DL,100		; ..
	DEC	DH		; ..
.SubSec:
	MOV	[Sec100],DL	;Save hundreds of seconds
	SUB	DH,[Seconds]	;Calculate seconds
	JNC	.SubMin		; ..
	ADD	DH,60		; ..
	DEC	CL		; ..
.SubMin:
	MOV	[Seconds],DH	;Save seconds
	SUB	CL,[Minutes]	;Calculate minutes
	JNC	.SubHrs		; ..
	ADD	CL,60		; ..
	DEC	CH		; ..
.SubHrs:
	MOV	[Minutes],CL	;Save minutes
	SUB	CH,[Hours]	;Calculate hours
    JNC .SubHrs1         ; ..
	ADD	CH,24		; ..
.SubHrs1:
	MOV	[Hours],CH	;Save hours
    RET                     ; ..

;Print the total time
PrintTime:
	push es
	mov di, cs
	mov es, di
	STD			;Make sure string ops go backward
	MOV	DL,[Hours]	;Print the hours
	CALL	Bin2Dec		; ..
	MOV	AH,2		;Print a colon
	MOV	DL,':'		; ..
    INT     21h             ; ..
	MOV	DL,[Minutes]	;Print the minutes
	CALL	Bin2Dec		; ..
	MOV	AH,2		;Print a colon
	MOV	DL,':'		; ..
    INT     21h             ; ..
	MOV	DL,[Seconds]	;Print the seconds
	CALL	Bin2Dec		; ..
	MOV	AH,2		;Print a period
	MOV	DL,'.'		; ..
	
    INT     21h             ; ..
	MOV	DL,[Sec100]	;Print the hundred of seconds
	CALL	Bin2Dec		; ..
	pop es
	clc            ; Reset carry/direction flags
	cld
    RET

;-------------------------------------------------------------------------------

;Subroutine to convert binary number in DL to decimal on console

Bin2Dec:
	XOR	DH,DH		  ;Clear upper half of DX
	MOV	BX,10		  ;Get divisor
	MOV	DI, NumBuf+1  ;Point to print buffer
.BinOut:
	MOV	AX,DX		;Numerator
	XOR	DX,DX		;Clear upper half
	DIV	BX		; ..
	XCHG	AX,DX		;Get quotient
	ADD	AL,30H		;Convert to ASCII
	STOSB			;Put in buffer
	OR	DX,DX		;Done?
	JNZ	.BinOut		;No

;Print the buffer
.PrintNum:
	CMP	DI, NumBuf ;See if only 1 digit
	JB	.PrintNum1	   ; ..
	MOV	AL,'0'		;Yes, put a leading zero in number buffer
	STOSB			; ..asdf
.PrintNum1:
	MOV	AH,9		;Display string function
	MOV	DX,DI		;Get current position in number buffer
	INC	DX		; ..
    INT 21h             ;Call DOS
	RET

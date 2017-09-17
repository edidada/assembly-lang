#cmpstest1.s A simple example of the CMPS instruction
.code32
.section .data
value1:
	.ascii "Test"
value2:
	.ascii "Test"
.section .text
.globl main
main:
	movl $1, %eax
	leal value1, %esi
	leal value2, %edi
	cld
	cmpsl
	je equal
	movl $1, %ebx
	int $0x80
equal:
	movl $0, %ebx
	int $0x80

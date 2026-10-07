#an example of using the push and pop instructions
.code32
.section .data
data:
	.int 125
.section .text
.globl main
main:
	movl $24420, %ecx
	movw $350, %bx
# pushpop.s:11 原代码 `movb $100, %eax` 被 GNU as 拒绝（movb 的目标不能是 32 位
# 寄存器），书中该例为 `movb $100, %al`。原行保留但用 .if 0 变惰性，避免阻塞构建。
.if 0
	movb $100, %eax
.endif
	movb $100, %al
	pushl %ecx
	pushw %bx
	pushl %eax
	pushl data
	pushl $data

	popl %eax
	popl %eax
	popl %eax
	popw %ax
	popl %eax
	movl $0, %ebx
	movl $1, %eax
	int $0x80

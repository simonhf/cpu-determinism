burn_cpu:
	pushq	%r12
	pushq	%rbp
	pushq	%rbx
	movl	%edi, %ebx
	movl	$1, %edi
	subq	$48, %rsp
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %r12
	movq	$0, 8(%rsp)
	movq	%r12, %rsi
	movq	16(%rsp), %rbp
	movq	24(%rsp), %rax
	subq	ts_start(%rip), %rbp
	subq	8+ts_start(%rip), %rax
	jns	.L21
	subq	$1, %rbp
	addq	$1000000000, %rax
.L21:
	imulq	$1000000000, %rbp, %rbp
	addq	%rax, %rbp
.L22:
	movq	8(%rsp), %rax
	subl	$1, %ebx
	addq	$1, %rax
	movq	%rax, 8(%rsp)
	testl	%ebx, %ebx
	jg	.L22
	movq	%r12, %rsi
	movl	$1, %edi
	movq	24(%rsp), %rax
	subq	8+ts_start(%rip), %rax
	movq	%rax, %rdx
	movq	16(%rsp), %rax
	js	.L28
	subq	ts_start(%rip), %rax
.L24:
	imulq	$1000000000, %rax, %rax
	addq	%rdx, %rax
	subq	%rbp, %rax
	movq	40(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L29
	addq	$48, %rsp
	popq	%rbx
	popq	%rbp
	popq	%r12
	ret
.L28:
	subq	ts_start(%rip), %rax
	addq	$1000000000, %rdx
	subq	$1, %rax
	jmp	.L24
.L29:
	call	__stack_chk_fail@PLT

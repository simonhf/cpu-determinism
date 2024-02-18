burn_cpu:
	pushq	%r12
	xorl	%esi, %esi
	pushq	%rbp
	pushq	%rbx
	movl	%edi, %ebx
	subq	$48, %rsp
	movq	%fs:40, %rax
	movq	%rax, 40(%rsp)
	xorl	%eax, %eax
	leaq	16(%rsp), %r12
	movq	$0, 8(%rsp)
	movq	%r12, %rdi
	call	gettimeofday@PLT
	movq	16(%rsp), %rbp
	movq	24(%rsp), %rax
	subq	tv_start(%rip), %rbp
	subq	8+tv_start(%rip), %rax
	jns	.L18
	subq	$1, %rbp
	addq	$1000000, %rax
.L18:
	imulq	$1000000000, %rbp, %rbp
	imulq	$1000, %rax, %rax
	addq	%rax, %rbp
.L19:
	movq	8(%rsp), %rax
	subl	$1, %ebx
	addq	$1, %rax
	movq	%rax, 8(%rsp)
	testl	%ebx, %ebx
	jg	.L19
	xorl	%esi, %esi
	movq	%r12, %rdi
	call	gettimeofday@PLT
	movq	16(%rsp), %rax
	movq	24(%rsp), %rdx
	subq	tv_start(%rip), %rax
	subq	8+tv_start(%rip), %rdx
	jns	.L20
	subq	$1, %rax
	addq	$1000000, %rdx
.L20:
	imulq	$1000000000, %rax, %rax
	imulq	$1000, %rdx, %rdx
	addq	%rdx, %rax
	subq	%rbp, %rax
	movq	40(%rsp), %rdx
	subq	%fs:40, %rdx
	jne	.L24
	addq	$48, %rsp
	popq	%rbx
	popq	%rbp
	popq	%r12
	ret
.L24:
	call	__stack_chk_fail@PLT

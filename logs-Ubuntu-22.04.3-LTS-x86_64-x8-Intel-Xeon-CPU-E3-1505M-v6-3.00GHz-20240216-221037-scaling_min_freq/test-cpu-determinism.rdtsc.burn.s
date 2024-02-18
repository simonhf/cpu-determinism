burn_cpu:
	movq	$0, -8(%rsp)
	rdtsc
	movq	%rax, %rcx
	salq	$32, %rdx
	orq	%rdx, %rcx
.L21:
	movq	-8(%rsp), %rax
	subl	$1, %edi
	addq	$1, %rax
	movq	%rax, -8(%rsp)
	testl	%edi, %edi
	jg	.L21
	rdtsc
	salq	$32, %rdx
	orq	%rdx, %rax
	xorl	%edx, %edx
	subq	%rcx, %rax
	imulq	$1000000000, %rax, %rax
	divq	tsc_per_second(%rip)
	ret

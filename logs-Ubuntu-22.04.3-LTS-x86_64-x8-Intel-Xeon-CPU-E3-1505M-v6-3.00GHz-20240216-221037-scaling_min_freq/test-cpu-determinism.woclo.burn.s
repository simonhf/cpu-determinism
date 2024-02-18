burn_cpu:
	movq	$0, -8(%rsp)
.L11:
	movq	-8(%rsp), %rax
	subl	$1, %edi
	addq	$1, %rax
	movq	%rax, -8(%rsp)
	testl	%edi, %edi
	jg	.L11
	xorl	%eax, %eax
	ret

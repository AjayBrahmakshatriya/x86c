	.text
	.globl x86c_libc_put_char
x86c_libc_put_char:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	16(%rbp), %rsi
	movq	$1, %rdi
	movq	$1, %rdx
	movq	$1, %rax
	syscall
	leave
	retq
	

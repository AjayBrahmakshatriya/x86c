	.text
	.globl _x86c_libc_begin
_x86c_libc_begin:
	## x86c_libc_start HAS to be the first function
	.globl _x86c_libc_start
_x86c_libc_start:
	// Address of main to be inserted here
	movabsq	$0, %rax
	call	*%rax	
	movq	%rax, %rdi
	movq	$60, %rax
	syscall		
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
_x86c_libc_end:	

	.data 
	.globl _x86c_libc_size
_x86c_libc_size:
	.quad	_x86c_libc_end - _x86c_libc_begin

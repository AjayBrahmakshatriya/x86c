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
	.globl x86c_libc_syscall6
x86c_libc_syscall6:
	movq	8(%rsp), %r9
	movq	16(%rsp), %r8
	movq	24(%rsp), %r10
	movq	32(%rsp), %rdx
	movq	40(%rsp), %rsi
	movq	48(%rsp), %rdi
	movq	56(%rsp), %rax
	syscall
	retq
_x86c_libc_end:	
	.data 
	.globl _x86c_libc_size
_x86c_libc_size:
	.quad	_x86c_libc_end - _x86c_libc_begin

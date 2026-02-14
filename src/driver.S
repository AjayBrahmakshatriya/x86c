	.text
filenotfound:
	.asciz "File not found"
.equ filenotfound_len, . - filenotfound

filenamemissing:
	.asciz "Invoke as x86c <filename>\n"
.equ filenamemissing_len, . - filenamemissing

/* Calling conventions for x86c 
Arg1: %rsi
Arg2: %rdi
Arg3: %rdx
Arg4: %rcx
Return: %rax
Return2: %rbx

Global variables - %r10...

%r10 - token_read_head

*/

	.globl main
main:
	movq	%rsi, %rbx

	cmp	$2, %edi
	leaq	filenamemissing(%rip), %rdi
	movq	$filenamemissing_len, %rsi
	jl	report_error

	movq 	8(%rbx), %rdi
	movq	$2, %rax
	xorq	%rsi, %rsi
	xorq	%rdx, %rdx
	syscall	
	
	cmp	$0, %rax
	leaq	filenotfound(%rip), %rdi
	movq	$filenotfound_len, %rsi
	jl	report_error
	
	movq	%rax, %rdi
	movq	$0, %rax	
	leaq	program_source(%rip), %rsi
	movq	$40959, %rdx
	syscall
	
	movq	$3, %rax
	syscall

	leaq	program_source(%rip), %r10

token_loop:
	callq	get_token	
	jmp	token_loop

	xorq 	%rax, %rax
	retq



report_error:
	movq	$1, %rax
	movq	%rsi, %rdx
	movq	%rdi, %rsi
	movq	$2, %rdi
	syscall
report_error_loop:
	jmp report_error_loop


	.section .bss
program_source:
	.lcomm buffer, 40960

	.data
token_read_head:
	.quad program_source

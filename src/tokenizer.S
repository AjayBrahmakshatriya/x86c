.include "defs.inc"

	.data
keyword_table:
	.quad KEYWORD_char
	.quad KEYWORD_continue
	.quad KEYWORD_else
	.quad KEYWORD_if
	.quad KEYWORD_int
	.quad KEYWORD_long
	.quad KEYWORD_return
	.quad KEYWORD_sizeof
	.quad KEYWORD_void
	.quad KEYWORD_while	
	.quad 0
	
	.text
	.globl 	append_token
append_token:
	movq	token_end(%rip), %rax
	movq	%rdi, (%rax)
	leaq	8(%rax), %rax
	movq	%rax, token_end(%rip)
	retq	


/*
Assemble token in %rbx, %rcx, %rdx, %rsi
*/
	.globl get_token
get_token:
	xorq	%rbx, %rbx
	xorq	%rcx, %rcx
	xorq	%rdx, %rdx
	xorq	%rsi, %rsi
	xorq	%rax, %rax

	movb	(%r10), %al
	incq	%r10

	mov	%al, %bl
	
	testb	%al, %al
	jz	program_parsing_end	

	# Check - ! " # $ % & ' ( ) * + , - . /
	cmp	$48, %al
	jl	get_token_special_character

	# check - 0-9	
	cmp	$58, %al
	jl	get_token_integer_start

	# check : ; < = > ? 	
	cmp	$64, %al
	jl	get_token_special_character

	# check A - z, TODO: Change when supporting []
	cmp	$123, %al
	jl 	get_token_identifier_and_keyword

	cmp	$126, %al
	jl	get_token_special_character

shift_and_continue:
	movq	%rdx, %rsi
	movq	%rcx, %rdx
	movq	%rbx, %rcx
	xorq	%rbx, %rbx	

read_till_end:
	movabsq	$0xff00000000000000, %rax
	testq	%rax, %rbx
	jnz	shift_and_continue
	
	movb	(%r10), %al	
	incq	%r10
	
	testb 	%al, %al
	###
	jz	get_token_end

	cmp	$33, %al
	jl 	consume_spaces

	shlq	$8, %rbx
	movb	%al, %bl
	
	jmp read_till_end	

consume_spaces:
	movb	(%r10), %al	
	incq	%r10	

	testb 	%al, %al
	###
	jz	get_token_end
	
	cmp	$33, %al
	jl 	consume_spaces


get_token_end:
	decq	%r10

	movq	%rbx, %rax
	retq
	
get_token_special_character:
	jmp	read_till_end			

get_token_identifier_and_keyword:
	call	read_till_end	

	testq	%rcx, %rcx
	jnz	store_identifier

	leaq	keyword_table(%rip), %rax
	leaq	-8(%rax), %rax

check_next_keyword:
	cmpq	$0, (%rax)
	jz	store_identifier

	leaq	8(%rax), %rax	
	cmpq	%rbx, (%rax)
	jne	check_next_keyword	

	movq	%rbx, %rax
	retq

store_identifier:	
	leaq	identifier_table(%rip), %rax
	leaq	-32(%rax), %rax

check_next_identifier:
	leaq	32(%rax), %rax
	cmpq	%rax, identifier_table_end(%rip)
	je	add_new_identifier
	cmpq	%rbx, (%rax)
	jne	check_next_identifier
	cmpq	%rcx, 8(%rax)
	jne	check_next_identifier
	cmpq	%rdx, 16(%rax)
	jne	check_next_identifier
	cmpq	%rsi, 24(%rax)
	jne	check_next_identifier

	leaq	32(%rax), %rax
	jmp	store_identifier_finalize
	
add_new_identifier:
	mov	%rbx, (%rax)
	mov	%rcx, 8(%rax)
	mov	%rdx, 16(%rax)
	mov	%rsi, 24(%rax)	
	leaq	32(%rax), %rax
	movq	%rax, identifier_table_end(%rip)	

store_identifier_finalize:
	leaq	identifier_table(%rip), %rbx
	subq	%rbx, %rax
	shrq	$5, %rax
	decq	%rax
	movq	%rax, %rbx
	movq	$TOKEN_IDENTIFIER, %rax
	retq

get_token_integer_start:
	xorq	%rbx, %rbx
get_token_integer:
	imul	$10, %ebx
	sub	$48, %eax
	add	%eax, %ebx

	movb	(%r10), %al
	incq	%r10
	
	cmp	$48, %al
	jge	get_token_integer

	call 	consume_spaces

	movq	$TOKEN_INTEGER, %rax
	retq
	
program_parsing_end:
	movq	$TOKEN_EOF, %rax
	retq

	.section .bss
	.lcomm token_buffer, 40960

	.data
token_end:
	.quad token_buffer


	.section .data
# 32 bytes per identifier
identifier_table:
	.quad	0x6d61696e		
	.quad	0
	.quad	0
	.quad	0
identifier_table_start:
	.space	40960

	.data
identifier_table_end:
	.quad	identifier_table_start


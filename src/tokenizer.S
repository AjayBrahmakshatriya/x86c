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

tokenize_lookup:
.byte  0
.space 32, TOKEN_MASK_SPACE
.space 15, TOKEN_MASK_SPECIAL # !-/
.space 10, TOKEN_MASK_INTEGER # 0 -9
.space 7, TOKEN_MASK_SPECIAL # :-@
.space 26, TOKEN_MASK_KEYWORD # A-Z
.space 4, TOKEN_MASK_SPECIAL # [-^
.byte	TOKEN_MASK_KEYWORD # _
.byte 	TOKEN_MASK_SPECIAL # `
.space 26, TOKEN_MASK_KEYWORD # a-z
.space 4, TOKEN_MASK_SPECIAL # { - ~
.byte TOKEN_MASK_SPACE # DEL
.space 128, TOKEN_MASK_SPACE

	.text
	.globl get_token
get_token:
	movq	token_cache(%rip), %rax
	movq	token_cache + 8(%rip), %rbx
	testq	%rax, %rax
	jz	get_token_continue
	movq	$0, token_cache(%rip)
	retq

get_token_continue:	
	movq	%r10, %rsi	

	movb	(%r10), %al
	testb	%al, %al
	jz	program_parsing_end

	movzbl 	%al, %eax
	leaq	tokenize_lookup(%rip), %rbx
	movb	(%rbx, %rax), %bl
	shrb	$4, %bl

next_character:
	leaq	1(%r10), %r10
	movb	(%r10), %al
	movzbl	%al, %eax
	leaq	tokenize_lookup(%rip), %rcx
	movb	(%rcx, %rax), %al
	andb	%bl, %al
	jnz	next_character

	# rsi - start of token, %r10 end of token + 1
	
	cmpb	$0b00001000, %bl # white space
	je	get_token

	cmpb	$0b00000001, %bl # integer
	je	token_as_integer

	cmpb	$0b00000100, %bl # special character
	je	token_as_special

	# must be a keyword/identifier	
	movq	%r10, %rax
	subq	%rsi, %rax		
	cmpq	$8, %rax
	jg	token_as_identifier
	
	callq	token_as_special # reuse logic to pick up token	
	leaq	keyword_table(%rip), %rbx
check_next_keyword:
	cmpq	$0, (%rbx)
	jz	token_as_identifier
	cmpq	%rax, (%rbx)
	leaq	8(%rbx), %rbx
	jne	check_next_keyword	
	retq

token_as_identifier:
	movq	identifier_table_end(%rip), %rdi
	movq	$0, (%rdi)
	movq	$0,  8(%rdi)
	movq	$0,  16(%rdi)
	movq	$0,  24(%rdi)
	
	movq	%r10, %rcx
	subq	%rsi, %rcx	
	rep	movsb	
	
	movq	identifier_table_end(%rip), %rbx

	leaq	identifier_table(%rip), %rax
check_next_identifier:	
	cmpq	%rax, %rbx
	je	identifier_store_and_return
	movq	%rax, %rdi
	movq	%rbx, %rsi			
	movq	$32, %rcx	
	rep	cmpsb
	leaq	32(%rax), %rax
	jne	check_next_identifier
	leaq	identifier_table(%rip), %rbx
	subq	%rbx, %rax
	shrq	$5, %rax
	decq	%rax
	movq	%rax, %rbx
	movq	$TOKEN_IDENTIFIER, %rax
	retq

identifier_store_and_return:
	leaq	32(%rbx), %rbx
	movq	%rbx, identifier_table_end(%rip)
	leaq	identifier_table(%rip), %rbx
	subq	%rbx, %rax
	shrq	$5, %rax
	movq	%rax, %rbx
	movq	$TOKEN_IDENTIFIER, %rax
	retq
	

token_as_integer:
	xorq	%rbx, %rbx
token_as_integer_continue:
	movb	(%rsi), %al
	movzbl	%al, %eax
	imulq	$10, %rbx	
	sub	$48, %eax # - 0
	addq	%rax, %rbx	
	incq	%rsi
	cmpq	%rsi, %r10
	jne	token_as_integer_continue		
	movq	$TOKEN_INTEGER, %rax
	retq	

token_as_special:
	movq	%rsi, %rcx
	xorq	%rax, %rax
token_as_special_continue:
	movb	(%rcx), %bl
	shl	$8, %rax
	movb	%bl, %al
	incq	%rcx
	cmpq	%rcx, %r10
	jne	token_as_special_continue
	retq	

program_parsing_end:
	movq	$TOKEN_EOF, %rax
	retq

	.globl return_token
return_token:
	movq	%rax, token_cache(%rip)
	movq	%rbx, token_cache + 8(%rip)
	retq


# 32 bytes per identifier, stored in string order padded with 0
	.section .data
identifier_scratch:
	.space	32, 0

identifier_table:
	.quad	0x000000006e69616d #main
        .quad   0, 0, 0
	# .quad	0x73797363616c6c36
	.quad	0x366c6c6163737973 #syscall6
	.quad	0, 0, 0

identifier_table_start:
        .space  40960

	.data
identifier_table_end:
	.quad	identifier_table_start


	.data
token_cache:
	.quad 0
	.quad 0


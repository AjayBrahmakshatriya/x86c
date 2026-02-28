.include "defs.inc"
/* Exprs can be of the form - 
<unary_operator> <expr>
( expr )
<integer>
<identifier>
optionally have- 
<binary_operator> <expr>
(..., ...,)
*/
	.data
invalid_expr:
	.asciz "Invalid Expr"
.equ invalid_expr_len, . - invalid_expr

invalid_identifier:
	.asciz "Invalid Identifier"
.equ invalid_identifier_len, . - invalid_identifier

invalid_pre_0_expr:
	.asciz "Invalid Expr of Precdence 0"
.equ invalid_pre_0_expr_len, . - invalid_pre_0_expr

.equ	BOTES, 24
.macro push_nullptr offset
	# 6a 00    push   $0x0
	movb	$0x6a, \offset(%r14)
	movb	$0x00, \offset+1(%r14)
.endm

	.text
	.globl parse_expr
parse_expr:
	call	parse_expr_pre_14
	retq

# Special case for parse_expr_pre which checks for assignment
parse_expr_pre_14:
	movq	$12, %rsi
	call	parse_expr_pre

parse_expr_pre_14_next:
	call	get_token
	cmpq	$TOKEN_ASSIGN, %rax
	jne	parse_expr_pre_14_end	

	movq	$12, %rsi	
	call	parse_expr_pre

	# TODO: Change associativity R-L
	# Generate code for assignment	
	# 5b    pop    %rbx
  	# 5b    pop    %rbx
  	# 58    pop    %rax
  	# 59    pop    %rcx
	movl	$0x59585b5b, (%r14)
	# 48 89 18   mov    %rbx,(%rax)
  	# 53	     push   %rbx 
	movl	$0x53188948, 4(%r14)
	push_nullptr 8
	leaq	10(%r14), %r14
	jmp	parse_expr_pre_14_next	

parse_expr_pre_14_end:
	call	return_token
	retq


parse_expr_pre_2:
	call	get_token
	cmpq	$TOKEN_AMP, %rax	
	jne	parse_expr_pre_2_not_amp
	call	parse_expr_pre_2
  	# 58                      pop    %rax
  	# 5b                      pop    %rbx
  	# 50                      push   %rax
  	# 6a 00                   push   $0x0			
	movl	$0x00505b58, (%r14)
	movw	$0x006a, 3(%r14)
	leaq	5(%r14), %r14
	retq
parse_expr_pre_2_not_amp:
	cmpq	$TOKEN_STAR, %rax
	jne	parse_expr_pre_2_not_star
	call	parse_expr_pre_2
 	# 58                      pop    %rax
 	# 58                      pop    %rax
 	# ff 30                   push   (%rax)
 	# 50                      push   %rax
	movl	$0x30ff5858, (%r14)
	movb	$0x50, 4(%r14)
	leaq	5(%r14), %r14
	retq

parse_expr_pre_2_not_star:
	call	return_token
	callq	parse_expr_pre_1
	retq	
		
parse_expr_pre_1:
	call	parse_expr_pre_0
parse_expr_pre_1_continue:
	call	get_token
	cmpq	$TOKEN_LPARAN, %rax
	je	parse_function_call_expr	
	call	return_token
	retq

# Identifier/Integers
parse_expr_pre_0:
	call	get_token	
	cmpq	$TOKEN_INTEGER, %rax
	je	parse_integer_expr
	cmpq	$TOKEN_IDENTIFIER, %rax
	je	parse_identifier_expr

	leaq	invalid_pre_0_expr(%rip), %rdi
	movq	$invalid_pre_0_expr_len, %rsi
	jmp	report_error	
	
parse_expr_pre_0_continue:	
	retq

parse_expr_pre:
	cmpq	$2, %rsi
	je	parse_expr_pre_2
	
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$40, %rsp
	# -8 (%rbp) - current precedence	
	# -16/24 (%rbp) - saved tokens
	# -32 (%rbp) - current operator entry
	# -40 (%rbp) - jump instruction address
	movq	%rsi, -8(%rbp)

	decq	%rsi
	call	parse_expr_pre

	movq	-8(%rbp), %rsi
	cmpq	$11, %rsi
	je	parse_expr_pre_11
	
	cmpq	$12, %rsi
	je	parse_expr_pre_12

parse_expr_pre_next:
	call	get_token		
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)

	call	check_binary_operator	
	cmpq	$0, %rax
	je	parse_expr_pre_finish

	movq	%rax, -32(%rbp)

	movq	8(%rax), %rbx
	movq	-8(%rbp), %rsi
	cmpq	%rbx, %rsi
	jne	parse_expr_pre_finish

	decq	%rsi
	call	parse_expr_pre	

	movq	-32(%rbp), %rax
	# 48 31 d2   xor    %rdx,%rdx
	movl	$0xd23148, (%r14)
	leaq	3(%r14), %r14
	# 48 31 c9   xor    %rcx,%rcx
	movl	$0xc93148, (%r14)
	# 5b    pop    %rbx
  	# 5b    pop    %rbx
  	# 58    pop    %rax
  	# 58    pop    %rax
	movb	$0x5b, 3(%r14)	
	movb	$0x5b, 4(%r14)	
	movb	$0x58, 5(%r14)
	movb	$0x58, 6(%r14)
	movq	16(%rax), %rcx
	movq	%rcx, 7(%r14)
	push_nullptr 15
	leaq	17(%r14), %r14

	jmp	parse_expr_pre_next	

parse_expr_pre_finish:
	movq	-16(%rbp), %rax
	movq	-24(%rbp), %rbx
	callq	return_token

	leave
	retq


parse_expr_pre_12:
	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_OR, %rax
	jne	parse_expr_pre_finish




	# Genereate boolenify of the first expr	
  	# 58                      pop    %rax
  	# 58                      pop    %rax
  	# 48 85 c0                test   %rax,%rax
  	# 0f 95 c0                setne  %al
  	# 0f b6 c0                movzbl %al,%eax
  	# 50                      push   %rax
  	# 6a 00                   push   $0x0
  	# 74 05                   je    84 <continue>
  	# e9 02 00 00 00          jmp    8a <skip_forward>
	movabsq	$0xc0950fc085485858, %rax
	movq	%rax, (%r14)
	movabsq	$0x0574006a50c0b60f, %rax
	movq	%rax, 8(%r14)
	leaq	16(%r14), %r14
	movq	%r14, -40(%rbp)
	movb	$0xe9, (%r14)
	leaq	5(%r14), %r14

parse_expr_pre_12_next:
	movq	$10, %rsi
	call	parse_expr_pre		
		
  	# 58                      pop    %rax
  	# 58                      pop    %rax
  	# 48 85 c0                test   %rax,%rax
  	# 0f 95 c0                setne  %al
  	# 0f b6 c0                movzbl %al,%eax
  	# 50                      push   %rax
  	# 6a 00                   push   $0x0
	movabsq	$0xc0950fc085485858, %rax
	movq	%rax, (%r14)
	movabsq	$0x0000006a50c0b60f, %rax
	movq	%rax, 8(%r14)
	leaq	14(%r14), %r14

	#0f 85 ff ff ff ff       jne     00 <forward_jmp_address>
	movw	$0x850f, (%r14)	
	leaq	2(%r14), %r14
	movq	-40(%rbp), %rax
	subq	%r14, %rax
	subq	$4, %rax
	movl	%eax, (%r14)
	leaq	4(%r14), %r14

	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_AND, %rax
	je	parse_expr_pre_12_next

	# patch the target for the forward jump		
	movq	%r14, %rax
	movq	-40(%rbp), %rbx		
	subq	%rbx, %rax
	subq	$5, %rax
	movl	%eax, 1(%rbx)

	jmp	parse_expr_pre_finish

parse_expr_pre_11:	
	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_AND, %rax
	jne	parse_expr_pre_finish

	# Genereate boolenify of the first expr	
  	# 58                      pop    %rax
  	# 58                      pop    %rax
  	# 48 85 c0                test   %rax,%rax
  	# 0f 95 c0                setne  %al
  	# 0f b6 c0                movzbl %al,%eax
  	# 50                      push   %rax
  	# 6a 00                   push   $0x0
  	# 75 05                   jne    84 <continue>
  	# e9 02 00 00 00          jmp    8a <skip_forward>
	movabsq	$0xc0950fc085485858, %rax
	movq	%rax, (%r14)
	movabsq	$0x0575006a50c0b60f, %rax
	movq	%rax, 8(%r14)
	leaq	16(%r14), %r14
	movq	%r14, -40(%rbp)
	movb	$0xe9, (%r14)
	leaq	5(%r14), %r14

parse_expr_pre_11_next:
	movq	$10, %rsi
	call	parse_expr_pre		
		
  	# 58                      pop    %rax
  	# 58                      pop    %rax
  	# 48 85 c0                test   %rax,%rax
  	# 0f 95 c0                setne  %al
  	# 0f b6 c0                movzbl %al,%eax
  	# 50                      push   %rax
  	# 6a 00                   push   $0x0
	movabsq	$0xc0950fc085485858, %rax
	movq	%rax, (%r14)
	movabsq	$0x0000006a50c0b60f, %rax
	movq	%rax, 8(%r14)
	leaq	14(%r14), %r14

	#0f 84 ff ff ff ff       je     00 <forward_jmp_address>
	movw	$0x840f, (%r14)	
	leaq	2(%r14), %r14
	movq	-40(%rbp), %rax
	subq	%r14, %rax
	subq	$4, %rax
	movl	%eax, (%r14)
	leaq	4(%r14), %r14

	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_AND, %rax
	je	parse_expr_pre_11_next

	# patch the target for the forward jump		
	movq	%r14, %rax
	movq	-40(%rbp), %rbx		
	subq	%rbx, %rax
	subq	$5, %rax
	movl	%eax, 1(%rbx)

	jmp	parse_expr_pre_finish

	.globl parse_expr_error
parse_expr_error:	
	leaq	invalid_expr(%rip), %rdi
	movq	$invalid_expr_len, %rsi
	jmp	report_error	


check_binary_operator:
	movq	%rax, %rbx
	leaq	binary_operator_table(%rip), %rax
	leaq	-BOTES(%rax), %rax
check_next_binary_operator:
	leaq	BOTES(%rax), %rax
	cmpq	$0, (%rax)
	je	check_binary_operator_end	
	cmpq	(%rax), %rbx
	jne	check_next_binary_operator
	retq	
check_binary_operator_end:
	xorq	%rax, %rax
	retq
	
parse_integer_expr:
	# 48 c7 c0 00 00 00 00    mov    $0x0000,%rax
   	# 50                      push   %rax
	movb	$0x48, (%r14)
	movb	$0xc7, 1(%r14)
	movb	$0xc0, 2(%r14)
	movl	%ebx,  3(%r14)	
	movb	$0x50, 7(%r14)
	push_nullptr 8
	leaq	10(%r14), %r14
	jmp 	parse_expr_pre_0_continue
	
parse_identifier_expr:
	call	check_local_table	
	testq	%rax, %rax
	jnz	parse_identifier_expr_local
	call	check_global_table
	testq	%rax, %rax
	jnz	parse_identifier_expr_global
	leaq	invalid_identifier(%rip), %rdi
	movq	$invalid_identifier_len, %rsi
	jmp	report_error	

parse_identifier_expr_local:
	movq	8(%rax), %rax	
 	# 48 8d 85 aa 00 00 00    lea    0xaa(%rbp),%rax
  	# ff 30                   push   (%rax)
  	# 50
	movb	$0x48, (%r14)
	movb	$0x8d, 1(%r14)
	movb	$0x85, 2(%r14)
	movl	%eax,  3(%r14)
	movb	$0xff, 7(%r14)	
	movb	$0x30, 8(%r14)
	movb	$0x50, 9(%r14)
	leaq	10(%r14), %r14
	jmp	parse_expr_pre_0_continue

parse_identifier_expr_global:
	movq	8(%rax), %rax	
	# 48 b8 00 00 00 00 00    movabs $0x0000000000000,%rax
  	# 00 00 00
  	# ff 30                   push   (%rax)
  	# 50                      push   %rax
	movb	$0x48, (%r14)
	movb	$0xb8, 1(%r14)
	movq	%rax, 2(%r14)
	movb	$0xff, 10(%r14)
	movb	$0x30, 11(%r14)	
	movb	$0x50, 12(%r14)
	leaq	13(%r14), %r14
	jmp	parse_expr_pre_0_continue

parse_function_call_expr:
	call	parse_function_call_expr_sub
	jmp	parse_expr_pre_1_continue

parse_function_call_expr_sub:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	-16(%rsp), %rsp
	# -8 (%rbp), number of arguments
	movq	$0, -8(%rbp)

	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_call_expr_end
	call	return_token

parse_next_call_argument:	
	call	parse_expr
	# 58    pop    %rax
	movb	$0x58, (%r14)	
	leaq	1(%r14), %r14
	addq	$8, -8(%rbp)	
	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_call_expr_end	
	jmp	parse_next_call_argument	
	
parse_function_call_expr_end:
	movq	-8(%rbp), %rax
	# 48 8b 84 24 00 00 00    mov    0x000000(%rsp),%rax
	# 00
	# ff d0                   call   *%rax
	movl	$0x24848b48, (%r14)
	movl	%eax, 4(%r14)
	movw	$0xd0ff, 8(%r14)
	# 48 8d a4 24 55 66 ff    lea    0xff6655(%rsp),%rsp
  	# 00
  	# 50                      push   %rax
	movl	$0x24a48d48, 10(%r14)
	leaq	16(%rax), %rax
	movl	%eax, 14(%r14)	
	movl	$0x50, 18(%r14)		
	push_nullptr 19
	leaq	21(%r14), %r14

	leave
	retq

check_global_table:
	leaq	global_symbol_table(%rip), %rax
check_global_table_next:
	cmpq	%rax, global_symbol_table_end(%rip)	
	je	global_table_not_found
	cmpq	(%rax), %rbx
	leaq	GTES(%rax), %rax
	jne	check_global_table_next	
	leaq	-GTES(%rax), %rax
	retq	
global_table_not_found:
	xorq	%rax, %rax
	retq

check_local_table:
	leaq	local_symbol_table(%rip), %rax
check_local_table_next:
	cmpq	%rax, local_symbol_table_end(%rip)	
	je	local_table_not_found
	cmpq	(%rax), %rbx
	leaq	LTES(%rax), %rax
	jne	check_local_table_next	
	leaq	-LTES(%rax), %rax
	retq	
local_table_not_found:
	xorq	%rax, %rax
	retq

	.data
#8 bytes for operator, 8 bytes for precedence, 8 bytes for instruction including push
binary_operator_table:
	.quad	TOKEN_STAR
	.quad	3
	.long	0x90909090
	.long	0x50ebf748	
	.quad	TOKEN_DIVIDE
	.quad	3
	.long	0x90909090
	.long	0x50fbf748
	.quad	TOKEN_PERCENT
	.quad	3
	.long	0x90909090
	.long	0x52fbf748
	.quad	TOKEN_PLUS
	.quad	4
	.long	0x90909090
	.long	0x53c30148
	.quad	TOKEN_MINUS
	.quad	4
	.long	0x90909090
	.long	0x50d82948
	.quad	TOKEN_LESSTHAN
	.quad	6
	.quad	0x9051c19c0fd83948
	.quad	TOKEN_GREATERTHAN
	.quad	6
	.quad	0x9051c19f0fd83948
	.quad	TOKEN_LESSEQUALS
	.quad	6
	.quad	0x9051c19e0fd83948
	.quad	TOKEN_GREATEREQUALS
	.quad	6
	.quad	0x9051c19d0fd83948
	.quad	TOKEN_EQUALS
	.quad	7
	.quad	0x9051c1940fd83948
	.quad	TOKEN_NOTEQUALS
	.quad	7
	.quad	0x9051c1950fd83948
	.quad	0
	.quad	0

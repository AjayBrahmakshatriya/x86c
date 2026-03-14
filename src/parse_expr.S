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

.equ	BOTES, 34
	
	.text
	# 0 - rvalue
	# 1 - lvalue
	.globl ensure_rvalue
ensure_rvalue:
	testq	%rax, %rax
	jz	ensure_rvalue_end
	# f3:   48 8b 00 mov    (%rax),%rax		
	movl	$0x8b48, (%r14)
	leaq	3(%r14), %r14	
	movq	$1, %rax
ensure_rvalue_end:
	retq	

get_stack_slot:
	movq	current_function_slots(%rip), %rax
	leaq	-8(%rax), %rbx
	movq	%rbx, current_function_slots(%rip)
	retq

stash_value_to_stack:
	# f6:   48 89 85 00 00 00 00 mov    %rax,-0x24(%rbp)
	movl	$0x00858948, (%r14)
	movl	%eax, 3(%r14)
	leaq	7(%r14), %r14
	retq

get_value_from_stack:
	# fa:   48 8b 9d 00 00 00 00 mov    -0x24(%rbp),%rbx		
	movl	$0x009d8b48, (%r14)
	movl	%eax, 3(%r14)
	leaq	7(%r14), %r14
	retq
	
	.globl parse_expr
parse_expr:
	call	parse_expr_pre_14
	retq

# Special case for parse_expr_pre which checks for assignment
parse_expr_pre_14:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	-8(%rsp), %rsp
	# -8(%rbp) - stack slot for the temporary/value category
	movq	$12, %rsi
	call	parse_expr_pre
	movq	%rax, -8(%rbp)
parse_expr_pre_14.check_next:
	call	get_token
	cmpq	$TOKEN_ASSIGN, %rax
	jne	parse_expr_pre_14.end	
	call	get_stack_slot
	movq	%rax, -8(%rbp)
	call	stash_value_to_stack
	movq	$12, %rsi	
	call	parse_expr_pre
	call	ensure_rvalue
	movq	-8(%rbp), %rax
	call	get_value_from_stack

	# TODO: Change associativity R-L
	# fe:   48 89 03 mov    %rax,(%rbx)	
	# 101:   48 89 d8       mov    %rbx,%rax
	movl 	$0x48038948, (%r14)
	movw	$0xd889, 4(%r14)
	leaq	6(%r14), %r14
	movq	$1, -8(%rbp)	
	jmp	parse_expr_pre_14.check_next
parse_expr_pre_14.end:
	call	return_token
	movq	-8(%rbp), %rax
	leave
	retq

# Handles & and *
parse_expr_pre_2:
	call	get_token
	cmpq	$TOKEN_AMP, %rax	
	jne	parse_expr_pre_2.not_amp
	call	parse_expr_pre_2
	# generates no code, just turns the lvalue into an rvlaue
	xorq	%rax, %rax
	retq
parse_expr_pre_2.not_amp:
	cmpq	$TOKEN_STAR, %rax
	jne	parse_expr_pre_2.not_star
	call	parse_expr_pre_2
	# generates no code, just turns the rvalue into an lvalue
	call	ensure_rvalue
	movq	$1, %rax
	retq
parse_expr_pre_2.not_star:
	call	return_token
	callq	parse_expr_pre_1
	retq	

# Handles function calls - ()
parse_expr_pre_1:
	pushq	%rbp
	movq	%rsp, %rbp
	leaq	-16(%rsp), %rsp
	# - 8 (%rbp) - left expression value category/stack slot
	# -16 (%rbp), number of arguments
	call	parse_expr_pre_0
parse_expr_pre_1.check_next_call:
	movq	%rax, -8(%rbp)
	call	get_token
	cmpq	$TOKEN_LPARAN, %rax
	je	parse_expr_pre_1.parse_function_call_expr	
	call	return_token
	movq	-8(%rbp), %rax
	leave
	retq

parse_expr_pre_1.parse_function_call_expr:	
	movq	$0, -16(%rbp)
	# Push the call target onto the stack
	# 50                      push   %rax
	movb	$0x50, (%r14)
	leaq	1(%r14), %r14

	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_expr_pre_1.call_end
	call	return_token
parse_expr_pre_1.next_argument:	
	call	parse_expr
	call	ensure_rvalue
	
	# 50    push    %rax
	movb	$0x50, (%r14)	
	leaq	1(%r14), %r14
	addq	$8, -16(%rbp)	
	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_expr_pre_1.call_end	
	jmp	parse_expr_pre_1.next_argument
	
parse_expr_pre_1.call_end:
	movq	-16(%rbp), %rax
	# 48 8b 84 24 00 00 00    mov    0x000000(%rsp),%rax
	# 00
	# ff d0                   call   *%rax
	movl	$0x24848b48, (%r14)
	movl	%eax, 4(%r14)
	movw	$0xd0ff, 8(%r14)
	# 48 8d a4 24 55 66 ff    lea    0xff6655(%rsp),%rsp
  	# 00
	movl	$0x24a48d48, 10(%r14)
	leaq	8(%rax), %rax
	movl	%eax, 14(%r14)	
	leaq	18(%r14), %r14
	xorq	%rax, %rax	
	jmp	parse_expr_pre_1.check_next_call

# Identifier/Integers
parse_expr_pre_0:
	call	get_token	
	cmpq	$TOKEN_INTEGER, %rax
	je	parse_expr_pre_0.expr_integer
	cmpq	$TOKEN_IDENTIFIER, %rax
	je	parse_expr_pre_0.expr_identifier
	leaq	invalid_pre_0_expr(%rip), %rdi
	movq	$invalid_pre_0_expr_len, %rsi
	jmp	report_error		

parse_expr_pre_0.expr_integer:
	# 48 c7 c0 00 00 00 00    mov    $0x0000,%rax
	movb	$0x48, (%r14)
	movb	$0xc7, 1(%r14)
	movb	$0xc0, 2(%r14)
	movl	%ebx,  3(%r14)	
	leaq	7(%r14), %r14
	xorq	%rax, %rax
	retq

parse_expr_pre_0.expr_identifier:
	call	check_local_table	
	testq	%rax, %rax
	jnz	parse_expr_pre_0.expr_local
	call	check_global_table
	testq	%rax, %rax
	jnz	parse_expr_pre_0.expr_global
	leaq	invalid_identifier(%rip), %rdi
	movq	$invalid_identifier_len, %rsi
	jmp	report_error	
parse_expr_pre_0.expr_local:
	movq	8(%rax), %rax	
 	# 48 8d 85 aa 00 00 00    lea    0xaa(%rbp),%rax
	movb	$0x48, (%r14)
	movb	$0x8d, 1(%r14)
	movb	$0x85, 2(%r14)
	movl	%eax,  3(%r14)
	leaq	7(%r14), %r14
	movq	$1, %rax
	retq

parse_expr_pre_0.expr_global:
	movq	8(%rax), %rax	
	# 48 b8 00 00 00 00 00    movabs $0x0000000000000,%rax
  	# 00 00 00
	movb	$0x48, (%r14)
	movb	$0xb8, 1(%r14)
	movq	%rax, 2(%r14)
	leaq	10(%r14), %r14
	movq	$1, %rax
	retq

# Handles all binary operators given precendence in rsi
parse_expr_pre:
	cmpq	$2, %rsi
	je	parse_expr_pre_2
	
	pushq	%rbp
	movq	%rsp, %rbp
	subq	$48, %rsp
	# -8 (%rbp) - current precedence	
	# -16/24 (%rbp) - saved tokens
	# -32 (%rbp) - current operator entry
	# -40 (%rbp) - jump instruction address
	# -48 (%rbp) - stack slot for first expression/value category of the first expression
	movq	%rsi, -8(%rbp)

	decq	%rsi
	call	parse_expr_pre
	movq	%rax, -48(%rbp)


	movq	-8(%rbp), %rsi
	cmpq	$11, %rsi
	je	parse_expr_pre_11
	
	cmpq	$12, %rsi
	je	parse_expr_pre_12

parse_expr_pre.next_expr:
	call	get_token		
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)

	call	check_binary_operator	
	cmpq	$0, %rax
	je	parse_expr_pre.finish

	movq	%rax, -32(%rbp)
	movq	8(%rax), %rbx
	movq	-8(%rbp), %rsi
	cmpq	%rbx, %rsi
	jne	parse_expr_pre.finish

	movq	-48(%rbp), %rax
	call	ensure_rvalue
	call	get_stack_slot
	movq	%rax, -48(%rbp)
	call	stash_value_to_stack

	decq	%rsi
	call	parse_expr_pre		
	call	ensure_rvalue
		
	movq	-48(%rbp), %rax
	call	get_value_from_stack
	
	movq	-32(%rbp), %rax
	leaq	24(%rax), %rsi
	movq	%r14, %rdi
	movq	16(%rax), %rcx	
	rep 	movsb
	movq	%rdi, %r14	
	
	movq	$0, -48(%rbp)

	jmp	parse_expr_pre.next_expr

parse_expr_pre.finish:
	movq	-16(%rbp), %rax
	movq	-24(%rbp), %rbx
	callq	return_token

	movq	-48(%rbp), %rax
	leave
	retq


parse_expr_pre_12:
	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_OR, %rax
	jne	parse_expr_pre.finish

	movq	-48(%rbp), %rax
	call 	ensure_rvalue
	
	# Genereate boolenify of the first expr	
  	# 48 85 c0                test   %rax,%rax
  	# 74 0a                   je     84 <continue>
	# b8 01 00 00 00          mov    $0x1,%eax
  	# e9 00 00 00 00          jmp    8a <skip_forward>
	movl	$0x74c08548, (%r14)
	movb	$0x0a, 4(%r14)	
	leaq	5(%r14), %r14	
	movq	%r14, -40(%rbp)
	movb	$0xb8, (%r14)
	movl	$0x1, 1(%r14)	
	movb	$0xe9, 5(%r14)
	leaq	10(%r14), %r14
	
parse_expr_pre_12.check_next:
	movq	$11, %rsi
	call	parse_expr_pre		
	call	ensure_rvalue	
	
  	# 48 85 c0                test   %rax,%rax
	
	movl	$0xc08548, (%r14)
	leaq	3(%r14), %r14
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
	cmpq	$TOKEN_OR, %rax
	je	parse_expr_pre_12.check_next

	# patch the target for the forward jump		
	movq	%r14, %rax
	movq	-40(%rbp), %rbx		
	subq	%rbx, %rax
	subq	$10, %rax
	movl	%eax, 6(%rbx)

	movq	$0, -48(%rbp)

	jmp	parse_expr_pre.finish

parse_expr_pre_11:	
	call	get_token
	movq	%rax, -16(%rbp)
	movq	%rbx, -24(%rbp)
	cmpq	$TOKEN_AND, %rax
	jne	parse_expr_pre.finish


	movq	-48(%rbp), %rax
	call	ensure_rvalue
	# Genereate boolenify of the first expr	
  	# 48 85 c0                test   %rax, %rax
  	# 75 05                   jne    84 <continue>
  	# e9 02 00 00 00          jmp    8a <skip_forward>

	movq	$0x75c08548, (%r14)
	movb	$0x05, 4(%r14)
	leaq	5(%r14), %r14
	movq	%r14, -40(%rbp)
	movb	$0xe9, (%r14)
	leaq	5(%r14), %r14

parse_expr_pre_11.check_next:
	movq	$10, %rsi
	call	parse_expr_pre		
	call	ensure_rvalue	
		
  	# 48 85 c0                test   %rax,%rax
	# b8 01 00 00 00          mov    $0x1,%eax
	# 0f 84 ff ff ff ff        je     00 <forward_jmp_address>
	
	movl	$0xb8c08548, (%r14)
	movl	$1, 4(%r14)
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
	je	parse_expr_pre_11.check_next

	# patch the target for the forward jump		
	movq	%r14, %rax
	movq	-40(%rbp), %rbx		
	subq	%rbx, %rax
	subq	$5, %rax
	movl	%eax, 1(%rbx)

	movq	$0, -48(%rbp)
	jmp	parse_expr_pre.finish

	.globl parse_expr_error
parse_expr_error:	
	leaq	invalid_expr(%rip), %rdi
	movq	$invalid_expr_len, %rsi
	jmp	report_error	


check_binary_operator:
	movq	%rax, %rbx
	leaq	binary_operator_table(%rip), %rax
	leaq	-BOTES(%rax), %rax
check_binary_operator.check_next:
	leaq	BOTES(%rax), %rax
	cmpq	$0, (%rax)
	je	check_binary_operator.end
	cmpq	(%rax), %rbx
	jne	check_binary_operator.check_next
	retq	
check_binary_operator.end:
	xorq	%rax, %rax
	retq
	
	
check_global_table:
	leaq	global_symbol_table(%rip), %rax
check_global_table.next:
	cmpq	%rax, global_symbol_table_end(%rip)	
	je	check_global_table.not_found
	cmpq	(%rax), %rbx
	leaq	GTES(%rax), %rax
	jne	check_global_table.next	
	leaq	-GTES(%rax), %rax
	retq	
check_global_table.not_found:
	xorq	%rax, %rax
	retq

check_local_table:
	leaq	local_symbol_table(%rip), %rax
check_local_table.next:
	cmpq	%rax, local_symbol_table_end(%rip)	
	je	check_local_table.not_found
	cmpq	(%rax), %rbx
	leaq	LTES(%rax), %rax
	jne	check_local_table.next	
	leaq	-LTES(%rax), %rax
	retq	
check_local_table.not_found:
	xorq	%rax, %rax
	retq

	.data
#8 bytes for operator, 8 bytes for precedence, 8 bytes for length, 10 bytes for instruction including push
binary_operator_table:

 	# 104:   48 0f af c3             imul   %rbx,%rax
	.quad	TOKEN_STAR
	.quad	3
	.quad	4
	.long	0xc3af0f48
	.space	6	
 	# 108:   48 93                   xchg   %rax,%rbx
 	# 10a:   48 99                   cqto
 	# 10c:   48 f7 fb                idiv   %rbx
	.quad	TOKEN_DIVIDE
	.quad	3
	.quad	7
	.quad	0x00fbf74899489348
	.space  2
 	# 10f:   48 93                   xchg   %rax,%rbx
 	# 111:   48 99                   cqto
 	# 113:   48 f7 fb                idiv   %rbx
 	# 116:   48 89 d0                mov    %rdx,%rax
	.quad	TOKEN_PERCENT
	.quad	3
	.quad	10
	.quad	0x48fbf74899489348
	.short	0xd089
 	# 119:   48 01 d8                add    %rbx,%rax
	.quad	TOKEN_PLUS
	.quad	4
	.quad	3
	.long	0x00d80148
	.space 	6
 	# 11c:   48 29 c3                sub    %rax,%rbx
 	# 11f:   48 89 d8                mov    %rbx,%rax
	.quad	TOKEN_MINUS
	.quad	4
	.quad	6
	.quad	0x0000d88948c32948
	.space  2
 	# 122:   48 39 c3                cmp    %rax,%rbx
 	# 125:   0f 9c c0                setl   %al
 	# 128:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_LESSTHAN
	.quad	6
	.quad	9
	.long	0x0fc33948
	.byte	0x9c
	.long 	0xc0b60fc0
	.space 	1
 	# 12b:   48 39 c3                cmp    %rax,%rbx
 	# 12e:   0f 9f c0                setg   %al
 	# 131:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_GREATERTHAN
	.quad	6
	.quad	9
	.long	0x0fc33948
	.byte	0x9f
	.long 	0xc0b60fc0
	.space 	1
 	# 134:   48 39 c3                cmp    %rax,%rbx
 	# 137:   0f 9e c0                setle  %al
 	# 13a:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_LESSEQUALS
	.quad	6
	.quad	9
	.long	0x0fc33948
	.byte	0x9e
	.long 	0xc0b60fc0
	.space 	1
 	# 13d:   48 39 c3                cmp    %rax,%rbx
 	# 140:   0f 9d c0                setge  %al
 	# 143:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_GREATEREQUALS
	.quad	6
	.quad	9
	.long	0x0fc33948
	.byte	0x9d
	.long 	0xc0b60fc0
	.space 	1
 	# 146:   48 39 c3                cmp    %rax,%rbx
 	# 149:   0f 94 c0                sete   %al
 	# 14c:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_EQUALS
	.quad	7
	.quad	9
	.long	0x0fc33948
	.byte	0x94
	.long 	0xc0b60fc0
	.space 	1
 	# 14f:   48 39 c3                cmp    %rax,%rbx
 	# 152:   0f 95 c0                setne  %al
 	# 155:   0f b6 c0                movzbl %al,%eax
	.quad	TOKEN_NOTEQUALS
	.quad	7
	.quad	9
	.long	0x0fc33948
	.byte	0x95
	.long 	0xc0b60fc0
	.space 	1

	.quad	0
	.quad	0
	.quad	0
	.space 	10

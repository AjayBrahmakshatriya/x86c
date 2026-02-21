.include "defs.inc"

	.text
pe_expected_type:
	.asciz "Parser Expected Type"
.equ pe_expected_type_len, . - pe_expected_type

pe_expected_identifier:
	.asciz "Parser Expected Identifier"
.equ pe_expected_identifier_len, . - pe_expected_identifier

pe_var_bad:
	.asciz "Variable Declaration expected = or ; and integer values"
.equ pe_var_bad_len, . - pe_var_bad

invalid_stmt:
	.asciz "Invalid Stmt"
.equ invalid_stmt_len, . - invalid_stmt

invalid_expr:
	.asciz "Invalid Expr"
.equ invalid_expr_len, . - invalid_expr

invalid_identifier:
	.asciz "Invalid Identifier"
.equ invalid_identifier_len, . - invalid_identifier

.equ 	GTES, 24
.equ	LTES, 24
.equ	BOTES, 16

.macro push_nullptr offset
	movb	$0x6a, \offset(%r14)
	movb	$0x00, \offset+1(%r14)
.endm

	.text
	.globl parse_tu	
parse_tu:
	call	get_token
	cmpq	$TOKEN_EOF, %rax
	je	parse_tu_end
	call	return_token
	call	parse_tld
	jmp	parse_tu

parse_tu_end:
	retq

parse_tld:	
	call 	parse_type
	movq 	%rax, %r11
	call 	get_token
	cmpq	$TOKEN_IDENTIFIER, %rax	
	leaq	pe_expected_identifier(%rip), %rdi	
	movq	$pe_expected_identifier_len, %rsi
	jne 	report_error

	movq	%rbx, %r12

	call 	get_token	

	cmpq	$TOKEN_LPARAN, %rax
	je	parse_function
	jmp 	parse_global_variable

parse_global_variable:
	xorq	%rbx, %rbx
	cmpq	$TOKEN_SEMICOLON, %rax
	je	parse_global_end
	cmpq	$TOKEN_ASSIGN, %rax
	jne	parse_global_error	
	call	get_token	
	cmpq	$TOKEN_INTEGER, %rax
	jne	parse_global_error
	pushq	%rbx
	call	get_token
	popq	%rbx
	jmp	parse_global_end	
	
parse_global_error:
	leaq	pe_var_bad(%rip), %rdi	
	movq	$pe_var_bad_len, %rsi
	jmp	report_error
		
parse_global_end:
	movq	global_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%r14, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	GTES(%rax), %rax
	movq	%rax, global_symbol_table_end(%rip)
	movq	%rbx, (%r14)
	leaq	8(%r14), %r14	
	retq		

	
parse_function:
	movq	global_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%r14, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	GTES(%rax), %rax
	movq	%rax, global_symbol_table_end(%rip)

	movq	$0, current_function_slots(%rip)
	leaq	local_symbol_table(%rip), %rax
	movq	%rax, local_symbol_table_end(%rip)

	call 	get_token	
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_body

	call	return_token

parse_argument:
	call	parse_type
	movq	%rax, %r11	
	call 	get_token
	cmpq	$TOKEN_IDENTIFIER, %rax	
	leaq	pe_expected_identifier(%rip), %rdi	
	movq	$pe_expected_identifier_len, %rsi
	jne 	report_error
	movq	%rbx, %r12

	# assign stack slot	
	movq	current_function_slots(%rip), %rbx 
	leaq	-8(%rbx), %rax
	movq	%rax, current_function_slots(%rip)
	
	movq	local_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%rbx, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	LTES(%rax), %rax
	movq	%rax, local_symbol_table_end(%rip)

	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_body		

	jmp	parse_argument

parse_function_body:
	callq	fix_local_symbol_table_for_args

	movl	$0xe5894855, (%r14)
	leaq	4(%r14), %r14
	
	movq	$0, current_function_slots(%rip)	
	# consume the {
	call	get_token		

	# First token of the next statement
parse_function_body_next:
	call	get_token
	cmpq	$TOKEN_RBRACES, %rax
	je	parse_function_body_end
	call	return_token
	call	parse_stmt
	jmp	parse_function_body_next

parse_function_body_end:
	callq	gen_function_body_cleanup
	retq

gen_function_body_cleanup:
	# Finalize the function
	movb	$0xc9, 	(%r14)	
	movb	$0xc3, 	1(%r14)
	leaq	2(%r14), %r14
	retq

fix_local_symbol_table_for_args:
	movq	current_function_slots(%rip), %rbx
	negq	%rbx
	addq	$8, %rbx	
	leaq	local_symbol_table(%rip), %rax
fix_local_table_next:
	cmpq	%rax, local_symbol_table_end(%rip)	
	je	fix_local_table_end
	addq	%rbx, 8(%rax)	
	leaq	LTES(%rax), %rax
	jmp	fix_local_table_next
fix_local_table_end:
	retq
	
/* Statements can be of the form - 
;
return <expr>;
expr;
if (expr) {...} else {...}
while (expr) {...}
<type> <identifier>;
*/
parse_stmt:
	call	get_token
	cmpq	$TOKEN_SEMICOLON, %rax
	je	parse_empty_stmt
	movabsq	$KEYWORD_return, %rcx
	cmpq	%rcx, %rax
	je	parse_return_stmt
	cmpq	$KEYWORD_if, %rax
	je	parse_if_stmt	
	movabsq	$KEYWORD_while, %rcx
	cmpq	%rcx, %rax	
	je	parse_while_stmt

	call	return_token
	jmp	parse_expr_stmt	

parse_return_stmt:
	call	parse_expr	
	movb	$0x58, 	(%r14)	
	movb	$0x58, 	1(%r14)	
	leaq	2(%r14), %r14
	# Consume semicolon
	call	get_token
	call	gen_function_body_cleanup
	retq

parse_expr_stmt:
	call	parse_expr
	movw	$0x5858, (%r14)
	leaq	2(%r14), %r14		
	call	get_token
	retq

parse_if_stmt:
	call	parse_if_stmt_sub
	retq

#000000000000007c <if_condition>:
#  7c:   58                      pop    %rax
#  7d:   58                      pop    %rax
#  7e:   48 85 c0                test   %rax,%rax
#  81:   0f 84 08 00 00 00       je     8f <else_part>
#  87:   90                      nop
#  88:   90                      nop
#  89:   90                      nop
#  8a:   e9 03 00 00 00          jmp    92 <if_end>
#
#000000000000008f <else_part>:
#  8f:   90                      nop
#  90:   90                      nop
#  91:   90                      nop


parse_if_stmt_sub:
	push	%rbp
	movq	%rsp, %rbp
	leaq	-32(%rsp), %rsp
	# -8(%rbp) - address of conditional forward jump
	# -16(%rbp) - address of unconditional forward jump after then
	
	call	get_token
	call	parse_expr
	call	get_token
	
	movw	$0x5858, (%r14)		
	movb	$0x48, 2(%r14)
	movb	$0x85, 3(%r14)
	movb	$0xc0, 4(%r14)
	movw	$0x840f, 5(%r14)
	leaq	7(%r14), %r14
	movq	%r14, -8(%rbp)
	leaq	4(%r14), %r14
	
	callq	parse_stmt_block			

	call	get_token
	cmpq	$KEYWORD_else, %rax
	jne	finish_if_no_else

	movb	$0xe9, (%r14)	
	leaq	1(%r14), %r14
	movq	%r14, -16(%rbp)
	leaq	4(%r14), %r14

	movq	-8(%rbp), %rax
	movq	%r14, %rbx
	subq	%rax, %rbx
	leaq	-4(%rbx), %rbx
	movl	%ebx, (%rax)
	
	callq	parse_stmt_block	
	movq	-16(%rbp), %rax
	movq	%r14, %rbx
	subq	%rax, %rbx
	leaq	-4(%rbx), %rbx
	movl	%ebx, (%rax)
	jmp	finish_if_stmt
	
finish_if_no_else:
	callq	return_token

	movq	-8(%rbp), %rax
	movq	%r14, %rbx
	subq	%rax, %rbx
	leaq	-4(%rbx), %rbx
	movl	%ebx, (%rax)	
	
finish_if_stmt:
	leave
	retq

#0000000000000093 <loop_back>:
#  93: 90                        nop
#  94: 58                        pop    %rax
#  95: 58                        pop    %rax
#  96: 48 85 c0                  test   %rax,%rax
#  99: 0f 84 08 00 00 00         je     a7 <loop_done>
#  9f: 90                        nop
#  a0: 90                        nop
#  a1: 90                        nop
#  a2: e9 ec ff ff ff            jmp    93 <loop_back>
#
#00000000000000a7 <loop_done>:
#  a7: 90     

parse_while_stmt:
	call	parse_while_stmt_sub
	retq

parse_while_stmt_sub:
	push	%rbp
	movq	%rsp, %rbp
	leaq	-32(%rsp), %rsp
	# -8(%rbp) - store start of loop
	# -16(%rbp) - address of conditional forward jump after check

	call	get_token	
	movq	%r14, -8(%rbp)
	call	parse_expr
	call	get_token

	movw	$0x5858, (%r14)		
	movb	$0x48, 2(%r14)
	movb	$0x85, 3(%r14)
	movb	$0xc0, 4(%r14)
	movw	$0x840f, 5(%r14)
	leaq	7(%r14), %r14
	movq	%r14, -16(%rbp)
	leaq	4(%r14), %r14

	callq	parse_stmt_block
	movb	$0xe9, (%r14)	
	leaq	1(%r14), %r14
	
	movq	-8(%rbp), %rax	
	subq	%r14, %rax	
	leaq	-4(%rax), %rax
	movl	%eax, (%r14)	
	leaq	4(%r14), %r14

	movq	-16(%rbp), %rax
	movq	%r14, %rbx
	subq	%rax, %rbx
	leaq	-4(%rbx), %rbx
	movl	%ebx, (%rax)	
	
finish_while_stmt:
	leave 
	retq
	
	
parse_empty_stmt:
	retq


parse_stmt_block:
	call	get_token
parse_stmt_block_next:
	call	get_token
	cmpq	$TOKEN_RBRACES, %rax
	je	parse_stmt_block_end	
	call	return_token
	call	parse_stmt
	jmp	parse_stmt_block_next	
parse_stmt_block_end:
	retq

/* Exprs can be of the form - 
<unary_operator> <expr>
( expr )
<integer>
<identifier>
optionally have- 
<binary_operator> <expr>
(..., ...,)
*/

parse_expr:
	call	get_token	
	cmpq	$TOKEN_INTEGER, %rax
	je	parse_integer_expr

	cmpq	$TOKEN_IDENTIFIER, %rax
	je	parse_identifier_expr

	.globl parse_expr_error
parse_expr_error:	
	leaq	invalid_expr(%rip), %rdi
	movq	$invalid_expr_len, %rsi
	jmp	report_error	

parse_expr_continue:
	call	get_token

	leaq	binary_operator_table(%rip), %rcx
	leaq	-BOTES(%rcx), %rcx
check_next_binary_operator:
	leaq	BOTES(%rcx), %rcx
	cmpq	$0, (%rcx)
	je	parse_binary_operator_end	
	cmpq	(%rcx), %rax
	je	parse_binary_operator_expr
	jmp	check_next_binary_operator

parse_binary_operator_end:
	cmpq	$TOKEN_ASSIGN, %rax		
	je	parse_assign_expr	

	cmpq	$TOKEN_LPARAN, %rax
	je	parse_function_call_expr

parse_expr_end:
	call	return_token	
	retq
	
parse_integer_expr:
	movb	$0x48, (%r14)
	movb	$0xc7, 1(%r14)
	movb	$0xc0, 2(%r14)
	movl	%ebx,  3(%r14)	
	movb	$0x50, 7(%r14)
	push_nullptr 8
	leaq	10(%r14), %r14
	jmp 	parse_expr_continue
	
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
	movb	$0x48, (%r14)
	movb	$0x8d, 1(%r14)
	movb	$0x85, 2(%r14)
	movl	%eax,  3(%r14)
	movb	$0xff, 7(%r14)	
	movb	$0x30, 8(%r14)
	movb	$0x50, 9(%r14)
	leaq	10(%r14), %r14
	jmp	parse_expr_continue

parse_identifier_expr_global:
	movq	8(%rax), %rax	
	movb	$0x48, (%r14)
	movb	$0xb8, 1(%r14)
	movq	%rax, 2(%r14)
	movb	$0xff, 10(%r14)
	movb	$0x30, 11(%r14)	
	movb	$0x50, 12(%r14)
	leaq	13(%r14), %r14
	jmp	parse_expr_continue

parse_binary_operator_expr:
	pushq	%rcx
	callq	parse_expr
	popq	%rcx
	movl	$0xd23148, (%r14)
	leaq	3(%r14), %r14
	movl	$0xc93148, (%r14)
	movb	$0x5b, 3(%r14)	
	movb	$0x5b, 4(%r14)	
	movb	$0x58, 5(%r14)
	movb	$0x58, 6(%r14)
	movq	8(%rcx), %rcx
	movq	%rcx, 7(%r14)
	push_nullptr 15
	leaq	17(%r14), %r14
	jmp	parse_expr_continue

parse_assign_expr:
	pushq	%rcx
	callq	parse_expr
	popq	%rcx
	movl	$0x59585b5b, (%r14)
	movl	$0x53188948, 4(%r14)
	push_nullptr 8
	leaq	10(%r14), %r14
	jmp	parse_expr_continue

parse_function_call_expr:
	call	parse_function_call_expr_sub
	jmp	parse_expr_continue

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
	movb	$0x58, (%r14)	
	leaq	1(%r14), %r14
	addq	$8, -8(%rbp)	
	call	get_token
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_call_expr_end	
	jmp	parse_next_call_argument	
	
parse_function_call_expr_end:
	movq	-8(%rbp), %rax
	movl	$0x24848b48, (%r14)
	movl	%eax, 4(%r14)
	movw	$0xd0ff, 8(%r14)
	movl	$0x24a48d48, 10(%r14)
	leaq	16(%rax), %rax
	movl	%eax, 14(%r14)	
	movl	$0x50, 18(%r14)		
	push_nullptr 19
	leaq	21(%r14), %r14

	leave
	retq
	
parse_type:
	call	get_token
	cmpq $KEYWORD_char, %rax
	je	parse_type_done
	cmpq $KEYWORD_int, %rax
	je	parse_type_done
	cmpq $KEYWORD_long, %rax
	je	parse_type_done
	cmpq 	$KEYWORD_void, %rax
	je	parse_type_done

	leaq	pe_expected_type(%rip), %rdi
	movq	$pe_expected_type_len, %rsi
	jmp	report_error

parse_type_done:
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
current_function_slots:
	.quad 0
	
	.section .data
	.globl global_symbol_table
# 24 (GTES) bytes per identifier, <identifier_index>, <codegen address>, <type of variable>
global_symbol_table:
	.quad	1
	.quad	x86c_libc_put_char
	.quad	KEYWORD_void
global_symbol_table_start:
	.space 40960

	.section .bss
# 24 (LTES) per identifier, <identifier_index>, <stack slot offset>, <type of variable>
	.lcomm local_symbol_table, 40960

	.data
	.globl global_symbol_table_end
global_symbol_table_end:
	.quad	global_symbol_table_start
local_symbol_table_end:
	.quad	local_symbol_table


	.data
#8 bytes for operator, 4 bytes for instruction including push
binary_operator_table:
	.quad	TOKEN_PLUS
	.long	0x90909090
	.long	0x53c30148
	.quad	TOKEN_MINUS
	.long	0x90909090
	.long	0x50d82948
	.quad	TOKEN_STAR
	.long	0x90909090
	.long	0x50ebf748	
	.quad	TOKEN_DIVIDE
	.long	0x90909090
	.long	0x50fbf748
	.quad	TOKEN_PERCENT
	.long	0x90909090
	.long	0x52fbf748
	.quad	TOKEN_EQUALS
	.quad	0x9051c1940fd83948
	.quad	TOKEN_NOTEQUALS
	.quad	0x9051c1950fd83948
	.quad	TOKEN_LESSTHAN
	.quad	0x9051c19c0fd83948
	.quad	TOKEN_GREATERTHAN
	.quad	0x9051c19f0fd83948
	.quad	TOKEN_LESSEQUALS
	.quad	0x9051c19e0fd83948
	.quad	TOKEN_GREATEREQUALS
	.quad	0x9051c19d0fd83948

	.quad	0
	.quad	0

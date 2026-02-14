.include "defs.inc"



	.text
pe_expected_type:
	.asciz "Parser Expected Type"
.equ pe_expected_type_len, . - pe_expected_type

pe_expected_identifier:
	.asciz "Parser Expected Identifier"
.equ pe_expected_identifier_len, . - pe_expected_identifier

pe_var_no_init:
	.asciz "Variable Intialization Not Supported"
.equ pe_var_no_init_len, . - pe_var_no_init

invalid_stmt:
	.asciz "Invalid Stmt"
.equ invalid_stmt_len, . - invalid_stmt

invalid_expr:
	.asciz "Invalid Expr"
.equ invalid_expr_len, . - invalid_expr

	.text
	.globl parse_tu	
parse_tu:
	call	get_token
	cmpq	$TOKEN_EOF, %rax
	je	parse_tu_end
	call	parse_tld
	jmp	parse_tu

parse_tu_end:
	retq

parse_tld:
	
	call 	parse_type_no_read
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
	cmpq	$TOKEN_SEMICOLON, %rax
	je	parse_global_end

	leaq	pe_var_no_init(%rip), %rdi	
	movq	$pe_var_no_init_len, %rsi
	jmp	report_error
		
parse_global_end:
	movq	global_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%r14, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	24(%rax), %rax
	movq	%rax, global_symbol_table_end(%rip)
	leaq	8(%r14), %r14

	retq		

	
parse_function:
	movq	global_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%r14, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	24(%rax), %rax
	movq	%rax, global_symbol_table_end(%rip)

	movq	$0, current_function_slots(%rip)
	leaq	local_symbol_table(%rip), %rax
	movq	%rax, local_symbol_table_end(%rip)

	call 	get_token	
	cmpq	$TOKEN_RPARAN, %rax
	je	parse_function_body

parse_argument:
	call	parse_type_no_read
	movq	%rax, %r11	
	call 	get_token
	cmpq	$TOKEN_IDENTIFIER, %rax	
	leaq	pe_expected_identifier(%rip), %rdi	
	movq	$pe_expected_identifier_len, %rsi
	jne 	report_error
	movq	%rbx, %r12

	# assign stack slot	
	movq	current_function_slots(%rip), %rbx 
	leaq	8(%rbx), %rax
	movq	%rax, current_function_slots(%rip)
	
	movq	local_symbol_table_end(%rip), %rax
	movq	%r12, (%rax)
	movq	%rbx, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	24(%rax), %rax
	movq	%rax, local_symbol_table_end(%rip)

	call	get_token
	cmpq	TOKEN_RPARAN, %rax
	je	parse_function_body		

	call 	get_token	
	jmp	parse_argument

parse_function_body:
	# consume the {
	call	get_token		

	# First token of the next statement
parse_function_body_next:
	call	get_token
	cmpq	$TOKEN_RBRACES, %rax
	je	parse_function_body_end
	call	parse_stmt
	jmp	parse_function_body_next

parse_function_body_end:
	# Finalize the function
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
	cmpq	$TOKEN_SEMICOLON, %rax
	je	parse_stmt_done
	movabsq	$KEYWORD_return, %rcx
	cmpq	%rcx, %rax
	je	parse_return_stmt
	leaq	invalid_stmt(%rip), %rdi
	movq	$invalid_stmt_len, %rsi
	jmp	report_error	

parse_return_stmt:
	call	parse_expr	
	# semicolon already consumed by parse_expr
	movb	$0x58, 	(%r14)	
	movb	$0xc3, 	1(%r14)
	leaq	2(%r14), %r14
	retq

parse_stmt_done:
	retq

/* Exprs can be of the form - 
<unary_operator> <expr>
( expr )
<integer>
<identifier>
optionally have- 
<binary_operator> <expr>
*/

parse_expr:
	call	get_token	
	cmpq	$TOKEN_INTEGER, %rax
	je	parse_integer_expr
	
	leaq	invalid_expr(%rip), %rdi
	movq	$invalid_expr_len, %rsi
	jmp	report_error	

parse_expr_continue:
	call 	get_token
	retq
	
parse_integer_expr:
	movb	$0x48, (%r14)
	movb	$0xc7, 1(%r14)
	movb	$0xc0, 2(%r14)
	movl	%ebx,  3(%r14)	
	movb	$0x50, 7(%r14)
	leaq	8(%r14), %r14
	jmp 	parse_expr_continue
	

parse_type:
parse_type_no_read:
	cmpq $KEYWORD_char, %rax
	je	parse_type_done
	cmpq $KEYWORD_int, %rax
	je	parse_type_done
	cmpq $KEYWORD_long, %rax
	je	parse_type_done
	cmpq $KEYWORD_void, %rax
	je	parse_type_done

	leaq	pe_expected_type(%rip), %rdi
	movq	$pe_expected_type_len, %rsi
	jmp	report_error

parse_type_done:
	retq


	.data
current_function_slots:
	.quad 0
	
	.section .bss
	.globl global_symbol_table
# 24 bytes per identifier, <identifier_index>, <codegen address>, <type of variable>
	.lcomm global_symbol_table, 40960

	.section .bss
# 24 bytes per identifier, <identifier_index>, <stack slot offset>, <type of variable>
	.lcomm local_symbol_table, 40960

	.data
	.globl global_symbol_table_end
global_symbol_table_end:
	.quad	global_symbol_table
local_symbol_table_end:
	.quad	local_symbol_table




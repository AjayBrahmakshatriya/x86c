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

parse_variable_decl_error_msg:
	.asciz "Variable declaration expected variable name"
.equ parse_variable_decl_error_msg_len, . - parse_variable_decl_error_msg


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

	# 55          		push   %rbp
  	# 48 89 e5    		mov    %rsp, %rbp
  	# 48 8d a4 24 cc ed ff  lea    -0x1234(%rsp),%rsp
  	# ff
	
	movl	$0xe5894855, (%r14)
	movl	$0x24a48d48, 4(%r14)
	leaq	8(%r14), %r14
	movq	%r14, current_function_stack_setup_patch(%rip)
	leaq	4(%r14), %r14
	
	movq	$-8, current_function_slots(%rip)	
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
	movq	current_function_slots(%rip), %rax
	movq	current_function_stack_setup_patch(%rip), %rbx
	movl	%eax, (%rbx)
	retq

gen_function_body_cleanup:
	# Finalize the function
  	# c9     leave
  	# c3     ret
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

	movq	%rax, %rsi	
	call	check_is_type	
	
	testq	%rax, %rax
	jnz	parse_variable_decl

	movq	%rsi, %rax

	call	return_token
	jmp	parse_expr_stmt	

parse_return_stmt:
	call	parse_expr	
	call	ensure_rvalue
	# Consume semicolon
	call	get_token
	call	gen_function_body_cleanup
	retq

parse_expr_stmt:
	call	parse_expr
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
	call	ensure_rvalue
	call	get_token
	
        # 48 85 c0             test   %rax,%rax
        # 0f 84 00 00 00 00    je     00 <else_part>
	movb	$0x48, 0(%r14)
	movb	$0x85, 1(%r14)
	movb	$0xc0, 2(%r14)
	movw	$0x840f, 3(%r14)
	leaq	5(%r14), %r14
	movq	%r14, -8(%rbp)
	leaq	4(%r14), %r14
	
	callq	parse_stmt_block			

	call	get_token
	cmpq	$KEYWORD_else, %rax
	jne	finish_if_no_else

	# e9 00 00 00 00    jmp    00 <if_end>
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
	call	ensure_rvalue
	call	get_token


  	# 48 85 c0             test   %rax,%rax
 	# 0f 84 00 00 00 00    je     00 <loop_done>
	movb	$0x48, 0(%r14)
	movb	$0x85, 1(%r14)
	movb	$0xc0, 2(%r14)
	movw	$0x840f, 3(%r14)
	leaq	5(%r14), %r14
	movq	%r14, -16(%rbp)
	leaq	4(%r14), %r14

	callq	parse_stmt_block

	# e9 ff ff ff ff    jmp    00 <loop_back>
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


parse_variable_decl:
	push	%rbp
	movq	%rsp, %rbp
	subq	$8, %rsp
	# -8 (%rbp) - current variable slot
	movq	%rsi, %rax
	call	return_token	
	call	parse_type
	movq	%rax, %r11
	call	get_token
	cmpq	$TOKEN_IDENTIFIER, %rax
	jne	parse_variable_decl_error
	movq	%rbx, %r12

	movq	current_function_slots(%rip), %rbx
	movq	local_symbol_table_end(%rip), %rax	
	movq	%r12, (%rax)
	movq	%rbx, 8(%rax)
	movq	%r11, 16(%rax)
	leaq	LTES(%rax), %rax
	movq	%rax, local_symbol_table_end(%rip)
	movq	%rbx, -8(%rbp)
	leaq	-0x8(%rbx), %rbx
	movq	%rbx, current_function_slots(%rip)
	
	call	get_token

	cmpq	$TOKEN_ASSIGN, %rax
	jne	parse_variable_decl_no_init

	call	parse_expr
	call	ensure_rvalue
        # 48 89 85 00 00 00 00    mov    %rax,0x0000(%rbp)	
	movq	-8(%rbp), %rbx
	movl	$0x00858948, 0(%r14)
	movl	%ebx, 3(%r14)
	leaq	7(%r14), %r14
	call	get_token	

parse_variable_decl_no_init:
	cmpq	$TOKEN_SEMICOLON, %rax
	jne	parse_variable_decl_error

	leave
	retq	

parse_variable_decl_error:
	leaq	parse_variable_decl_error_msg(%rip), %rdi
	movq	$parse_variable_decl_error_msg_len, %rsi
	jmp	report_error

check_is_type:
	movq	$1, %rax	
	cmpq	$KEYWORD_char, %rsi
	je	check_is_type_return
	cmpq	$KEYWORD_int, %rsi
	je	check_is_type_return
	cmpq	$KEYWORD_long, %rsi
	je	check_is_type_return	
	cmpq	$KEYWORD_void, %rsi
	je	check_is_type_return

	xor	%rax, %rax
check_is_type_return:
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
	call	get_token
	cmpq	$TOKEN_STAR, %rax
	je	parse_type_done
	call	return_token

	retq


	.data
	.globl current_function_slots
current_function_slots:
	.quad 0
current_function_stack_setup_patch:
	.quad 0
	
	.section .data
	.globl global_symbol_table
# 24 (GTES) bytes per identifier, <identifier_index>, <codegen address>, <type of variable>
global_symbol_table:
	.quad	1
	.quad	x86c_libc_syscall6	
#+ codegen_buffer + elf_header_size
	.quad	KEYWORD_void
global_symbol_table_start:
	.space 40960

	.section .bss
# 24 (LTES) per identifier, <identifier_index>, <stack slot offset>, <type of variable>
	.globl local_symbol_table
	.lcomm local_symbol_table, 40960

	.data
	.globl global_symbol_table_end
global_symbol_table_end:
	.quad	global_symbol_table_start

	.globl local_symbol_table_end
local_symbol_table_end:
	.quad	local_symbol_table



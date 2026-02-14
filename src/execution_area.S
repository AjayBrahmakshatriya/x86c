	.section .execarea, "awx", @nobits
	.globl codegen_buffer
codegen_buffer:
	.space 409600


	.text
main_not_found_msg:
	.asciz "Main function not found"
.equ main_not_found_msg_len, . - main_not_found_msg


main_not_found:
	leaq	main_not_found_msg(%rip), %rdi
	movq	$main_not_found_msg_len, %rsi
	jmp	report_error

	.text
	.globl execute_program
execute_program:
	# identifier index of main is 0
	leaq	global_symbol_table(%rip), %rax
	movq	global_symbol_table_end(%rip), %rbx
	leaq	-24(%rax), %rax
check_next_function:
	leaq	24(%rax), %rax
	cmpq	%rax, %rbx
	je	main_not_found
	cmpq	$0, (%rax)
	jne	check_next_function

	movq	8(%rax), %rax
	jmp	*%rax

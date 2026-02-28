.include "defs.inc"
	.bss
	.globl codegen_buffer
	.balign 4096
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


	.globl	prepare_execution_area
prepare_execution_area:
	leaq	codegen_buffer(%rip), %rdi
	leaq	elf_template_header(%rip), %rsi
	movq	$elf_header_size, %rcx
	cld
	rep	movsb		
		
	movq	%rdi, elf_template_header_e_entry - elf_template_header + codegen_buffer(%rip)

	leaq	_x86c_libc_begin(%rip), %rsi
	movq	_x86c_libc_size(%rip), %rcx
	rep 	movsb

	# Patch in address of put_char
	leaq	x86c_libc_put_char(%rip), %rax
	leaq	_x86c_libc_begin(%rip), %rbx
	subq	%rbx, %rax
	leaq	codegen_buffer(%rip), %rbx
	leaq	elf_header_size(%rax, %rbx, 1), %rax
	movq	%rax, global_symbol_table + 8(%rip)
	
	movq	%rdi, %r14
	retq
	
	.globl execution_area_finalize		
execution_area_finalize:
	leaq	codegen_buffer(%rip), %rdi
	movq	%r14, %rax
	subq	%rdi, %rax
	subq	$elf_header_size, %rax
	movq	%rax, ph_template_header_program_size - elf_template_header + codegen_buffer(%rip)	
	movq	%rax, ph_template_header_program_size - elf_template_header + codegen_buffer + 8(%rip)	

	leaq	global_symbol_table(%rip), %rax
	movq	global_symbol_table_end(%rip), %rbx
	leaq	-24(%rax), %rax
execution_area_finalize_check_next:
	leaq	24(%rax), %rax
	cmpq	%rax, %rbx
	je	main_not_found
	cmpq	$0, (%rax)
	jne	execution_area_finalize_check_next

	movq	8(%rax), %rax
	# movq	%rax, elf_template_header_e_entry - elf_template_header + codegen_buffer(%rip)
	leaq	codegen_buffer(%rip), %rbx
	movq	%rax, elf_header_size + 2 (%rbx)	
	retq	
	


	.data
elf_template_header:
	# ELF MAGIC STRING
	.quad 0x00010102464c457f
	.quad 0
	# Elf64_Half e_type;
	.short 	2
	# Elf64_Half e_machine;
	.short 62
	# Elf64_Word e_version;
	.long 1
	# Elf64_Addr e_entry;
elf_template_header_e_entry:
	.quad 0
	# Elf64_Off e_phoff;
	.quad ph_template_header - elf_template_header
	# Elf64_Off e_shoff;
	.quad 0
	# Elf64_Word e_flags;
	.long 0
	# Elf64_Half e_ehsize;
	.short 64
	# Elf64_Half e_phentsize;
	.short 56
	# Elf64_Half e_phnum;
	.short 1
	# Elf64_Half e_shentsize;
	.short 0
	# Elf64_Half e_shnum;
	.short 0
	# Elf64_Half e_shstrndx;
	.short 0
	
ph_template_header:
	#Elf64_Word p_type;
	.long 1
	#Elf64_Word p_flags;
	.long 7
	#Elf64_Off p_offset;
	.quad ph_template_end - elf_template_header
	#Elf64_Addr p_vaddr;
	.quad codegen_buffer + (ph_template_end - elf_template_header)
	#Elf64_Addr p_paddr;
	.quad 0
	#Elf64_Xword p_filesz;
ph_template_header_program_size:
	.quad 0	
	#Elf64_Xword p_memsz;
	.quad 0
	#Elf64_Xword p_align;
	.quad 0x1000
ph_template_end:



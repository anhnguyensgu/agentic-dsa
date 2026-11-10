<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	push   rax
	mov    rbx,rdx
	mov    r13,rsi
	lea    r14,[rdx+0x1]
	lea    r15,[rdx*4+0x4]
	mov    rax,r14
	shr    rax,0x3e
	setne  dl
	movabs rax,0x7ffffffffffffffc
	cmp    r15,rax
	seta   al
	or     al,dl
	mov    ebp,ebx
	inc    ebp
	jne    <coin_change+0x91>
	test   al,al
	jne    <coin_change+0x95>
	test   r15,r15
	je     <coin_change+0x13e>
	mov    rbp,rdi
	call   QWORD PTR [rip+0x4054b]
	mov    r12d,0x4
	mov    esi,0x4
	mov    rdi,r15
	call   QWORD PTR [rip+0x40587]
	test   rax,rax
	je     <coin_change+0x98>
	mov    rsi,r14
	mov    rdi,rbp
	test   r14,r14
	je     <coin_change+0x21f>
	mov    DWORD PTR [rax],0x0
	test   r13,r13
	jne    <coin_change+0x17e>
	jmp    <coin_change+0x1d6>
	test   al,al
	je     <coin_change+0xa4>
	xor    r12d,r12d
	mov    rdi,r12
	mov    rsi,r15
	call   QWORD PTR [rip+0x404e4]
	test   r15,r15
	je     <coin_change+0x153>
	mov    QWORD PTR [rsp],rdi
	call   QWORD PTR [rip+0x404e9]
	mov    r12d,0x4
	mov    esi,0x4
	mov    rdi,r15
	call   QWORD PTR [rip+0x404dd]
	mov    rdi,QWORD PTR [rsp]
	mov    rsi,r14
	test   rax,rax
	je     <coin_change+0x98>
	cmp    r14,0x2
	jb     <coin_change+0x164>
	lea    r9,[rbx-0x1]
	mov    edx,ebx
	and    edx,0x7
	mov    r8,rax
	cmp    r9,0x7
	jb     <coin_change+0x130>
	mov    r9,rbx
	and    r9,0xfffffffffffffff8
	mov    r8,rax
	nop    DWORD PTR [rax]
	mov    DWORD PTR [r8],ebp
	mov    DWORD PTR [r8+0x4],ebp
	mov    DWORD PTR [r8+0x8],ebp
	mov    DWORD PTR [r8+0xc],ebp
	mov    DWORD PTR [r8+0x10],ebp
	mov    DWORD PTR [r8+0x14],ebp
	mov    DWORD PTR [r8+0x18],ebp
	mov    DWORD PTR [r8+0x1c],ebp
	add    r8,0x20
	add    r9,0xfffffffffffffff8
	jne    <coin_change+0x100>
	test   rdx,rdx
	je     <coin_change+0x170>
	xchg   ax,ax
	mov    DWORD PTR [r8],ebp
	add    r8,0x4
	dec    rdx
	jne    <coin_change+0x130>
	jmp    <coin_change+0x170>
	mov    eax,0x4
	xor    esi,esi
	test   r14,r14
	jne    <coin_change+0x7d>
	jmp    <coin_change+0x21f>
	mov    eax,0x4
	xor    esi,esi
	cmp    r14,0x2
	jae    <coin_change+0xe1>
	mov    r8,rax
	test   r14,r14
	je     <coin_change+0x21f>
	mov    DWORD PTR [r8],ebp
	mov    DWORD PTR [rax],0x0
	test   r13,r13
	je     <coin_change+0x1d6>
	lea    rdx,[rdi+r13*4]
	lea    r8,[rbx+0x1]
	jmp    <coin_change+0x199>
	nop    DWORD PTR [rax+rax*1+0x0]
	add    rdi,0x4
	cmp    rdi,rdx
	je     <coin_change+0x1d0>
	mov    ecx,DWORD PTR [rdi]
	cmp    r14,rcx
	jbe    <coin_change+0x190>
	mov    r9,r8
	sub    r9,rcx
	lea    r10,[rax+rcx*4]
	xor    ecx,ecx
	jmp    <coin_change+0x1b8>
	xchg   ax,ax
	inc    rcx
	cmp    r9,rcx
	je     <coin_change+0x190>
	cmp    rcx,r14
	jae    <coin_change+0x20c>
	mov    r11d,DWORD PTR [rax+rcx*4]
	inc    r11d
	cmp    r11d,DWORD PTR [r10+rcx*4]
	jae    <coin_change+0x1b0>
	mov    DWORD PTR [r10+rcx*4],r11d
	jmp    <coin_change+0x1b0>
	cmp    rbx,0xffffffffffffffff
	je     <coin_change+0x230>
	mov    r14d,DWORD PTR [rax+rbx*4]
	test   rsi,rsi
	je     <coin_change+0x1f1>
	shl    rsi,0x2
	mov    edx,0x4
	mov    rdi,rax
	call   QWORD PTR [rip+0x403bf]
	cmp    rbx,r14
	mov    eax,0xffffffff
	cmovae eax,r14d
	add    rsp,0x8
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	lea    rdx,[rip+0x3e565]
	mov    rdi,rcx
	mov    rsi,r14
	call   QWORD PTR [rip+0x403d9]
	lea    rdx,[rip+0x3e53a]
	xor    edi,edi
	xor    esi,esi
	call   QWORD PTR [rip+0x403c8]
	lea    rdx,[rip+0x3e559]
	mov    rdi,0xffffffffffffffff
	mov    rsi,r14
	call   QWORD PTR [rip+0x403b1]

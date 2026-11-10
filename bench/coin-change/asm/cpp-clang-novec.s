<coin_change>:
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	push   rax
	mov    rbx,rdx
	mov    r14,rsi
	mov    r15,rdi
	xor    edi,edi
	mov    r12,rdx
	mov    esi,0x0
	inc    r12
	je     <coin_change+0xb8>
	mov    rax,r12
	shr    rax,0x3e
	jne    <coin_change+0x174>
	lea    r13d,[rbx+0x1]
	lea    rdi,[r12*4+0x0]
	call   <_Znwm>
	mov    rdi,rax
	mov    al,0x3e
	bzhi   rcx,rbx,rax
	mov    edx,ebx
	not    edx
	mov    rax,rdi
	test   dl,0x7
	je     <coin_change+0x7c>
	lea    edx,[rbx+0x1]
	and    edx,0x7
	mov    rax,rdi
	nop    WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax],r13d
	add    rax,0x4
	dec    rdx
	jne    <coin_change+0x70>
	lea    rsi,[rdi+r12*4]
	cmp    rcx,0x7
	jb     <coin_change+0xb8>
	cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax],r13d
	mov    DWORD PTR [rax+0x4],r13d
	mov    DWORD PTR [rax+0x8],r13d
	mov    DWORD PTR [rax+0xc],r13d
	mov    DWORD PTR [rax+0x10],r13d
	mov    DWORD PTR [rax+0x14],r13d
	mov    DWORD PTR [rax+0x18],r13d
	mov    DWORD PTR [rax+0x1c],r13d
	add    rax,0x20
	cmp    rax,rsi
	jne    <coin_change+0x90>
	mov    DWORD PTR [rdi],0x0
	test   r14,r14
	je     <coin_change+0x14d>
	lea    rax,[rdi+0x4]
	xor    ecx,ecx
	jmp    <coin_change+0xd8>
	nop
	inc    rcx
	cmp    rcx,r14
	je     <coin_change+0x14d>
	mov    edx,DWORD PTR [r15+rcx*4]
	cmp    r12,rdx
	jbe    <coin_change+0xd0>
	lea    r8d,[rbx+rdx*1]
	mov    r9,rdx
	test   r8b,0x1
	jne    <coin_change+0x102>
	mov    r8d,DWORD PTR [rdi]
	inc    r8d
	cmp    r8d,DWORD PTR [rdi+rdx*4]
	jae    <coin_change+0xfe>
	mov    DWORD PTR [rdi+rdx*4],r8d
	lea    r9,[rdx+0x1]
	cmp    rbx,rdx
	je     <coin_change+0xd0>
	mov    r8,r12
	sub    r8,r9
	lea    r9,[rax+r9*4]
	shl    rdx,0x2
	neg    rdx
	jmp    <coin_change+0x12a>
	nop    WORD PTR [rax+rax*1+0x0]
	add    r9,0x8
	add    r8,0xfffffffffffffffe
	je     <coin_change+0xd0>
	mov    r10d,DWORD PTR [r9+rdx*1-0x4]
	inc    r10d
	cmp    r10d,DWORD PTR [r9-0x4]
	jae    <coin_change+0x13c>
	mov    DWORD PTR [r9-0x4],r10d
	mov    r10d,DWORD PTR [r9+rdx*1]
	inc    r10d
	cmp    r10d,DWORD PTR [r9]
	jae    <coin_change+0x120>
	mov    DWORD PTR [r9],r10d
	jmp    <coin_change+0x120>
	mov    eax,DWORD PTR [rdi+rbx*4]
	cmp    rbx,rax
	mov    ebx,0xffffffff
	cmovae ebx,eax
	sub    rsi,rdi
	call   <_ZdlPvm>
	mov    eax,ebx
	add    rsp,0x8
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	call   <_ZNSt3__16vectorIjNS_9allocatorIjEEE20__throw_length_errorB9nin220108Ev>

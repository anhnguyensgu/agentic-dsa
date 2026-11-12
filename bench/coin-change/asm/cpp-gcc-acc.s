<coin_change>:
	endbr64
	push   rbp
	mov    rbp,rsp
	push   r15
	lea    r15,[rdx+0x1]
	mov    rax,r15
	push   r14
	push   r13
	push   r12
	push   rbx
	and    rsp,0xffffffffffffffe0
	sub    rsp,0x20
	shr    rax,0x3d
	jne    <coin_change+0x1ce>
	mov    r12,rdx
	test   r15,r15
	je     <coin_change+0x1b3>
	lea    r14,[r15*4+0x0]
	mov    rbx,rdi
	mov    rdi,r14
	mov    QWORD PTR [rsp+0x18],rsi
	lea    r13d,[rdx+0x1]
	call   <_Znwm@plt>
	mov    r9,rax
	lea    rax,[r14-0x4]
	mov    rdx,rax
	shr    rdx,0x2
	cmp    rax,0x18
	mov    rsi,QWORD PTR [rsp+0x18]
	lea    rdi,[rdx+0x1]
	jbe    <coin_change+0x1c4>
	mov    rcx,rdi
	shr    rcx,0x3
	shl    rcx,0x5
	lea    r8,[rcx+r9*1]
	and    ecx,0x20
	vpbroadcastd ymm0,r13d
	mov    rax,r9
	je     <coin_change+0xa0>
	lea    rax,[r9+0x20]
	vmovdqu YMMWORD PTR [r9],ymm0
	cmp    rax,r8
	je     <coin_change+0xb2>
	xchg   ax,ax
	vmovdqu YMMWORD PTR [rax],ymm0
	vmovdqu YMMWORD PTR [rax+0x20],ymm0
	add    rax,0x40
	cmp    rax,r8
	jne    <coin_change+0xa0>
	mov    rcx,rdi
	and    rcx,0xfffffffffffffff8
	and    edi,0x7
	lea    rax,[r9+rcx*4]
	je     <coin_change+0x1bc>
	vzeroupper
	sub    rdx,rcx
	lea    rdi,[rdx+0x1]
	cmp    rdx,0x2
	jbe    <coin_change+0xf2>
	mov    rdx,rdi
	and    rdx,0xfffffffffffffffc
	vpbroadcastd xmm0,r13d
	and    edi,0x3
	vmovdqu XMMWORD PTR [r9+rcx*4],xmm0
	lea    rax,[rax+rdx*4]
	je     <coin_change+0x113>
	lea    rdx,[r9+r14*1]
	lea    rcx,[rax+0x4]
	mov    DWORD PTR [rax],r13d
	cmp    rdx,rcx
	je     <coin_change+0x113>
	lea    rcx,[rax+0x8]
	mov    DWORD PTR [rax+0x4],r13d
	cmp    rdx,rcx
	je     <coin_change+0x113>
	mov    DWORD PTR [rax+0x8],r13d
	mov    DWORD PTR [r9],0x0
	cmp    r15,0x1
	je     <coin_change+0x188>
	lea    rdi,[rbx+rsi*4]
	mov    ecx,0x1
	test   rsi,rsi
	je     <coin_change+0x17b>
	xchg   ax,ax
	mov    rax,rbx
	mov    esi,r13d
	cs nop WORD PTR [rax+rax*1+0x0]
	mov    edx,DWORD PTR [rax]
	cmp    rcx,rdx
	jb     <coin_change+0x158>
	mov    r8,rcx
	sub    r8,rdx
	mov    edx,DWORD PTR [r9+r8*4]
	inc    edx
	cmp    esi,edx
	cmova  esi,edx
	add    rax,0x4
	cmp    rax,rdi
	jne    <coin_change+0x140>
	mov    DWORD PTR [r9+rcx*4],esi
	lea    rax,[rcx+0x1]
	cmp    r12,rcx
	je     <coin_change+0x188>
	mov    rcx,rax
	jmp    <coin_change+0x130>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    rcx,rax
	mov    DWORD PTR [r9+rcx*4],r13d
	lea    rax,[rcx+0x1]
	cmp    r12,rcx
	jne    <coin_change+0x178>
	mov    edx,DWORD PTR [r9+r12*4]
	mov    ebx,0xffffffff
	cmp    r12,rdx
	cmovae ebx,edx
	mov    rsi,r14
	mov    rdi,r9
	call   <_ZdlPvm@plt>
	lea    rsp,[rbp-0x28]
	mov    eax,ebx
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	mov    DWORD PTR [rdx+0x1],0x0
	ud2
	vzeroupper
	jmp    <coin_change+0x113>
	mov    rax,r9
	xor    ecx,ecx
	jmp    <coin_change+0xc9>
	lea    rdi,[rip+0x9f3]
	call   <_ZSt20__throw_length_errorPKc@plt>

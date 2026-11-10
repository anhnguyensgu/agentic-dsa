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
	lea    r12,[rdx*4+0x4]
	mov    rdi,r12
	call   <malloc@plt>
	test   rax,rax
	je     <coin_change+0x1bf>
	test   r12,r12
	je     <coin_change+0xa0>
	lea    ecx,[rbx+0x1]
	mov    dl,0x3e
	bzhi   rsi,rbx,rdx
	mov    edi,ebx
	not    edi
	mov    rdx,rax
	test   dil,0x7
	je     <coin_change+0x6b>
	lea    edi,[rbx+0x1]
	and    edi,0x7
	mov    rdx,rax
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdx],ecx
	add    rdx,0x4
	dec    rdi
	jne    <coin_change+0x60>
	cmp    rsi,0x7
	jb     <coin_change+0xa0>
	add    r12,rax
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdx],ecx
	mov    DWORD PTR [rdx+0x4],ecx
	mov    DWORD PTR [rdx+0x8],ecx
	mov    DWORD PTR [rdx+0xc],ecx
	mov    DWORD PTR [rdx+0x10],ecx
	mov    DWORD PTR [rdx+0x14],ecx
	mov    DWORD PTR [rdx+0x18],ecx
	mov    DWORD PTR [rdx+0x1c],ecx
	add    rdx,0x20
	cmp    rdx,r12
	jne    <coin_change+0x80>
	mov    DWORD PTR [rax],0x0
	test   r14,r14
	je     <coin_change+0x198>
	lea    rcx,[rbx+0x1]
	mov    rdx,rax
	add    rdx,0xc
	xor    esi,esi
	jmp    <coin_change+0xcc>
	xchg   ax,ax
	inc    rsi
	cmp    rsi,r14
	je     <coin_change+0x198>
	mov    edi,DWORD PTR [r15+rsi*4]
	mov    r8,rbx
	sub    r8,rdi
	jb     <coin_change+0xc0>
	mov    r10d,ecx
	sub    r10d,edi
	mov    r9,rdi
	and    r10d,0x3
	je     <coin_change+0x111>
	mov    r9,rdi
	xor    r11d,r11d
	nop    DWORD PTR [rax]
	mov    r12d,DWORD PTR [rax+r11*4]
	inc    r12d
	mov    r13d,DWORD PTR [rax+r9*4]
	cmp    r12d,r13d
	cmovae r12d,r13d
	mov    DWORD PTR [rax+r9*4],r12d
	inc    r9
	inc    r11
	cmp    r10,r11
	jne    <coin_change+0xf0>
	cmp    r8,0x3
	jb     <coin_change+0xc0>
	mov    r8,rcx
	sub    r8,r9
	lea    r9,[rdx+r9*4]
	shl    rdi,0x2
	neg    rdi
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    r10d,DWORD PTR [r9+rdi*1-0xc]
	inc    r10d
	mov    r11d,DWORD PTR [r9-0xc]
	mov    r12d,DWORD PTR [r9-0x8]
	cmp    r10d,r11d
	cmovae r10d,r11d
	mov    DWORD PTR [r9-0xc],r10d
	mov    r10d,DWORD PTR [r9+rdi*1-0x8]
	inc    r10d
	cmp    r10d,r12d
	cmovae r10d,r12d
	mov    DWORD PTR [r9-0x8],r10d
	mov    r10d,DWORD PTR [r9+rdi*1-0x4]
	inc    r10d
	mov    r11d,DWORD PTR [r9-0x4]
	cmp    r10d,r11d
	cmovae r10d,r11d
	mov    DWORD PTR [r9-0x4],r10d
	mov    r10d,DWORD PTR [r9+rdi*1]
	inc    r10d
	mov    r11d,DWORD PTR [r9]
	cmp    r10d,r11d
	cmovae r10d,r11d
	mov    DWORD PTR [r9],r10d
	add    r9,0x10
	add    r8,0xfffffffffffffffc
	jne    <coin_change+0x130>
	jmp    <coin_change+0xc0>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	call   <free@plt>
	mov    eax,ebx
	add    rsp,0x8
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	ud2

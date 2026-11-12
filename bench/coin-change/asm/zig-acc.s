<coin_change>:
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r12
	push   rbx
	mov    rbx,rdx
	mov    r14,rsi
	mov    r15,rdi
	lea    r12,[rdx*4+0x4]
	mov    rdi,r12
	call   <malloc@plt>
	test   rax,rax
	je     <coin_change+0x29c>
	lea    ecx,[rbx+0x1]
	test   r12,r12
	je     <coin_change+0xa0>
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
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
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
	test   rbx,rbx
	je     <coin_change+0x27b>
	test   r14,r14
	je     <coin_change+0x208>
	mov    edx,r14d
	and    edx,0x3
	mov    rsi,r14
	and    rsi,0xfffffffffffffffc
	mov    edi,0x1
	jmp    <coin_change+0xe1>
	nop    DWORD PTR [rax+0x0]
	mov    DWORD PTR [rax+rdi*4],r8d
	cmp    rdi,rbx
	lea    rdi,[rdi+0x1]
	je     <coin_change+0x27b>
	xor    r9d,r9d
	mov    r8d,ecx
	cmp    r14,0x4
	jae    <coin_change+0x110>
	jmp    <coin_change+0x1c9>
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    r8d,r10d
	add    r9,0x4
	cmp    rsi,r9
	je     <coin_change+0x1c0>
	mov    r11d,DWORD PTR [r15+r9*4]
	mov    r10,rdi
	sub    r10,r11
	jae    <coin_change+0x150>
	mov    r11d,DWORD PTR [r15+r9*4+0x4]
	mov    r10,rdi
	sub    r10,r11
	jae    <coin_change+0x16b>
	mov    r11d,DWORD PTR [r15+r9*4+0x8]
	mov    r10,rdi
	sub    r10,r11
	jae    <coin_change+0x186>
	mov    r11d,DWORD PTR [r15+r9*4+0xc]
	mov    r10,rdi
	sub    r10,r11
	jb     <coin_change+0x103>
	jmp    <coin_change+0x1a5>
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r8d
	cmovb  r8d,r10d
	mov    r11d,DWORD PTR [r15+r9*4+0x4]
	mov    r10,rdi
	sub    r10,r11
	jb     <coin_change+0x129>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r8d
	cmovb  r8d,r10d
	mov    r11d,DWORD PTR [r15+r9*4+0x8]
	mov    r10,rdi
	sub    r10,r11
	jb     <coin_change+0x136>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r8d
	cmovb  r8d,r10d
	mov    r11d,DWORD PTR [r15+r9*4+0xc]
	mov    r10,rdi
	sub    r10,r11
	jb     <coin_change+0x103>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r8d
	jb     <coin_change+0x100>
	mov    r10d,r8d
	jmp    <coin_change+0x100>
	nop    DWORD PTR [rax]
	test   rdx,rdx
	je     <coin_change+0xd0>
	lea    r9,[r15+r9*4]
	xor    r10d,r10d
	jmp    <coin_change+0x1ec>
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	inc    r10
	cmp    rdx,r10
	je     <coin_change+0xd0>
	mov    r12d,DWORD PTR [r9+r10*4]
	mov    r11,rdi
	sub    r11,r12
	jb     <coin_change+0x1e0>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r8d
	cmovb  r8d,r11d
	jmp    <coin_change+0x1e0>
	mov    edx,ebx
	and    edx,0x7
	mov    esi,0x1
	cmp    rbx,0x8
	jb     <coin_change+0x261>
	mov    rdi,rbx
	and    rdi,0xfffffffffffffff8
	xor    esi,esi
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+rsi*4+0x4],ecx
	mov    DWORD PTR [rax+rsi*4+0x8],ecx
	mov    DWORD PTR [rax+rsi*4+0xc],ecx
	mov    DWORD PTR [rax+rsi*4+0x10],ecx
	mov    DWORD PTR [rax+rsi*4+0x14],ecx
	mov    DWORD PTR [rax+rsi*4+0x18],ecx
	mov    DWORD PTR [rax+rsi*4+0x1c],ecx
	mov    DWORD PTR [rax+rsi*4+0x20],ecx
	add    rsi,0x8
	cmp    rdi,rsi
	jne    <coin_change+0x230>
	test   rdx,rdx
	je     <coin_change+0x27b>
	inc    rsi
	lea    rsi,[rax+rsi*4]
	xor    edi,edi
	nop    WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rsi+rdi*4],ecx
	inc    rdi
	cmp    rdx,rdi
	jne    <coin_change+0x270>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	call   <free@plt>
	mov    eax,ebx
	pop    rbx
	pop    r12
	pop    r14
	pop    r15
	pop    rbp
	ret
	ud2

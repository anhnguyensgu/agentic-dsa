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
	je     <coin_change+0x22e>
	lea    ecx,[rbx+0x1]
	mov    dl,0x3e
	bzhi   rsi,rbx,rdx
	mov    edi,ebx
	not    edi
	mov    rdx,rax
	test   dil,0x7
	je     <coin_change+0x5b>
	lea    edi,[rbx+0x1]
	and    edi,0x7
	mov    rdx,rax
	mov    DWORD PTR [rdx],ecx
	add    rdx,0x4
	dec    rdi
	jne    <coin_change+0x50>
	cmp    rsi,0x7
	jb     <coin_change+0x90>
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
	jne    <coin_change+0x70>
	mov    DWORD PTR [rax],0x0
	test   r14,r14
	je     <coin_change+0x204>
	lea    rcx,[rbx+0x1]
	xor    esi,esi
	vpcmpeqd ymm0,ymm0,ymm0
	mov    QWORD PTR [rbp-0x30],rbx
	jmp    <coin_change+0xbc>
	nop
	inc    rsi
	cmp    rsi,r14
	je     <coin_change+0x204>
	mov    edi,DWORD PTR [r15+rsi*4]
	cmp    edi,0x8
	setb   r8b
	mov    edi,edi
	lea    r9,[rdi+0x8]
	cmp    r9,rcx
	seta   r9b
	or     r9b,r8b
	mov    r8,rdi
	jne    <coin_change+0x11a>
	xor    r9d,r9d
	mov    r10,rdi
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu ymm1,YMMWORD PTR [rax+r9*1]
	vpsubd ymm1,ymm1,ymm0
	vpminud ymm1,ymm1,YMMWORD PTR [rax+r10*4]
	vmovdqu YMMWORD PTR [rax+r10*4],ymm1
	lea    r8,[r10+0x8]
	add    r9,0x20
	add    r10,0x10
	cmp    r10,rcx
	mov    r10,r8
	jbe    <coin_change+0xf0>
	mov    r9,rbx
	sub    r9,r8
	jb     <coin_change+0xb0>
	mov    r10d,ecx
	sub    r10d,r8d
	and    r10d,0x3
	je     <coin_change+0x17c>
	mov    rbx,r14
	mov    r14,r15
	lea    r11,[rax+r8*4]
	lea    r12,[rdi*4+0x0]
	neg    r12
	neg    r10
	xor    r13d,r13d
	nop    DWORD PTR [rax+0x0]
	mov    edx,DWORD PTR [r11+r12*1]
	inc    edx
	mov    r15d,DWORD PTR [r11]
	cmp    edx,r15d
	cmovae edx,r15d
	mov    DWORD PTR [r11],edx
	dec    r13
	add    r11,0x4
	cmp    r10,r13
	jne    <coin_change+0x150>
	sub    r8,r13
	mov    r15,r14
	mov    r14,rbx
	mov    rbx,QWORD PTR [rbp-0x30]
	cmp    r9,0x3
	jb     <coin_change+0xb0>
	mov    r9,rcx
	sub    r9,r8
	lea    rdx,[rax+0xc]
	lea    r8,[rdx+r8*4]
	shl    rdi,0x2
	neg    rdi
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    edx,DWORD PTR [r8+rdi*1-0xc]
	inc    edx
	mov    r10d,DWORD PTR [r8-0xc]
	mov    r11d,DWORD PTR [r8-0x8]
	cmp    edx,r10d
	cmovae edx,r10d
	mov    DWORD PTR [r8-0xc],edx
	mov    edx,DWORD PTR [r8+rdi*1-0x8]
	inc    edx
	cmp    edx,r11d
	cmovae edx,r11d
	mov    DWORD PTR [r8-0x8],edx
	mov    edx,DWORD PTR [r8+rdi*1-0x4]
	inc    edx
	mov    r10d,DWORD PTR [r8-0x4]
	cmp    edx,r10d
	cmovae edx,r10d
	mov    DWORD PTR [r8-0x4],edx
	mov    edx,DWORD PTR [r8+rdi*1]
	inc    edx
	mov    r10d,DWORD PTR [r8]
	cmp    edx,r10d
	cmovae edx,r10d
	mov    DWORD PTR [r8],edx
	add    r8,0x10
	add    r9,0xfffffffffffffffc
	jne    <coin_change+0x1a0>
	jmp    <coin_change+0xb0>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	vzeroupper
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

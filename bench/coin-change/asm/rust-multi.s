<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x38
	mov    r13,rdx
	mov    r14,rsi
	lea    rbp,[rdx+0x1]
	lea    r12,[rdx*4+0x4]
	mov    rax,rbp
	shr    rax,0x3e
	setne  cl
	movabs rax,0x7ffffffffffffffc
	cmp    r12,rax
	seta   al
	or     al,cl
	mov    ebx,r13d
	inc    ebx
	jne    <coin_change+0x9e>
	test   al,al
	jne    <coin_change+0xa2>
	test   r12,r12
	je     <coin_change+0x16d>
	mov    QWORD PTR [rsp],r13
	mov    r15,rdi
	call   QWORD PTR [rip+0x4092b]
	mov    r13d,0x4
	mov    esi,0x4
	mov    rdi,r12
	call   QWORD PTR [rip+0x40967]
	test   rax,rax
	je     <coin_change+0xa5>
	mov    rsi,rbp
	mov    rdi,r15
	mov    r13,QWORD PTR [rsp]
	test   rbp,rbp
	je     <coin_change+0x619>
	mov    DWORD PTR [rax],0x0
	cmp    rbp,0x2
	jae    <coin_change+0x1b5>
	jmp    <coin_change+0x520>
	test   al,al
	je     <coin_change+0xb1>
	xor    r13d,r13d
	mov    rdi,r13
	mov    rsi,r12
	call   QWORD PTR [rip+0x408bf]
	mov    QWORD PTR [rsp],r13
	test   r12,r12
	je     <coin_change+0x182>
	mov    r15,rdi
	call   QWORD PTR [rip+0x408c1]
	mov    r13d,0x4
	mov    esi,0x4
	mov    rdi,r12
	call   QWORD PTR [rip+0x408b5]
	mov    rdi,r15
	mov    rsi,rbp
	test   rax,rax
	je     <coin_change+0xa5>
	cmp    rbp,0x2
	jb     <coin_change+0x193>
	mov    edx,0x1
	mov    rcx,rax
	mov    r13,QWORD PTR [rsp]
	cmp    r13,0x20
	jb     <coin_change+0x149>
	mov    r9,r13
	and    r9,0xffffffffffffffe0
	lea    rcx,[rax+r9*4]
	lea    rdx,[r9+0x1]
	vpbroadcastd ymm0,ebx
	xor    r8d,r8d
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax+r8*4],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x60],ymm0
	add    r8,0x20
	cmp    r9,r8
	jne    <coin_change+0x120>
	cmp    r13,r9
	je     <coin_change+0x1a3>
	mov    r8,r13
	sub    r8,rdx
	inc    r8
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rcx],ebx
	add    rcx,0x4
	dec    r8
	jne    <coin_change+0x160>
	jmp    <coin_change+0x1a3>
	mov    eax,0x4
	xor    esi,esi
	test   rbp,rbp
	jne    <coin_change+0x89>
	jmp    <coin_change+0x619>
	mov    eax,0x4
	xor    esi,esi
	cmp    rbp,0x2
	jae    <coin_change+0xf0>
	mov    rcx,rax
	test   rbp,rbp
	mov    r13,QWORD PTR [rsp]
	je     <coin_change+0x619>
	mov    DWORD PTR [rcx],ebx
	mov    DWORD PTR [rax],0x0
	cmp    rbp,0x2
	jb     <coin_change+0x520>
	movabs r8,0x1ffffffffffffffc
	and    r8,r14
	lea    rcx,[rdi+r8*4]
	shl    r14,0x2
	mov    r9d,r14d
	and    r9d,0xc
	mov    QWORD PTR [rsp+0x18],rcx
	lea    rdx,[rcx+r9*1]
	test   r8,r8
	je     <coin_change+0x3db>
	mov    QWORD PTR [rsp+0x8],rbp
	mov    QWORD PTR [rsp+0x10],rsi
	mov    QWORD PTR [rsp],r9
	lea    rsi,[r9-0x4]
	mov    ecx,esi
	shr    ecx,0x2
	inc    ecx
	and    ecx,0x3
	mov    QWORD PTR [rsp+0x20],rcx
	mov    QWORD PTR [rsp+0x30],rsi
	and    esi,0xc
	mov    QWORD PTR [rsp+0x28],rsi
	mov    r12d,0x1
	jmp    <coin_change+0x24d>
	nop    DWORD PTR [rax+0x0]
	mov    r11d,r15d
	cmp    r13d,r11d
	cmovb  r11d,r13d
	cmp    r14d,ebp
	cmovb  ebp,r14d
	cmp    ebp,r11d
	cmovae ebp,r11d
	mov    DWORD PTR [rax+r12*4],ebp
	mov    r13,r9
	cmp    r12,r9
	lea    r12,[r12+0x1]
	je     <coin_change+0x50c>
	mov    r9,r13
	xor    ecx,ecx
	mov    r15d,ebx
	mov    r13d,ebx
	mov    ebp,ebx
	mov    r14d,ebx
	jmp    <coin_change+0x270>
	nop
	mov    r14d,r11d
	add    rcx,0x4
	cmp    r8,rcx
	je     <coin_change+0x2f0>
	mov    r11d,r14d
	mov    r14d,ebp
	mov    ebp,r13d
	mov    r10d,r15d
	mov    esi,DWORD PTR [rdi+rcx*4]
	mov    r15,r12
	sub    r15,rsi
	jb     <coin_change+0x293>
	mov    r15d,DWORD PTR [rax+r15*4]
	inc    r15d
	cmp    r15d,r10d
	jb     <coin_change+0x296>
	mov    r15d,r10d
	mov    esi,DWORD PTR [rdi+rcx*4+0x4]
	mov    r10,r12
	sub    r10,rsi
	jb     <coin_change+0x2ae>
	mov    r13d,DWORD PTR [rax+r10*4]
	inc    r13d
	cmp    r13d,ebp
	jb     <coin_change+0x2b1>
	mov    r13d,ebp
	mov    esi,DWORD PTR [rdi+rcx*4+0x8]
	mov    r10,r12
	sub    r10,rsi
	jb     <coin_change+0x2c8>
	mov    ebp,DWORD PTR [rax+r10*4]
	inc    ebp
	cmp    ebp,r14d
	jb     <coin_change+0x2cb>
	mov    ebp,r14d
	mov    esi,DWORD PTR [rdi+rcx*4+0xc]
	mov    r10,r12
	sub    r10,rsi
	jb     <coin_change+0x260>
	mov    r14d,DWORD PTR [rax+r10*4]
	inc    r14d
	cmp    r14d,r11d
	jae    <coin_change+0x260>
	jmp    <coin_change+0x263>
	nop    DWORD PTR [rax+0x0]
	cmp    QWORD PTR [rsp],0x0
	je     <coin_change+0x220>
	cmp    DWORD PTR [rsp+0x28],0xc
	jne    <coin_change+0x3a0>
	mov    r11d,r15d
	lea    rcx,[rdi+r8*4]
	cmp    DWORD PTR [rsp+0x30],0xc
	jae    <coin_change+0x330>
	jmp    <coin_change+0x223>
	nop    DWORD PTR [rax+0x0]
	mov    r11d,r10d
	add    rcx,0x10
	cmp    rcx,rdx
	je     <coin_change+0x223>
	mov    esi,DWORD PTR [rcx]
	mov    r10,r12
	sub    r10,rsi
	jb     <coin_change+0x346>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r11d
	jb     <coin_change+0x349>
	mov    r10d,r11d
	mov    esi,DWORD PTR [rcx+0x4]
	mov    r11,r12
	sub    r11,rsi
	jb     <coin_change+0x360>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r10d
	jb     <coin_change+0x363>
	mov    r11d,r10d
	mov    esi,DWORD PTR [rcx+0x8]
	mov    r10,r12
	sub    r10,rsi
	jb     <coin_change+0x37a>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r11d
	jb     <coin_change+0x37d>
	mov    r10d,r11d
	mov    esi,DWORD PTR [rcx+0xc]
	mov    r11,r12
	sub    r11,rsi
	jb     <coin_change+0x320>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r10d
	jae    <coin_change+0x320>
	jmp    <coin_change+0x323>
	cs nop WORD PTR [rax+rax*1+0x0]
	mov    r10,QWORD PTR [rsp+0x20]
	lea    rcx,[rdi+r8*4]
	jmp    <coin_change+0x3c3>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    r11d,r15d
	add    rcx,0x4
	mov    r15d,r11d
	dec    r10
	je     <coin_change+0x30d>
	mov    esi,DWORD PTR [rcx]
	mov    r11,r12
	sub    r11,rsi
	jb     <coin_change+0x3b0>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r15d
	jae    <coin_change+0x3b0>
	jmp    <coin_change+0x3b3>
	test   r9,r9
	je     <coin_change+0x55b>
	mov    QWORD PTR [rsp+0x8],rbp
	mov    QWORD PTR [rsp+0x10],rsi
	add    r14,0xfffffffffffffffc
	mov    ecx,r14d
	shr    ecx,0x2
	inc    ecx
	and    ecx,0x3
	mov    edi,r14d
	and    edi,0xc
	neg    rcx
	mov    r8d,0x1
	jmp    <coin_change+0x428>
	xchg   ax,ax
	cmp    ebx,r10d
	cmovb  r10d,ebx
	mov    DWORD PTR [rax+r8*4],r10d
	cmp    r8,r13
	lea    r8,[r8+0x1]
	je     <coin_change+0x50c>
	mov    r10d,ebx
	mov    r9,QWORD PTR [rsp+0x18]
	cmp    edi,0xc
	jne    <coin_change+0x4d0>
	cmp    r14,0xc
	jae    <coin_change+0x45c>
	jmp    <coin_change+0x410>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    r10d,r11d
	add    r9,0x10
	cmp    r9,rdx
	je     <coin_change+0x410>
	mov    r15d,DWORD PTR [r9]
	mov    r11,r8
	sub    r11,r15
	jb     <coin_change+0x473>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r10d
	jb     <coin_change+0x476>
	mov    r11d,r10d
	mov    r15d,DWORD PTR [r9+0x4]
	mov    r10,r8
	sub    r10,r15
	jb     <coin_change+0x48e>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r11d
	jb     <coin_change+0x491>
	mov    r10d,r11d
	mov    r15d,DWORD PTR [r9+0x8]
	mov    r11,r8
	sub    r11,r15
	jb     <coin_change+0x4a9>
	mov    r11d,DWORD PTR [rax+r11*4]
	inc    r11d
	cmp    r11d,r10d
	jb     <coin_change+0x4ac>
	mov    r11d,r10d
	mov    r15d,DWORD PTR [r9+0xc]
	mov    r10,r8
	sub    r10,r15
	jb     <coin_change+0x450>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,r11d
	jae    <coin_change+0x450>
	jmp    <coin_change+0x453>
	cs nop WORD PTR [rax+rax*1+0x0]
	mov    r11,rcx
	mov    ebp,ebx
	mov    r9,QWORD PTR [rsp+0x18]
	jmp    <coin_change+0x4f3>
	nop    DWORD PTR [rax+0x0]
	mov    r10d,ebp
	add    r9,0x4
	mov    ebp,r10d
	inc    r11
	je     <coin_change+0x439>
	mov    r15d,DWORD PTR [r9]
	mov    r10,r8
	sub    r10,r15
	jb     <coin_change+0x4e0>
	mov    r10d,DWORD PTR [rax+r10*4]
	inc    r10d
	cmp    r10d,ebp
	jae    <coin_change+0x4e0>
	jmp    <coin_change+0x4e3>
	cmp    r13,0xffffffffffffffff
	mov    rsi,QWORD PTR [rsp+0x10]
	mov    rcx,QWORD PTR [rsp+0x8]
	je     <coin_change+0x62a>
	mov    ebx,DWORD PTR [rax+r13*4]
	test   rsi,rsi
	je     <coin_change+0x53e>
	shl    rsi,0x2
	mov    edx,0x4
	mov    rdi,rax
	vzeroupper
	call   QWORD PTR [rip+0x4045a]
	cmp    r13,rbx
	mov    eax,0xffffffff
	cmovae eax,ebx
	add    rsp,0x38
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	vzeroupper
	ret
	mov    edx,0x1
	cmp    r13,0x4
	jb     <coin_change+0x5f8>
	cmp    r13,0x20
	jae    <coin_change+0x574>
	xor    ecx,ecx
	jmp    <coin_change+0x5c0>
	mov    rcx,r13
	and    rcx,0xffffffffffffffe0
	vpbroadcastd ymm0,ebx
	xor    edx,edx
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax+rdx*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x64],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0x590>
	cmp    r13,rcx
	je     <coin_change+0x520>
	test   r13b,0x1c
	je     <coin_change+0x610>
	mov    rdi,r13
	and    rdi,0xfffffffffffffffc
	lea    rdx,[rdi+0x1]
	vpbroadcastd xmm0,ebx
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu XMMWORD PTR [rax+rcx*4+0x4],xmm0
	add    rcx,0x4
	cmp    rdi,rcx
	jne    <coin_change+0x5e0>
	cmp    r13,rdi
	je     <coin_change+0x520>
	lea    rcx,[r13+0x1]
	nop    DWORD PTR [rax+0x0]
	mov    DWORD PTR [rax+rdx*4],ebx
	inc    rdx
	cmp    rcx,rdx
	jne    <coin_change+0x600>
	jmp    <coin_change+0x520>
	or     rcx,0x1
	mov    rdx,rcx
	jmp    <coin_change+0x5f8>
	lea    rdx,[rip+0x3e540]
	xor    edi,edi
	xor    esi,esi
	call   QWORD PTR [rip+0x403b6]
	lea    rdx,[rip+0x3e547]
	mov    rdi,0xffffffffffffffff
	mov    rsi,rcx
	vzeroupper
	call   QWORD PTR [rip+0x4039c]

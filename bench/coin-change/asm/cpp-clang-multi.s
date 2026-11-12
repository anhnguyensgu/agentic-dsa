<coin_change>:
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x18
	lea    r15,[rdx+0x1]
	mov    rax,r15
	shr    rax,0x3e
	jne    <coin_change+0x2bb>
	mov    rbx,rdx
	mov    r14,rsi
	mov    r12,rdi
	lea    r13d,[rdx+0x1]
	lea    rdi,[r15*4+0x0]
	mov    QWORD PTR [rbp-0x38],rdi
	call   <_Znwm>
	mov    r11d,r13d
	mov    cl,0x3e
	bzhi   rsi,rbx,rcx
	mov    rdi,rax
	cmp    rsi,0x3
	jb     <coin_change+0xd3>
	lea    rcx,[rsi+0x1]
	movabs rdx,0x7fffffffffffffe0
	cmp    rsi,0x1f
	jae    <coin_change+0x6f>
	xor    esi,esi
	jmp    <coin_change+0xae>
	mov    rsi,rcx
	and    rsi,rdx
	vpbroadcastd ymm0,r11d
	xor    edi,edi
	nop    DWORD PTR [rax]
	vmovdqu YMMWORD PTR [rax+rdi*4],ymm0
	vmovdqu YMMWORD PTR [rax+rdi*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rax+rdi*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rax+rdi*4+0x60],ymm0
	add    rdi,0x20
	cmp    rsi,rdi
	jne    <coin_change+0x80>
	cmp    rcx,rsi
	je     <coin_change+0xec>
	test   cl,0x1c
	je     <coin_change+0x2b2>
	add    rdx,0x1c
	and    rdx,rcx
	lea    rdi,[rax+rdx*4]
	vpbroadcastd xmm0,r11d
	nop
	vmovdqu XMMWORD PTR [rax+rsi*4],xmm0
	add    rsi,0x4
	cmp    rdx,rsi
	jne    <coin_change+0xc0>
	cmp    rcx,rdx
	je     <coin_change+0xec>
	lea    rcx,[rax+r15*4]
	nop    WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi],r11d
	add    rdi,0x4
	cmp    rdi,rcx
	jne    <coin_change+0xe0>
	mov    DWORD PTR [rax],0x0
	cmp    r15,0x2
	jb     <coin_change+0x284>
	mov    ecx,0x1
	mov    QWORD PTR [rbp-0x40],rbx
	mov    DWORD PTR [rbp-0x2c],r11d
	jmp    <coin_change+0x12f>
	nop    DWORD PTR [rax+rax*1+0x0]
	cmp    esi,r13d
	cmovb  r13d,esi
	cmp    edi,r13d
	cmovb  r13d,edi
	mov    DWORD PTR [rax+rcx*4],r13d
	cmp    rcx,rbx
	lea    rcx,[rcx+0x1]
	je     <coin_change+0x284>
	cmp    r14,0x4
	jae    <coin_change+0x150>
	mov    esi,r11d
	mov    r13d,r11d
	mov    edi,r11d
	xor    r8d,r8d
	cmp    r8,r14
	jae    <coin_change+0x110>
	jmp    <coin_change+0x208>
	nop    DWORD PTR [rax+rax*1+0x0]
	xor    r9d,r9d
	mov    ebx,r11d
	mov    edx,r11d
	mov    r15d,r11d
	jmp    <coin_change+0x17f>
	xchg   ax,ax
	mov    r10d,ebx
	lea    r8,[r9+0x4]
	add    r9,0x8
	mov    ebx,r10d
	mov    edx,r13d
	mov    r15d,esi
	mov    r11d,edi
	cmp    r9,r14
	mov    r9,r8
	ja     <coin_change+0x1f0>
	mov    edi,DWORD PTR [r12+r9*4]
	mov    rsi,rcx
	sub    rsi,rdi
	jb     <coin_change+0x197>
	mov    r13d,DWORD PTR [rax+rsi*4]
	inc    r13d
	cmp    r13d,edx
	jb     <coin_change+0x19a>
	mov    r13d,edx
	mov    esi,DWORD PTR [r12+r9*4+0x4]
	mov    rdx,rcx
	sub    rdx,rsi
	jb     <coin_change+0x1b1>
	mov    esi,DWORD PTR [rax+rdx*4]
	inc    esi
	cmp    esi,r15d
	jb     <coin_change+0x1b4>
	mov    esi,r15d
	mov    edi,DWORD PTR [r12+r9*4+0x8]
	mov    rdx,rcx
	sub    rdx,rdi
	jb     <coin_change+0x1cb>
	mov    edi,DWORD PTR [rax+rdx*4]
	inc    edi
	cmp    edi,r11d
	jb     <coin_change+0x1ce>
	mov    edi,r11d
	mov    r8d,DWORD PTR [r12+r9*4+0xc]
	mov    rdx,rcx
	sub    rdx,r8
	jb     <coin_change+0x160>
	mov    r10d,DWORD PTR [rax+rdx*4]
	inc    r10d
	cmp    r10d,ebx
	jae    <coin_change+0x160>
	jmp    <coin_change+0x163>
	cmp    r10d,edi
	cmovb  edi,r10d
	mov    rbx,QWORD PTR [rbp-0x40]
	mov    r11d,DWORD PTR [rbp-0x2c]
	cmp    r8,r14
	jae    <coin_change+0x110>
	mov    r9,r8
	or     r9,0x1
	test   r14b,0x1
	je     <coin_change+0x234>
	mov    r8d,DWORD PTR [r12+r8*4]
	mov    rdx,rcx
	sub    rdx,r8
	jb     <coin_change+0x22b>
	mov    edx,DWORD PTR [rax+rdx*4]
	inc    edx
	cmp    edx,r13d
	jb     <coin_change+0x22e>
	mov    edx,r13d
	mov    r13d,edx
	mov    r8,r9
	cmp    r14,r9
	jne    <coin_change+0x250>
	jmp    <coin_change+0x110>
	xchg   ax,ax
	mov    r13d,edx
	add    r8,0x2
	cmp    r14,r8
	je     <coin_change+0x110>
	mov    r9d,DWORD PTR [r12+r8*4]
	mov    rdx,rcx
	sub    rdx,r9
	jb     <coin_change+0x266>
	mov    edx,DWORD PTR [rax+rdx*4]
	inc    edx
	cmp    edx,r13d
	jb     <coin_change+0x269>
	mov    edx,r13d
	mov    r10d,DWORD PTR [r12+r8*4+0x4]
	mov    r9,rcx
	sub    r9,r10
	jb     <coin_change+0x240>
	mov    r13d,DWORD PTR [rax+r9*4]
	inc    r13d
	cmp    r13d,edx
	jae    <coin_change+0x240>
	jmp    <coin_change+0x243>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	mov    rsi,QWORD PTR [rbp-0x38]
	vzeroupper
	call   <_ZdlPvm>
	mov    eax,ebx
	add    rsp,0x18
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	lea    rdi,[rax+rsi*4]
	jmp    <coin_change+0xd3>
	call   <_ZNSt3__16vectorIjNS_9allocatorIjEEE20__throw_length_errorB9nin220108Ev>

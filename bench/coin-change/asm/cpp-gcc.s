<coin_change>:
	endbr64
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	lea    rbx,[rdx+0x1]
	mov    rax,rbx
	and    rsp,0xffffffffffffffe0
	sub    rsp,0x20
	shr    rax,0x3d
	jne    <coin_change+0x303>
	mov    r14,rdx
	test   rbx,rbx
	je     <coin_change+0x2f0>
	lea    r15,[rbx*4+0x0]
	lea    ecx,[rdx+0x1]
	mov    r12,rdi
	mov    r13,rsi
	mov    rdi,r15
	mov    DWORD PTR [rsp+0x18],ecx
	call   <_Znwm@plt>
	mov    ecx,DWORD PTR [rsp+0x18]
	mov    rdi,rax
	lea    rax,[r15-0x4]
	mov    rdx,rax
	shr    rdx,0x2
	cmp    rax,0x18
	lea    r8,[rdx+0x1]
	jbe    <coin_change+0x2f9>
	mov    rsi,r8
	vpbroadcastd ymm0,ecx
	mov    rax,rdi
	shr    rsi,0x3
	shl    rsi,0x5
	lea    r9,[rsi+rdi*1]
	and    esi,0x20
	je     <coin_change+0xa0>
	lea    rax,[rdi+0x20]
	vmovdqu YMMWORD PTR [rdi],ymm0
	cmp    rax,r9
	je     <coin_change+0xb2>
	nop    DWORD PTR [rax]
	vmovdqu YMMWORD PTR [rax],ymm0
	add    rax,0x40
	vmovdqu YMMWORD PTR [rax-0x20],ymm0
	cmp    rax,r9
	jne    <coin_change+0xa0>
	mov    rsi,r8
	and    rsi,0xfffffffffffffff8
	and    r8d,0x7
	lea    rax,[rdi+rsi*4]
	je     <coin_change+0x10a>
	sub    rdx,rsi
	lea    r8,[rdx+0x1]
	cmp    rdx,0x2
	jbe    <coin_change+0xec>
	mov    rdx,r8
	vpbroadcastd xmm0,ecx
	and    rdx,0xfffffffffffffffc
	and    r8d,0x3
	vmovdqu XMMWORD PTR [rdi+rsi*4],xmm0
	lea    rax,[rax+rdx*4]
	je     <coin_change+0x10a>
	lea    rdx,[rdi+r15*1]
	lea    rsi,[rax+0x4]
	mov    DWORD PTR [rax],ecx
	cmp    rdx,rsi
	je     <coin_change+0x10a>
	lea    rsi,[rax+0x8]
	mov    DWORD PTR [rax+0x4],ecx
	cmp    rdx,rsi
	je     <coin_change+0x10a>
	mov    DWORD PTR [rax+0x8],ecx
	mov    DWORD PTR [rdi],0x0
	test   r13,r13
	je     <coin_change+0x192>
	mov    QWORD PTR [rsp+0x18],r15
	mov    eax,0x1
	lea    r10,[rdi+r15*1]
	xor    r11d,r11d
	vpbroadcastd xmm2,eax
	vpbroadcastd ymm1,eax
	nop    WORD PTR [rax+rax*1+0x0]
	mov    r8d,DWORD PTR [r12+r11*4]
	cmp    r8,rbx
	jae    <coin_change+0x185>
	mov    r9,r14
	lea    rax,[r8*4+0x0]
	sub    r9,r8
	cmp    r9,0x2
	jbe    <coin_change+0x167>
	lea    rax,[r8*4+0x0]
	lea    rdx,[rax-0x4]
	cmp    rdx,0x18
	ja     <coin_change+0x1c0>
	lea    rdx,[rdi+rax*1]
	neg    rax
	xchg   ax,ax
	mov    esi,DWORD PTR [rdx+rax*1]
	lea    ecx,[rsi+0x1]
	cmp    ecx,DWORD PTR [rdx]
	jae    <coin_change+0x17c>
	mov    DWORD PTR [rdx],ecx
	add    rdx,0x4
	cmp    rdx,r10
	jne    <coin_change+0x170>
	inc    r11
	cmp    r13,r11
	jne    <coin_change+0x138>
	mov    r15,QWORD PTR [rsp+0x18]
	mov    edx,DWORD PTR [rdi+r14*4]
	mov    ebx,0xffffffff
	mov    rsi,r15
	cmp    r14,rdx
	cmovae ebx,edx
	vzeroupper
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
	nop    DWORD PTR [rax]
	lea    rsi,[r9+0x1]
	cmp    r9,0x6
	jbe    <coin_change+0x2e3>
	mov    r15,rsi
	add    rax,rdi
	xor    edx,edx
	xor    ecx,ecx
	shr    r15,0x3
	vpaddd ymm0,ymm1,YMMWORD PTR [rdi+rdx*1]
	vpcmpltud k1,ymm0,YMMWORD PTR [rax+rdx*1]
	kortestb k1,k1
	jne    <coin_change+0x2c8>
	inc    rcx
	add    rdx,0x20
	cmp    r15,rcx
	jne    <coin_change+0x1dc>
	mov    rdx,rsi
	and    rdx,0xfffffffffffffff8
	and    esi,0x7
	lea    rcx,[r8+rdx*1]
	mov    rax,rcx
	je     <coin_change+0x185>
	sub    r9,rdx
	lea    rsi,[r9+0x1]
	cmp    r9,0x2
	jbe    <coin_change+0x250>
	vpaddd xmm0,xmm2,XMMWORD PTR [rdi+rdx*4]
	lea    rcx,[rdi+rcx*4]
	vpcmpltud k1,xmm0,XMMWORD PTR [rcx]
	kortestb k1,k1
	jne    <coin_change+0x2d8>
	mov    rdx,rsi
	and    rdx,0xfffffffffffffffc
	add    rax,rdx
	and    esi,0x3
	je     <coin_change+0x185>
	mov    rdx,rax
	lea    rcx,[rax*4+0x0]
	sub    rdx,r8
	lea    rsi,[rdi+rcx*1]
	mov    edx,DWORD PTR [rdi+rdx*4]
	inc    edx
	cmp    edx,DWORD PTR [rsi]
	jae    <coin_change+0x26d>
	mov    DWORD PTR [rsi],edx
	lea    rdx,[rax+0x1]
	cmp    rdx,rbx
	jae    <coin_change+0x185>
	sub    rdx,r8
	lea    rsi,[rdi+rcx*1+0x4]
	mov    edx,DWORD PTR [rdi+rdx*4]
	inc    edx
	cmp    edx,DWORD PTR [rsi]
	jae    <coin_change+0x28d>
	mov    DWORD PTR [rsi],edx
	add    rax,0x2
	cmp    rax,rbx
	jae    <coin_change+0x185>
	sub    rax,r8
	lea    rdx,[rdi+rcx*1+0x8]
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,DWORD PTR [rdx]
	jae    <coin_change+0x185>
	inc    r11
	mov    DWORD PTR [rdx],eax
	cmp    r13,r11
	jne    <coin_change+0x138>
	jmp    <coin_change+0x18d>
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu32 YMMWORD PTR [rax+rdx*1]{k1},ymm0
	jmp    <coin_change+0x1f3>
	nop    DWORD PTR [rax+0x0]
	vmovdqu32 XMMWORD PTR [rcx]{k1},xmm0
	jmp    <coin_change+0x23d>
	mov    rax,r8
	xor    edx,edx
	mov    rcx,r8
	jmp    <coin_change+0x223>
	mov    DWORD PTR [rdx+0x1],0x0
	ud2
	mov    rax,rdi
	xor    esi,esi
	jmp    <coin_change+0xc3>
	lea    rdi,[rip+0x8be]
	call   <_ZSt20__throw_length_errorPKc@plt>

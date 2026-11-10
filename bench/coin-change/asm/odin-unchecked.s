<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x38
	mov    rax,rcx
	mov    r14,rdx
	mov    r12,rsi
	mov    r13,rdi
	lea    rdi,[rdx+0x1]
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	shl    rdi,0x2
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x20],xmm0
	mov    QWORD PTR [rsp+0x18],rax
	mov    QWORD PTR [rsp],rax
	lea    r8,[rip+0x2c36d]
	lea    r9,[rsp+0x20]
	mov    esi,0x4
	mov    QWORD PTR [rsp+0x10],rdi
	call   <runtime::mem_alloc_bytes>
	mov    r15,r14
	mov    rdi,QWORD PTR [rsp+0x20]
	inc    r15
	je     <coin_change+0xeb>
	lea    ecx,[r14+0x1]
	cmp    r15,0x4
	jae    <coin_change+0x76>
	xor    edx,edx
	jmp    <coin_change+0xe0>
	cmp    r15,0x20
	jae    <coin_change+0x80>
	xor    edx,edx
	jmp    <coin_change+0xbb>
	mov    rdx,r15
	and    rdx,0xffffffffffffffe0
	vpbroadcastd ymm0,ecx
	xor    eax,eax
	nop
	vmovdqu YMMWORD PTR [rdi+rax*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rax*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rax*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rax*4+0x60],ymm0
	add    rax,0x20
	cmp    rdx,rax
	jne    <coin_change+0x90>
	cmp    r15,rdx
	je     <coin_change+0xeb>
	test   r15b,0x1c
	je     <coin_change+0xe0>
	mov    rax,rdx
	mov    rdx,r15
	and    rdx,0xfffffffffffffffc
	vpbroadcastd xmm0,ecx
	nop    DWORD PTR [rax+rax*1+0x0]
	vmovdqu XMMWORD PTR [rdi+rax*4],xmm0
	add    rax,0x4
	cmp    rdx,rax
	jne    <coin_change+0xd0>
	jmp    <coin_change+0xe6>
	mov    DWORD PTR [rdi+rdx*4],ecx
	inc    rdx
	cmp    r15,rdx
	jne    <coin_change+0xe0>
	mov    DWORD PTR [rdi],0x0
	test   r12,r12
	jle    <coin_change+0x368>
	lea    rcx,[rdi+r14*4+0x4]
	lea    rdx,[rdi+0x60]
	xor    r8d,r8d
	vpcmpeqd ymm0,ymm0,ymm0
	vpbroadcastd ymm1,DWORD PTR [rip+0x1fcf1]
	jmp    <coin_change+0x12c>
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	inc    r8
	cmp    r8,r12
	je     <coin_change+0x368>
	mov    r9d,DWORD PTR [r13+r8*4+0x0]
	mov    rax,r15
	sub    rax,r9
	jbe    <coin_change+0x120>
	mov    r11,r9
	cmp    rax,0x8
	jb     <coin_change+0x250>
	cmp    rdi,rcx
	setb   sil
	lea    r10,[r9*4+0x0]
	lea    rbp,[rdi+r9*4]
	mov    r11,rcx
	sub    r11,r10
	cmp    rbp,r11
	setb   r10b
	mov    r11,r9
	test   r10b,sil
	jne    <coin_change+0x250>
	cmp    rax,0x20
	jae    <coin_change+0x180>
	xor    r10d,r10d
	jmp    <coin_change+0x207>
	mov    r10,rax
	and    r10,0xffffffffffffffe0
	lea    rsi,[rdx+r9*4]
	xor    r11d,r11d
	xchg   ax,ax
	vpaddd ymm2,ymm1,YMMWORD PTR [rdx+r11*4-0x60]
	vpaddd ymm3,ymm1,YMMWORD PTR [rdx+r11*4-0x40]
	vpaddd ymm4,ymm1,YMMWORD PTR [rdx+r11*4-0x20]
	vpaddd ymm5,ymm1,YMMWORD PTR [rdx+r11*4]
	vpcmpltud k1,ymm2,YMMWORD PTR [rsi+r11*4-0x60]
	vpcmpltud k2,ymm3,YMMWORD PTR [rsi+r11*4-0x40]
	vpcmpltud k3,ymm4,YMMWORD PTR [rsi+r11*4-0x20]
	vpcmpltud k4,ymm5,YMMWORD PTR [rsi+r11*4]
	vmovdqu32 YMMWORD PTR [rsi+r11*4-0x60]{k1},ymm2
	vmovdqu32 YMMWORD PTR [rsi+r11*4-0x40]{k2},ymm3
	vmovdqu32 YMMWORD PTR [rsi+r11*4-0x20]{k3},ymm4
	vmovdqu32 YMMWORD PTR [rsi+r11*4]{k4},ymm5
	add    r11,0x20
	cmp    r10,r11
	jne    <coin_change+0x190>
	cmp    rax,r10
	je     <coin_change+0x120>
	test   al,0x18
	je     <coin_change+0x35d>
	mov    rsi,rax
	and    rsi,0xfffffffffffffff8
	lea    r11,[rsi+r9*1]
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu ymm2,YMMWORD PTR [rdi+r10*4]
	vpsubd ymm2,ymm2,ymm0
	vpcmpltud k1,ymm2,YMMWORD PTR [rbp+r10*4+0x0]
	vmovdqu32 YMMWORD PTR [rbp+r10*4+0x0]{k1},ymm2
	add    r10,0x8
	cmp    rsi,r10
	jne    <coin_change+0x220>
	cmp    rax,rsi
	je     <coin_change+0x120>
	nop    DWORD PTR [rax]
	mov    eax,r15d
	sub    eax,r11d
	mov    r10,r11
	and    eax,0x3
	je     <coin_change+0x2a6>
	lea    r10,[rdi+r11*4]
	lea    rbp,[r9*4+0x0]
	neg    rbp
	neg    rax
	xor    esi,esi
	jmp    <coin_change+0x28c>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	dec    rsi
	add    r10,0x4
	cmp    rax,rsi
	je     <coin_change+0x2a0>
	mov    ebx,DWORD PTR [r10+rbp*1]
	inc    ebx
	cmp    ebx,DWORD PTR [r10]
	jae    <coin_change+0x280>
	mov    DWORD PTR [r10],ebx
	jmp    <coin_change+0x280>
	nop    DWORD PTR [rax+0x0]
	mov    r10,r11
	sub    r10,rsi
	mov    rax,r14
	sub    rax,r11
	cmp    rax,0x3
	jb     <coin_change+0x120>
	mov    rax,r15
	sub    rax,r10
	lea    rsi,[rdi+0xc]
	lea    r10,[rsi+r10*4]
	shl    r9,0x2
	neg    r9
	jmp    <coin_change+0x2de>
	nop    DWORD PTR [rax]
	add    r10,0x10
	add    rax,0xfffffffffffffffc
	je     <coin_change+0x120>
	mov    esi,DWORD PTR [r10+r9*1-0xc]
	inc    esi
	cmp    esi,DWORD PTR [r10-0xc]
	jb     <coin_change+0x320>
	mov    esi,DWORD PTR [r10+r9*1-0x8]
	inc    esi
	cmp    esi,DWORD PTR [r10-0x8]
	jb     <coin_change+0x331>
	mov    esi,DWORD PTR [r10+r9*1-0x4]
	inc    esi
	cmp    esi,DWORD PTR [r10-0x4]
	jb     <coin_change+0x342>
	mov    esi,DWORD PTR [r10+r9*1]
	inc    esi
	cmp    esi,DWORD PTR [r10]
	jae    <coin_change+0x2d0>
	jmp    <coin_change+0x355>
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [r10-0xc],esi
	mov    esi,DWORD PTR [r10+r9*1-0x8]
	inc    esi
	cmp    esi,DWORD PTR [r10-0x8]
	jae    <coin_change+0x2f8>
	mov    DWORD PTR [r10-0x8],esi
	mov    esi,DWORD PTR [r10+r9*1-0x4]
	inc    esi
	cmp    esi,DWORD PTR [r10-0x4]
	jae    <coin_change+0x305>
	mov    DWORD PTR [r10-0x4],esi
	mov    esi,DWORD PTR [r10+r9*1]
	inc    esi
	cmp    esi,DWORD PTR [r10]
	jae    <coin_change+0x2d0>
	mov    DWORD PTR [r10],esi
	jmp    <coin_change+0x2d0>
	add    r10,r9
	mov    r11,r10
	jmp    <coin_change+0x250>
	mov    eax,DWORD PTR [rdi+r14*4]
	cmp    r14,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    r9,QWORD PTR [rsp+0x18]
	mov    rdx,QWORD PTR [r9]
	mov    rcx,QWORD PTR [r9+0x8]
	lea    r8,[rip+0x2c056]
	mov    rsi,QWORD PTR [rsp+0x10]
	vzeroupper
	call   <runtime::mem_free_with_size>
	mov    eax,ebp
	add    rsp,0x38
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret

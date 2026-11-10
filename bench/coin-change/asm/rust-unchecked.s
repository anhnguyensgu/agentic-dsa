<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x18
	mov    r14,rdx
	mov    r12,rsi
	lea    r15,[rdx+0x1]
	lea    r10,[rdx*4+0x4]
	mov    rax,r15
	shr    rax,0x3e
	setne  cl
	movabs rax,0x7ffffffffffffffc
	cmp    r10,rax
	seta   al
	or     al,cl
	mov    ebp,r14d
	inc    ebp
	mov    QWORD PTR [rsp+0x8],rdx
	jne    <coin_change+0xa5>
	test   al,al
	jne    <coin_change+0xa9>
	test   r10,r10
	je     <coin_change+0x17d>
	mov    r14,rdi
	mov    rbx,r10
	call   QWORD PTR [rip+0x407d7]
	mov    r13d,0x4
	mov    esi,0x4
	mov    rdi,rbx
	call   QWORD PTR [rip+0x40813]
	mov    r10,rbx
	test   rax,rax
	je     <coin_change+0xac>
	mov    rsi,r15
	mov    rdi,r14
	mov    r14,QWORD PTR [rsp+0x8]
	test   r15,r15
	je     <coin_change+0x4cd>
	mov    DWORD PTR [rax],0x0
	test   r12,r12
	jne    <coin_change+0x1c0>
	jmp    <coin_change+0x48f>
	test   al,al
	je     <coin_change+0xb8>
	xor    r13d,r13d
	mov    rdi,r13
	mov    rsi,r10
	call   QWORD PTR [rip+0x40768]
	test   r10,r10
	je     <coin_change+0x192>
	mov    rbx,rdi
	call   QWORD PTR [rip+0x4076e]
	mov    r13d,0x4
	mov    esi,0x4
	lea    rdi,[r14*4+0x4]
	call   QWORD PTR [rip+0x4075d]
	lea    r10,[r14*4+0x4]
	mov    rdi,rbx
	mov    rsi,r15
	test   rax,rax
	je     <coin_change+0xac>
	cmp    r15,0x2
	jb     <coin_change+0x1a3>
	mov    edx,0x1
	mov    rcx,rax
	cmp    r14,0x20
	jb     <coin_change+0x159>
	mov    r8,r14
	and    r8,0xffffffffffffffe0
	lea    rcx,[rax+r8*4]
	lea    rdx,[r8+0x1]
	vpbroadcastd ymm0,ebp
	xor    r9d,r9d
	cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax+r9*4],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x60],ymm0
	add    r9,0x20
	cmp    r8,r9
	jne    <coin_change+0x130>
	cmp    r14,r8
	je     <coin_change+0x1af>
	mov    r8,r14
	sub    r8,rdx
	inc    r8
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rcx],ebp
	add    rcx,0x4
	dec    r8
	jne    <coin_change+0x170>
	jmp    <coin_change+0x1af>
	mov    eax,0x4
	xor    esi,esi
	test   r15,r15
	jne    <coin_change+0x91>
	jmp    <coin_change+0x4cd>
	mov    eax,0x4
	xor    esi,esi
	cmp    r15,0x2
	jae    <coin_change+0x100>
	mov    rcx,rax
	test   r15,r15
	je     <coin_change+0x4cd>
	mov    DWORD PTR [rcx],ebp
	mov    DWORD PTR [rax],0x0
	test   r12,r12
	je     <coin_change+0x48f>
	mov    QWORD PTR [rsp+0x10],rsi
	lea    rcx,[rdi+r12*4]
	add    r10,rax
	mov    rsi,r10
	lea    rdx,[r14+0x1]
	vpcmpeqd ymm0,ymm0,ymm0
	vmovdqa64 zmm1,ZMMWORD PTR [rip+0xfffffffffffeff0f]
	vpbroadcastd ymm2,DWORD PTR [rip+0xfffffffffffeff72]
	vpbroadcastq zmm3,QWORD PTR [rip+0xfffffffffffeff94]
	jmp    <coin_change+0x20d>
	cs nop WORD PTR [rax+rax*1+0x0]
	add    rdi,0x4
	cmp    rdi,rcx
	je     <coin_change+0x484>
	mov    r10d,DWORD PTR [rdi]
	cmp    r15,r10
	jbe    <coin_change+0x200>
	mov    r11,rdx
	sub    r11,r10
	mov    r12,r10
	cmp    r11,0x8
	jb     <coin_change+0x370>
	mov    rbx,rsi
	cmp    rax,rsi
	setb   r8b
	lea    r13,[r10*4+0x0]
	lea    r9,[rax+r10*4]
	sub    rbx,r13
	cmp    r9,rbx
	setb   r9b
	mov    r12,r10
	test   r9b,r8b
	jne    <coin_change+0x370>
	cmp    r11,0x20
	jae    <coin_change+0x264>
	xor    ebp,ebp
	mov    r8,r10
	jmp    <coin_change+0x314>
	mov    rbp,r11
	and    rbp,0xffffffffffffffe0
	lea    r8,[rbp+r10*1+0x0]
	vpbroadcastq zmm4,r10
	vpaddq zmm5,zmm4,zmm1
	lea    r9,[rax+0x60]
	lea    r12,[r9+r10*4]
	xor    r9d,r9d
	nop    WORD PTR [rax+rax*1+0x0]
	vpsubq xmm6,xmm5,xmm4
	vmovq  rbx,xmm6
	vpaddd ymm6,ymm2,YMMWORD PTR [rax+rbx*4]
	vpaddd ymm7,ymm2,YMMWORD PTR [rax+rbx*4+0x20]
	vpaddd ymm8,ymm2,YMMWORD PTR [rax+rbx*4+0x40]
	vpaddd ymm9,ymm2,YMMWORD PTR [rax+rbx*4+0x60]
	vpcmpltud k1,ymm6,YMMWORD PTR [r12+r9*4-0x60]
	vpcmpltud k2,ymm7,YMMWORD PTR [r12+r9*4-0x40]
	vpcmpltud k3,ymm8,YMMWORD PTR [r12+r9*4-0x20]
	vpcmpltud k4,ymm9,YMMWORD PTR [r12+r9*4]
	vmovdqu32 YMMWORD PTR [r12+r9*4-0x60]{k1},ymm6
	vmovdqu32 YMMWORD PTR [r12+r9*4-0x40]{k2},ymm7
	vmovdqu32 YMMWORD PTR [r12+r9*4-0x20]{k3},ymm8
	vmovdqu32 YMMWORD PTR [r12+r9*4]{k4},ymm9
	add    r9,0x20
	vpaddq zmm5,zmm5,zmm3
	cmp    rbp,r9
	jne    <coin_change+0x290>
	cmp    r11,rbp
	je     <coin_change+0x200>
	test   r11b,0x18
	je     <coin_change+0x479>
	mov    rbx,r11
	and    rbx,0xfffffffffffffff8
	lea    r12,[rbx+r10*1]
	lea    r14,[r13+rbp*4+0x0]
	add    r14,rax
	mov    r9,rbx
	sub    r9,rbp
	lea    r8,[rax+r8*4]
	sub    r8,r13
	xor    r13d,r13d
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu ymm4,YMMWORD PTR [r8+r13*4]
	vpsubd ymm4,ymm4,ymm0
	vpcmpltud k1,ymm4,YMMWORD PTR [r14+r13*4]
	vmovdqu32 YMMWORD PTR [r14+r13*4]{k1},ymm4
	add    r13,0x8
	cmp    r9,r13
	jne    <coin_change+0x340>
	cmp    r11,rbx
	mov    r14,QWORD PTR [rsp+0x8]
	je     <coin_change+0x200>
	mov    r11d,edx
	sub    r11d,r12d
	mov    r8,r12
	and    r11d,0x3
	je     <coin_change+0x3c6>
	lea    r8,[rax+r12*4]
	lea    r13,[r10*4+0x0]
	neg    r13
	neg    r11
	xor    r9d,r9d
	jmp    <coin_change+0x3ac>
	cs nop WORD PTR [rax+rax*1+0x0]
	add    r8,0x4
	dec    r9
	cmp    r11,r9
	je     <coin_change+0x3c0>
	mov    ebx,DWORD PTR [r8+r13*1]
	inc    ebx
	cmp    ebx,DWORD PTR [r8]
	jae    <coin_change+0x3a0>
	mov    DWORD PTR [r8],ebx
	jmp    <coin_change+0x3a0>
	nop    DWORD PTR [rax+0x0]
	mov    r8,r12
	sub    r8,r9
	mov    r9,r14
	sub    r9,r12
	cmp    r9,0x3
	jb     <coin_change+0x200>
	shl    r10,0x2
	lea    r11,[rax+0xc]
	sub    r11,r10
	jmp    <coin_change+0x3fc>
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    r8,r9
	cmp    rdx,r9
	je     <coin_change+0x200>
	mov    r9d,DWORD PTR [r11+r8*4-0xc]
	inc    r9d
	cmp    r9d,DWORD PTR [rax+r8*4]
	jb     <coin_change+0x450>
	mov    r9d,DWORD PTR [r11+r8*4-0x8]
	inc    r9d
	cmp    r9d,DWORD PTR [rax+r8*4+0x4]
	jb     <coin_change+0x463>
	mov    r9d,DWORD PTR [r11+r8*4-0x4]
	inc    r9d
	cmp    r9d,DWORD PTR [rax+r8*4+0x8]
	jae    <coin_change+0x42d>
	mov    DWORD PTR [rax+r8*4+0x8],r9d
	lea    r9,[r8+0x4]
	mov    r10d,DWORD PTR [r11+r8*4]
	inc    r10d
	cmp    r10d,DWORD PTR [rax+r8*4+0xc]
	jae    <coin_change+0x3f0>
	mov    DWORD PTR [rax+r9*4-0x4],r10d
	jmp    <coin_change+0x3f0>
	cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+r8*4],r9d
	mov    r9d,DWORD PTR [r11+r8*4-0x8]
	inc    r9d
	cmp    r9d,DWORD PTR [rax+r8*4+0x4]
	jae    <coin_change+0x419>
	mov    DWORD PTR [rax+r8*4+0x4],r9d
	mov    r9d,DWORD PTR [r11+r8*4-0x4]
	inc    r9d
	cmp    r9d,DWORD PTR [rax+r8*4+0x8]
	jb     <coin_change+0x428>
	jmp    <coin_change+0x42d>
	add    rbp,r10
	mov    r12,rbp
	jmp    <coin_change+0x370>
	cmp    r14,0xffffffffffffffff
	mov    rsi,QWORD PTR [rsp+0x10]
	je     <coin_change+0x4de>
	mov    r14d,DWORD PTR [rax+r14*4]
	test   rsi,rsi
	je     <coin_change+0x4ad>
	shl    rsi,0x2
	mov    edx,0x4
	mov    rdi,rax
	vzeroupper
	call   QWORD PTR [rip+0x4039b]
	cmp    QWORD PTR [rsp+0x8],r14
	mov    eax,0xffffffff
	cmovae eax,r14d
	add    rsp,0x18
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	vzeroupper
	ret
	lea    rdx,[rip+0x3e53c]
	xor    edi,edi
	xor    esi,esi
	call   QWORD PTR [rip+0x403b2]
	lea    rdx,[rip+0x3e543]
	mov    rdi,0xffffffffffffffff
	mov    rsi,r15
	vzeroupper
	call   QWORD PTR [rip+0x40398]

<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	push   rax
	mov    rbx,rdx
	mov    r15,rsi
	mov    r12,rdi
	movabs rbp,0x7fffffffffffffe0
	lea    r9,[rdx+0x1]
	lea    r13,[rdx*4+0x4]
	mov    rax,r9
	shr    rax,0x3e
	setne  cl
	lea    rax,[rbp+0x1c]
	cmp    r13,rax
	seta   al
	or     al,cl
	mov    r14d,ebx
	inc    r14d
	jne    <coin_change+0x98>
	test   al,al
	jne    <coin_change+0x9c>
	test   r13,r13
	je     <coin_change+0x15e>
	call   QWORD PTR [rip+0x4080d]
	mov    esi,0x4
	mov    rdi,r13
	call   QWORD PTR [rip+0x4084f]
	mov    edi,0x4
	test   rax,rax
	je     <coin_change+0x9e>
	lea    r9,[rbx+0x1]
	mov    rsi,r9
	test   r9,r9
	je     <coin_change+0x511>
	mov    DWORD PTR [rax],0x0
	cmp    r9,0x2
	jae    <coin_change+0x1a3>
	jmp    <coin_change+0x4cc>
	test   al,al
	je     <coin_change+0xa7>
	xor    edi,edi
	mov    rsi,r13
	call   QWORD PTR [rip+0x407a9]
	test   r13,r13
	je     <coin_change+0x173>
	call   QWORD PTR [rip+0x407b2]
	mov    esi,0x4
	mov    rdi,r13
	call   QWORD PTR [rip+0x407ac]
	mov    edi,0x4
	lea    r9,[rbx+0x1]
	mov    rsi,r9
	test   rax,rax
	je     <coin_change+0x9e>
	cmp    r9,0x2
	jb     <coin_change+0x184>
	mov    edx,0x1
	mov    rcx,rax
	cmp    rbx,0x20
	jb     <coin_change+0x139>
	mov    rdi,rbx
	and    rdi,0xffffffffffffffe0
	lea    rcx,[rax+rdi*4]
	lea    rdx,[rdi+0x1]
	vpbroadcastd ymm0,r14d
	xor    r8d,r8d
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax+r8*4],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rax+r8*4+0x60],ymm0
	add    r8,0x20
	cmp    rdi,r8
	jne    <coin_change+0x110>
	cmp    rbx,rdi
	je     <coin_change+0x190>
	mov    rdi,rbx
	sub    rdi,rdx
	inc    rdi
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rcx],r14d
	add    rcx,0x4
	dec    rdi
	jne    <coin_change+0x150>
	jmp    <coin_change+0x190>
	mov    eax,0x4
	xor    esi,esi
	test   r9,r9
	jne    <coin_change+0x83>
	jmp    <coin_change+0x511>
	mov    eax,0x4
	xor    esi,esi
	cmp    r9,0x2
	jae    <coin_change+0xdf>
	mov    rcx,rax
	test   r9,r9
	je     <coin_change+0x511>
	mov    DWORD PTR [rcx],r14d
	mov    DWORD PTR [rax],0x0
	cmp    r9,0x2
	jb     <coin_change+0x4cc>
	test   r15,r15
	je     <coin_change+0x42f>
	lea    rcx,[r12+r15*4]
	shl    r15,0x2
	add    r15,0xfffffffffffffffc
	mov    r8,r15
	shr    r8,0x2
	inc    r8
	mov    rdx,r8
	and    rdx,rbp
	vpbroadcastd ymm0,r14d
	add    rbp,0x18
	and    rbp,r8
	mov    r10d,0x1
	vpcmpeqd ymm1,ymm1,ymm1
	jmp    <coin_change+0x201>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+r10*4],r11d
	cmp    r10,rbx
	lea    r10,[r10+0x1]
	je     <coin_change+0x407>
	mov    r13,r12
	mov    r11d,r14d
	cmp    r15,0x1c
	jb     <coin_change+0x3ed>
	vpbroadcastq zmm2,r10
	cmp    r15,0x7c
	jae    <coin_change+0x230>
	xor    edi,edi
	mov    r11d,r14d
	jmp    <coin_change+0x368>
	nop    WORD PTR [rax+rax*1+0x0]
	xor    r11d,r11d
	vmovdqa ymm3,ymm0
	vmovdqa ymm4,ymm0
	vmovdqa ymm5,ymm0
	vmovdqa ymm6,ymm0
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vpmovzxdq zmm7,YMMWORD PTR [r12+r11*4]
	vpmovzxdq zmm8,YMMWORD PTR [r12+r11*4+0x20]
	vpmovzxdq zmm9,YMMWORD PTR [r12+r11*4+0x40]
	vpmovzxdq zmm10,YMMWORD PTR [r12+r11*4+0x60]
	vpcmpnltuq k4,zmm2,zmm7
	vpcmpnltuq k3,zmm2,zmm8
	vpcmpnltuq k2,zmm2,zmm9
	vpcmpnltuq k1,zmm2,zmm10
	vpsubq zmm7,zmm2,zmm7
	vpsubq zmm8,zmm2,zmm8
	vpsubq zmm9,zmm2,zmm9
	vpsubq zmm10,zmm2,zmm10
	kmovq  k5,k4
	vpxor  xmm11,xmm11,xmm11
	vpgatherqd ymm11{k5},DWORD PTR [rax+zmm7*4]
	kmovq  k5,k3
	vpxor  xmm7,xmm7,xmm7
	vpgatherqd ymm7{k5},DWORD PTR [rax+zmm8*4]
	kmovq  k5,k2
	vpxor  xmm8,xmm8,xmm8
	vpgatherqd ymm8{k5},DWORD PTR [rax+zmm9*4]
	kmovq  k5,k1
	vpxor  xmm9,xmm9,xmm9
	vpgatherqd ymm9{k5},DWORD PTR [rax+zmm10*4]
	vpsubd ymm10,ymm11,ymm1
	vpsubd ymm7,ymm7,ymm1
	vpsubd ymm8,ymm8,ymm1
	vpsubd ymm9,ymm9,ymm1
	vpminud ymm3{k4},ymm10,ymm3
	vpminud ymm4{k3},ymm7,ymm4
	vpminud ymm5{k2},ymm8,ymm5
	vpminud ymm6{k1},ymm9,ymm6
	add    r11,0x20
	cmp    rdx,r11
	jne    <coin_change+0x250>
	vpminud ymm3,ymm3,ymm4
	vpminud ymm4,ymm5,ymm6
	vpminud ymm3,ymm3,ymm4
	vextracti128 xmm4,ymm3,0x1
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0xee
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0x55
	vpminud xmm3,xmm3,xmm4
	vmovd  r11d,xmm3
	cmp    r8,rdx
	je     <coin_change+0x1f0>
	mov    rdi,rdx
	lea    r13,[r12+rdx*4]
	test   r8b,0x18
	je     <coin_change+0x3ed>
	vpbroadcastd ymm3,r11d
	xchg   ax,ax
	vpmovzxdq zmm4,YMMWORD PTR [r12+rdi*4]
	vpcmpnltuq k1,zmm2,zmm4
	vpsubq zmm4,zmm2,zmm4
	kmovq  k2,k1
	vpxor  xmm5,xmm5,xmm5
	vpgatherqd ymm5{k2},DWORD PTR [rax+zmm4*4]
	vpsubd ymm4,ymm5,ymm1
	vpminud ymm3{k1},ymm4,ymm3
	add    rdi,0x8
	cmp    rbp,rdi
	jne    <coin_change+0x370>
	vextracti128 xmm2,ymm3,0x1
	vpminud xmm2,xmm3,xmm2
	vpshufd xmm3,xmm2,0xee
	vpminud xmm2,xmm2,xmm3
	vpshufd xmm3,xmm2,0x55
	vpminud xmm2,xmm2,xmm3
	vmovd  r11d,xmm2
	lea    r13,[r12+rbp*4]
	cmp    r8,rbp
	jne    <coin_change+0x3ed>
	jmp    <coin_change+0x1f0>
	nop    DWORD PTR [rax+0x0]
	add    r13,0x4
	cmp    r13,rcx
	je     <coin_change+0x1f0>
	mov    r9d,DWORD PTR [r13+0x0]
	mov    rdi,r10
	sub    rdi,r9
	jb     <coin_change+0x3e0>
	mov    edi,DWORD PTR [rax+rdi*4]
	inc    edi
	cmp    edi,r11d
	cmovb  r11d,edi
	jmp    <coin_change+0x3e0>
	cmp    rbx,0xffffffffffffffff
	lea    rcx,[rbx+0x1]
	jne    <coin_change+0x4cc>
	lea    rdx,[rip+0x3e63c]
	mov    rdi,0xffffffffffffffff
	mov    rsi,rcx
	vzeroupper
	call   QWORD PTR [rip+0x40491]
	mov    edx,0x1
	cmp    rbx,0x4
	jb     <coin_change+0x4b4>
	cmp    rbx,0x20
	jae    <coin_change+0x444>
	xor    ecx,ecx
	jmp    <coin_change+0x48b>
	mov    rcx,rbx
	and    rcx,0xffffffffffffffe0
	vpbroadcastd ymm0,r14d
	xor    edx,edx
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax+rdx*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rax+rdx*4+0x64],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0x460>
	cmp    rbx,rcx
	je     <coin_change+0x4cc>
	test   bl,0x1c
	je     <coin_change+0x508>
	mov    rdi,rbx
	and    rdi,0xfffffffffffffffc
	lea    rdx,[rdi+0x1]
	vpbroadcastd xmm0,r14d
	nop    DWORD PTR [rax+0x0]
	vmovdqu XMMWORD PTR [rax+rcx*4+0x4],xmm0
	add    rcx,0x4
	cmp    rdi,rcx
	jne    <coin_change+0x4a0>
	cmp    rbx,rdi
	je     <coin_change+0x4cc>
	lea    rcx,[rbx+0x1]
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+rdx*4],r14d
	inc    rdx
	cmp    rcx,rdx
	jne    <coin_change+0x4c0>
	mov    r14d,DWORD PTR [rax+rbx*4]
	test   rsi,rsi
	je     <coin_change+0x4ea>
	shl    rsi,0x2
	mov    edx,0x4
	mov    rdi,rax
	vzeroupper
	call   QWORD PTR [rip+0x4038e]
	cmp    rbx,r14
	mov    eax,0xffffffff
	cmovae eax,r14d
	add    rsp,0x8
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	vzeroupper
	ret
	or     rcx,0x1
	mov    rdx,rcx
	jmp    <coin_change+0x4b4>
	lea    rdx,[rip+0x3e528]
	xor    edi,edi
	xor    esi,esi
	call   QWORD PTR [rip+0x4039e]

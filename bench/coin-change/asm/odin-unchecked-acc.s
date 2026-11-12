<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x28
	mov    rbx,rcx
	mov    r15,rdx
	mov    r12,rsi
	mov    r13,rdi
	lea    r14,[rdx+0x1]
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	shl    r14,0x2
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x10],xmm0
	mov    QWORD PTR [rsp],rbx
	lea    r8,[rip+0x2c262]
	lea    r9,[rsp+0x10]
	mov    esi,0x4
	mov    rdi,r14
	call   <runtime::mem_alloc_bytes>
	mov    rcx,r15
	mov    rdi,QWORD PTR [rsp+0x10]
	inc    rcx
	jne    <coin_change+0x68>
	mov    DWORD PTR [rdi],0x0
	jmp    <coin_change+0x3fb>
	lea    eax,[r15+0x1]
	cmp    rcx,0x4
	jae    <coin_change+0x76>
	xor    edx,edx
	jmp    <coin_change+0xe0>
	cmp    rcx,0x20
	jae    <coin_change+0x80>
	xor    edx,edx
	jmp    <coin_change+0xba>
	mov    rdx,rcx
	and    rdx,0xffffffffffffffe0
	vpbroadcastd ymm0,eax
	xor    esi,esi
	nop
	vmovdqu YMMWORD PTR [rdi+rsi*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x60],ymm0
	add    rsi,0x20
	cmp    rdx,rsi
	jne    <coin_change+0x90>
	cmp    rcx,rdx
	je     <coin_change+0xeb>
	test   cl,0x1c
	je     <coin_change+0xe0>
	mov    rsi,rdx
	mov    rdx,rcx
	and    rdx,0xfffffffffffffffc
	vpbroadcastd xmm0,eax
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu XMMWORD PTR [rdi+rsi*4],xmm0
	add    rsi,0x4
	cmp    rdx,rsi
	jne    <coin_change+0xd0>
	jmp    <coin_change+0xe6>
	mov    DWORD PTR [rdi+rdx*4],eax
	inc    rdx
	cmp    rcx,rdx
	jne    <coin_change+0xe0>
	mov    DWORD PTR [rdi],0x0
	test   r15,r15
	je     <coin_change+0x3fb>
	test   r12,r12
	jle    <coin_change+0x359>
	movabs rcx,0x7fffffffffffffe0
	mov    rdx,r12
	and    rdx,rcx
	vpbroadcastd ymm0,eax
	or     rcx,0x18
	and    rcx,r12
	mov    esi,0x1
	vpcmpeqd ymm1,ymm1,ymm1
	jmp    <coin_change+0x141>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi+rsi*4],r8d
	cmp    rsi,r15
	lea    rsi,[rsi+0x1]
	je     <coin_change+0x3fb>
	cmp    r12,0x8
	jae    <coin_change+0x160>
	xor    r9d,r9d
	mov    r8d,eax
	jmp    <coin_change+0x33c>
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vpbroadcastq zmm2,rsi
	cmp    r12,0x20
	jae    <coin_change+0x180>
	xor    r10d,r10d
	mov    r8d,eax
	jmp    <coin_change+0x2b8>
	nop    WORD PTR [rax+rax*1+0x0]
	xor    r8d,r8d
	vmovdqa ymm3,ymm0
	vmovdqa ymm4,ymm0
	vmovdqa ymm5,ymm0
	vmovdqa ymm6,ymm0
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vpmovzxdq zmm7,YMMWORD PTR [r13+r8*4+0x0]
	vpmovzxdq zmm8,YMMWORD PTR [r13+r8*4+0x20]
	vpmovzxdq zmm9,YMMWORD PTR [r13+r8*4+0x40]
	vpmovzxdq zmm10,YMMWORD PTR [r13+r8*4+0x60]
	vpcmpnltuq k4,zmm2,zmm7
	vpcmpnltuq k3,zmm2,zmm8
	vpcmpnltuq k2,zmm2,zmm9
	vpcmpnltuq k1,zmm2,zmm10
	vpsubq zmm7,zmm2,zmm7
	vpsubq zmm8,zmm2,zmm8
	vpsubq zmm9,zmm2,zmm9
	vpsubq zmm10,zmm2,zmm10
	vpxor  xmm11,xmm11,xmm11
	kmovq  k5,k4
	vpgatherqd ymm11{k5},DWORD PTR [rdi+zmm7*4]
	vpxor  xmm7,xmm7,xmm7
	kmovq  k5,k3
	vpgatherqd ymm7{k5},DWORD PTR [rdi+zmm8*4]
	vpxor  xmm8,xmm8,xmm8
	kmovq  k5,k2
	vpgatherqd ymm8{k5},DWORD PTR [rdi+zmm9*4]
	vpxor  xmm9,xmm9,xmm9
	kmovq  k5,k1
	vpgatherqd ymm9{k5},DWORD PTR [rdi+zmm10*4]
	vpsubd ymm10,ymm11,ymm1
	vpsubd ymm7,ymm7,ymm1
	vpsubd ymm8,ymm8,ymm1
	vpsubd ymm9,ymm9,ymm1
	vpminud ymm3{k4},ymm10,ymm3
	vpminud ymm4{k3},ymm7,ymm4
	vpminud ymm5{k2},ymm8,ymm5
	vpminud ymm6{k1},ymm9,ymm6
	add    r8,0x20
	cmp    rdx,r8
	jne    <coin_change+0x1a0>
	vpminud ymm3,ymm3,ymm4
	vpminud ymm4,ymm5,ymm6
	vpminud ymm3,ymm3,ymm4
	vextracti128 xmm4,ymm3,0x1
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0xee
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0x55
	vpminud xmm3,xmm3,xmm4
	vmovd  r8d,xmm3
	cmp    r12,rdx
	je     <coin_change+0x130>
	mov    r10,rdx
	mov    r9,rdx
	test   r12b,0x18
	je     <coin_change+0x33c>
	vpbroadcastd ymm3,r8d
	xchg   ax,ax
	vpmovzxdq zmm4,YMMWORD PTR [r13+r10*4+0x0]
	vpcmpnltuq k1,zmm2,zmm4
	vpsubq zmm4,zmm2,zmm4
	vpxor  xmm5,xmm5,xmm5
	kmovq  k2,k1
	vpgatherqd ymm5{k2},DWORD PTR [rdi+zmm4*4]
	vpsubd ymm4,ymm5,ymm1
	vpminud ymm3{k1},ymm4,ymm3
	add    r10,0x8
	cmp    rcx,r10
	jne    <coin_change+0x2c0>
	vextracti128 xmm2,ymm3,0x1
	vpminud xmm2,xmm3,xmm2
	vpshufd xmm3,xmm2,0xee
	vpminud xmm2,xmm2,xmm3
	vpshufd xmm3,xmm2,0x55
	vpminud xmm2,xmm2,xmm3
	vmovd  r8d,xmm2
	mov    r9,rcx
	cmp    r12,rcx
	jne    <coin_change+0x33c>
	jmp    <coin_change+0x130>
	nop    DWORD PTR [rax+0x0]
	inc    r9
	cmp    r12,r9
	je     <coin_change+0x130>
	mov    r11d,DWORD PTR [r13+r9*4+0x0]
	mov    r10,rsi
	sub    r10,r11
	jb     <coin_change+0x330>
	mov    r10d,DWORD PTR [rdi+r10*4]
	inc    r10d
	cmp    r10d,r8d
	cmovb  r8d,r10d
	jmp    <coin_change+0x330>
	mov    esi,0x1
	cmp    r15,0x4
	jb     <coin_change+0x3f0>
	cmp    r15,0x20
	jae    <coin_change+0x372>
	xor    edx,edx
	jmp    <coin_change+0x3bc>
	mov    rdx,r15
	and    rdx,0xffffffffffffffe0
	vpbroadcastd ymm0,eax
	xor    esi,esi
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rdi+rsi*4+0x64],ymm0
	add    rsi,0x20
	cmp    rdx,rsi
	jne    <coin_change+0x390>
	cmp    r15,rdx
	je     <coin_change+0x3fb>
	test   r15b,0x1c
	je     <coin_change+0x437>
	mov    r8,r15
	and    r8,0xfffffffffffffffc
	lea    rsi,[r8+0x1]
	vpbroadcastd xmm0,eax
	nop    DWORD PTR [rax]
	vmovdqu XMMWORD PTR [rdi+rdx*4+0x4],xmm0
	add    rdx,0x4
	cmp    r8,rdx
	jne    <coin_change+0x3d0>
	cmp    r15,r8
	je     <coin_change+0x3fb>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi+rsi*4],eax
	inc    rsi
	cmp    rcx,rsi
	jne    <coin_change+0x3f0>
	mov    eax,DWORD PTR [rdi+r15*4]
	cmp    r15,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    rdx,QWORD PTR [rbx]
	mov    rcx,QWORD PTR [rbx+0x8]
	lea    r8,[rip+0x2beb8]
	mov    rsi,r14
	mov    r9,rbx
	vzeroupper
	call   <runtime::mem_free_with_size>
	mov    eax,ebp
	add    rsp,0x28
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	or     rdx,0x1
	mov    rsi,rdx
	jmp    <coin_change+0x3f0>

<coin_change>:
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	push   rax
	lea    r15,[rdx+0x1]
	mov    rax,r15
	shr    rax,0x3e
	jne    <coin_change+0x42f>
	mov    rbx,rdx
	mov    r14,rsi
	mov    r12,rdi
	lea    r13d,[rdx+0x1]
	lea    rdi,[r15*4+0x0]
	mov    QWORD PTR [rbp-0x30],rdi
	call   <_Znwm>
	mov    cl,0x3e
	bzhi   rsi,rbx,rcx
	mov    rdi,rax
	cmp    rsi,0x3
	jb     <coin_change+0xd3>
	lea    rcx,[rsi+0x1]
	movabs rdx,0x7fffffffffffffe0
	cmp    rsi,0x1f
	jae    <coin_change+0x69>
	xor    esi,esi
	jmp    <coin_change+0xae>
	mov    rsi,rcx
	and    rsi,rdx
	vpbroadcastd ymm0,r13d
	xor    edi,edi
	nop    WORD PTR [rax+rax*1+0x0]
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
	je     <coin_change+0x426>
	add    rdx,0x1c
	and    rdx,rcx
	lea    rdi,[rax+rdx*4]
	vpbroadcastd xmm0,r13d
	nop
	vmovdqu XMMWORD PTR [rax+rsi*4],xmm0
	add    rsi,0x4
	cmp    rdx,rsi
	jne    <coin_change+0xc0>
	cmp    rcx,rdx
	je     <coin_change+0xec>
	lea    rcx,[rax+r15*4]
	nop    WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi],r13d
	add    rdi,0x4
	cmp    rdi,rcx
	jne    <coin_change+0xe0>
	mov    DWORD PTR [rax],0x0
	cmp    r15,0x2
	jb     <coin_change+0x3f8>
	mov    rcx,r14
	and    rcx,0xffffffffffffffe0
	vpbroadcastd ymm0,r13d
	mov    rdx,r14
	and    rdx,0xfffffffffffffff8
	mov    esi,0x1
	vpcmpeqd ymm1,ymm1,ymm1
	jmp    <coin_change+0x130>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+rsi*4],edi
	cmp    rsi,rbx
	lea    rsi,[rsi+0x1]
	je     <coin_change+0x3f8>
	mov    edi,r13d
	test   r14,r14
	je     <coin_change+0x120>
	cmp    r14,0x8
	jae    <coin_change+0x150>
	mov    edi,r13d
	xor    r8d,r8d
	jmp    <coin_change+0x3dc>
	nop    DWORD PTR [rax+0x0]
	vpbroadcastq ymm2,rsi
	cmp    r14,0x20
	jae    <coin_change+0x167>
	xor    r9d,r9d
	mov    edi,r13d
	jmp    <coin_change+0x336>
	xor    edi,edi
	vmovdqa ymm3,ymm0
	vmovdqa ymm4,ymm0
	vmovdqa ymm5,ymm0
	vmovdqa ymm6,ymm0
	nop    DWORD PTR [rax+0x0]
	vpmovzxdq ymm8,XMMWORD PTR [r12+rdi*4+0x10]
	vpmovzxdq ymm9,XMMWORD PTR [r12+rdi*4]
	vpmovzxdq ymm10,XMMWORD PTR [r12+rdi*4+0x30]
	vpmovzxdq ymm11,XMMWORD PTR [r12+rdi*4+0x20]
	vpmovzxdq ymm12,XMMWORD PTR [r12+rdi*4+0x50]
	vpmovzxdq ymm13,XMMWORD PTR [r12+rdi*4+0x40]
	vpmovzxdq ymm14,XMMWORD PTR [r12+rdi*4+0x70]
	vpmovzxdq ymm7,XMMWORD PTR [r12+rdi*4+0x60]
	vpcmpnltuq k5,ymm2,ymm9
	vpcmpnltuq k2,ymm2,ymm8
	kshiftlb k0,k2,0x4
	korb   k1,k5,k0
	vpcmpnltuq k3,ymm2,ymm11
	vpcmpnltuq k4,ymm2,ymm10
	vpsubq ymm8,ymm2,ymm8
	vpxor  xmm15,xmm15,xmm15
	vpgatherqd xmm15{k2},DWORD PTR [rax+ymm8*4]
	kshiftlb k0,k4,0x4
	korb   k2,k3,k0
	vpsubq ymm8,ymm2,ymm9
	vpxor  xmm9,xmm9,xmm9
	vpgatherqd xmm9{k5},DWORD PTR [rax+ymm8*4]
	vpcmpnltuq k5,ymm2,ymm13
	vpsubq ymm8,ymm2,ymm10
	vpxor  xmm10,xmm10,xmm10
	vpgatherqd xmm10{k4},DWORD PTR [rax+ymm8*4]
	vpcmpnltuq k4,ymm2,ymm12
	vpsubq ymm8,ymm2,ymm11
	vpxor  xmm11,xmm11,xmm11
	vpgatherqd xmm11{k3},DWORD PTR [rax+ymm8*4]
	kshiftlb k0,k4,0x4
	korb   k3,k5,k0
	vpsubq ymm8,ymm2,ymm12
	vpxor  xmm12,xmm12,xmm12
	vpgatherqd xmm12{k4},DWORD PTR [rax+ymm8*4]
	vpcmpnltuq k4,ymm2,ymm14
	vpsubq ymm8,ymm2,ymm13
	vpxor  xmm13,xmm13,xmm13
	vpgatherqd xmm13{k5},DWORD PTR [rax+ymm8*4]
	kshiftlb k0,k4,0x4
	vpsubq ymm8,ymm2,ymm14
	vpxor  xmm14,xmm14,xmm14
	vpgatherqd xmm14{k4},DWORD PTR [rax+ymm8*4]
	vpcmpnltuq k5,ymm2,ymm7
	korb   k4,k5,k0
	vpsubq ymm7,ymm2,ymm7
	vpxor  xmm8,xmm8,xmm8
	vpgatherqd xmm8{k5},DWORD PTR [rax+ymm7*4]
	vinserti128 ymm7,ymm9,xmm15,0x1
	vpsubd ymm7,ymm7,ymm1
	vpminud ymm3{k1},ymm7,ymm3
	vinserti128 ymm7,ymm11,xmm10,0x1
	vpsubd ymm7,ymm7,ymm1
	vpminud ymm4{k2},ymm7,ymm4
	vinserti128 ymm7,ymm13,xmm12,0x1
	vpsubd ymm7,ymm7,ymm1
	vpminud ymm5{k3},ymm7,ymm5
	vinserti128 ymm7,ymm8,xmm14,0x1
	vpsubd ymm7,ymm7,ymm1
	vpminud ymm6{k4},ymm7,ymm6
	add    rdi,0x20
	cmp    rcx,rdi
	jne    <coin_change+0x180>
	vpminud ymm3,ymm3,ymm4
	vpminud ymm4,ymm5,ymm6
	vpminud ymm3,ymm3,ymm4
	vextracti128 xmm4,ymm3,0x1
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0xee
	vpminud xmm3,xmm3,xmm4
	vpshufd xmm4,xmm3,0x55
	vpminud xmm3,xmm3,xmm4
	vmovd  edi,xmm3
	cmp    r14,rcx
	je     <coin_change+0x120>
	mov    r9,rcx
	mov    r8,rcx
	test   r14b,0x18
	je     <coin_change+0x3dc>
	vpbroadcastd ymm3,edi
	nop    DWORD PTR [rax+0x0]
	vpmovzxdq ymm4,XMMWORD PTR [r12+r9*4+0x10]
	vpmovzxdq ymm5,XMMWORD PTR [r12+r9*4]
	vpcmpnltuq k1,ymm2,ymm5
	vpcmpnltuq k2,ymm2,ymm4
	kshiftlb k0,k2,0x4
	korb   k3,k1,k0
	vpsubq ymm5,ymm2,ymm5
	vpsubq ymm4,ymm2,ymm4
	vpxor  xmm6,xmm6,xmm6
	vpgatherqd xmm6{k2},DWORD PTR [rax+ymm4*4]
	vpxor  xmm4,xmm4,xmm4
	vpgatherqd xmm4{k1},DWORD PTR [rax+ymm5*4]
	vinserti128 ymm4,ymm4,xmm6,0x1
	vpsubd ymm4,ymm4,ymm1
	vpminud ymm3{k3},ymm4,ymm3
	add    r9,0x8
	cmp    rdx,r9
	jne    <coin_change+0x340>
	vextracti128 xmm2,ymm3,0x1
	vpminud xmm2,xmm3,xmm2
	vpshufd xmm3,xmm2,0xee
	vpminud xmm2,xmm2,xmm3
	vpshufd xmm3,xmm2,0x55
	vpminud xmm2,xmm2,xmm3
	vmovd  edi,xmm2
	mov    r8,rdx
	cmp    r14,rdx
	jne    <coin_change+0x3dc>
	jmp    <coin_change+0x120>
	nop    DWORD PTR [rax+0x0]
	inc    r8
	cmp    r14,r8
	je     <coin_change+0x120>
	mov    r10d,DWORD PTR [r12+r8*4]
	mov    r9,rsi
	sub    r9,r10
	jb     <coin_change+0x3d0>
	mov    r9d,DWORD PTR [rax+r9*4]
	inc    r9d
	cmp    r9d,edi
	cmovb  edi,r9d
	jmp    <coin_change+0x3d0>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	mov    rsi,QWORD PTR [rbp-0x30]
	vzeroupper
	call   <_ZdlPvm>
	mov    eax,ebx
	add    rsp,0x8
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

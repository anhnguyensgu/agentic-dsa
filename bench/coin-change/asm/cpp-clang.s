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
	xor    edi,edi
	mov    r12,rdx
	mov    esi,0x0
	inc    r12
	je     <coin_change+0x10c>
	mov    rax,r12
	shr    rax,0x3e
	jne    <coin_change+0x31d>
	lea    r13d,[rbx+0x1]
	lea    rdi,[r12*4+0x0]
	call   <_Znwm>
	mov    rdi,rax
	lea    rsi,[rax+r12*4]
	mov    al,0x3e
	bzhi   rdx,rbx,rax
	mov    r8,rdi
	cmp    rdx,0x3
	jb     <coin_change+0x100>
	lea    rax,[rdx+0x1]
	movabs rcx,0x7fffffffffffffe0
	cmp    rdx,0x1f
	jae    <coin_change+0x7b>
	xor    edx,edx
	jmp    <coin_change+0xc1>
	mov    rdx,rax
	and    rdx,rcx
	vpbroadcastd ymm0,r13d
	xor    r8d,r8d
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+r8*4],ymm0
	vmovdqu YMMWORD PTR [rdi+r8*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+r8*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+r8*4+0x60],ymm0
	add    r8,0x20
	cmp    rdx,r8
	jne    <coin_change+0x90>
	cmp    rax,rdx
	je     <coin_change+0x10c>
	test   al,0x1c
	je     <coin_change+0x314>
	add    rcx,0x1c
	and    rcx,rax
	lea    r8,[rdi+rcx*4]
	vpbroadcastd xmm0,r13d
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu XMMWORD PTR [rdi+rdx*4],xmm0
	add    rdx,0x4
	cmp    rcx,rdx
	jne    <coin_change+0xe0>
	cmp    rax,rcx
	je     <coin_change+0x10c>
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [r8],r13d
	add    r8,0x4
	cmp    r8,rsi
	jne    <coin_change+0x100>
	mov    DWORD PTR [rdi],0x0
	test   r14,r14
	je     <coin_change+0x2ea>
	lea    rcx,[rdi+0x60]
	xor    r8d,r8d
	vpcmpeqd ymm0,ymm0,ymm0
	vpbroadcastd ymm1,DWORD PTR [rip+0xffffffffffff5901]
	jmp    <coin_change+0x14c>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	inc    r8
	cmp    r8,r14
	je     <coin_change+0x2ea>
	mov    r9d,DWORD PTR [r15+r8*4]
	mov    r10,r12
	sub    r10,r9
	jbe    <coin_change+0x140>
	mov    rdx,r9
	cmp    r10,0x8
	jb     <coin_change+0x260>
	lea    r13,[rdi+rbx*4+0x4]
	cmp    rdi,r13
	setb   al
	lea    rdx,[r9*4+0x0]
	lea    r11,[rdi+r9*4]
	sub    r13,rdx
	cmp    r11,r13
	setb   r13b
	mov    rdx,r9
	test   r13b,al
	jne    <coin_change+0x260>
	cmp    r10,0x20
	jae    <coin_change+0x1a0>
	xor    r13d,r13d
	jmp    <coin_change+0x225>
	mov    r13,r10
	and    r13,0xffffffffffffffe0
	lea    rdx,[rcx+r9*4]
	xor    eax,eax
	nop    DWORD PTR [rax]
	vpaddd ymm2,ymm1,YMMWORD PTR [rcx+rax*4-0x60]
	vpaddd ymm3,ymm1,YMMWORD PTR [rcx+rax*4-0x40]
	vpaddd ymm4,ymm1,YMMWORD PTR [rcx+rax*4-0x20]
	vpaddd ymm5,ymm1,YMMWORD PTR [rcx+rax*4]
	vpcmpltud k1,ymm2,YMMWORD PTR [rdx+rax*4-0x60]
	vpcmpltud k2,ymm3,YMMWORD PTR [rdx+rax*4-0x40]
	vpcmpltud k3,ymm4,YMMWORD PTR [rdx+rax*4-0x20]
	vpcmpltud k4,ymm5,YMMWORD PTR [rdx+rax*4]
	vmovdqu32 YMMWORD PTR [rdx+rax*4-0x60]{k1},ymm2
	vmovdqu32 YMMWORD PTR [rdx+rax*4-0x40]{k2},ymm3
	vmovdqu32 YMMWORD PTR [rdx+rax*4-0x20]{k3},ymm4
	vmovdqu32 YMMWORD PTR [rdx+rax*4]{k4},ymm5
	add    rax,0x20
	cmp    r13,rax
	jne    <coin_change+0x1b0>
	cmp    r10,r13
	je     <coin_change+0x140>
	test   r10b,0x18
	je     <coin_change+0x2df>
	mov    rax,r10
	and    rax,0xfffffffffffffff8
	lea    rdx,[rax+r9*1]
	vmovdqu ymm2,YMMWORD PTR [rdi+r13*4]
	vpsubd ymm2,ymm2,ymm0
	vpcmpltud k1,ymm2,YMMWORD PTR [r11+r13*4]
	vmovdqu32 YMMWORD PTR [r11+r13*4]{k1},ymm2
	add    r13,0x8
	cmp    rax,r13
	jne    <coin_change+0x230>
	cmp    r10,rax
	je     <coin_change+0x140>
	nop    DWORD PTR [rax+rax*1+0x0]
	lea    r10d,[rbx+rdx*1]
	mov    rax,rdx
	test   r10b,0x1
	jne    <coin_change+0x284>
	mov    rax,rdx
	sub    rax,r9
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,DWORD PTR [rdi+rdx*4]
	jae    <coin_change+0x280>
	mov    DWORD PTR [rdi+rdx*4],eax
	lea    rax,[rdx+0x1]
	cmp    rbx,rdx
	je     <coin_change+0x140>
	mov    rdx,r12
	sub    rdx,rax
	lea    r10,[rdi+0x4]
	lea    r10,[r10+rax*4]
	shl    r9,0x2
	neg    r9
	jmp    <coin_change+0x2be>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	add    r10,0x8
	add    rdx,0xfffffffffffffffe
	je     <coin_change+0x140>
	mov    eax,DWORD PTR [r10+r9*1-0x4]
	inc    eax
	cmp    eax,DWORD PTR [r10-0x4]
	jae    <coin_change+0x2cf>
	mov    DWORD PTR [r10-0x4],eax
	mov    eax,DWORD PTR [r10+r9*1]
	inc    eax
	cmp    eax,DWORD PTR [r10]
	jae    <coin_change+0x2b0>
	mov    DWORD PTR [r10],eax
	jmp    <coin_change+0x2b0>
	add    r13,r9
	mov    rdx,r13
	jmp    <coin_change+0x260>
	mov    eax,DWORD PTR [rdi+rbx*4]
	cmp    rbx,rax
	mov    ebx,0xffffffff
	cmovae ebx,eax
	sub    rsi,rdi
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
	lea    r8,[rdi+rdx*4]
	jmp    <coin_change+0x100>
	call   <_ZNSt3__16vectorIjNS_9allocatorIjEEE20__throw_length_errorB9nin220108Ev>

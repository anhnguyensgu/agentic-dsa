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
	lea    r14,[rdx+0x1]
	lea    r12,[rdx*4+0x4]
	mov    rax,r14
	shr    rax,0x3e
	setne  cl
	movabs rax,0x7ffffffffffffffc
	cmp    r12,rax
	seta   al
	or     al,cl
	mov    ebp,ebx
	inc    ebp
	jne    <coin_change+0x91>
	test   al,al
	jne    <coin_change+0x95>
	test   r12,r12
	je     <coin_change+0x15d>
	mov    rbp,rdi
	call   QWORD PTR [rip+0x4066b]
	mov    r13d,0x4
	mov    esi,0x4
	mov    rdi,r12
	call   QWORD PTR [rip+0x406a7]
	test   rax,rax
	je     <coin_change+0x98>
	mov    rsi,r14
	mov    rdi,rbp
	test   r14,r14
	je     <coin_change+0x340>
	mov    DWORD PTR [rax],0x0
	test   r15,r15
	jne    <coin_change+0x1a0>
	jmp    <coin_change+0x2eb>
	test   al,al
	je     <coin_change+0xa4>
	xor    r13d,r13d
	mov    rdi,r13
	mov    rsi,r12
	call   QWORD PTR [rip+0x40604]
	test   r12,r12
	je     <coin_change+0x172>
	mov    QWORD PTR [rsp],r15
	mov    r15,rdi
	call   QWORD PTR [rip+0x40606]
	mov    r13d,0x4
	mov    esi,0x4
	mov    rdi,r12
	call   QWORD PTR [rip+0x405fa]
	mov    rdi,r15
	mov    r15,QWORD PTR [rsp]
	mov    rsi,r14
	test   rax,rax
	je     <coin_change+0x98>
	cmp    r14,0x2
	jb     <coin_change+0x183>
	mov    edx,0x1
	mov    rcx,rax
	cmp    rbx,0x20
	jb     <coin_change+0x139>
	mov    r8,rbx
	and    r8,0xffffffffffffffe0
	lea    rcx,[rax+r8*4]
	lea    rdx,[r8+0x1]
	vpbroadcastd ymm0,ebp
	xor    r9d,r9d
	nop    DWORD PTR [rax]
	vmovdqu YMMWORD PTR [rax+r9*4],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rax+r9*4+0x60],ymm0
	add    r9,0x20
	cmp    r8,r9
	jne    <coin_change+0x110>
	cmp    rbx,r8
	je     <coin_change+0x18f>
	mov    r8,rbx
	sub    r8,rdx
	inc    r8
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rcx],ebp
	add    rcx,0x4
	dec    r8
	jne    <coin_change+0x150>
	jmp    <coin_change+0x18f>
	mov    eax,0x4
	xor    esi,esi
	test   r14,r14
	jne    <coin_change+0x7d>
	jmp    <coin_change+0x340>
	mov    eax,0x4
	xor    esi,esi
	cmp    r14,0x2
	jae    <coin_change+0xe7>
	mov    rcx,rax
	test   r14,r14
	je     <coin_change+0x340>
	mov    DWORD PTR [rcx],ebp
	mov    DWORD PTR [rax],0x0
	test   r15,r15
	je     <coin_change+0x2eb>
	lea    rdx,[rdi+r15*4]
	lea    r8,[rax+0x4]
	lea    r9,[rax+0x60]
	mov    r10d,0x20
	vpbroadcastd ymm0,DWORD PTR [rip+0xfffffffffffeffb1]
	jmp    <coin_change+0x1cd>
	nop    DWORD PTR [rax]
	add    rdi,0x4
	cmp    rdi,rdx
	je     <coin_change+0x2e5>
	mov    r11d,DWORD PTR [rdi]
	cmp    r14,r11
	jbe    <coin_change+0x1c0>
	mov    r12,rbx
	sub    r12,r11
	cmp    r12,r14
	mov    r15,r14
	cmovb  r15,r12
	inc    r15
	mov    rcx,r11
	cmp    r15,0x20
	jbe    <coin_change+0x2a6>
	lea    r13,[rax+r11*4]
	cmp    r12,r14
	cmovae r12,r14
	lea    rcx,[r8+r12*4]
	cmp    r13,rcx
	jae    <coin_change+0x219>
	lea    r12,[rcx+r11*4]
	mov    rcx,r11
	cmp    rax,r12
	jb     <coin_change+0x2a6>
	mov    ecx,r15d
	and    ecx,0x1f
	cmove  rcx,r10
	sub    r15,rcx
	lea    rcx,[r15+r11*1]
	lea    r12,[r9+r11*4]
	xor    r13d,r13d
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vpaddd ymm1,ymm0,YMMWORD PTR [r9+r13*4-0x60]
	vpaddd ymm2,ymm0,YMMWORD PTR [r9+r13*4-0x40]
	vpaddd ymm3,ymm0,YMMWORD PTR [r9+r13*4-0x20]
	vpaddd ymm4,ymm0,YMMWORD PTR [r9+r13*4]
	vpcmpltud k1,ymm1,YMMWORD PTR [r12+r13*4-0x60]
	vpcmpltud k2,ymm2,YMMWORD PTR [r12+r13*4-0x40]
	vpcmpltud k3,ymm3,YMMWORD PTR [r12+r13*4-0x20]
	vpcmpltud k4,ymm4,YMMWORD PTR [r12+r13*4]
	vmovdqu32 YMMWORD PTR [r12+r13*4-0x60]{k1},ymm1
	vmovdqu32 YMMWORD PTR [r12+r13*4-0x40]{k2},ymm2
	vmovdqu32 YMMWORD PTR [r12+r13*4-0x20]{k3},ymm3
	vmovdqu32 YMMWORD PTR [r12+r13*4]{k4},ymm4
	add    r13,0x20
	cmp    r15,r13
	jne    <coin_change+0x240>
	mov    r15,r11
	neg    r15
	lea    r13,[r11*4+0x0]
	mov    r12,rax
	sub    r12,r13
	jmp    <coin_change+0x2cc>
	nop    DWORD PTR [rax+0x0]
	inc    rcx
	cmp    r14,rcx
	je     <coin_change+0x1c0>
	lea    r13,[r15+rcx*1]
	cmp    r13,r14
	jae    <coin_change+0x327>
	mov    ebp,DWORD PTR [r12+rcx*4]
	inc    ebp
	cmp    ebp,DWORD PTR [rax+rcx*4]
	jae    <coin_change+0x2c0>
	mov    DWORD PTR [rax+rcx*4],ebp
	jmp    <coin_change+0x2c0>
	cmp    rbx,0xffffffffffffffff
	je     <coin_change+0x351>
	mov    r14d,DWORD PTR [rax+rbx*4]
	test   rsi,rsi
	je     <coin_change+0x309>
	shl    rsi,0x2
	mov    edx,0x4
	mov    rdi,rax
	vzeroupper
	call   QWORD PTR [rip+0x403c7]
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
	sub    rcx,r11
	lea    rdx,[rip+0x3e567]
	mov    rdi,rcx
	mov    rsi,r14
	vzeroupper
	call   QWORD PTR [rip+0x403d8]
	lea    rdx,[rip+0x3e539]
	xor    edi,edi
	xor    esi,esi
	call   QWORD PTR [rip+0x403c7]
	lea    rdx,[rip+0x3e558]
	mov    rdi,0xffffffffffffffff
	mov    rsi,r14
	vzeroupper
	call   QWORD PTR [rip+0x403ad]

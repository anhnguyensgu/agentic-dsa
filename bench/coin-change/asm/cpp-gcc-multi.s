<coin_change>:
	endbr64
	push   rbp
	mov    rbp,rsp
	push   r15
	lea    r15,[rdx+0x1]
	mov    rax,r15
	push   r14
	push   r13
	push   r12
	push   rbx
	and    rsp,0xffffffffffffffe0
	sub    rsp,0x20
	shr    rax,0x3d
	mov    QWORD PTR [rsp+0x18],rdx
	jne    <coin_change+0x329>
	test   r15,r15
	je     <coin_change+0x309>
	mov    eax,DWORD PTR [rsp+0x18]
	lea    r14,[r15*4+0x0]
	mov    r12,rdi
	mov    rdi,r14
	mov    r13,rsi
	lea    ebx,[rax+0x1]
	call   <_Znwm@plt>
	mov    rdi,rax
	lea    rax,[r14-0x4]
	mov    rdx,rax
	shr    rdx,0x2
	lea    rsi,[rdx+0x1]
	cmp    rax,0x18
	jbe    <coin_change+0x31f>
	mov    rcx,rsi
	shr    rcx,0x3
	shl    rcx,0x5
	lea    r8,[rcx+rdi*1]
	and    ecx,0x20
	vpbroadcastd ymm0,ebx
	mov    rax,rdi
	je     <coin_change+0xa0>
	lea    rax,[rdi+0x20]
	vmovdqu YMMWORD PTR [rdi],ymm0
	cmp    rax,r8
	je     <coin_change+0xb2>
	nop    DWORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rax],ymm0
	vmovdqu YMMWORD PTR [rax+0x20],ymm0
	add    rax,0x40
	cmp    rax,r8
	jne    <coin_change+0xa0>
	mov    rcx,rsi
	and    rcx,0xfffffffffffffff8
	and    esi,0x7
	lea    rax,[rdi+rcx*4]
	je     <coin_change+0x317>
	vzeroupper
	sub    rdx,rcx
	lea    rsi,[rdx+0x1]
	cmp    rdx,0x2
	jbe    <coin_change+0xf1>
	mov    rdx,rsi
	and    rdx,0xfffffffffffffffc
	vpbroadcastd xmm0,ebx
	and    esi,0x3
	vmovdqu XMMWORD PTR [rdi+rcx*4],xmm0
	lea    rax,[rax+rdx*4]
	je     <coin_change+0x10f>
	lea    rdx,[rdi+r14*1]
	lea    rcx,[rax+0x4]
	mov    DWORD PTR [rax],ebx
	cmp    rdx,rcx
	je     <coin_change+0x10f>
	lea    rcx,[rax+0x8]
	mov    DWORD PTR [rax+0x4],ebx
	cmp    rdx,rcx
	je     <coin_change+0x10f>
	mov    DWORD PTR [rax+0x8],ebx
	mov    DWORD PTR [rdi],0x0
	cmp    r15,0x1
	je     <coin_change+0x2dd>
	lea    rax,[r13-0x4]
	mov    rdx,rax
	shr    rdx,0x2
	and    rax,0xfffffffffffffffc
	add    rax,0x4
	shl    rdx,0x4
	mov    QWORD PTR [rsp+0x10],rax
	mov    QWORD PTR [rsp+0x8],r14
	lea    r9,[r12+rdx*1+0x10]
	mov    eax,0x1
	cmp    r13,0x3
	jbe    <coin_change+0x2bd>
	nop    DWORD PTR [rax+0x0]
	mov    r10,r12
	mov    edx,ebx
	mov    r8d,ebx
	mov    esi,ebx
	mov    ecx,ebx
	nop    DWORD PTR [rax+0x0]
	mov    r11d,DWORD PTR [r10]
	cmp    rax,r11
	jb     <coin_change+0x184>
	mov    r14,rax
	sub    r14,r11
	mov    r11d,DWORD PTR [rdi+r14*4]
	inc    r11d
	cmp    ecx,r11d
	cmova  ecx,r11d
	mov    r11d,DWORD PTR [r10+0x4]
	cmp    rax,r11
	jb     <coin_change+0x1a1>
	mov    r14,rax
	sub    r14,r11
	mov    r11d,DWORD PTR [rdi+r14*4]
	inc    r11d
	cmp    esi,r11d
	cmova  esi,r11d
	mov    r11d,DWORD PTR [r10+0x8]
	cmp    rax,r11
	jb     <coin_change+0x1be>
	mov    r14,rax
	sub    r14,r11
	mov    r11d,DWORD PTR [rdi+r14*4]
	inc    r11d
	cmp    r8d,r11d
	cmova  r8d,r11d
	mov    r11d,DWORD PTR [r10+0xc]
	cmp    rax,r11
	jb     <coin_change+0x1db>
	mov    r14,rax
	sub    r14,r11
	mov    r11d,DWORD PTR [rdi+r14*4]
	inc    r11d
	cmp    edx,r11d
	cmova  edx,r11d
	add    r10,0x10
	cmp    r10,r9
	jne    <coin_change+0x168>
	mov    r15,QWORD PTR [rsp+0x10]
	mov    r10,r15
	cmp    r15,r13
	jae    <coin_change+0x290>
	mov    r14d,DWORD PTR [r12+r10*4]
	lea    r11,[r10*4+0x0]
	cmp    rax,r14
	jb     <coin_change+0x21a>
	mov    r15,rax
	sub    r15,r14
	mov    r14d,DWORD PTR [rdi+r15*4]
	inc    r14d
	cmp    ecx,r14d
	cmova  ecx,r14d
	lea    r14,[r10+0x1]
	cmp    r14,r13
	jae    <coin_change+0x290>
	mov    r14d,DWORD PTR [r12+r11*1+0x4]
	cmp    rax,r14
	jb     <coin_change+0x241>
	mov    r15,rax
	sub    r15,r14
	mov    r14d,DWORD PTR [rdi+r15*4]
	inc    r14d
	cmp    ecx,r14d
	cmova  ecx,r14d
	lea    r14,[r10+0x2]
	cmp    r14,r13
	jae    <coin_change+0x290>
	mov    r14d,DWORD PTR [r12+r11*1+0x8]
	cmp    rax,r14
	jb     <coin_change+0x268>
	mov    r15,rax
	sub    r15,r14
	mov    r14d,DWORD PTR [rdi+r15*4]
	inc    r14d
	cmp    ecx,r14d
	cmova  ecx,r14d
	add    r10,0x3
	cmp    r10,r13
	jae    <coin_change+0x290>
	mov    r10d,DWORD PTR [r12+r11*1+0xc]
	cmp    rax,r10
	jb     <coin_change+0x290>
	mov    r11,rax
	sub    r11,r10
	mov    r10d,DWORD PTR [rdi+r11*4]
	inc    r10d
	cmp    ecx,r10d
	cmova  ecx,r10d
	nop
	cmp    edx,r8d
	cmova  edx,r8d
	cmp    esi,ecx
	cmova  esi,ecx
	cmp    edx,esi
	jb     <coin_change+0x2a2>
	mov    edx,esi
	mov    DWORD PTR [rdi+rax*4],edx
	lea    rdx,[rax+0x1]
	cmp    QWORD PTR [rsp+0x18],rax
	je     <coin_change+0x2d8>
	mov    rax,rdx
	cmp    r13,0x3
	ja     <coin_change+0x158>
	mov    esi,ebx
	test   r13,r13
	je     <coin_change+0x2a0>
	mov    r8d,ebx
	mov    edx,ebx
	mov    ecx,ebx
	xor    r10d,r10d
	jmp    <coin_change+0x1f5>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    r14,QWORD PTR [rsp+0x8]
	mov    rbx,QWORD PTR [rsp+0x18]
	mov    rsi,r14
	mov    edx,DWORD PTR [rdi+rbx*4]
	cmp    rbx,rdx
	mov    ebx,0xffffffff
	cmovae ebx,edx
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
	mov    rax,QWORD PTR [rsp+0x18]
	mov    DWORD PTR [rax+0x1],0x0
	ud2
	vzeroupper
	jmp    <coin_change+0x10f>
	mov    rax,rdi
	xor    ecx,ecx
	jmp    <coin_change+0xc9>
	lea    rdi,[rip+0x898]
	call   <_ZSt20__throw_length_errorPKc@plt>

<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x38
	mov    QWORD PTR [rsp+0x18],rdi
	mov    r13,rdx
	inc    r13
	js     <coin_change+0x33d>
	mov    rbx,rcx
	mov    r14,rdx
	mov    r12,rsi
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	lea    rdi,[r13*4+0x0]
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x20],xmm0
	mov    QWORD PTR [rsp],rbx
	lea    r8,[rip+0x2ecc4]
	lea    r9,[rsp+0x20]
	mov    esi,0x4
	call   <runtime::mem_alloc_bytes>
	mov    rdi,QWORD PTR [rsp+0x20]
	test   rdi,rdi
	mov    r15,r13
	cmove  r15,rdi
	test   r13,r13
	je     <coin_change+0xe4>
	lea    eax,[r14+0x1]
	cmp    r15,r14
	mov    rcx,r14
	cmovb  rcx,r15
	cmp    rcx,0x20
	jae    <coin_change+0x87>
	xor    ecx,ecx
	jmp    <coin_change+0xd0>
	inc    rcx
	mov    edx,ecx
	and    edx,0x1f
	mov    esi,0x20
	cmovne rsi,rdx
	sub    rcx,rsi
	vpbroadcastd ymm0,eax
	xor    edx,edx
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rdx*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x60],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0xb0>
	cmp    r15,rcx
	je     <coin_change+0x315>
	mov    DWORD PTR [rdi+rcx*4],eax
	inc    rcx
	cmp    r13,rcx
	jne    <coin_change+0xd0>
	test   r15,r15
	je     <coin_change+0x34c>
	mov    QWORD PTR [rsp+0x10],rbx
	mov    DWORD PTR [rdi],0x0
	test   r12,r12
	mov    r9,QWORD PTR [rsp+0x18]
	jle    <coin_change+0x270>
	lea    rdx,[rdi+0x60]
	mov    rsi,r14
	not    rsi
	xor    r10d,r10d
	vpbroadcastd ymm0,DWORD PTR [rip+0x21648]
	jmp    <coin_change+0x12c>
	xchg   ax,ax
	inc    r10
	cmp    r10,r12
	je     <coin_change+0x270>
	mov    ebp,DWORD PTR [r9+r10*4]
	cmp    r13,rbp
	jbe    <coin_change+0x120>
	cmp    r15,rbp
	mov    rbx,rbp
	cmova  rbx,r15
	mov    rcx,r14
	sub    rcx,rbp
	cmp    r15,rcx
	mov    r11,rcx
	cmovb  r11,r15
	mov    r8,rbx
	sub    r8,rbp
	cmp    r11,r8
	cmovae r11,r8
	mov    rax,rbp
	cmp    r11,0x20
	jb     <coin_change+0x226>
	lea    r9,[rdi+rbp*4]
	cmp    r15,rcx
	cmovb  rcx,r15
	cmp    rcx,r8
	cmovae rcx,r8
	lea    rax,[rdi+0x4]
	lea    rax,[rax+rcx*4]
	cmp    r9,rax
	mov    r9,QWORD PTR [rsp+0x18]
	jae    <coin_change+0x19d>
	lea    rcx,[rax+rbp*4]
	mov    rax,rbp
	cmp    rdi,rcx
	jb     <coin_change+0x226>
	inc    r11
	mov    eax,r11d
	and    eax,0x1f
	mov    ecx,0x20
	cmove  rax,rcx
	sub    r11,rax
	lea    rax,[r11+rbp*1]
	lea    rcx,[rdx+rbp*4]
	xor    r8d,r8d
	nop    DWORD PTR [rax]
	vpaddd ymm1,ymm0,YMMWORD PTR [rdx+r8*4-0x60]
	vpaddd ymm2,ymm0,YMMWORD PTR [rdx+r8*4-0x40]
	vpaddd ymm3,ymm0,YMMWORD PTR [rdx+r8*4-0x20]
	vpaddd ymm4,ymm0,YMMWORD PTR [rdx+r8*4]
	vpcmpltud k1,ymm1,YMMWORD PTR [rcx+r8*4-0x60]
	vpcmpltud k2,ymm2,YMMWORD PTR [rcx+r8*4-0x40]
	vpcmpltud k3,ymm3,YMMWORD PTR [rcx+r8*4-0x20]
	vpcmpltud k4,ymm4,YMMWORD PTR [rcx+r8*4]
	vmovdqu32 YMMWORD PTR [rcx+r8*4-0x60]{k1},ymm1
	vmovdqu32 YMMWORD PTR [rcx+r8*4-0x40]{k2},ymm2
	vmovdqu32 YMMWORD PTR [rcx+r8*4-0x20]{k3},ymm3
	vmovdqu32 YMMWORD PTR [rcx+r8*4]{k4},ymm4
	add    r8,0x20
	cmp    r11,r8
	jne    <coin_change+0x1c0>
	mov    r11,rax
	neg    r11
	lea    rcx,[rax*4+0x0]
	mov    r8,rbx
	neg    r8
	sub    rax,rbp
	jmp    <coin_change+0x253>
	nop
	dec    r11
	add    rcx,0x4
	inc    rax
	cmp    rsi,r11
	je     <coin_change+0x120>
	cmp    rax,r15
	jae    <coin_change+0x2bb>
	cmp    r8,r11
	je     <coin_change+0x2e8>
	mov    ebp,DWORD PTR [rdi+rax*4]
	inc    ebp
	cmp    ebp,DWORD PTR [rdi+rcx*1]
	jae    <coin_change+0x240>
	mov    DWORD PTR [rdi+rcx*1],ebp
	jmp    <coin_change+0x240>
	cmp    r14,r15
	jae    <coin_change+0x374>
	mov    eax,DWORD PTR [rdi+r14*4]
	cmp    r14,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    r9,QWORD PTR [rsp+0x10]
	mov    rdx,QWORD PTR [r9]
	mov    rcx,QWORD PTR [r9+0x8]
	shl    r15,0x2
	lea    r8,[rip+0x2eaa1]
	mov    rsi,r15
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
	mov    rcx,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rcx
	lea    rdi,[rip+0x292be]
	mov    esi,0x39
	mov    edx,0x1a
	mov    ecx,0xc
	mov    r8,rax
	mov    r9,r15
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x29291]
	mov    esi,0x39
	mov    edx,0x1b
	mov    ecx,0xe
	mov    r8,rbx
	mov    r9,r13
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x29269]
	mov    esi,0x39
	mov    edx,0x14
	mov    ecx,0x6
	mov    r8,r15
	mov    r9,r15
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	lea    rdi,[rip+0x2e9cc]
	mov    rsi,r13
	call   <runtime::make_slice_error_loc.handle_error-13711>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x29232]
	mov    esi,0x39
	mov    edx,0x16
	mov    ecx,0x5
	xor    r8d,r8d
	xor    r9d,r9d
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x29205]
	mov    esi,0x39
	mov    edx,0x20
	mov    ecx,0xd
	mov    r8,r14
	mov    r9,r15
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>

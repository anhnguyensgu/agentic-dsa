<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x28
	mov    r14,rdx
	inc    r14
	js     <coin_change+0x296>
	mov    rbx,rcx
	mov    r15,rdx
	mov    r13,rsi
	mov    rbp,rdi
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	lea    r12,[r14*4+0x0]
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x10],xmm0
	mov    QWORD PTR [rsp],rbx
	lea    r8,[rip+0x2ebb6]
	lea    r9,[rsp+0x10]
	mov    esi,0x4
	mov    rdi,r12
	call   <runtime::mem_alloc_bytes>
	mov    rdi,QWORD PTR [rsp+0x10]
	test   rdi,rdi
	mov    r9,r14
	cmove  r9,rdi
	test   r14,r14
	je     <coin_change+0x2a5>
	lea    eax,[r15+0x1]
	cmp    r9,r15
	mov    rcx,r15
	cmovb  rcx,r9
	cmp    rcx,0x20
	jae    <coin_change+0x8c>
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
	nop    DWORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rdx*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x60],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0xb0>
	cmp    r9,rcx
	je     <coin_change+0x24c>
	mov    DWORD PTR [rdi+rcx*4],eax
	inc    rcx
	cmp    r14,rcx
	jne    <coin_change+0xd0>
	mov    DWORD PTR [rdi],0x0
	test   r15,r15
	je     <coin_change+0x1ee>
	test   r13,r13
	jle    <coin_change+0x15a>
	mov    ecx,0x1
	nop    DWORD PTR [rax]
	xor    esi,esi
	mov    edx,eax
	jmp    <coin_change+0x118>
	cs nop WORD PTR [rax+rax*1+0x0]
	inc    rsi
	cmp    r13,rsi
	je     <coin_change+0x140>
	mov    r10d,DWORD PTR [rbp+rsi*4+0x0]
	mov    r8,rcx
	sub    r8,r10
	jb     <coin_change+0x110>
	cmp    r8,r9
	jae    <coin_change+0x22a>
	mov    r8d,DWORD PTR [rdi+r8*4]
	inc    r8d
	cmp    r8d,edx
	cmovb  edx,r8d
	jmp    <coin_change+0x110>
	xchg   ax,ax
	cmp    rcx,r9
	je     <coin_change+0x271>
	mov    DWORD PTR [rdi+rcx*4],edx
	cmp    rcx,r15
	lea    rcx,[rcx+0x1]
	jne    <coin_change+0x100>
	jmp    <coin_change+0x1e4>
	lea    rdx,[r15-0x1]
	cmp    r15,rdx
	cmovb  rdx,r15
	inc    rdx
	mov    ecx,0x1
	cmp    rdx,0x20
	jbe    <coin_change+0x1d0>
	mov    ecx,edx
	and    ecx,0x1f
	mov    r8d,0x20
	cmovne r8,rcx
	mov    rsi,rdx
	sub    rsi,r8
	neg    r8
	lea    rcx,[rdx+r8*1+0x1]
	vpbroadcastd ymm0,eax
	xor    edx,edx
	nop    DWORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x64],ymm0
	add    rdx,0x20
	cmp    rsi,rdx
	jne    <coin_change+0x1a0>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	cmp    r14,rcx
	je     <coin_change+0x271>
	mov    DWORD PTR [rdi+rcx*4],eax
	inc    rcx
	cmp    r14,rcx
	jne    <coin_change+0x1d0>
	cmp    r15,0xffffffffffffffff
	je     <coin_change+0x2ca>
	mov    eax,DWORD PTR [rdi+r15*4]
	cmp    r15,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    rdx,QWORD PTR [rbx]
	mov    rcx,QWORD PTR [rbx+0x8]
	lea    r8,[rip+0x2ea25]
	mov    rsi,r12
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
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x292a3]
	mov    esi,0x3d
	mov    edx,0x1f
	mov    ecx,0xd
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x29281]
	mov    esi,0x3d
	mov    edx,0x17
	mov    ecx,0x6
	mov    r8,r9
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x2925c]
	mov    esi,0x3d
	mov    edx,0x25
	mov    ecx,0x6
	mov    r8,r9
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	lea    rdi,[rip+0x2e963]
	mov    rsi,r14
	call   <runtime::make_slice_error_loc.handle_error-13711>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x29228]
	mov    esi,0x3d
	mov    edx,0x19
	mov    ecx,0x5
	xor    r8d,r8d
	xor    r9d,r9d
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    QWORD PTR [rsp],rbx
	lea    rdi,[rip+0x29203]
	mov    esi,0x3d
	mov    edx,0x27
	mov    ecx,0xf
	mov    r8,0xffffffffffffffff
	mov    r9,r14
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>

<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x38
	mov    r14,rdx
	inc    r14
	js     <coin_change+0x585>
	mov    rax,rcx
	mov    r15,rdx
	mov    r13,rsi
	mov    rbp,rdi
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	lea    rdi,[r14*4+0x0]
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x20],xmm0
	mov    QWORD PTR [rsp+0x10],rax
	mov    QWORD PTR [rsp],rax
	lea    r8,[rip+0x2eca1]
	lea    r9,[rsp+0x20]
	mov    esi,0x4
	mov    QWORD PTR [rsp+0x18],rdi
	call   <runtime::mem_alloc_bytes>
	mov    rdi,QWORD PTR [rsp+0x20]
	test   rdi,rdi
	mov    r9,r14
	cmove  r9,rdi
	test   r14,r14
	je     <coin_change+0x594>
	lea    r12d,[r15+0x1]
	cmp    r9,r15
	mov    rax,r15
	cmovb  rax,r9
	cmp    rax,0x20
	jae    <coin_change+0x93>
	xor    eax,eax
	jmp    <coin_change+0xd0>
	inc    rax
	mov    ecx,eax
	and    ecx,0x1f
	mov    edx,0x20
	cmovne rdx,rcx
	sub    rax,rdx
	vpbroadcastd ymm0,r12d
	xor    ecx,ecx
	nop
	vmovdqu YMMWORD PTR [rdi+rcx*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x60],ymm0
	add    rcx,0x20
	cmp    rax,rcx
	jne    <coin_change+0xb0>
	cmp    r9,rax
	je     <coin_change+0x531>
	mov    DWORD PTR [rdi+rax*4],r12d
	inc    rax
	cmp    r14,rax
	jne    <coin_change+0xd0>
	mov    DWORD PTR [rdi],0x0
	test   r15,r15
	je     <coin_change+0x3ef>
	cmp    r13,0x4
	jae    <coin_change+0x1ea>
	test   r13,r13
	je     <coin_change+0x35d>
	mov    rax,r15
	neg    rax
	mov    ecx,0x1
	jmp    <coin_change+0x135>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi+rcx*4],edx
	lea    rdx,[rax+rcx*1+0x1]
	inc    rcx
	cmp    rdx,0x1
	je     <coin_change+0x3e5>
	mov    esi,DWORD PTR [rbp+0x0]
	mov    r8,rcx
	mov    edx,r12d
	sub    r8,rsi
	jb     <coin_change+0x163>
	cmp    r8,r9
	jae    <coin_change+0x50a>
	shl    rsi,0x2
	mov    rdx,rdi
	sub    rdx,rsi
	mov    edx,DWORD PTR [rdx+rcx*4]
	inc    edx
	cmp    edx,r12d
	jb     <coin_change+0x163>
	mov    edx,r12d
	cmp    r13,0x1
	je     <coin_change+0x1d0>
	mov    esi,DWORD PTR [rbp+0x4]
	mov    r8,rcx
	sub    r8,rsi
	jb     <coin_change+0x192>
	cmp    r8,r9
	jae    <coin_change+0x50a>
	shl    rsi,0x2
	mov    r8,rdi
	sub    r8,rsi
	mov    esi,DWORD PTR [r8+rcx*4]
	inc    esi
	cmp    esi,edx
	cmovb  edx,esi
	cmp    r13,0x2
	je     <coin_change+0x1d0>
	mov    esi,DWORD PTR [rbp+0x8]
	mov    r8,rcx
	sub    r8,rsi
	jb     <coin_change+0x1d0>
	cmp    r8,r9
	jae    <coin_change+0x50a>
	shl    rsi,0x2
	mov    r8,rdi
	sub    r8,rsi
	mov    esi,DWORD PTR [r8+rcx*4]
	inc    esi
	cmp    esi,edx
	cmovb  edx,esi
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	cmp    r9,rcx
	je     <coin_change+0x55b>
	cmp    edx,r12d
	jb     <coin_change+0x120>
	mov    edx,r12d
	jmp    <coin_change+0x120>
	mov    edx,0x1
	nop
	mov    r8d,0x2
	mov    esi,r12d
	mov    r11d,r12d
	mov    r10d,r12d
	mov    ecx,r12d
	jmp    <coin_change+0x22e>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,esi
	cmovb  esi,eax
	lea    rax,[r8+0x4]
	add    r8,0x6
	cmp    r8,r13
	mov    r8,rax
	ja     <coin_change+0x2f0>
	lea    rax,[r8-0x2]
	cmp    rax,r13
	jae    <coin_change+0x459>
	mov    ebx,DWORD PTR [rbp+r8*4-0x8]
	mov    rax,rdx
	sub    rax,rbx
	jb     <coin_change+0x25b>
	cmp    rax,r9
	jae    <coin_change+0x42f>
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,ecx
	cmovb  ecx,eax
	lea    rax,[r8-0x1]
	cmp    rax,r13
	jae    <coin_change+0x486>
	mov    ebx,DWORD PTR [rbp+r8*4-0x4]
	mov    rax,rdx
	sub    rax,rbx
	jb     <coin_change+0x28a>
	cmp    rax,r9
	jae    <coin_change+0x42f>
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,r10d
	cmovb  r10d,eax
	cmp    r8,r13
	jae    <coin_change+0x4e0>
	mov    ebx,DWORD PTR [rbp+r8*4+0x0]
	mov    rax,rdx
	sub    rax,rbx
	jb     <coin_change+0x2b5>
	cmp    rax,r9
	jae    <coin_change+0x42f>
	mov    eax,DWORD PTR [rdi+rax*4]
	inc    eax
	cmp    eax,r11d
	cmovb  r11d,eax
	lea    rax,[r8+0x1]
	cmp    rax,r13
	jae    <coin_change+0x4b3>
	mov    ebx,DWORD PTR [rbp+r8*4+0x4]
	mov    rax,rdx
	sub    rax,rbx
	jb     <coin_change+0x21a>
	cmp    rax,r9
	jb     <coin_change+0x210>
	jmp    <coin_change+0x42f>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	add    rax,0xfffffffffffffffe
	cmp    rax,r13
	jb     <coin_change+0x338>
	cmp    rdx,r9
	je     <coin_change+0x55b>
	cmp    ecx,r10d
	cmovb  r10d,ecx
	cmp    r11d,esi
	cmovb  esi,r11d
	cmp    r10d,esi
	cmovb  esi,r10d
	mov    DWORD PTR [rdi+rdx*4],esi
	cmp    rdx,r15
	lea    rdx,[rdx+0x1]
	jne    <coin_change+0x1f0>
	jmp    <coin_change+0x3e5>
	nop    DWORD PTR [rax+0x0]
	inc    rax
	cmp    r13,rax
	je     <coin_change+0x2f9>
	mov    ebx,DWORD PTR [rbp+rax*4+0x0]
	mov    r8,rdx
	sub    r8,rbx
	jb     <coin_change+0x330>
	cmp    r8,r9
	jae    <coin_change+0x50a>
	mov    r8d,DWORD PTR [rdi+r8*4]
	inc    r8d
	cmp    r8d,ecx
	cmovb  ecx,r8d
	jmp    <coin_change+0x330>
	lea    rcx,[r15-0x1]
	cmp    r15,rcx
	cmovb  rcx,r15
	inc    rcx
	mov    eax,0x1
	cmp    rcx,0x20
	jbe    <coin_change+0x3d0>
	mov    eax,ecx
	and    eax,0x1f
	mov    esi,0x20
	cmovne rsi,rax
	mov    rdx,rcx
	sub    rdx,rsi
	neg    rsi
	lea    rax,[rcx+rsi*1+0x1]
	vpbroadcastd ymm0,r12d
	xor    ecx,ecx
	nop    WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rdi+rcx*4+0x64],ymm0
	add    rcx,0x20
	cmp    rdx,rcx
	jne    <coin_change+0x3a0>
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	cmp    r14,rax
	je     <coin_change+0x55b>
	mov    DWORD PTR [rdi+rax*4],r12d
	inc    rax
	cmp    r14,rax
	jne    <coin_change+0x3d0>
	cmp    r15,0xffffffffffffffff
	je     <coin_change+0x5be>
	mov    eax,DWORD PTR [rdi+r15*4]
	cmp    r15,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    r9,QWORD PTR [rsp+0x10]
	mov    rdx,QWORD PTR [r9]
	mov    rcx,QWORD PTR [r9+0x8]
	lea    r8,[rip+0x2e90f]
	mov    rsi,QWORD PTR [rsp+0x18]
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
	lea    rdi,[rip+0x29150]
	mov    esi,0x3f
	mov    edx,0x15
	mov    ecx,0xb
	mov    r8,rax
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rcx,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rcx
	lea    rdi,[rip+0x29126]
	mov    esi,0x3f
	mov    edx,0x2c
	mov    ecx,0x1c
	mov    r8,rax
	mov    r9,r13
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rcx,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rcx
	lea    rdi,[rip+0x290f9]
	mov    esi,0x3f
	mov    edx,0x2d
	mov    ecx,0x1c
	mov    r8,rax
	mov    r9,r13
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rcx,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rcx
	lea    rdi,[rip+0x290cc]
	mov    esi,0x3f
	mov    edx,0x2f
	mov    ecx,0x1c
	mov    r8,rax
	mov    r9,r13
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x2909f]
	mov    esi,0x3f
	mov    edx,0x2e
	mov    ecx,0x1c
	mov    r9,r13
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x29075]
	mov    esi,0x3f
	mov    edx,0x15
	mov    ecx,0xb
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x2904e]
	mov    esi,0x3f
	mov    edx,0x24
	mov    ecx,0x6
	mov    r8,r9
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x29024]
	mov    esi,0x3f
	mov    edx,0x34
	mov    ecx,0x6
	mov    r8,r9
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	lea    rdi,[rip+0x2e764]
	mov    rsi,r14
	call   <runtime::make_slice_error_loc.handle_error-13711>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x28feb]
	mov    esi,0x3f
	mov    edx,0x26
	mov    ecx,0x5
	xor    r8d,r8d
	xor    r9d,r9d
	call   <runtime::bounds_check_error_with_context.handle_error-1271>
	mov    rax,QWORD PTR [rsp+0x10]
	mov    QWORD PTR [rsp],rax
	lea    rdi,[rip+0x28fc1]
	mov    esi,0x3f
	mov    edx,0x36
	mov    ecx,0xf
	mov    r8,0xffffffffffffffff
	mov    r9,r14
	vzeroupper
	call   <runtime::bounds_check_error_with_context.handle_error-1271>

<coin_change>:
	push   rbp
	mov    rbp,rsp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x18
	mov    rbx,rdx
	mov    r14,rsi
	mov    r15,rdi
	lea    r12,[rdx*4+0x4]
	mov    rdi,r12
	call   <malloc@plt>
	test   rax,rax
	je     <coin_change+0x443>
	lea    r13d,[rbx+0x1]
	test   r12,r12
	je     <coin_change+0xa8>
	mov    dl,0x3e
	bzhi   rsi,rbx,rdx
	mov    edi,ebx
	not    edi
	mov    rdx,rax
	test   dil,0x7
	je     <coin_change+0x6c>
	lea    edi,[rbx+0x1]
	and    edi,0x7
	mov    rdx,rax
	nop    DWORD PTR [rax+0x0]
	mov    DWORD PTR [rdx],r13d
	add    rdx,0x4
	dec    rdi
	jne    <coin_change+0x60>
	cmp    rsi,0x7
	jb     <coin_change+0xa8>
	add    r12,rax
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdx],r13d
	mov    DWORD PTR [rdx+0x4],r13d
	mov    DWORD PTR [rdx+0x8],r13d
	mov    DWORD PTR [rdx+0xc],r13d
	mov    DWORD PTR [rdx+0x10],r13d
	mov    DWORD PTR [rdx+0x14],r13d
	mov    DWORD PTR [rdx+0x18],r13d
	mov    DWORD PTR [rdx+0x1c],r13d
	add    rdx,0x20
	cmp    rdx,r12
	jne    <coin_change+0x80>
	mov    DWORD PTR [rax],0x0
	test   rbx,rbx
	je     <coin_change+0x41c>
	cmp    r14,0x4
	jae    <coin_change+0x15a>
	test   r14,r14
	je     <coin_change+0x3b5>
	mov    edx,DWORD PTR [r15]
	mov    esi,0x1
	jmp    <coin_change+0xf0>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rax+rsi*4],edi
	cmp    rsi,rbx
	lea    rsi,[rsi+0x1]
	je     <coin_change+0x41c>
	mov    r8,rsi
	mov    edi,r13d
	sub    r8,rdx
	jb     <coin_change+0x108>
	mov    edi,DWORD PTR [rax+r8*4]
	inc    edi
	cmp    edi,r13d
	cmovae edi,r13d
	cmp    r14,0x1
	je     <coin_change+0x150>
	mov    r9d,DWORD PTR [r15+0x4]
	mov    r8,rsi
	sub    r8,r9
	jb     <coin_change+0x128>
	mov    r8d,DWORD PTR [rax+r8*4]
	inc    r8d
	cmp    r8d,edi
	cmovb  edi,r8d
	cmp    r14,0x2
	je     <coin_change+0x150>
	mov    r9d,DWORD PTR [r15+0x8]
	mov    r8,rsi
	sub    r8,r9
	jb     <coin_change+0x150>
	mov    r8d,DWORD PTR [rax+r8*4]
	inc    r8d
	cmp    r8d,edi
	cmovb  edi,r8d
	nop    DWORD PTR [rax+rax*1+0x0]
	cmp    edi,r13d
	jb     <coin_change+0xe0>
	mov    edi,r13d
	jmp    <coin_change+0xe0>
	mov    edi,r14d
	and    edi,0x3
	mov    QWORD PTR [rbp-0x40],rdi
	neg    rdi
	mov    r8d,0x1
	mov    QWORD PTR [rbp-0x38],rbx
	mov    DWORD PTR [rbp-0x2c],r13d
	jmp    <coin_change+0x1ae>
	nop    WORD PTR [rax+rax*1+0x0]
	mov    rbx,QWORD PTR [rbp-0x38]
	mov    r13d,DWORD PTR [rbp-0x2c]
	cmp    r12d,r10d
	cmovb  r10d,r12d
	cmp    r11d,r9d
	cmovb  r9d,r11d
	cmp    r10d,r9d
	cmovb  r9d,r10d
	mov    DWORD PTR [rax+r8*4],r9d
	cmp    r8,rbx
	lea    r8,[r8+0x1]
	je     <coin_change+0x41c>
	lea    rbx,[r15+0x10]
	xor    esi,esi
	mov    r9d,r13d
	mov    r11d,r13d
	mov    r10d,r13d
	mov    r12d,r13d
	jmp    <coin_change+0x1e8>
	data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	lea    r13,[rsi+0x4]
	add    rsi,0x8
	lea    rbx,[rdx+0x10]
	cmp    rsi,r14
	mov    rsi,r13
	ja     <coin_change+0x280>
	mov    rdx,rbx
	mov    ecx,DWORD PTR [r15+rsi*4]
	mov    rbx,r8
	sub    rbx,rcx
	jae    <coin_change+0x220>
	mov    ecx,DWORD PTR [r15+rsi*4+0x4]
	mov    rbx,r8
	sub    rbx,rcx
	jae    <coin_change+0x239>
	mov    ecx,DWORD PTR [r15+rsi*4+0x8]
	mov    rbx,r8
	sub    rbx,rcx
	jae    <coin_change+0x252>
	mov    ecx,DWORD PTR [r15+rsi*4+0xc]
	mov    rbx,r8
	sub    rbx,rcx
	jb     <coin_change+0x1d0>
	jmp    <coin_change+0x26f>
	mov    ecx,DWORD PTR [rax+rbx*4]
	inc    ecx
	cmp    ecx,r12d
	cmovb  r12d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0x4]
	mov    rbx,r8
	sub    rbx,rcx
	jb     <coin_change+0x204>
	mov    ecx,DWORD PTR [rax+rbx*4]
	inc    ecx
	cmp    ecx,r10d
	cmovb  r10d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0x8]
	mov    rbx,r8
	sub    rbx,rcx
	jb     <coin_change+0x211>
	mov    ecx,DWORD PTR [rax+rbx*4]
	inc    ecx
	cmp    ecx,r11d
	cmovb  r11d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0xc]
	mov    rbx,r8
	sub    rbx,rcx
	jb     <coin_change+0x1d0>
	mov    ecx,DWORD PTR [rax+rbx*4]
	inc    ecx
	cmp    ecx,r9d
	cmovb  r9d,ecx
	jmp    <coin_change+0x1d0>
	cmp    r14,r13
	jbe    <coin_change+0x180>
	cmp    QWORD PTR [rbp-0x40],0x0
	je     <coin_change+0x2d8>
	xor    ebx,ebx
	jmp    <coin_change+0x2ac>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	dec    rbx
	add    rdx,0x4
	cmp    rdi,rbx
	je     <coin_change+0x2d0>
	mov    ecx,DWORD PTR [rdx]
	mov    rsi,r8
	sub    rsi,rcx
	jb     <coin_change+0x2a0>
	mov    ecx,DWORD PTR [rax+rsi*4]
	inc    ecx
	cmp    ecx,r12d
	cmovb  r12d,ecx
	jmp    <coin_change+0x2a0>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    rsi,r13
	sub    rsi,rbx
	jmp    <coin_change+0x2db>
	mov    rsi,r13
	not    r13
	add    r13,r14
	cmp    r13,0x3
	mov    rbx,QWORD PTR [rbp-0x38]
	mov    r13d,DWORD PTR [rbp-0x2c]
	jae    <coin_change+0x310>
	jmp    <coin_change+0x188>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    r12d,edx
	add    rsi,0x4
	cmp    r14,rsi
	je     <coin_change+0x188>
	mov    ecx,DWORD PTR [r15+rsi*4]
	mov    rdx,r8
	sub    rdx,rcx
	jae    <coin_change+0x350>
	mov    ecx,DWORD PTR [r15+rsi*4+0x4]
	mov    rdx,r8
	sub    rdx,rcx
	jae    <coin_change+0x369>
	mov    ecx,DWORD PTR [r15+rsi*4+0x8]
	mov    rdx,r8
	sub    rdx,rcx
	jae    <coin_change+0x382>
	mov    ecx,DWORD PTR [r15+rsi*4+0xc]
	mov    rdx,r8
	sub    rdx,rcx
	jb     <coin_change+0x303>
	jmp    <coin_change+0x39f>
	data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    ecx,DWORD PTR [rax+rdx*4]
	inc    ecx
	cmp    ecx,r12d
	cmovb  r12d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0x4]
	mov    rdx,r8
	sub    rdx,rcx
	jb     <coin_change+0x329>
	mov    ecx,DWORD PTR [rax+rdx*4]
	inc    ecx
	cmp    ecx,r12d
	cmovb  r12d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0x8]
	mov    rdx,r8
	sub    rdx,rcx
	jb     <coin_change+0x336>
	mov    ecx,DWORD PTR [rax+rdx*4]
	inc    ecx
	cmp    ecx,r12d
	cmovb  r12d,ecx
	mov    ecx,DWORD PTR [r15+rsi*4+0xc]
	mov    rdx,r8
	sub    rdx,rcx
	jb     <coin_change+0x303>
	mov    edx,DWORD PTR [rax+rdx*4]
	inc    edx
	cmp    edx,r12d
	jb     <coin_change+0x300>
	mov    edx,r12d
	jmp    <coin_change+0x300>
	mov    edx,ebx
	and    edx,0x7
	mov    esi,0x1
	cmp    rbx,0x8
	jb     <coin_change+0x409>
	mov    rdi,rbx
	and    rdi,0xfffffffffffffff8
	xor    esi,esi
	xchg   ax,ax
	mov    DWORD PTR [rax+rsi*4+0x4],r13d
	mov    DWORD PTR [rax+rsi*4+0x8],r13d
	mov    DWORD PTR [rax+rsi*4+0xc],r13d
	mov    DWORD PTR [rax+rsi*4+0x10],r13d
	mov    DWORD PTR [rax+rsi*4+0x14],r13d
	mov    DWORD PTR [rax+rsi*4+0x18],r13d
	mov    DWORD PTR [rax+rsi*4+0x1c],r13d
	mov    DWORD PTR [rax+rsi*4+0x20],r13d
	add    rsi,0x8
	cmp    rdi,rsi
	jne    <coin_change+0x3d0>
	test   rdx,rdx
	je     <coin_change+0x41c>
	inc    rsi
	lea    rsi,[rax+rsi*4]
	xor    edi,edi
	nop
	mov    DWORD PTR [rsi+rdi*4],r13d
	inc    rdi
	cmp    rdx,rdi
	jne    <coin_change+0x410>
	mov    ecx,DWORD PTR [rax+rbx*4]
	cmp    rbx,rcx
	mov    ebx,0xffffffff
	cmovae ebx,ecx
	mov    rdi,rax
	call   <free@plt>
	mov    eax,ebx
	add    rsp,0x18
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	ud2

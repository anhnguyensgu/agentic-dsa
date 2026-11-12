<coin_change>:
	push   rbp
	push   r15
	push   r14
	push   r13
	push   r12
	push   rbx
	sub    rsp,0x78
	mov    rax,rcx
	mov    r15,rdx
	mov    r13,rsi
	mov    r12,rdi
	lea    rdi,[rdx+0x1]
	mov    rdx,QWORD PTR [rcx]
	mov    rcx,QWORD PTR [rcx+0x8]
	shl    rdi,0x2
	vpxor  xmm0,xmm0,xmm0
	vmovdqa XMMWORD PTR [rsp+0x60],xmm0
	mov    QWORD PTR [rsp+0x50],rax
	mov    QWORD PTR [rsp],rax
	lea    r8,[rip+0x2c34d]
	lea    r9,[rsp+0x60]
	mov    esi,0x4
	mov    QWORD PTR [rsp+0x48],rdi
	call   <runtime::mem_alloc_bytes>
	mov    rax,r15
	mov    rdi,QWORD PTR [rsp+0x60]
	inc    rax
	jne    <coin_change+0x6f>
	mov    DWORD PTR [rdi],0x0
	jmp    <coin_change+0xa9c>
	lea    r14d,[r15+0x1]
	cmp    rax,0x4
	jae    <coin_change+0x7d>
	xor    ecx,ecx
	jmp    <coin_change+0xf0>
	cmp    rax,0x20
	jae    <coin_change+0x87>
	xor    ecx,ecx
	jmp    <coin_change+0xc9>
	mov    rcx,rax
	and    rcx,0xffffffffffffffe0
	vpbroadcastd ymm0,r14d
	xor    edx,edx
	cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rdx*4],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x20],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x40],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x60],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0xa0>
	cmp    rax,rcx
	je     <coin_change+0xfc>
	test   al,0x1c
	je     <coin_change+0xf0>
	mov    rdx,rcx
	mov    rcx,rax
	and    rcx,0xfffffffffffffffc
	vpbroadcastd xmm0,r14d
	nop    DWORD PTR [rax+0x0]
	vmovdqu XMMWORD PTR [rdi+rdx*4],xmm0
	add    rdx,0x4
	cmp    rcx,rdx
	jne    <coin_change+0xe0>
	jmp    <coin_change+0xf7>
	mov    DWORD PTR [rdi+rcx*4],r14d
	inc    rcx
	cmp    rax,rcx
	jne    <coin_change+0xf0>
	mov    DWORD PTR [rdi],0x0
	test   r15,r15
	je     <coin_change+0xa9c>
	cmp    r13,0x4
	jae    <coin_change+0x237>
	test   r13,r13
	je     <coin_change+0x966>
	dec    r13
	vpbroadcastq ymm0,r13
	mov    eax,0x1
	cmp    r15,0x1
	je     <coin_change+0x990>
	mov    rcx,r15
	and    rcx,0xfffffffffffffffe
	vpbroadcastd xmm1,r14d
	vpcmpnltuq k1,ymm0,YMMWORD PTR [rip+0x26832]
	vpcmpeqd xmm2,xmm2,xmm2
	jmp    <coin_change+0x171>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi+rax*4+0x4],esi
	add    rax,0x2
	cmp    rdx,rcx
	je     <coin_change+0x986>
	vmovdqu32 xmm3{k1}{z},XMMWORD PTR [r12]
	vpbroadcastq ymm4,rax
	vpmovzxdq ymm3,xmm3
	vpcmpnltuq k2{k1},ymm4,ymm3
	vpsubq ymm3,ymm4,ymm3
	vpxor  xmm4,xmm4,xmm4
	kmovq  k3,k2
	vpgatherqd xmm4{k3},DWORD PTR [rdi+ymm3*4]
	vpsubd xmm3,xmm4,xmm2
	vmovdqa xmm4,xmm1
	vpminud xmm4{k2},xmm3,xmm1
	vpshufd xmm3,xmm4,0xee
	vpminud xmm3,xmm4,xmm3
	vpshufd xmm4,xmm3,0x55
	vpminud xmm3,xmm3,xmm4
	vmovd  edx,xmm3
	cmp    edx,r14d
	jb     <coin_change+0x1cc>
	mov    edx,r14d
	mov    DWORD PTR [rdi+rax*4],edx
	lea    rdx,[rax+0x1]
	vmovdqu32 xmm3{k1}{z},XMMWORD PTR [r12]
	vpbroadcastq ymm4,rdx
	vpmovzxdq ymm3,xmm3
	vpcmpnltuq k2{k1},ymm4,ymm3
	vpsubq ymm3,ymm4,ymm3
	vpxor  xmm4,xmm4,xmm4
	kmovq  k3,k2
	vpgatherqd xmm4{k3},DWORD PTR [rdi+ymm3*4]
	vpsubd xmm3,xmm4,xmm2
	vmovdqa xmm4,xmm1
	vpminud xmm4{k2},xmm3,xmm1
	vpshufd xmm3,xmm4,0xee
	vpminud xmm3,xmm4,xmm3
	vpshufd xmm4,xmm3,0x55
	vpminud xmm3,xmm3,xmm4
	vmovd  esi,xmm3
	cmp    esi,r14d
	jb     <coin_change+0x160>
	mov    esi,r14d
	jmp    <coin_change+0x160>
	xor    esi,esi
	mov    rax,r13
	add    rax,0xfffffffffffffffc
	mov    eax,0x0
	adc    rax,0xffffffffffffffff
	mov    rdx,r13
	add    rdx,0xfffffffffffffffc
	adc    rsi,0x3
	mov    rcx,rax
	shld   rcx,rdx,0x3e
	mov    QWORD PTR [rsp+0x58],rdx
	shld   rsi,rdx,0x3e
	inc    rsi
	lea    rdx,[rcx*4+0x0]
	shr    rcx,0x3e
	setne  cl
	cmp    rdx,0xfffffffffffffff8
	setae  dl
	cmp    rax,0x4
	setae  al
	or     al,dl
	or     al,cl
	mov    BYTE PTR [rsp+0x17],al
	mov    QWORD PTR [rsp+0x20],rsi
	and    rsi,0xfffffffffffffff0
	lea    rax,[rsi*4+0x0]
	mov    QWORD PTR [rsp+0x38],rax
	lea    rax,[rsi*4+0x4]
	mov    QWORD PTR [rsp+0x30],rax
	vpbroadcastd ymm0,r14d
	mov    QWORD PTR [rsp+0x18],rsi
	lea    rax,[rsi-0x1]
	mov    QWORD PTR [rsp+0x28],rax
	mov    r10d,0x1
	vpcmpeqd ymm1,ymm1,ymm1
	vmovdqa ymm2,YMMWORD PTR [rip+0x26629]
	vmovdqa ymm3,YMMWORD PTR [rip+0x26641]
	vmovdqa ymm4,YMMWORD PTR [rip+0x26659]
	vmovdqa ymm5,YMMWORD PTR [rip+0x26671]
	mov    QWORD PTR [rsp+0x40],r15
	jmp    <coin_change+0x324>
	cs nop WORD PTR [rax+rax*1+0x0]
	cmp    r9d,ebp
	cmovb  ebp,r9d
	cmp    r11d,eax
	cmovb  eax,r11d
	cmp    ebp,eax
	cmovb  eax,ebp
	mov    DWORD PTR [rdi+r10*4],eax
	cmp    r10,r15
	lea    r10,[r10+0x1]
	je     <coin_change+0xa9c>
	mov    edx,0x4
	cmp    QWORD PTR [rsp+0x20],0x10
	jb     <coin_change+0x33c>
	cmp    BYTE PTR [rsp+0x17],0x0
	je     <coin_change+0x450>
	xor    ecx,ecx
	xor    esi,esi
	mov    eax,r14d
	mov    r11d,r14d
	mov    ebp,r14d
	mov    r9d,r14d
	dec    rcx
	mov    rbx,rcx
	jmp    <coin_change+0x373>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	lea    rdx,[r8+0x4]
	inc    rbx
	mov    rsi,r8
	cmp    rdx,r13
	ja     <coin_change+0x410>
	mov    r8,rdx
	mov    edx,DWORD PTR [r12+rsi*4]
	mov    rcx,r10
	sub    rcx,rdx
	jae    <coin_change+0x3b0>
	mov    edx,DWORD PTR [r12+rsi*4+0x4]
	mov    rcx,r10
	sub    rcx,rdx
	jae    <coin_change+0x3c9>
	mov    edx,DWORD PTR [r12+rsi*4+0x8]
	mov    rcx,r10
	sub    rcx,rdx
	jae    <coin_change+0x3e0>
	mov    edx,DWORD PTR [r12+rsi*4+0xc]
	mov    rcx,r10
	sub    rcx,rdx
	jb     <coin_change+0x360>
	jmp    <coin_change+0x3fd>
	nop    DWORD PTR [rax+rax*1+0x0]
	mov    ecx,DWORD PTR [rdi+rcx*4]
	inc    ecx
	cmp    ecx,r9d
	cmovb  r9d,ecx
	mov    edx,DWORD PTR [r12+rsi*4+0x4]
	mov    rcx,r10
	sub    rcx,rdx
	jb     <coin_change+0x38f>
	mov    ecx,DWORD PTR [rdi+rcx*4]
	inc    ecx
	cmp    ecx,ebp
	cmovb  ebp,ecx
	mov    edx,DWORD PTR [r12+rsi*4+0x8]
	mov    rcx,r10
	sub    rcx,rdx
	jb     <coin_change+0x39c>
	mov    ecx,DWORD PTR [rdi+rcx*4]
	inc    ecx
	cmp    ecx,r11d
	cmovb  r11d,ecx
	mov    edx,DWORD PTR [r12+rsi*4+0xc]
	mov    rcx,r10
	sub    rcx,rdx
	jb     <coin_change+0x360>
	mov    ecx,DWORD PTR [rdi+rcx*4]
	inc    ecx
	cmp    ecx,eax
	cmovb  eax,ecx
	jmp    <coin_change+0x360>
	nop    DWORD PTR [rax+0x0]
	add    rdx,0xfffffffffffffffc
	mov    r8,rdx
	cmp    r8,r13
	jae    <coin_change+0x300>
	shl    rbx,0x2
	mov    rsi,QWORD PTR [rsp+0x58]
	sub    rsi,rbx
	cmp    rsi,0x8
	jb     <coin_change+0x94c>
	cmp    rsi,0x20
	jae    <coin_change+0x76c>
	xor    ebx,ebx
	jmp    <coin_change+0x8b2>
	nop    WORD PTR [rax+rax*1+0x0]
	vpbroadcastq zmm12,r10
	mov    rax,QWORD PTR [rsp+0x18]
	lea    rdx,[r12+0x80]
	vmovdqa ymm13,ymm0
	vmovdqa ymm14,ymm0
	vmovdqa ymm10,ymm0
	vmovdqa ymm11,ymm0
	vmovdqa ymm8,ymm0
	vmovdqa ymm9,ymm0
	vmovdqa ymm6,ymm0
	vmovdqa ymm7,ymm0
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu64 zmm15,ZMMWORD PTR [rdx-0x80]
	vmovdqu64 zmm17,ZMMWORD PTR [rdx-0x40]
	vmovdqu64 zmm16,ZMMWORD PTR [rdx]
	vmovdqu64 zmm18,ZMMWORD PTR [rdx+0x40]
	vmovdqa64 zmm19,zmm15
	vpermt2d zmm19,zmm2,zmm17
	vmovdqa64 zmm20,zmm15
	vmovdqa64 zmm21,zmm16
	vpermt2d zmm21,zmm2,zmm18
	vpmovzxdq zmm19,ymm19
	vpmovzxdq zmm21,ymm21
	vpcmpnltuq k2,zmm12,zmm19
	vpcmpnltuq k1,zmm12,zmm21
	vpsubq zmm19,zmm12,zmm19
	vpsubq zmm21,zmm12,zmm21
	vpxord xmm22,xmm22,xmm22
	kmovq  k3,k2
	vpgatherqd ymm22{k3},DWORD PTR [rdi+zmm19*4]
	vpxord xmm19,xmm19,xmm19
	kmovq  k3,k1
	vpgatherqd ymm19{k3},DWORD PTR [rdi+zmm21*4]
	vpermt2d zmm20,zmm3,zmm17
	vmovdqa64 zmm21,zmm15
	vpermt2d zmm21,zmm4,zmm17
	vmovdqa64 zmm23,zmm16
	vpermt2d zmm23,zmm3,zmm18
	vmovdqa64 zmm24,zmm16
	vpermt2d zmm24,zmm4,zmm18
	vpsubd ymm22,ymm22,ymm1
	vpminud ymm6{k2},ymm22,ymm6
	vpmovzxdq zmm20,ymm20
	vpmovzxdq zmm22,ymm23
	vpcmpnltuq k3,zmm12,zmm20
	vpcmpnltuq k2,zmm12,zmm22
	vpsubq zmm20,zmm12,zmm20
	vpsubq zmm22,zmm12,zmm22
	kmovq  k4,k3
	vpxord xmm23,xmm23,xmm23
	vpgatherqd ymm23{k4},DWORD PTR [rdi+zmm20*4]
	kmovq  k4,k2
	vpxord xmm20,xmm20,xmm20
	vpgatherqd ymm20{k4},DWORD PTR [rdi+zmm22*4]
	vpmovzxdq zmm21,ymm21
	vpmovzxdq zmm22,ymm24
	vpcmpnltuq k5,zmm12,zmm21
	vpcmpnltuq k4,zmm12,zmm22
	vpsubq zmm21,zmm12,zmm21
	vpsubq zmm22,zmm12,zmm22
	kmovq  k6,k5
	vpxord xmm24,xmm24,xmm24
	vpgatherqd ymm24{k6},DWORD PTR [rdi+zmm21*4]
	kmovq  k6,k4
	vpxord xmm21,xmm21,xmm21
	vpgatherqd ymm21{k6},DWORD PTR [rdi+zmm22*4]
	vpsubd ymm19,ymm19,ymm1
	vpminud ymm7{k1},ymm19,ymm7
	vpsubd ymm19,ymm23,ymm1
	vpminud ymm8{k3},ymm19,ymm8
	vpermt2d zmm15,zmm5,zmm17
	vpermt2d zmm16,zmm5,zmm18
	vpsubd ymm17,ymm20,ymm1
	vpminud ymm9{k2},ymm17,ymm9
	vpsubd ymm17,ymm24,ymm1
	vpsubd ymm18,ymm21,ymm1
	vpminud ymm10{k5},ymm17,ymm10
	vpminud ymm11{k4},ymm18,ymm11
	vpmovzxdq zmm15,ymm15
	vpmovzxdq zmm16,ymm16
	vpcmpnltuq k1,zmm12,zmm15
	vpcmpnltuq k2,zmm12,zmm16
	vpsubq zmm15,zmm12,zmm15
	vpsubq zmm16,zmm12,zmm16
	kmovq  k3,k1
	vpxord xmm17,xmm17,xmm17
	vpgatherqd ymm17{k3},DWORD PTR [rdi+zmm15*4]
	kmovq  k3,k2
	vpxor  xmm15,xmm15,xmm15
	vpgatherqd ymm15{k3},DWORD PTR [rdi+zmm16*4]
	vpsubd ymm16,ymm17,ymm1
	vpsubd ymm15,ymm15,ymm1
	vpminud ymm13{k1},ymm16,ymm13
	vpminud ymm14{k2},ymm15,ymm14
	add    rdx,0x100
	add    rax,0xfffffffffffffff0
	jne    <coin_change+0x490>
	vpminud ymm12,ymm13,ymm14
	vextracti128 xmm13,ymm12,0x1
	vpminud xmm12,xmm12,xmm13
	vpshufd xmm13,xmm12,0xee
	vpminud xmm12,xmm12,xmm13
	vpshufd xmm13,xmm12,0x55
	vpminud xmm12,xmm12,xmm13
	vmovd  eax,xmm12
	vpminud ymm10,ymm10,ymm11
	vextracti128 xmm11,ymm10,0x1
	vpminud xmm10,xmm10,xmm11
	vpshufd xmm11,xmm10,0xee
	vpminud xmm10,xmm10,xmm11
	vpshufd xmm11,xmm10,0x55
	vpminud xmm10,xmm10,xmm11
	vmovd  r11d,xmm10
	vpminud ymm8,ymm8,ymm9
	vextracti128 xmm9,ymm8,0x1
	vpminud xmm8,xmm8,xmm9
	vpshufd xmm9,xmm8,0xee
	vpminud xmm8,xmm8,xmm9
	vpshufd xmm9,xmm8,0x55
	vpminud xmm8,xmm8,xmm9
	vmovd  ebp,xmm8
	vpminud ymm6,ymm6,ymm7
	vextracti128 xmm7,ymm6,0x1
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0xee
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0x55
	vpminud xmm6,xmm6,xmm7
	vmovd  r9d,xmm6
	mov    r15,QWORD PTR [rsp+0x18]
	mov    rcx,r15
	mov    rdx,QWORD PTR [rsp+0x30]
	mov    r8,QWORD PTR [rsp+0x38]
	mov    rsi,r8
	mov    rbx,QWORD PTR [rsp+0x28]
	cmp    QWORD PTR [rsp+0x20],r15
	mov    r15,QWORD PTR [rsp+0x40]
	jne    <coin_change+0x34c>
	jmp    <coin_change+0x417>
	mov    rbx,rsi
	and    rbx,0xffffffffffffffe0
	vpbroadcastq zmm7,r10
	vpbroadcastd ymm6,r9d
	lea    rcx,[r12+0x60]
	lea    rdx,[rcx+r8*4]
	xor    r9d,r9d
	vmovdqa ymm8,ymm6
	vmovdqa ymm9,ymm6
	vmovdqa ymm10,ymm6
	nop    WORD PTR [rax+rax*1+0x0]
	vpmovzxdq zmm11,YMMWORD PTR [rdx+r9*4-0x60]
	vpmovzxdq zmm12,YMMWORD PTR [rdx+r9*4-0x40]
	vpmovzxdq zmm13,YMMWORD PTR [rdx+r9*4-0x20]
	vpmovzxdq zmm14,YMMWORD PTR [rdx+r9*4]
	vpcmpnltuq k4,zmm7,zmm11
	vpcmpnltuq k3,zmm7,zmm12
	vpcmpnltuq k2,zmm7,zmm13
	vpcmpnltuq k1,zmm7,zmm14
	vpsubq zmm11,zmm7,zmm11
	vpsubq zmm12,zmm7,zmm12
	vpsubq zmm13,zmm7,zmm13
	vpsubq zmm14,zmm7,zmm14
	kmovq  k5,k4
	vpxor  xmm15,xmm15,xmm15
	vpgatherqd ymm15{k5},DWORD PTR [rdi+zmm11*4]
	kmovq  k5,k3
	vpxor  xmm11,xmm11,xmm11
	vpgatherqd ymm11{k5},DWORD PTR [rdi+zmm12*4]
	vpxor  xmm12,xmm12,xmm12
	kmovq  k5,k2
	vpgatherqd ymm12{k5},DWORD PTR [rdi+zmm13*4]
	vpxor  xmm13,xmm13,xmm13
	kmovq  k5,k1
	vpgatherqd ymm13{k5},DWORD PTR [rdi+zmm14*4]
	vpsubd ymm14,ymm15,ymm1
	vpsubd ymm11,ymm11,ymm1
	vpsubd ymm12,ymm12,ymm1
	vpsubd ymm13,ymm13,ymm1
	vpminud ymm6{k4},ymm14,ymm6
	vpminud ymm8{k3},ymm11,ymm8
	vpminud ymm9{k2},ymm12,ymm9
	vpminud ymm10{k1},ymm13,ymm10
	add    r9,0x20
	cmp    rbx,r9
	jne    <coin_change+0x7a0>
	vpminud ymm6,ymm6,ymm8
	vpminud ymm7,ymm9,ymm10
	vpminud ymm6,ymm6,ymm7
	vextracti128 xmm7,ymm6,0x1
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0xee
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0x55
	vpminud xmm6,xmm6,xmm7
	vmovd  r9d,xmm6
	cmp    rsi,rbx
	je     <coin_change+0x300>
	test   sil,0x18
	je     <coin_change+0x936>
	mov    rcx,rsi
	and    rcx,0xfffffffffffffff8
	vpbroadcastq zmm7,r10
	vpbroadcastd ymm6,r9d
	lea    rdx,[r12+r8*4]
	add    r8,rcx
	nop    DWORD PTR [rax+0x0]
	vpmovzxdq zmm8,YMMWORD PTR [rdx+rbx*4]
	vpcmpnltuq k1,zmm7,zmm8
	vpsubq zmm8,zmm7,zmm8
	kmovq  k2,k1
	vpxor  xmm9,xmm9,xmm9
	vpgatherqd ymm9{k2},DWORD PTR [rdi+zmm8*4]
	vpsubd ymm8,ymm9,ymm1
	vpminud ymm6{k1},ymm8,ymm6
	add    rbx,0x8
	cmp    rcx,rbx
	jne    <coin_change+0x8d0>
	vextracti128 xmm7,ymm6,0x1
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0xee
	vpminud xmm6,xmm6,xmm7
	vpshufd xmm7,xmm6,0x55
	vpminud xmm6,xmm6,xmm7
	vmovd  r9d,xmm6
	cmp    rsi,rcx
	jne    <coin_change+0x94c>
	jmp    <coin_change+0x300>
	add    r8,rbx
	jmp    <coin_change+0x94c>
	nop    DWORD PTR [rax+rax*1+0x0]
	inc    r8
	cmp    r13,r8
	je     <coin_change+0x300>
	mov    edx,DWORD PTR [r12+r8*4]
	mov    rcx,r10
	sub    rcx,rdx
	jb     <coin_change+0x940>
	mov    ecx,DWORD PTR [rdi+rcx*4]
	inc    ecx
	cmp    ecx,r9d
	cmovb  r9d,ecx
	jmp    <coin_change+0x940>
	mov    edx,0x1
	cmp    r15,0x4
	jb     <coin_change+0xa90>
	cmp    r15,0x20
	jae    <coin_change+0xa04>
	xor    ecx,ecx
	jmp    <coin_change+0xa50>
	test   r15b,0x1
	je     <coin_change+0xa9c>
	vpcmpnltuq k1,ymm0,YMMWORD PTR [rip+0x25fe5]
	vpbroadcastd xmm0,r14d
	vmovdqu32 xmm1{k1}{z},XMMWORD PTR [r12]
	vpbroadcastq ymm2,rax
	vpmovzxdq ymm1,xmm1
	vpcmpnltuq k1{k1},ymm2,ymm1
	vpsubq ymm1,ymm2,ymm1
	vpxor  xmm2,xmm2,xmm2
	kmovq  k2,k1
	vpgatherqd xmm2{k2},DWORD PTR [rdi+ymm1*4]
	vpcmpeqd xmm1,xmm1,xmm1
	vpsubd xmm1,xmm2,xmm1
	vpminud xmm0{k1},xmm1,xmm0
	vpshufd xmm1,xmm0,0xee
	vpminud xmm0,xmm0,xmm1
	vpshufd xmm1,xmm0,0x55
	vpminud xmm0,xmm0,xmm1
	vmovd  ecx,xmm0
	cmp    ecx,r14d
	cmovb  r14d,ecx
	mov    DWORD PTR [rdi+rax*4],r14d
	jmp    <coin_change+0xa9c>
	mov    rcx,r15
	and    rcx,0xffffffffffffffe0
	vpbroadcastd ymm0,r14d
	xor    edx,edx
	data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x4],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x24],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x44],ymm0
	vmovdqu YMMWORD PTR [rdi+rdx*4+0x64],ymm0
	add    rdx,0x20
	cmp    rcx,rdx
	jne    <coin_change+0xa20>
	cmp    r15,rcx
	je     <coin_change+0xa9c>
	test   r15b,0x1c
	je     <coin_change+0xadc>
	mov    rsi,r15
	and    rsi,0xfffffffffffffffc
	lea    rdx,[rsi+0x1]
	vpbroadcastd xmm0,r14d
	data16 data16 data16 data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	vmovdqu XMMWORD PTR [rdi+rcx*4+0x4],xmm0
	add    rcx,0x4
	cmp    rsi,rcx
	jne    <coin_change+0xa70>
	cmp    r15,rsi
	je     <coin_change+0xa9c>
	data16 data16 cs nop WORD PTR [rax+rax*1+0x0]
	mov    DWORD PTR [rdi+rdx*4],r14d
	inc    rdx
	cmp    rax,rdx
	jne    <coin_change+0xa90>
	mov    eax,DWORD PTR [rdi+r15*4]
	cmp    r15,rax
	mov    ebp,0xffffffff
	cmovae ebp,eax
	mov    r9,QWORD PTR [rsp+0x50]
	mov    rdx,QWORD PTR [r9]
	mov    rcx,QWORD PTR [r9+0x8]
	lea    r8,[rip+0x2b902]
	mov    rsi,QWORD PTR [rsp+0x48]
	vzeroupper
	call   <runtime::mem_free_with_size>
	mov    eax,ebp
	add    rsp,0x78
	pop    rbx
	pop    r12
	pop    r13
	pop    r14
	pop    r15
	pop    rbp
	ret
	or     rcx,0x1
	mov    rdx,rcx
	jmp    <coin_change+0xa90>

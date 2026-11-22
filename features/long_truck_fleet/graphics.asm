option casemap:none

EXTERN GetTruckCapacity:PROC
EXTERN NativeDrawQuad:PROC
EXTERN TruckBodySegments:BYTE
EXTERN GroundAxisLimit:DWORD
EXTERN NativeSpriteMarker:PROC
EXTERN BedMarkerConstants:BYTE
EXTERN FleetWorldEpoch:DWORD
EXTERN TruckBedSnapshots:BYTE
EXTERN GamePointer:QWORD

PUBLIC DrawTruckBody
PUBLIC LocateTruckCargo
PUBLIC ClassifyTruckCargoRender

.code

; Nonblocking per-bucket lock. Only this patch's own static memory is shared.
; A contended bucket falls back; it never stalls game drawing or simulation.
AcquireTruckSnapshot MACRO failLabel:req
    mov r11, QWORD PTR [rcx+38h]
    cmp r11d, -1
    je failLabel
    mov r10, r11
    shr r10, 32
    cmp r10d, -1
    je failLabel
    mov r9d, r11d
    ror r9d, 13
    xor r10d, r9d
    and r10d, 15
    shl r10d, 6
    lea rax, TruckBedSnapshots
    add rax, r10
    mov r9d, 1
    xchg DWORD PTR [rax], r9d
    test r9d, r9d
    jnz failLabel
ENDM

; RCX owner, EDX capacity (zero clears), R8 local draw geometry and identity.
WriteTruckSnapshot PROC
    AcquireTruckSnapshot writeDone
    test edx, edx
    jnz writeBed
    cmp QWORD PTR [rax+8], rcx
    jne unlockWriter
    cmp QWORD PTR [rax+10h], r11
    jne unlockWriter
    mov DWORD PTR [rax+4], 0
    jmp unlockWriter
writeBed:
    mov r9d, DWORD PTR [r8+18h]
    cmp r9d, DWORD PTR [FleetWorldEpoch]
    jne unlockWriter
    cmp QWORD PTR [r8+30h], r11
    jne unlockWriter
    mov DWORD PTR [rax+4], edx
    mov QWORD PTR [rax+8], rcx
    mov QWORD PTR [rax+10h], r11
    mov DWORD PTR [rax+18h], r9d
    mov r9, QWORD PTR [r8+20h]
    mov QWORD PTR [rax+20h], r9
    movq xmm0, QWORD PTR [r8+28h]
    movq xmm1, QWORD PTR [r8]
    subps xmm1, xmm0
    movq QWORD PTR [rax+28h], xmm1
    movq xmm1, QWORD PTR [r8+8]
    subps xmm1, xmm0
    movq QWORD PTR [rax+30h], xmm1
    movq xmm1, QWORD PTR [r8+10h]
    subps xmm1, xmm0
    movq QWORD PTR [rax+38h], xmm1
unlockWriter:
    mov DWORD PTR [rax], 0
writeDone:
    ret
WriteTruckSnapshot ENDP

; RCX owner, EDX resolved capacity, R8 optional destination for the copy.
ReadTruckSnapshot PROC
    AcquireTruckSnapshot noBed
    cmp DWORD PTR [rax+4], edx
    jne invalidBed
    cmp QWORD PTR [rax+8], rcx
    jne invalidBed
    cmp QWORD PTR [rax+10h], r11
    jne invalidBed
    mov r9d, DWORD PTR [FleetWorldEpoch]
    cmp DWORD PTR [rax+18h], r9d
    jne invalidBed
    mov r9, QWORD PTR [rcx+54h]
    cmp QWORD PTR [rax+20h], r9
    jne invalidBed
    test r8, r8
    jz accessDone
    mov r9, QWORD PTR [rax+28h]
    mov QWORD PTR [r8], r9
    mov r9, QWORD PTR [rax+30h]
    mov QWORD PTR [r8+8], r9
    mov r9, QWORD PTR [rax+38h]
    mov QWORD PTR [r8+10h], r9
accessDone:
    mov DWORD PTR [rax], 0
    mov eax, 1
    ret
invalidBed:
    mov DWORD PTR [rax], 0
noBed:
    xor eax, eax
    ret
ReadTruckSnapshot ENDP

; Call-site wrapper for the ordinary native object world mesh. Split the same
; stock atlas coordinates into tail, bed and cab. Only the bed grows.
DrawTruckBody PROC
    sub rsp, 0F8h
    mov QWORD PTR [rsp+58h], rcx
    mov QWORD PTR [rsp+60h], rdx
    mov QWORD PTR [rsp+68h], r8
    mov QWORD PTR [rsp+70h], r9

    cmp DWORD PTR [rdi+40h], 8Bh
    jne stockQuad
    mov rcx, rdi
    call GetTruckCapacity
    cmp eax, 12
    je checkStockShape
    cmp eax, 16
    jne stockQuad
checkStockShape:
    mov DWORD PTR [rsp+9Ch], eax
    mov eax, DWORD PTR [FleetWorldEpoch]
    mov DWORD PTR [rsp+0B8h], eax
    mov rax, QWORD PTR [rdi+54h]
    mov QWORD PTR [rsp+0C0h], rax
    mov rax, QWORD PTR [rdi+48h]
    mov QWORD PTR [rsp+0C8h], rax
    mov rax, QWORD PTR [rdi+38h]
    mov QWORD PTR [rsp+0D0h], rax
    mov rax, QWORD PTR [rbp+20h]
    test rax, rax
    jz clearBed
    cmp DWORD PTR [rax+20h], 6
    jne clearBed
    cmp DWORD PTR [rax+24h], 64
    jne clearBed
    cmp DWORD PTR [rax+28h], 4
    jne clearBed
    cmp DWORD PTR [rax+2Ch], 15
    jne clearBed
    cmp DWORD PTR [rax+30h], 0
    jne clearBed
    mov eax, DWORD PTR [rsp+9Ch]
    sub eax, 8
    shr eax, 1                  ; Two/four extra ground-world tiles.
    cvtsi2ss xmm0, eax
    mov rax, QWORD PTR [rsp+70h]
    movss xmm1, DWORD PTR [rax]
    mulss xmm1, xmm1
    movss xmm2, DWORD PTR [rax+4]
    mulss xmm2, xmm2
    addss xmm1, xmm2
    ucomiss xmm1, DWORD PTR [GroundAxisLimit]
    jbe clearBed
    sqrtss xmm1, xmm1
    mulss xmm1, DWORD PTR [rsp+120h] ; Original stock scale.
    ucomiss xmm1, DWORD PTR [GroundAxisLimit]
    jbe clearBed
    divss xmm0, xmm1             ; Extra length in native longitudinal vector units.
    movss DWORD PTR [rsp+78h], xmm0
    mov DWORD PTR [rsp+7Ch], 0

nextSegment:
    movsxd r10, DWORD PTR [rsp+7Ch]
    imul r10, 24
    lea r11, TruckBodySegments
    add r11, r10
    movss xmm0, DWORD PTR [rsp+78h]
    movaps xmm1, xmm0
    mulss xmm1, DWORD PTR [r11+0Ch]
    addss xmm1, DWORD PTR [r11+8]
    mulss xmm1, DWORD PTR [rsp+120h]

    mov rax, QWORD PTR [rsp+70h]
    mov rdx, QWORD PTR [rsp+60h]
    movaps xmm2, xmm1
    mulss xmm2, DWORD PTR [rax]
    addss xmm2, DWORD PTR [rdx]
    movss DWORD PTR [rsp+80h], xmm2
    movaps xmm2, xmm1
    mulss xmm2, DWORD PTR [rax+4]
    addss xmm2, DWORD PTR [rdx+4]
    movss DWORD PTR [rsp+84h], xmm2
    mulss xmm1, DWORD PTR [rax+8]
    addss xmm1, DWORD PTR [rdx+8]
    movss DWORD PTR [rsp+88h], xmm1

    mulss xmm0, DWORD PTR [r11+14h]
    addss xmm0, DWORD PTR [r11+10h]
    movaps xmm1, xmm0
    mulss xmm1, DWORD PTR [rax]
    movss DWORD PTR [rsp+90h], xmm1
    movaps xmm1, xmm0
    mulss xmm1, DWORD PTR [rax+4]
    movss DWORD PTR [rsp+94h], xmm1
    mulss xmm0, DWORD PTR [rax+8]
    movss DWORD PTR [rsp+98h], xmm0

    mov eax, DWORD PTR [rsp+120h]
    mov DWORD PTR [rsp+20h], eax
    mov eax, DWORD PTR [rsp+128h]
    mov DWORD PTR [rsp+28h], eax
    movss xmm0, DWORD PTR [rsp+140h]
    movaps xmm1, xmm0
    mulss xmm1, DWORD PTR [r11]
    addss xmm1, DWORD PTR [rsp+130h]
    movss DWORD PTR [rsp+30h], xmm1
    mov eax, DWORD PTR [rsp+138h]
    mov DWORD PTR [rsp+38h], eax
    mulss xmm0, DWORD PTR [r11+4]
    movss DWORD PTR [rsp+40h], xmm0
    mov rax, QWORD PTR [rsp+148h]
    mov QWORD PTR [rsp+48h], rax

    mov rcx, QWORD PTR [rsp+58h]
    lea rdx, [rsp+80h]
    mov r8, QWORD PTR [rsp+68h]
    lea r9, [rsp+90h]
    call NativeDrawQuad
    cmp DWORD PTR [rsp+7Ch], 1
    jne advanceSegment

    ; Recreate only the bed's first triangle using DrawQuad's native float
    ; operations and this invocation's own vectors, before publishing it.
    mov rax, QWORD PTR [rsp+68h]
    movq xmm0, QWORD PTR [rax]
    movq xmm1, QWORD PTR [rsp+90h]
    movq xmm2, QWORD PTR [rsp+80h]
    movss xmm3, DWORD PTR [rsp+120h]
    shufps xmm3, xmm3, 0
    mulps xmm0, xmm3
    mulps xmm1, xmm3
    lea rax, BedMarkerConstants
    movss xmm3, DWORD PTR [rax+2Ch]
    shufps xmm3, xmm3, 0
    mulps xmm0, xmm3
    mulps xmm1, xmm3
    movaps xmm3, xmm2
    subps xmm3, xmm0
    subps xmm3, xmm1
    movq QWORD PTR [rsp+0A0h], xmm3
    addps xmm2, xmm0
    movaps xmm3, xmm2
    subps xmm3, xmm1
    movq QWORD PTR [rsp+0A8h], xmm3
    addps xmm2, xmm1
    movq QWORD PTR [rsp+0B0h], xmm2
advanceSegment:
    inc DWORD PTR [rsp+7Ch]
    cmp DWORD PTR [rsp+7Ch], 3
    jb nextSegment
    mov rcx, rdi
    mov edx, DWORD PTR [rsp+9Ch]
    lea r8, [rsp+0A0h]
    call WriteTruckSnapshot
    add rsp, 0F8h
    ret

clearBed:
    mov rcx, rdi
    xor edx, edx
    call WriteTruckSnapshot
stockQuad:
    mov rcx, QWORD PTR [rsp+58h]
    mov rdx, QWORD PTR [rsp+60h]
    mov r8, QWORD PTR [rsp+68h]
    mov r9, QWORD PTR [rsp+70h]
    add rsp, 0F8h
    jmp NativeDrawQuad
DrawTruckBody ENDP

; Native stock-sprite marker call inside WorldObject::GetSlotPosition.
; RDI holds the owner and R15 its render cache. Native postprocessing maps
; fractional x/y through that cache's world AABB, with an optional Y offset.
LocateTruckCargo PROC
    sub rsp, 68h
    mov QWORD PTR [rsp+20h], rcx
    mov QWORD PTR [rsp+28h], rdx
    mov QWORD PTR [rsp+30h], r8
    mov DWORD PTR [rsp+38h], r9d
    cmp DWORD PTR [rdi+40h], 8Bh
    jne nativeMarker
    mov rcx, rdi
    call GetTruckCapacity
    cmp eax, 12
    je longMarker
    cmp eax, 16
    jne nativeMarker
longMarker:
    cmp DWORD PTR [rsp+38h], eax
    jae nativeMarker
    mov DWORD PTR [rsp+40h], eax
    mov rcx, rdi
    mov edx, eax
    lea r8, [rsp+48h]
    call ReadTruckSnapshot
    test eax, eax
    jz nativeMarker

    lea rdx, BedMarkerConstants
    lea rax, [rsp+48h]
    mov ecx, DWORD PTR [rsp+38h]
    mov r8d, ecx
    and r8d, 1
    movss xmm0, DWORD PTR [rdx+r8*4+1Ch] ; One-quarter or three-quarters across.
    shr ecx, 1
    cvtsi2ss xmm1, ecx
    mov ecx, DWORD PTR [rsp+40h]
    shr ecx, 1
    dec ecx
    cvtsi2ss xmm2, ecx
    divss xmm1, xmm2
    mulss xmm1, DWORD PTR [rdx+24h]
    movss xmm2, DWORD PTR [rdx+28h]
    subss xmm2, xmm1              ; Near cab on first row, near tail on last.

    movss xmm1, DWORD PTR [rax+8]
    subss xmm1, DWORD PTR [rax]
    mulss xmm1, xmm0
    movss xmm3, DWORD PTR [rax+10h]
    subss xmm3, DWORD PTR [rax+8]
    mulss xmm3, xmm2
    addss xmm1, xmm3
    addss xmm1, DWORD PTR [rax]
    movss xmm3, DWORD PTR [rax+0Ch]
    subss xmm3, DWORD PTR [rax+4]
    mulss xmm3, xmm0
    movss xmm4, DWORD PTR [rax+14h]
    subss xmm4, DWORD PTR [rax+0Ch]
    mulss xmm4, xmm2
    addss xmm3, xmm4
    addss xmm3, DWORD PTR [rax+4]
    addss xmm1, DWORD PTR [rdi+48h]
    addss xmm3, DWORD PTR [rdi+4Ch]

    movss xmm0, DWORD PTR [rdi+60h]
    ucomiss xmm0, DWORD PTR [rdx+2Ch]
    jbe nativeVerticalBiasDone
    subss xmm3, DWORD PTR [rdx+30h]
nativeVerticalBiasDone:
    movss xmm2, DWORD PTR [r15+4]
    subss xmm2, DWORD PTR [r15]
    movss xmm4, DWORD PTR [r15+0Ch]
    subss xmm4, DWORD PTR [r15+8]
    ucomiss xmm2, DWORD PTR [GroundAxisLimit]
    jbe nativeMarker
    ucomiss xmm4, DWORD PTR [GroundAxisLimit]
    jbe nativeMarker
    subss xmm1, DWORD PTR [r15]
    divss xmm1, xmm2
    subss xmm3, DWORD PTR [r15+8]
    divss xmm3, xmm4
    mov rax, QWORD PTR [rsp+90h]
    movss DWORD PTR [rax], xmm1
    mov rax, QWORD PTR [rsp+98h]
    movss DWORD PTR [rax], xmm3
    mov rax, QWORD PTR [rsp+0A0h]
    mov DWORD PTR [rax], 0
    mov rax, QWORD PTR [rsp+0A8h]
    mov DWORD PTR [rax], 0
    mov eax, 1
    add rsp, 68h
    ret
nativeMarker:
    mov rcx, QWORD PTR [rsp+20h]
    mov rdx, QWORD PTR [rsp+28h]
    mov r8, QWORD PTR [rsp+30h]
    mov r9d, DWORD PTR [rsp+38h]
    add rsp, 68h
    jmp NativeSpriteMarker
LocateTruckCargo ENDP

; Return ZF for hidden overflow, SF for the original special object and
; neither flag for the ordinary renderer. Only visual batching is skipped.
ClassifyTruckCargoRender PROC
    push r12
    sub rsp, 50h
    mov r12, rsp
    mov QWORD PTR [rsp+20h], rdx
    cmp DWORD PTR [rbx+40h], 24Dh
    je stockSpecial
    cmp BYTE PTR [rbx+6Eh], 1
    jne stockOrdinary
    mov r8, QWORD PTR [rbx+98h]
    cmp r8d, -1
    je stockOrdinary
    mov r9, r8
    shr r9, 32
    mov r11, QWORD PTR [GamePointer]
    test r11, r11
    jz stockOrdinary
    mov r11, QWORD PTR [r11+198h]
    test r11, r11
    jz stockOrdinary
    mov r10d, DWORD PTR [r11+44B4h]
    test r10d, r10d
    jle stockOrdinary
    cmp r9d, r10d
    jae stockOrdinary
    mov r10, QWORD PTR [r11+44C0h]
    test r10, r10
    jz stockOrdinary
    cmp BYTE PTR [r10+r9], 0
    je stockOrdinary
    mov r10, QWORD PTR [r11+44B8h]
    test r10, r10
    jz stockOrdinary
    mov r10, QWORD PTR [r10+r9*8]
    test r10, r10
    jz stockOrdinary
    cmp QWORD PTR [r10+38h], r8
    jne stockOrdinary
    cmp DWORD PTR [r10+40h], 8Bh
    jne stockOrdinary
    mov r8, QWORD PTR [rbx+38h]
    cmp r8d, -1
    je stockOrdinary
    cmp DWORD PTR [rbx+3Ch], -1
    je stockOrdinary
    xor r9d, r9d
checkCargoSlot:
    cmp QWORD PTR [r10+r9*8+0D8h], r8
    je matchedCargo
    inc r9d
    cmp r9d, 20
    jb checkCargoSlot
    jmp stockOrdinary
matchedCargo:
    cmp r9d, 8
    jb stockOrdinary
    mov DWORD PTR [rsp+28h], r9d
    mov QWORD PTR [rsp+30h], r10
    mov rcx, r10
    call GetTruckCapacity
    cmp eax, 12
    je checkLongSlot
    cmp eax, 16
    jne suppressCargo
checkLongSlot:
    cmp DWORD PTR [rsp+28h], eax
    jae suppressCargo
    mov rcx, QWORD PTR [rsp+30h]
    mov edx, eax
    xor r8d, r8d
    call ReadTruckSnapshot
    test eax, eax
    jz suppressCargo
stockOrdinary:
    mov eax, 1
    jmp classified
stockSpecial:
    mov QWORD PTR [rbp+40h], rbx ; Displaced stock store.
    mov eax, -1
    jmp classified
suppressCargo:
    xor eax, eax
classified:
    mov rdx, QWORD PTR [rsp+20h]
    test al, al
    lea rsp, [r12+50h]
    pop r12
    ret
ClassifyTruckCargoRender ENDP

END

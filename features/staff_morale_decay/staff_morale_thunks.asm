option casemap:none

EXTERN TrackedWorld:QWORD
EXTERN ForgivenDeaths:DWORD
EXTERN RecoveryStart:QWORD
EXTERN ResumeMorale:PROC
EXTERN LoadVictory:PROC

PUBLIC ApplyDeathPenalty, RecordStaffDeath, ResetOnLoad, AdvanceRecovery

.code

; The native morale function is a leaf. Return to its next instruction with
; XMM3 adjusted, preserving its desired morale calculation and all UI counters.
ApplyDeathPenalty PROC
    sub rsp, 28h
    mov eax, DWORD PTR [rdx+2798h]
    test eax, eax
    jle subtractPenalty
    mov r10, rdx
    call AdvanceRecovery
subtractPenalty:
    cvtsi2ss xmm0, eax
    subss xmm3, xmm0
    add rsp, 28h
    jmp ResumeMorale
ApplyDeathPenalty ENDP

; The stock branch reaches this call only for a staff death. Give any prior
; outstanding deaths their elapsed recovery before incrementing the raw count.
RecordStaffDeath PROC
    sub rsp, 28h
    lea r10, [rcx-2588h]
    mov eax, DWORD PTR [rcx+210h]
    call AdvanceRecovery
    test eax, eax
    jne countDeath
    movsd xmm0, QWORD PTR [r10+80h]
    movsd QWORD PTR [RecoveryStart], xmm0
countDeath:
    inc DWORD PTR [rcx+210h]
    add rsp, 28h
    ret
RecordStaffDeath ENDP

; The stock staff-death count is session-local. Reset the associated recovery
; state on the game's world load path, which may reuse the same world address.
ResetOnLoad PROC
    xor eax, eax
    mov QWORD PTR [TrackedWorld], rax
    jmp LoadVictory
ResetOnLoad ENDP

; R10 is the world and EAX is its unmodified staff death count. Return the
; outstanding count. Retain partial days while existing deaths remain pending.
AdvanceRecovery PROC
    test eax, eax
    jle resetEmpty
    cmp QWORD PTR [TrackedWorld], r10
    jne startTracking
    cmp eax, DWORD PTR [ForgivenDeaths]
    jl startTracking
    sub eax, DWORD PTR [ForgivenDeaths]
    jz recoveryDone

    movsd xmm0, QWORD PTR [r10+80h]
    subsd xmm0, QWORD PTR [RecoveryStart]
    xorpd xmm2, xmm2
    ucomisd xmm0, xmm2
    jb anchorClock
    mov r11, 4096800000000000h  ; 1440.0 game minutes per day
    movq xmm2, r11
    ucomisd xmm0, xmm2
    jb recoveryDone
    divsd xmm0, xmm2
    cvttsd2si r11, xmm0
    cmp r11, rax
    jae clearPenalty

    add DWORD PTR [ForgivenDeaths], r11d
    sub eax, r11d
    cvtsi2sd xmm0, r11d
    mulsd xmm0, xmm2
    addsd xmm0, QWORD PTR [RecoveryStart]
    movsd QWORD PTR [RecoveryStart], xmm0
recoveryDone:
    ret

clearPenalty:
    add DWORD PTR [ForgivenDeaths], eax
    xor eax, eax
    ret

resetEmpty:
    xor eax, eax
startTracking:
    mov QWORD PTR [TrackedWorld], r10
    mov DWORD PTR [ForgivenDeaths], 0
anchorClock:
    movsd xmm0, QWORD PTR [r10+80h]
    movsd QWORD PTR [RecoveryStart], xmm0
    ret
AdvanceRecovery ENDP

END

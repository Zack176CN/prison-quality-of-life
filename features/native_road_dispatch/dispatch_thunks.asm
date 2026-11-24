option casemap:none

EXTERN Game:QWORD
EXTERN DispatchState:QWORD
EXTERN DispatchObjectKind:DWORD
EXTERN RunNativeUpdate:PROC
EXTERN CheckRoadEntrance:PROC
EXTERN CheckNativeBacklog:PROC
EXTERN SpawnRoadTruck:PROC
EXTERN ContinueNativeBacklog:PROC
EXTERN NativeWastePermission:PROC
EXTERN NativeExportsPermission:PROC
EXTERN PreferredTruckCapacity:DWORD
EXTERN FleetWorldEpoch:DWORD
EXTERN DispatchPreferencesWorld:QWORD
EXTERN ContinueWorldConstruction:PROC
EXTERN MaterialDefCount:DWORD
EXTERN MaterialDefTable:QWORD

PUBLIC DispatchNativeUpdate
PUBLIC CollectDispatchBacklog
PUBLIC EnqueueNativeDispatch
PUBLIC ConfigureNativeDispatch
PUBLIC StoreDispatchConfiguration
PUBLIC GetNativeDispatchState
PUBLIC HasNativeRoad
PUBLIC ResetDispatchForWorldConstruction
PUBLIC DispatchSpawnReturn
PUBLIC RefreshDispatchBacklog

WorldPointer    EQU 00h
LastMinute      EQU 08h
PendingCount    EQU 0Ch
Configuration   EQU 10h
NextAutoMinute  EQU 14h
AutoInterval    EQU 18h
DispatchStatus  EQU 1Ch
NextCategory    EQU 20h
CaptureCounts   EQU 24h
WasteCount      EQU 28h
ExportsCount    EQU 2Ch
NextSpawnTime   EQU 30h
ActiveConsole   EQU 38h
NextBacklogScan EQU 48h
LastBacklogScan EQU 4Ch
BacklogSnapshot EQU 50h
LastOutcome     EQU 58h
BacklogScanInterval EQU 5

; Zero means ready. Other values report the last attempt to the UI.
StatusSent      EQU 1
StatusCooldown  EQU 2
StatusLimit     EQU 3
StatusEntrance  EQU 4
StatusBacklog   EQU 5
StatusUnavailable EQU 6

.code

; ECX is 1 or 2. Return the full accepted count, or zero on failure.
EnqueueNativeDispatch PROC
    xor eax, eax
    cmp ecx, 1
    jb enqueueDone
    cmp ecx, 2
    ja enqueueDone
    mov rdx, QWORD PTR [Game]
    test rdx, rdx
    jz enqueueDone
    mov rdx, QWORD PTR [rdx+198h]
    test rdx, rdx
    jz enqueueDone
    lea r8, DispatchState
    cmp QWORD PTR [r8+WorldPointer], rdx
    jne enqueueDone
    cmp DWORD PTR [r8+ActiveConsole], 1
    jne enqueueDone
    mov eax, DWORD PTR [r8+PendingCount]
enqueueRetry:
    lea r9d, [rax+rcx]
    cmp r9d, 5
    ja enqueueRejected
    lock cmpxchg DWORD PTR [r8+PendingCount], r9d
    jne enqueueRetry
    mov eax, ecx
enqueueDone:
    ret
enqueueRejected:
    xor eax, eax
    ret
EnqueueNativeDispatch ENDP

; ECX=minutes (0/15/30/60), EDX=truck cap (1..5), R8D=stacks (1..64), R9D=balance (0/1).
ConfigureNativeDispatch PROC
    test r9d, r9d
    jz StoreDispatchConfiguration
    cmp BYTE PTR [NativeWastePermission], 0E9h
    jne checkSavedBalance
    cmp BYTE PTR [NativeExportsPermission], 0E9h
    je StoreDispatchConfiguration
checkSavedBalance:
    ; Allow the other controls to retain a saved preference while balance is disabled.
    lea rax, DispatchState
    test DWORD PTR [rax+Configuration], 01000000h
    jnz StoreDispatchConfiguration
    xor eax, eax
    ret
ConfigureNativeDispatch ENDP

; Validate before publishing, including when loading a saved, inactive balance setting.
StoreDispatchConfiguration PROC
    xor eax, eax
    test ecx, ecx
    jz intervalValid
    cmp ecx, 15
    je intervalValid
    cmp ecx, 30
    je intervalValid
    cmp ecx, 60
    jne configurationDone
intervalValid:
    dec edx
    cmp edx, 4
    ja configurationDone
    inc edx
    dec r8d
    cmp r8d, 63
    ja configurationDone
    inc r8d
    cmp r9d, 1
    ja configurationDone
    shl edx, 8
    shl r8d, 16
    shl r9d, 24
    or ecx, edx
    or ecx, r8d
    or ecx, r9d
    lea r10, DispatchState
    mov DWORD PTR [r10+Configuration], ecx
    mov eax, 1
configurationDone:
    ret
StoreDispatchConfiguration ENDP

GetNativeDispatchState PROC
    lea rax, DispatchState
    ret
GetNativeDispatchState ENDP

; Called in native road logistics update. Tail-call the displaced native update.
DispatchNativeUpdate PROC
    sub rsp, 58h
    mov QWORD PTR [rsp+20h], rcx
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz nativeUpdate
    mov r10, QWORD PTR [rax+198h]
    test r10, r10
    jz nativeUpdate
    movsd xmm0, QWORD PTR [r10+80h]
    cvttsd2si ecx, xmm0
    test ecx, ecx
    js nativeUpdate
    lea r11, DispatchState
    cmp QWORD PTR [r11+WorldPointer], r10
    jne resetWorld
    cmp ecx, DWORD PTR [r11+LastMinute]
    jl resetWorld
    je nativeUpdate

    mov DWORD PTR [r11+LastMinute], ecx
    mov QWORD PTR [rsp+28h], r10
    movsd QWORD PTR [rsp+30h], xmm0
    mov DWORD PTR [rsp+38h], ecx
    mov DWORD PTR [rsp+3Ch], 0

    ; Construction plans live outside this table. Require a built, uncarried console.
    mov eax, DWORD PTR [DispatchObjectKind]
    test eax, eax
    jle noActiveConsole
    mov ecx, DWORD PTR [r10+44B4h]
    test ecx, ecx
    jle noActiveConsole
    mov r8, QWORD PTR [r10+44B8h]
    test r8, r8
    jz noActiveConsole
    mov r9, QWORD PTR [r10+44C0h]
    test r9, r9
    jz noActiveConsole
    xor edx, edx
findActiveConsole:
    cmp BYTE PTR [r9+rdx], 0
    je nextConsoleCandidate
    mov r10, QWORD PTR [r8+rdx*8]
    test r10, r10
    jz nextConsoleCandidate
    cmp DWORD PTR [r10+40h], eax
    jne nextConsoleCandidate
    cmp BYTE PTR [r10+6Eh], 0
    je consoleReady
nextConsoleCandidate:
    inc edx
    cmp edx, ecx
    jl findActiveConsole
noActiveConsole:
    mov DWORD PTR [r11+ActiveConsole], 0
    xor eax, eax
    xchg DWORD PTR [r11+PendingCount], eax
    mov DWORD PTR [r11+AutoInterval], -1
    mov DWORD PTR [r11+DispatchStatus], StatusUnavailable
    mov DWORD PTR [r11+NextBacklogScan], 0
    jmp nativeUpdate
consoleReady:
    cmp DWORD PTR [r11+ActiveConsole], 0
    jne resumeActiveConsole
    mov DWORD PTR [r11+DispatchStatus], 0
resumeActiveConsole:
    mov DWORD PTR [r11+ActiveConsole], 1
    mov r10, QWORD PTR [rsp+28h]
    mov ecx, DWORD PTR [rsp+38h]
    cmp ecx, DWORD PTR [r11+NextBacklogScan]
    jl readDispatchConfiguration
    mov r8d, ecx
    mov rdx, r10
    mov rcx, QWORD PTR [rsp+20h]
    call RefreshDispatchBacklog
    lea r11, DispatchState
    mov r10, QWORD PTR [rsp+28h]
    mov ecx, DWORD PTR [rsp+38h]
    movsd xmm0, QWORD PTR [rsp+30h]
readDispatchConfiguration:
    mov eax, DWORD PTR [r11+Configuration]
    test eax, eax
    jnz useConfiguration
    mov eax, 00080200h        ; Manual mode, two active trucks, eight stacks, balance off.
useConfiguration:
    mov DWORD PTR [rsp+40h], eax
    movzx edx, al
    cmp edx, DWORD PTR [r11+AutoInterval]
    je checkAutoDeadline
    mov DWORD PTR [r11+AutoInterval], edx
    lea r8d, [rcx+rdx]
    mov DWORD PTR [r11+NextAutoMinute], r8d
checkAutoDeadline:
    test edx, edx
    jz checkPending
    cmp ecx, DWORD PTR [r11+NextAutoMinute]
    jl checkPending
    mov DWORD PTR [rsp+3Ch], 2
    add edx, ecx
    mov DWORD PTR [r11+NextAutoMinute], edx
checkPending:
    cmp DWORD PTR [r11+PendingCount], 0
    jle testAttempt
    or DWORD PTR [rsp+3Ch], 1
testAttempt:
    cmp DWORD PTR [rsp+3Ch], 0
    je nativeUpdate
    mov edx, StatusCooldown
    comisd xmm0, QWORD PTR [r11+NextSpawnTime]
    jb setStatus

    mov rcx, r10
    call HasNativeRoad
    lea r11, DispatchState
    mov edx, StatusUnavailable
    test al, al
    jz setStatus
    mov r10, QWORD PTR [rsp+28h]

    ; Do not scan an invalid world table, or count cars from a different world.
    mov ecx, DWORD PTR [r10+44B4h]
    mov edx, StatusUnavailable
    test ecx, ecx
    jle setStatus
    mov r8, QWORD PTR [r10+44B8h]
    test r8, r8
    jz setStatus
    mov r9, QWORD PTR [r10+44C0h]
    test r9, r9
    jz setStatus
    mov eax, DWORD PTR [rsp+40h]
    movzx edx, ah
    xor eax, eax
countTrucks:
    cmp BYTE PTR [r9+rax], 0
    je nextObject
    mov r10, QWORD PTR [r8+rax*8]
    test r10, r10
    jz nextObject
    cmp DWORD PTR [r10+40h], 8Bh
    jne nextObject
    dec edx
    jz activeLimitReached
nextObject:
    inc eax
    cmp eax, ecx
    jl countTrucks

    call CheckRoadEntrance
    test al, al
    jne entranceOccupied

    ; Reuse this minute's room counts. If the periodic read has not run,
    ; refresh before any decision that depends on the current inventory.
    test DWORD PTR [rsp+3Ch], 1
    jz requestBacklog
    test DWORD PTR [rsp+40h], 01000000h
    jz spawnTruck
requestBacklog:
    lea r11, DispatchState
    mov r8d, DWORD PTR [rsp+38h]
    cmp r8d, DWORD PTR [r11+LastBacklogScan]
    je checkFreshBacklog
    mov rcx, QWORD PTR [rsp+20h]
    mov rdx, QWORD PTR [rsp+28h]
    call RefreshDispatchBacklog
    lea r11, DispatchState
checkFreshBacklog:
    test DWORD PTR [rsp+3Ch], 1
    jnz spawnTruck
    mov ecx, DWORD PTR [rsp+40h]
    shr ecx, 16
    and ecx, 0FFh
    mov eax, DWORD PTR [r11+WasteCount]
    add eax, DWORD PTR [r11+ExportsCount]
    cmp eax, ecx
    jl backlogTooSmall

spawnTruck:
    call SpawnRoadTruck
DispatchSpawnReturn LABEL BYTE
    lea r11, DispatchState
    mov edx, StatusUnavailable
    test rax, rax
    jz setStatus
    test DWORD PTR [rsp+3Ch], 1
    jz markCooldown
    lock dec DWORD PTR [r11+PendingCount]
markCooldown:
    movsd xmm0, QWORD PTR [rsp+30h]
    mov rdx, 4014000000000000h  ; 5.0 in-game minutes.
    movq xmm1, rdx
    addsd xmm0, xmm1
    movsd QWORD PTR [r11+NextSpawnTime], xmm0
    mov DWORD PTR [r11+DispatchStatus], StatusSent
    mov DWORD PTR [r11+LastOutcome], StatusSent

    test DWORD PTR [rsp+40h], 01000000h
    jz nativeUpdate
    cmp BYTE PTR [NativeWastePermission], 0E9h
    jne nativeUpdate
    cmp BYTE PTR [NativeExportsPermission], 0E9h
    jne nativeUpdate
    cmp DWORD PTR [r11+WasteCount], 0
    jle nativeUpdate
    cmp DWORD PTR [r11+ExportsCount], 0
    jle nativeUpdate
    cmp QWORD PTR [rax+90h], 15
    jne nativeUpdate
    cmp QWORD PTR [rax+88h], 0
    je writeStockPickupTag
    cmp QWORD PTR [rax+88h], 12
    jne nativeUpdate
    mov rdx, 31304E5F444F4150h  ; PAOD_N01, installed by our long-truck constructor.
    cmp QWORD PTR [rax+78h], rdx
    jne nativeUpdate
    cmp DWORD PTR [rax+80h], 4C32312Dh
    je applyTag
    cmp DWORD PTR [rax+80h], 4C36312Dh
    jne nativeUpdate
    jmp applyTag
writeStockPickupTag:
    mov BYTE PTR [rax+80h], 0
    mov QWORD PTR [rax+88h], 8
applyTag:
    mov rdx, 3130475F444F4150h  ; PAOD_G01: garbage allowed; exports denied by permission hook.
    cmp DWORD PTR [r11+NextCategory], 0
    je storePickupCategory
    mov rdx, 3130455F444F4150h  ; PAOD_E01: exports allowed; garbage denied by permission hook.
storePickupCategory:
    mov QWORD PTR [rax+78h], rdx
    xor DWORD PTR [r11+NextCategory], 1
    jmp nativeUpdate

activeLimitReached:
    mov edx, StatusLimit
    jmp restoreStateForStatus
entranceOccupied:
    mov edx, StatusEntrance
    jmp restoreStateForStatus
backlogTooSmall:
    mov edx, StatusBacklog
restoreStateForStatus:
    lea r11, DispatchState
setStatus:
    mov DWORD PTR [r11+DispatchStatus], edx
    mov DWORD PTR [r11+LastOutcome], edx
    jmp nativeUpdate

resetWorld:
    ; Preserve preferences already read by the stock load before its first tick.
    cmp QWORD PTR [r11+WorldPointer], r10
    je clearOldPreferences
    cmp QWORD PTR [DispatchPreferencesWorld], r10
    je resetTransientState
clearOldPreferences:
    mov DWORD PTR [r11+Configuration], 0
    mov DWORD PTR [PreferredTruckCapacity], 0
resetTransientState:
    mov QWORD PTR [DispatchPreferencesWorld], r10
    mov QWORD PTR [r11+WorldPointer], 0
    lock inc DWORD PTR [FleetWorldEpoch]
    mov DWORD PTR [r11+ActiveConsole], 0
    mov DWORD PTR [r11+LastMinute], ecx
    xor eax, eax
    xchg DWORD PTR [r11+PendingCount], eax
    mov DWORD PTR [r11+AutoInterval], -1
    mov DWORD PTR [r11+DispatchStatus], 0
    mov DWORD PTR [r11+NextCategory], 0
    mov QWORD PTR [r11+CaptureCounts], 0
    mov DWORD PTR [r11+ExportsCount], 0
    mov DWORD PTR [r11+NextBacklogScan], 0
    mov DWORD PTR [r11+LastBacklogScan], -1
    mov QWORD PTR [r11+BacklogSnapshot], 0
    mov DWORD PTR [r11+LastOutcome], 0
    mov QWORD PTR [r11+NextSpawnTime], 0
    mov QWORD PTR [r11+WorldPointer], r10
nativeUpdate:
    mov rcx, QWORD PTR [rsp+20h]
    add rsp, 58h
    jmp RunNativeUpdate
DispatchNativeUpdate ENDP

; RCX is the road manager, RDX the world, R8D the current game minute.
; Publish the pair together after the native room iteration has completed.
RefreshDispatchBacklog PROC
    sub rsp, 28h
    mov DWORD PTR [rsp+20h], r8d
    lea r11, DispatchState
    mov QWORD PTR [r11+WasteCount], 0
    mov DWORD PTR [r11+CaptureCounts], 1
    add rdx, 3038h
    call CheckNativeBacklog
    lea r11, DispatchState
    mov DWORD PTR [r11+CaptureCounts], 0
    mov rax, QWORD PTR [r11+WasteCount]
    mov QWORD PTR [r11+BacklogSnapshot], rax
    mov eax, DWORD PTR [rsp+20h]
    mov DWORD PTR [r11+LastBacklogScan], eax
    add eax, BacklogScanInterval
    mov DWORD PTR [r11+NextBacklogScan], eax
    add rsp, 28h
    ret
RefreshDispatchBacklog ENDP

; Native backlog scanner ended one zone kind. EBX=category, EBP=cumulative stacks.
; Only collect when our own call is in progress. All original comparison logic runs.
CollectDispatchBacklog PROC
    lea rax, DispatchState
    cmp DWORD PTR [rax+CaptureCounts], 1
    jne resumeBacklog
    test ebx, ebx
    jne saveExports
    mov DWORD PTR [rax+WasteCount], ebp
    jmp resumeBacklog
saveExports:
    mov ecx, ebp
    sub ecx, DWORD PTR [rax+WasteCount]
    mov DWORD PTR [rax+ExportsCount], ecx
resumeBacklog:
    inc rbx
    mov QWORD PTR [rsp+20h], rbx
    jmp ContinueNativeBacklog
CollectDispatchBacklog ENDP

; Native World coordinates match the stock truck spawn column and tile layout.
HasNativeRoad PROC
    mov r8d, DWORD PTR [rcx+70h]
    add r8d, DWORD PTR [rcx+68h]
    sub r8d, 10
    xor eax, eax
    test r8d, r8d
    js roadDone
    cmp r8d, DWORD PTR [rcx+60h]
    jge roadDone
    cmp DWORD PTR [rcx+64h], 1
    jle roadDone
    mov rdx, QWORD PTR [rcx+48E8h]
    test rdx, rdx
    jz roadDone
    add r8d, DWORD PTR [rcx+60h]  ; Entrance tile at y=1.
    imul r8, r8, 0E0h
    movsxd r8, DWORD PTR [rdx+r8+18h]
    test r8d, r8d
    js roadDone
    cmp r8d, DWORD PTR [MaterialDefCount]
    jge roadDone
    mov rcx, QWORD PTR [MaterialDefTable]
    test rcx, rcx
    jz roadDone
    imul r8, r8, 248h
    add rcx, r8
    mov r8, QWORD PTR [rcx+10h]
    cmp r8, 4
    jb roadDone
    cmp QWORD PTR [rcx+18h], 15
    jbe roadName
    mov rcx, QWORD PTR [rcx]
    test rcx, rcx
    jz roadDone
roadName:
    cmp DWORD PTR [rcx], 64616F52h  ; Road.
    jne roadDone
    cmp r8, 4
    je roadFound
    cmp r8, 12
    jb roadDone
    mov rdx, 73676E696B72614Dh     ; Markings.
    cmp QWORD PTR [rcx+4], rdx
    je checkRoadMarkingsLength
    cmp r8, 12
    jne roadDone
    mov rdx, 676E6973736F7243h     ; Crossing.
    cmp QWORD PTR [rcx+4], rdx
    je roadFound
    jmp roadDone
checkRoadMarkingsLength:
    cmp r8, 12
    je roadFound
    cmp r8, 16
    jne checkRoadMarkingsRight
    cmp DWORD PTR [rcx+12], 7466654Ch
    je roadFound
    jmp roadDone
checkRoadMarkingsRight:
    cmp r8, 17
    jne roadDone
    cmp DWORD PTR [rcx+12], 68676952h
    jne roadDone
    cmp BYTE PTR [rcx+16], 74h
    jne roadDone
roadFound:
    mov eax, 1
roadDone:
    ret
HasNativeRoad ENDP

; Every stock world allocation calls this constructor, even if an address is reused.
ResetDispatchForWorldConstruction PROC
    mov QWORD PTR [rsp+8], rcx  ; Displaced instruction at the constructor entry.
    lea r11, DispatchState
    mov QWORD PTR [r11+WorldPointer], 0
    mov QWORD PTR [DispatchPreferencesWorld], rcx
    mov DWORD PTR [r11+ActiveConsole], 0
    xor eax, eax
    xchg DWORD PTR [r11+PendingCount], eax
    mov DWORD PTR [r11+Configuration], 0
    mov DWORD PTR [r11+NextBacklogScan], 0
    mov DWORD PTR [r11+LastOutcome], 0
    mov DWORD PTR [PreferredTruckCapacity], 0
    lock inc DWORD PTR [FleetWorldEpoch]
    jmp ContinueWorldConstruction
ResetDispatchForWorldConstruction ENDP

END

option casemap:none

EXTERN AfterLoadCapacity:PROC
EXTERN AfterCheckGarbageCapacity:PROC
EXTERN AfterCheckExportsCapacity:PROC
EXTERN SkipGarbageStop:PROC
EXTERN SkipExportsStop:PROC
EXTERN AfterSlotSearchLimit:PROC
EXTERN AfterInitialInsertCheck:PROC
EXTERN TryNextInsertSlot:PROC
EXTERN AfterInsertLoop:PROC
EXTERN AfterGetInsertCapacity:PROC
EXTERN AfterCheckInsertSlot:PROC
EXTERN RejectInsertSlot:PROC
EXTERN CreateNativeObject:PROC
EXTERN DispatchSpawnReturn:BYTE
EXTERN PreferredTruckCapacity:DWORD

PUBLIC GetTruckCapacity, LoadCapacity, CheckGarbageCapacity, CheckExportsCapacity
PUBLIC SlotSearchLimit, InitialInsertCheck, InsertLoopCheck, GetInsertCapacity, CheckInsertSlot
PUBLIC ConstructSupplyTruck

SupplyTruckKind EQU 8Bh
NameCapacity    EQU 90h
NameLength      EQU 88h
NameBytes       EQU 78h

.code

; RCX = object. The stock kind and inline name validate the per-vehicle length.
; Preserve all registers except EAX and flags so the helper is usable from
; inline native call sites with live arguments.
GetTruckCapacity PROC
    mov eax, 8
    test rcx, rcx
    jz gotCapacity
    cmp DWORD PTR [rcx+40h], SupplyTruckKind
    jne gotCapacity
    cmp QWORD PTR [rcx+NameLength], 12
    jne gotCapacity
    cmp QWORD PTR [rcx+NameCapacity], 15
    jne gotCapacity
    cmp DWORD PTR [rcx+NameBytes], 444F4150h ; PAOD
    jne gotCapacity
    cmp DWORD PTR [rcx+NameBytes+4], 31304E5Fh ; _N01, _E01 or _G01
    je checkCapacitySuffix
    cmp DWORD PTR [rcx+NameBytes+4], 3130455Fh
    je checkCapacitySuffix
    cmp DWORD PTR [rcx+NameBytes+4], 3130475Fh
    jne gotCapacity
checkCapacitySuffix:
    cmp BYTE PTR [rcx+NameBytes+12], 0
    jne gotCapacity
    cmp DWORD PTR [rcx+NameBytes+8], 4C32312Dh ; -12L
    je twelveSlots
    cmp DWORD PTR [rcx+NameBytes+8], 4C36312Dh ; -16L
    jne gotCapacity
    mov eax, 16
    ret
twelveSlots:
    mov eax, 12
gotCapacity:
    ret
GetTruckCapacity ENDP

; Native loading job planner: count space before generating cargo moves.
LoadCapacity PROC
    cmp DWORD PTR [r13+40h], SupplyTruckKind
    jne loadOtherVehicle
    mov rcx, r13
    call GetTruckCapacity
    mov esi, eax
    jmp loadCargoArray
loadOtherVehicle:
    mov esi, DWORD PTR [rcx+7Ch]
loadCargoArray:
    lea rax, [r13+0D8h]
    jmp AfterLoadCapacity
LoadCapacity ENDP

CHECK_PICKUP_CAPACITY MACRO FullStop, AvailableStop
    mov r9d, eax
    mov rcx, rsi
    call GetTruckCapacity
    cmp r9d, eax
    mov eax, r9d
    jge FullStop
    jmp AvailableStop
ENDM

CheckGarbageCapacity PROC
    CHECK_PICKUP_CAPACITY SkipGarbageStop, AfterCheckGarbageCapacity
CheckGarbageCapacity ENDP

CheckExportsCapacity PROC
    CHECK_PICKUP_CAPACITY SkipExportsStop, AfterCheckExportsCapacity
CheckExportsCapacity ENDP

; The native free-slot search accepts an optional upper slot index.
SlotSearchLimit PROC
    cmp DWORD PTR [rcx+40h], SupplyTruckKind
    jne nativeSearchLimit
    call GetTruckCapacity
    dec eax
    mov ecx, DWORD PTR [rsp+88h]
    test ecx, ecx
    cmovs ecx, eax
    cmp ecx, eax
    cmovg ecx, eax
    jmp AfterSlotSearchLimit
nativeSearchLimit:
    mov ecx, DWORD PTR [rsp+88h]
    test ecx, ecx
    js capNativeSearch
    mov eax, DWORD PTR [r10+7Ch]
    dec eax
    cmp ecx, eax
    jle searchLimitReady
capNativeSearch:
    mov ecx, DWORD PTR [r10+7Ch]
    dec ecx
searchLimitReady:
    jmp AfterSlotSearchLimit
SlotSearchLimit ENDP

; The native insertion function uses the parallel object/cargo definitions for
; its asset keys and filters. Resolve only the bound, leaving the pointer intact.
INSERT_CAPACITY MACRO
    LOCAL insertBoundReady
    mov eax, DWORD PTR [rdi+7Ch]
    cmp DWORD PTR [rsi+40h], SupplyTruckKind
    jne insertBoundReady
    mov r9, rcx
    mov rcx, rsi
    call GetTruckCapacity
    mov rcx, r9
insertBoundReady:
ENDM

InitialInsertCheck PROC
    INSERT_CAPACITY
    cmp eax, ebx
    jle RejectInsertSlot
    jmp AfterInitialInsertCheck
InitialInsertCheck ENDP

InsertLoopCheck PROC
    INSERT_CAPACITY
    cmp ebx, eax
    jl TryNextInsertSlot
    jmp AfterInsertLoop
InsertLoopCheck ENDP

GetInsertCapacity PROC
    INSERT_CAPACITY
    mov r8d, eax
    test r8d, r8d
    jmp AfterGetInsertCapacity
GetInsertCapacity ENDP

CheckInsertSlot PROC
    INSERT_CAPACITY
    cmp r15d, eax
    jge RejectInsertSlot
    jmp AfterCheckInsertSlot
CheckInsertSlot ENDP

; SupplyTruck factory from the normal native create/position/register routine.
; Only the dispatcher's exact caller continuation can request a long truck.
; The length is attached before native position/bounds registration.
ConstructSupplyTruck PROC
    sub rsp, 38h
    xor r10d, r10d
    lea rax, DispatchSpawnReturn
    cmp QWORD PTR [rsp+68h], rax
    jne createTruck
    mov r10d, DWORD PTR [PreferredTruckCapacity]
createTruck:
    mov DWORD PTR [rsp+20h], r10d
    call CreateNativeObject
    test rax, rax
    jz truckCreated
    cmp DWORD PTR [rax+40h], SupplyTruckKind
    jne truckCreated
    cmp QWORD PTR [rax+NameLength], 0
    jne truckCreated
    cmp QWORD PTR [rax+NameCapacity], 15
    jne truckCreated
    mov ecx, DWORD PTR [rsp+20h]
    mov edx, 4C32312Dh
    cmp ecx, 12
    je recordTruckLength
    mov edx, 4C36312Dh
    cmp ecx, 16
    jne truckCreated
recordTruckLength:
    mov rcx, 31304E5F444F4150h   ; PAOD_N01
    mov QWORD PTR [rax+NameBytes], rcx
    mov DWORD PTR [rax+NameBytes+8], edx
    mov BYTE PTR [rax+NameBytes+12], 0
    mov QWORD PTR [rax+NameLength], 12
truckCreated:
    add rsp, 38h
    ret
ConstructSupplyTruck ENDP

END

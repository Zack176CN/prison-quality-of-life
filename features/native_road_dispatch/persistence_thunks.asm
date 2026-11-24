option casemap:none

EXTERN WriteWorldProperties:PROC
EXTERN ReadWorldProperties:PROC
EXTERN InsertSaveProperty:PROC
EXTERN FindSaveProperty:PROC
EXTERN DispatchSaveKey:BYTE
EXTERN DispatchState:QWORD
EXTERN DispatchPreferencesWorld:QWORD
EXTERN PreferredTruckCapacity:DWORD
EXTERN StoreDispatchConfiguration:PROC

PUBLIC SaveDispatchPreferences
PUBLIC LoadDispatchPreferences

Configuration EQU 10h
DefaultConfiguration EQU 00080200h
SettingsVersion EQU 40000000h

.code

; The stock writer has World in RBX and its root directory in R14.
SaveDispatchPreferences PROC
    sub rsp, 28h
    call WriteWorldProperties
    cmp QWORD PTR [DispatchPreferencesWorld], rbx
    jne saveDone
    lea r10, DispatchState
    mov edx, DWORD PTR [r10+Configuration]
    mov ecx, DWORD PTR [PreferredTruckCapacity]
    xor eax, eax
    cmp ecx, 12
    je saveMidLength
    cmp ecx, 16
    jne packSettings
    mov eax, 04000000h
    jmp packSettings
saveMidLength:
    mov eax, 02000000h
packSettings:
    test edx, edx
    jnz writeSettings
    test eax, eax
    jz saveDone
    mov edx, DefaultConfiguration
writeSettings:
    or eax, edx
    or eax, SettingsVersion
    mov DWORD PTR [rsp+20h], eax
    mov rcx, r14
    lea rdx, DispatchSaveKey
    call InsertSaveProperty
    test rax, rax
    jz saveDone
    mov DWORD PTR [rax+20h], 1 ; Native signed 32-bit property.
    mov edx, DWORD PTR [rsp+20h]
    mov DWORD PTR [rax+24h], edx
saveDone:
    add rsp, 28h
    ret
SaveDispatchPreferences ENDP

; The stock reader has World in RSI and its parsed root directory in R13.
LoadDispatchPreferences PROC
    sub rsp, 28h
    call ReadWorldProperties
    lea r10, DispatchState
    mov QWORD PTR [r10], 0 ; Let the next tick initialize the transient queue.
    mov DWORD PTR [r10+Configuration], 0
    mov DWORD PTR [PreferredTruckCapacity], 0
    mov QWORD PTR [DispatchPreferencesWorld], rsi
    mov rcx, r13
    lea rdx, DispatchSaveKey
    call FindSaveProperty
    test rax, rax
    jz loadDone
    cmp DWORD PTR [rax+20h], 1
    jne loadDone
    mov eax, DWORD PTR [rax+24h]
    mov edx, eax
    and edx, 0F8000000h
    cmp edx, SettingsVersion
    jne loadDone
    mov ecx, eax
    shr ecx, 25
    and ecx, 3
    cmp ecx, 3
    je loadDone
    mov DWORD PTR [rsp+20h], ecx
    movzx ecx, al
    movzx edx, ah
    mov r8d, eax
    shr r8d, 16
    and r8d, 0FFh
    mov r9d, eax
    shr r9d, 24
    and r9d, 1
    call StoreDispatchConfiguration
    test eax, eax
    jz loadDone
    mov ecx, DWORD PTR [rsp+20h]
    lea eax, [rcx*4+8]
    mov DWORD PTR [PreferredTruckCapacity], eax
loadDone:
    add rsp, 28h
    ret
LoadDispatchPreferences ENDP

END

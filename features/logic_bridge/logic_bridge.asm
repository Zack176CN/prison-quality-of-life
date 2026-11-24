OPTION CASEMAP:NONE

EXTERN Game:QWORD
EXTERN BroadcastOutput:PROC
EXTERN NativeVisitedScan:PROC
EXTERN NativeNotVisited:PROC
EXTERN NativeAlreadyVisited:PROC
EXTERN GetProcessHeapImport:QWORD
EXTERN HeapAllocImport:QWORD
EXTERN HeapFreeImport:QWORD

; The original BroadcastOutput drops RBP to caller RSP - 67h. Its own
; highest caller-shadow access is [rbp+7Fh]. These are wrapper locals.
ContextBitmap EQU 87h
ContextWorld EQU 8Fh
ContextWidth EQU 97h
ContextHeight EQU 9Bh
ContextHeap EQU 9Fh
MaximumCells EQU 40000h
MinimumVisited EQU 32
HeapZeroMemory EQU 8

.code

PUBLIC BroadcastWithVisitedBitmap
BroadcastWithVisitedBitmap PROC
    sub rsp, 48h
    xor eax, eax
    mov QWORD PTR [rsp+20h], rax
    mov QWORD PTR [rsp+28h], rax
    mov QWORD PTR [rsp+30h], rax
    mov QWORD PTR [rsp+38h], rax
    call BroadcastOutput
    mov r8, QWORD PTR [rsp+20h]
    test r8, r8
    jle broadcastDone
    mov QWORD PTR [rsp+20h], 0
    mov rcx, QWORD PTR [rsp+38h]
    xor edx, edx
    call QWORD PTR [HeapFreeImport]
broadcastDone:
    add rsp, 48h
    ret
BroadcastWithVisitedBitmap ENDP

; Windows invokes this termination handler if the wrapper is unwound.
; EstablisherFrame (RDX) points to its fixed post-prologue RSP.
PUBLIC FreeVisitedBitmapOnUnwind
FreeVisitedBitmapOnUnwind PROC
    sub rsp, 28h
    mov r8, QWORD PTR [rdx+20h]
    test r8, r8
    jle handlerDone
    mov QWORD PTR [rdx+20h], 0
    mov rcx, QWORD PTR [rdx+38h]
    xor edx, edx
    call QWORD PTR [HeapFreeImport]
handlerDone:
    mov eax, 1                         ; ExceptionContinueSearch
    add rsp, 28h
    ret
FreeVisitedBitmapOnUnwind ENDP

; Runs on the original BroadcastOutput frame without moving RSP.
; RBX and RDI are the candidate X and Y. R12 and ESI are the stock
; visited list and its length. Original appends and order stay in place.
PUBLIC CheckVisited
CheckVisited PROC
    mov rax, QWORD PTR [rbp+ContextBitmap]
    test rax, rax
    jg bitmapReady
    js originalCheck
    cmp esi, MinimumVisited
    jl originalCheck
    call InitializeVisitedBitmap
    mov rax, QWORD PTR [rbp+ContextBitmap]
    test rax, rax
    jle originalCheck
bitmapReady:
    mov rdx, QWORD PTR [Game]
    test rdx, rdx
    jz invalidateBitmap
    mov rdx, QWORD PTR [rdx+198h]
    test rdx, rdx
    jz invalidateBitmap
    cmp rdx, QWORD PTR [rbp+ContextWorld]
    jne invalidateBitmap
    mov r8d, DWORD PTR [rdx+60h]
    mov r9d, DWORD PTR [rdx+64h]
    cmp r8d, DWORD PTR [rbp+ContextWidth]
    jne invalidateBitmap
    cmp r9d, DWORD PTR [rbp+ContextHeight]
    jne invalidateBitmap
    cmp ebx, r8d
    jae originalCheck
    cmp edi, r9d
    jae originalCheck
    imul r8d, edi
    add r8d, ebx
    bts DWORD PTR [rax], r8d
    jc NativeAlreadyVisited
    jmp NativeNotVisited

invalidateBitmap:
    ; Leave the pointer available to the wrapper cleanup.
    mov QWORD PTR [rbp+ContextWorld], 0
originalCheck:
    xor ecx, ecx
    test esi, esi
    jle NativeNotVisited
    jmp NativeVisitedScan
CheckVisited ENDP

PUBLIC InitializeVisitedBitmap
InitializeVisitedBitmap PROC
    sub rsp, 28h
    ; Prevent repeat attempts on an oversized map or a failed allocation.
    mov QWORD PTR [rbp+ContextBitmap], -1
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz initDone
    mov rax, QWORD PTR [rax+198h]
    test rax, rax
    jz initDone
    mov QWORD PTR [rbp+ContextWorld], rax
    mov edx, DWORD PTR [rax+60h]
    mov ecx, DWORD PTR [rax+64h]
    lea eax, [rdx-1]
    cmp eax, MaximumCells-1
    ja initDone
    lea eax, [rcx-1]
    cmp eax, MaximumCells-1
    ja initDone
    mov DWORD PTR [rbp+ContextWidth], edx
    mov DWORD PTR [rbp+ContextHeight], ecx
    imul ecx, edx
    jo initDone
    cmp ecx, MaximumCells
    ja initDone
    add ecx, 31
    shr ecx, 5
    shl ecx, 2
    mov DWORD PTR [rsp+20h], ecx

    call QWORD PTR [GetProcessHeapImport]
    test rax, rax
    jz initDone
    mov QWORD PTR [rbp+ContextHeap], rax
    mov rcx, rax
    mov edx, HeapZeroMemory
    mov r8d, DWORD PTR [rsp+20h]
    call QWORD PTR [HeapAllocImport]
    test rax, rax
    jz initDone
    mov QWORD PTR [rbp+ContextBitmap], rax

    ; Copy membership from the original list, including its seed.
    mov r8d, DWORD PTR [rbp+ContextWidth]
    mov r9d, DWORD PTR [rbp+ContextHeight]
    mov r10, r12
    mov r11d, esi
seedLoop:
    mov ecx, DWORD PTR [r10]
    mov edx, DWORD PTR [r10+4]
    cmp ecx, r8d
    jae nextSeed
    cmp edx, r9d
    jae nextSeed
    imul edx, r8d
    add edx, ecx
    bts DWORD PTR [rax], edx
nextSeed:
    add r10, 12
    sub r11d, 1
    jnz seedLoop
initDone:
    add rsp, 28h
    ret
InitializeVisitedBitmap ENDP
END

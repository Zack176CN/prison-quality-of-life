; Pack a replaced door with the same native object and teardown as Dismantle.
OPTION CASEMAP:NONE

EXTERN ResolveObjectHandle:PROC
EXTERN GetWorldCell:PROC
EXTERN GetCellMaterial:PROC
EXTERN CreateDismantledItem:PROC
EXTERN RotateDismantledItem:PROC
EXTERN DismantledRotation:DWORD
EXTERN RemoveWorldObject:PROC

.code

PUBLIC RecoverOldDoor
RecoverOldDoor PROC
    ; RCX is the active world, RDX the exact UID/index of an eligible old door.
    sub rsp, 78h
    mov qword ptr [rsp+30h], rcx
    mov rax, qword ptr [rdx]
    mov qword ptr [rsp+38h], rax
    lea rdx, [rsp+38h]
    call ResolveObjectHandle
    test rax, rax
    jz recovery_done
    cmp byte ptr [rax+6Ch], 0
    jne recovery_done
    mov qword ptr [rsp+40h], rax
    mov ecx, dword ptr [rax+40h]
    mov dword ptr [rsp+48h], ecx
    cvttss2si edx, dword ptr [rax+48h]
    cvttss2si r8d, dword ptr [rax+4Ch]
    mov dword ptr [rsp+4Ch], edx
    mov dword ptr [rsp+50h], r8d
    ; Prefer a nearby floor on the old door's passage axis. The original
    ; cell may now contain a finished wall or a locked replacement door.
    mov eax, dword ptr [rax+54h]
    and eax, 7FFFFFFFh
    setne byte ptr [rsp+68h]
    mov dword ptr [rsp+5Ch], 0
try_neighbor:
    mov edx, dword ptr [rsp+4Ch]
    mov r8d, dword ptr [rsp+50h]
    mov eax, dword ptr [rsp+5Ch]
    cmp eax, 4
    je pack_door
    mov r9d, eax
    and r9d, 1
    lea r9d, [r9*2-1]
    shr eax, 1
    xor al, byte ptr [rsp+68h]
    test al, al
    jnz horizontal_neighbor
    add r8d, r9d
    jmp check_cell
horizontal_neighbor:
    add edx, r9d
check_cell:
    mov rcx, qword ptr [rsp+30h]
    cmp edx, dword ptr [rcx+60h]
    jae next_neighbor
    cmp r8d, dword ptr [rcx+64h]
    jae next_neighbor
    mov dword ptr [rsp+54h], edx
    mov dword ptr [rsp+58h], r8d
    call GetWorldCell
    test rax, rax
    jz next_neighbor
    mov rcx, rax
    call GetCellMaterial
    cmp byte ptr [rax+48h], 0
    jne next_neighbor
    mov edx, dword ptr [rsp+54h]
    mov r8d, dword ptr [rsp+58h]
    jmp pack_door
next_neighbor:
    inc dword ptr [rsp+5Ch]
    jmp try_neighbor
pack_door:
    mov rcx, qword ptr [rsp+30h]
    cvtsi2ss xmm1, edx
    cvtsi2ss xmm2, r8d
    mov r9d, dword ptr [rsp+48h]
    mov dword ptr [rsp+20h], 1
    call CreateDismantledItem
    test rax, rax
    jz recovery_done
    mov qword ptr [rsp+60h], rax
    lea rdx, [rax+38h]
    mov rcx, qword ptr [rsp+30h]
    call ResolveObjectHandle
    cmp rax, qword ptr [rsp+60h]
    jne recovery_done
    mov rcx, qword ptr [rsp+40h]
    cmp byte ptr [rcx+70h], 0
    je dismantle_old
    mov byte ptr [rax+70h], 1
dismantle_old:
    mov rdx, qword ptr [rcx]
    call qword ptr [rdx+60h]
    mov rcx, qword ptr [rsp+60h]
    add rcx, 54h
    movss xmm1, DismantledRotation
    call RotateDismantledItem
    mov rcx, qword ptr [rsp+40h]
    mov edx, dword ptr [rcx+1F4h]
    mov rax, qword ptr [rsp+60h]
    mov dword ptr [rax+1F4h], edx
    mov rcx, qword ptr [rsp+30h]
    lea rdx, [rsp+38h]
    call RemoveWorldObject
recovery_done:
    add rsp, 78h
    ret
RecoverOldDoor ENDP

END

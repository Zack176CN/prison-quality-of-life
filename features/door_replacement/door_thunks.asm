; Windows x64 continuations for replacing one- or two-cell doors.
OPTION CASEMAP:NONE

EXTERN InputManager:QWORD
EXTERN Game:QWORD
EXTERN ObjectDefTable:QWORD
EXTERN ObjectDefCount:DWORD
EXTERN PendingCell:QWORD
EXTERN PendingType:DWORD
EXTERN PendingId:QWORD
EXTERN PendingOldAnchor:QWORD
EXTERN PendingOldSize:QWORD
EXTERN IgnoreCommand:QWORD
EXTERN IgnoreId:QWORD

EXTERN ResolveObjectHandle:PROC
EXTERN GetObjectFootprint:PROC
EXTERN ValidateConstruction:PROC
EXTERN CommitConstruction:PROC
EXTERN IsObjectCarried:PROC
EXTERN ResumeObjectTool:PROC
EXTERN ResumeCollisionCheck:PROC
EXTERN NextObject:PROC
EXTERN FinishNewObject:PROC
EXTERN CompleteOriginalJob:PROC
EXTERN LeaveOriginalJob:PROC
EXTERN RecoverOldDoor:PROC
EXTERN RemoveWorldObject:PROC

.code

PUBLIC IsSmallDoor
IsSmallDoor PROC
    xor eax, eax
    test ecx, ecx
    js not_single
    cmp ecx, ObjectDefCount
    jge not_single
    movsxd rcx, ecx
    imul rcx, rcx, 198h
    mov rdx, ObjectDefTable
    test rdx, rdx
    jz not_single
    add rcx, rdx
    test byte ptr [rcx+98h], 40h
    jz not_single
    mov edx, dword ptr [rcx+40h]
    dec edx
    cmp edx, 1
    ja not_single
    mov ecx, dword ptr [rcx+44h]
    dec ecx
    cmp ecx, 1
    ja not_single
    add ecx, edx
    cmp ecx, 1
    setbe al
not_single:
    ret
IsSmallDoor ENDP

PUBLIC CaptureClick
CaptureClick PROC
    ; Existing object-tool stack is already aligned with the caller home area.
    movzx ebp, al
    mov qword ptr PendingId, 0
    test bpl, bpl
    jz click_done
    cmp byte ptr [rdi+48h], 0
    je click_done
    cmp dword ptr [rdi+70h], 7
    jne click_done
    cmp dword ptr [rdi+84h], 2
    jne click_done
    mov rax, InputManager
    test rax, rax
    jz click_done
    ; The native tool repeats while held. Only the left-button down edge may replace.
    cmp byte ptr [rax+14Dh], 0
    je click_done
    mov ecx, dword ptr [rdi+74h]
    call IsSmallDoor
    test al, al
    jz click_done
    mov rax, Game
    test rax, rax
    jz click_done
    mov rcx, qword ptr [rax+198h]
    test rcx, rcx
    jz click_done
    cvttss2si edx, dword ptr [rdi+40h]
    cvttss2si eax, dword ptr [rdi+44h]
    shl rax, 32
    or rdx, rax
    mov r8d, dword ptr [rdi+74h]
    mov r9, qword ptr [rdi+7Ch]
    call CaptureDoorInFootprint
click_done:
    cmp byte ptr [rdi+48h], 0
    jmp ResumeObjectTool
CaptureClick ENDP

PUBLIC CommitDoorWithReplacement
CommitDoorWithReplacement PROC
    sub rsp, 48h
    mov qword ptr [rsp+20h], rcx
    mov dword ptr [rsp+28h], edx
    mov dword ptr [rsp+30h], r8d
    mov dword ptr [rsp+38h], r9d
    mov qword ptr PendingId, 0

    ; The Doors tab under Walls & Doors uses the material toolbar's object
    ; route. The preview has already produced a native command at this point.
    mov eax, dword ptr [rdi+70h]
    sub eax, 2
    cmp eax, 1
    ja commit_stock
    cmp dword ptr [rdi+78h], 2
    jne commit_stock
    cmp dword ptr [rcx+30h], 5
    jne commit_stock
    cmp dword ptr [rcx+44h], 1
    jne commit_stock
    cmp dword ptr [rcx+48h], 1
    jne commit_stock
    cmp qword ptr [rcx+64h], -1
    jne commit_stock

    cmp dword ptr [rdi+84h], 1
    jne check_direct_click
    mov rax, InputManager
    test rax, rax
    jz commit_stock
    cmp byte ptr [rax+150h], 0
    je commit_stock
    jmp capture_toolbar_door
check_direct_click:
    cmp dword ptr [rdi+84h], 2
    jne commit_stock
    test r8b, r8b
    jz commit_stock
capture_toolbar_door:
    mov ecx, dword ptr [rcx+34h]
    call IsSmallDoor
    test al, al
    jz commit_stock
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rcx+38h]
    mov r8d, dword ptr [rcx+34h]
    mov r9, qword ptr [rcx+50h]
    sub rcx, 1288h
    call CaptureDoorInFootprint
commit_stock:
    mov rcx, qword ptr [rsp+20h]
    mov edx, dword ptr [rsp+28h]
    mov r8d, dword ptr [rsp+30h]
    mov r9d, dword ptr [rsp+38h]
    add rsp, 48h
    jmp CommitConstruction
CommitDoorWithReplacement ENDP

PUBLIC CaptureDoorInFootprint
CaptureDoorInFootprint PROC
    sub rsp, 68h
    mov qword ptr [rsp+38h], rcx  ; world
    mov qword ptr [rsp+40h], rdx  ; proposed anchor X, Y
    mov dword ptr [rsp+48h], r8d  ; selected door kind
    mov qword ptr [rsp+50h], r9   ; selected orientation
    mov r9d, r8d
    mov rax, rdx
    shr rax, 32
    mov r8d, eax
    call CaptureExactDoor
    cmp qword ptr PendingId, 0
    jne footprint_done

    ; The request still builds one object. The stock validator scans its
    ; oriented width and height from the command anchor, so a double door
    ; can overlap a single old door entirely in its second cell.
    mov ecx, dword ptr [rsp+48h]
    xor edx, edx
    mov r8, qword ptr [rsp+50h]
    lea r9, [rsp+58h]
    lea rax, [rsp+5Ch]
    mov qword ptr [rsp+20h], rax
    lea rax, [rsp+60h]
    mov qword ptr [rsp+28h], rax
    lea rax, [rsp+64h]
    mov qword ptr [rsp+30h], rax
    call GetObjectFootprint
    mov edx, dword ptr [rsp+40h]
    mov r8d, dword ptr [rsp+44h]
    mov rax, qword ptr [rsp+60h]
    mov rcx, 3F80000040000000h   ; 2.0 wide, 1.0 high.
    cmp rax, rcx
    jne check_vertical_footprint
    inc edx
    jmp capture_second_cell
check_vertical_footprint:
    mov rcx, 400000003F800000h   ; 1.0 wide, 2.0 high.
    cmp rax, rcx
    jne footprint_done
    inc r8d
capture_second_cell:
    mov rcx, qword ptr [rsp+38h]
    mov r9d, dword ptr [rsp+48h]
    call CaptureExactDoor
    cmp qword ptr PendingId, 0
    je footprint_done
    mov rax, 3F8000003F800000h
    cmp qword ptr PendingOldSize, rax
    jne reject_second_cell
    ; Match the submitted native command by its true anchor even when the
    ; old door was selected from the other cell of the proposed footprint.
    mov rax, qword ptr [rsp+40h]
    mov qword ptr PendingCell, rax
    jmp footprint_done
reject_second_cell:
    mov qword ptr PendingId, 0
footprint_done:
    add rsp, 68h
    ret
CaptureDoorInFootprint ENDP

PUBLIC CaptureExactDoor
CaptureExactDoor PROC
    sub rsp, 78h
    mov dword ptr [rsp+38h], edx  ; exact footprint cell X, Y
    mov dword ptr [rsp+3Ch], r8d
    mov dword ptr [rsp+40h], r9d  ; selected new kind
    mov dword ptr [rsp+44h], 0    ; spatial candidate probe index
    mov qword ptr [rsp+48h], rcx  ; world

    ; Some saved objects are found by an adjacent tile's spatial entry. Every
    ; candidate still has to physically cover the requested footprint cell.
find_candidate:
    mov edx, dword ptr [rsp+38h]
    mov r8d, dword ptr [rsp+3Ch]
    mov eax, dword ptr [rsp+44h]
    cmp eax, 1
    jne candidate_two
    dec edx
    jmp read_candidate
candidate_two:
    cmp eax, 2
    jne candidate_three
    inc edx
    jmp read_candidate
candidate_three:
    cmp eax, 3
    jne candidate_four
    dec r8d
    jmp read_candidate
candidate_four:
    cmp eax, 4
    jne read_candidate
    inc r8d
read_candidate:
    mov rcx, qword ptr [rsp+48h]
    test edx, edx
    js next_candidate
    test r8d, r8d
    js next_candidate
    mov eax, dword ptr [rcx+60h]
    cmp edx, eax
    jge next_candidate
    cmp r8d, dword ptr [rcx+64h]
    jge next_candidate
    mov r9, qword ptr [rcx+48E8h]
    test r9, r9
    jz next_candidate
    imul eax, r8d
    add eax, edx
    cdqe
    imul rax, rax, 0E0h
    add rax, r9
    mov qword ptr [rsp+70h], rax
    mov dword ptr [rsp+68h], 0    ; index in this cell's native object list
next_cell_entry:
    mov rdx, qword ptr [rsp+70h]
    movsxd rax, dword ptr [rsp+68h]
    cmp eax, dword ptr [rdx+5Ch]
    jge next_candidate
    mov rcx, qword ptr [rdx+68h]
    test rcx, rcx
    jz next_candidate
    cmp byte ptr [rcx+rax], 0
    je advance_entry
    mov rdx, qword ptr [rdx+60h]
    test rdx, rdx
    jz next_candidate
    lea rdx, [rdx+rax*8]
    mov rcx, qword ptr [rsp+48h]
    call ResolveObjectHandle
    test rax, rax
    jz advance_entry
    cmp byte ptr [rax+6Ch], 0
    jne advance_entry
    cmp byte ptr [rax+6Eh], 0
    jne advance_entry
    mov qword ptr [rsp+50h], rax
    mov ecx, dword ptr [rax+40h]
    cmp ecx, dword ptr [rsp+40h]
    je advance_entry
    call IsSmallDoor
    test al, al
    jz advance_entry

    ; Let the game account for sprite orientation. The native helper writes
    ; the upper-left corner and both dimensions as floats.
    mov rax, qword ptr [rsp+50h]
    mov ecx, dword ptr [rax+40h]
    mov rdx, qword ptr [rax+48h]
    mov r8, qword ptr [rax+54h]
    lea r9, [rsp+58h]
    lea rax, [rsp+5Ch]
    mov qword ptr [rsp+20h], rax
    lea rax, [rsp+60h]
    mov qword ptr [rsp+28h], rax
    lea rax, [rsp+64h]
    mov qword ptr [rsp+30h], rax
    call GetObjectFootprint

    cvttss2si r8d, dword ptr [rsp+58h]
    cvtsi2ss xmm0, r8d
    ucomiss xmm0, dword ptr [rsp+58h]
    jp advance_entry
    jne advance_entry
    mov edx, dword ptr [rsp+38h]
    sub edx, r8d
    cvttss2si eax, dword ptr [rsp+60h]
    cmp edx, eax
    jae advance_entry

    cvttss2si r9d, dword ptr [rsp+5Ch]
    cvtsi2ss xmm0, r9d
    ucomiss xmm0, dword ptr [rsp+5Ch]
    jp advance_entry
    jne advance_entry
    mov edx, dword ptr [rsp+3Ch]
    sub edx, r9d
    cvttss2si eax, dword ptr [rsp+64h]
    cmp edx, eax
    jae advance_entry

    mov dword ptr [rsp+68h], r8d
    mov dword ptr [rsp+6Ch], r9d
    mov rax, qword ptr [rsp+68h]
    mov PendingOldAnchor, rax
    mov rax, qword ptr [rsp+60h]
    mov PendingOldSize, rax
    mov rax, qword ptr [rsp+38h]
    mov PendingCell, rax
    mov eax, dword ptr [rsp+40h]
    mov PendingType, eax
    mov rax, qword ptr [rsp+50h]
    mov rax, qword ptr [rax+38h]
    mov PendingId, rax
    jmp capture_finished
advance_entry:
    inc dword ptr [rsp+68h]
    jmp next_cell_entry
next_candidate:
    inc dword ptr [rsp+44h]
    cmp dword ptr [rsp+44h], 4
    jle find_candidate
capture_finished:
    add rsp, 78h
    ret
CaptureExactDoor ENDP

PUBLIC ValidateWithReplacement
ValidateWithReplacement PROC
    mov rax, PendingId
    test rax, rax
    jz validate_stock
    mov qword ptr PendingId, 0
    cmp dword ptr [rdx], 5
    jne validate_stock
    cmp dword ptr [rdx+14h], 1
    jne validate_stock
    cmp dword ptr [rdx+18h], 1
    jne validate_stock
    cmp qword ptr [rdx+34h], -1
    jne validate_stock
    mov r8, PendingCell
    cmp r8, qword ptr [rdx+8h]
    jne validate_stock
    mov r8d, PendingType
    cmp r8d, dword ptr [rdx+4h]
    jne validate_stock

    ; A command can sit between the mouse event and work-order creation.
    ; Refuse a second command for the same live object in either native queue.
    mov r8d, dword ptr [rcx+294h]
    test r8d, r8d
    jle check_work
    mov r9, qword ptr [rcx+288h]
    test r9, r9
    jz check_work
check_build_item:
    mov r10, qword ptr [r9]
    test r10, r10
    jz next_build_item
    cmp dword ptr [r10], 5
    jne next_build_item
    cmp qword ptr [r10+34h], rax
    je validate_duplicate
next_build_item:
    add r9, 8
    dec r8d
    jnz check_build_item
check_work:
    mov r10, Game
    test r10, r10
    jz validate_stock
    mov r10, qword ptr [r10+198h]
    test r10, r10
    jz validate_stock
    mov r8d, dword ptr [r10+13Ch]
    test r8d, r8d
    jle validate_replacement
    mov r9, qword ptr [r10+130h]
    test r9, r9
    jz validate_replacement
check_work_item:
    mov r10, qword ptr [r9]
    test r10, r10
    jz next_work_item
    cmp dword ptr [r10+20h], 2
    jne next_work_item
    cmp dword ptr [r10+0B4h], -13
    jne next_work_item
    cmp qword ptr [r10+0C0h], rax
    je validate_duplicate
next_work_item:
    add r9, 8
    dec r8d
    jnz check_work_item
validate_replacement:
    mov IgnoreId, rax
    mov IgnoreCommand, rdx
    jmp ValidateScoped
validate_duplicate:
    mov dword ptr [rdx+28h], -2
    ret
validate_stock:
    jmp ValidateConstruction
ValidateWithReplacement ENDP

PUBLIC ValidateScoped
ValidateScoped PROC
    sub rsp, 78h
    mov qword ptr [rsp+50h], rcx
    mov qword ptr [rsp+58h], rdx
    mov rax, qword ptr [rdx+8h]
    mov qword ptr [rsp+60h], rax
    cmp rax, PendingOldAnchor
    je validate_scoped_command
    mov rax, PendingOldSize
    mov r8, 3F8000003F800000h     ; two float values of 1.0: a single-cell target
    cmp rax, r8
    je validate_scoped_command

    ; Keep a like-shaped double door on the original cells even if the user
    ; clicked the second half. A rotated or single replacement uses the click.
    mov ecx, dword ptr [rdx+4h]
    mov r8, qword ptr [rdx+20h]
    xor edx, edx
    lea r9, [rsp+38h]
    lea rax, [rsp+3Ch]
    mov qword ptr [rsp+20h], rax
    lea rax, [rsp+40h]
    mov qword ptr [rsp+28h], rax
    lea rax, [rsp+44h]
    mov qword ptr [rsp+30h], rax
    call GetObjectFootprint
    mov rax, qword ptr [rsp+40h]
    cmp rax, PendingOldSize
    jne validate_scoped_command
    mov rdx, qword ptr [rsp+58h]
    mov rax, PendingOldAnchor
    mov qword ptr [rdx+8h], rax
validate_scoped_command:
    mov rcx, qword ptr [rsp+50h]
    mov rdx, qword ptr [rsp+58h]
    call ValidateConstruction
    mov rdx, qword ptr [rsp+58h]
    mov qword ptr IgnoreCommand, 0
    cmp dword ptr [rdx+28h], 0
    jle restore_candidate
    cmp dword ptr [rdx+0D4h], 1
    jne unexpected_candidates
    ; Native object construction serializes this handle as Move.u/Move.i.
    ; Its updater requests stock atomic replacement rather than a normal build.
    mov rax, IgnoreId
    mov qword ptr [rdx+34h], rax
    jmp validation_done
unexpected_candidates:
    mov dword ptr [rdx+28h], -2
restore_candidate:
    mov rax, qword ptr [rsp+60h]
    mov qword ptr [rdx+8h], rax
validation_done:
    add rsp, 78h
    ret
ValidateScoped ENDP

PUBLIC ExcludeReplacedDoor
ExcludeReplacedDoor PROC
    mov rcx, IgnoreCommand
    cmp rcx, qword ptr [rbp+2C8h]
    jne ordinary_collision
    mov rcx, IgnoreId
    cmp rcx, qword ptr [r10+38h]
    je skip_old_door
ordinary_collision:
    mov rcx, rax
    call IsObjectCarried
    jmp ResumeCollisionCheck
skip_old_door:
    jmp NextObject
ExcludeReplacedDoor ENDP

PUBLIC PreserveDoorOnBuildFailure
PreserveDoorOnBuildFailure PROC
    ; The replaced branch uses the native resolved-new-object test.
    jnz new_object_ready
    cmp dword ptr [rdi+20h], 2
    jne original_completion
    cmp dword ptr [rdi+0B4h], -13
    jne original_completion
    test r12, r12
    jz original_completion
    mov rax, Game
    mov rcx, qword ptr [rax+198h]
    lea rdx, [rdi+0C0h]
    call ResolveObjectHandle
    cmp rax, r12
    jne original_completion
    mov ecx, dword ptr [r12+40h]
    cmp ecx, dword ptr [rdi+4Ch]
    je original_completion
    call IsSmallDoor
    test al, al
    jz original_completion
    mov ecx, dword ptr [rdi+4Ch]
    call IsSmallDoor
    test al, al
    jz original_completion
    ; Leave the still-valid original door in the world if creation failed.
    jmp LeaveOriginalJob
new_object_ready:
    jmp FinishNewObject
original_completion:
    jmp CompleteOriginalJob
PreserveDoorOnBuildFailure ENDP

PUBLIC RecoverDoorJob
RecoverDoorJob PROC
    ; The stock completion has already placed and initialized the new door.
    ; Its ordinary consumed-object, dismantle and scripted jobs stay native.
    sub rsp, 38h
    mov qword ptr [rsp+20h], rcx
    mov qword ptr [rsp+28h], rdx
    cmp dword ptr [rdi+20h], 2
    jne remove_normally
    cmp dword ptr [rdi+0B4h], -13
    jne remove_normally
    lea rax, [rdi+0C0h]
    cmp rdx, rax
    jne remove_normally
    test r12, r12
    jz remove_normally
    mov ecx, dword ptr [r12+40h]
    cmp ecx, dword ptr [rdi+4Ch]
    je remove_normally
    call IsSmallDoor
    test al, al
    jz remove_normally
    mov ecx, dword ptr [rdi+4Ch]
    call IsSmallDoor
    test al, al
    jz remove_normally
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rsp+28h]
    add rsp, 38h
    jmp RecoverOldDoor
remove_normally:
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rsp+28h]
    add rsp, 38h
    jmp RemoveWorldObject
RecoverDoorJob ENDP

END

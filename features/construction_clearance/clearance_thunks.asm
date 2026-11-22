; Keep accepted wall/door commands pending while workers clear their tree footprint.
OPTION CASEMAP:NONE

EXTERN Game:QWORD
EXTERN ObjectDefCount:DWORD
EXTERN ObjectDefTable:QWORD
EXTERN MaterialValidatorReturn:PROC
EXTERN OrdinaryWallValidatorReturn:PROC
EXTERN ReadStockWallFlags:PROC
EXTERN ContinueWallObjectLoop:PROC
EXTERN ContinueDoorObjectLoop:PROC
EXTERN CheckNativeMoveSlot:PROC
EXTERN CheckNativeDoorCollisions:PROC
EXTERN ContinueCommandDispatch:PROC
EXTERN ContinuePendingCancellation:PROC
EXTERN FinishPendingCancellation:PROC
EXTERN IsWallMaterial:PROC
EXTERN GetObjectFootprint:PROC
EXTERN ResolveObjectHandle:PROC
EXTERN IsObjectCarried:PROC
EXTERN FindObjectJob:PROC
EXTERN ScheduleDismantle:PROC
EXTERN ScheduleStumpRemoval:PROC
EXTERN CancelWorkBatch:PROC
EXTERN CancelConstructionBatch:PROC

TreeObject EQU 037h
TreeStumpObject EQU 012Eh
WallCommand EQU 3
ObjectCommand EQU 5
PendingStatus EQU 1
ActiveStatus EQU 2
TreeDismantleJob EQU 6
StumpRemovalJob EQU 7

CHECK_SMALL_DOOR MACRO type32:req, definition64:req, fallback:req
    LOCAL check_tall_door, eligible_door
    test type32, type32
    js fallback
    cmp type32, ObjectDefCount
    jge fallback
    movsxd definition64, type32
    imul definition64, definition64, 198h
    mov r9, ObjectDefTable
    test r9, r9
    jz fallback
    add definition64, r9
    test byte ptr [definition64+98h], 40h
    jz fallback
    cmp dword ptr [definition64+44h], 1
    jne check_tall_door
    cmp dword ptr [definition64+40h], 1
    je eligible_door
    cmp dword ptr [definition64+40h], 2
    jne fallback
    jmp eligible_door
check_tall_door:
    cmp dword ptr [definition64+40h], 1
    jne fallback
    cmp dword ptr [definition64+44h], 2
    jne fallback
eligible_door:
ENDM

.code

PUBLIC AllowTreeInWallPlan
AllowTreeInWallPlan PROC
    cmp r8d, TreeObject
    je check_wall_origin
    cmp r8d, TreeStumpObject
    jne stock_wall_flags
check_wall_origin:
    ; Both wall validator paths have verified the material before scanning objects.
    lea rax, MaterialValidatorReturn
    cmp qword ptr [rsp+98h], rax
    je allow_wall_plan
    lea rax, OrdinaryWallValidatorReturn
    cmp qword ptr [rsp+98h], rax
    je allow_wall_plan
stock_wall_flags:
    test byte ptr [rcx+88h], 1
    jmp ReadStockWallFlags
allow_wall_plan:
    jmp ContinueWallObjectLoop
AllowTreeInWallPlan ENDP

PUBLIC AllowTreeInDoorPlan
AllowTreeInDoorPlan PROC
    cmp dword ptr [r10+40h], TreeObject
    je check_door_command
    cmp dword ptr [r10+40h], TreeStumpObject
    jne stock_door_collisions
check_door_command:
    ; The native carriages/ghost-object check already ran. Only new small doors qualify.
    mov rax, qword ptr [rbp+2C8h]
    cmp dword ptr [rax], ObjectCommand
    jne stock_door_collisions
    cmp dword ptr [rax+14h], 1
    jne stock_door_collisions
    cmp dword ptr [rax+18h], 1
    jne stock_door_collisions
    cmp qword ptr [rax+34h], -1
    jne stock_door_collisions
    mov ecx, dword ptr [rax+4h]
    CHECK_SMALL_DOOR ecx, rcx, stock_door_collisions
    jmp ContinueDoorObjectLoop
stock_door_collisions:
    cmp dword ptr [r14], -1
    je no_native_move
    jmp CheckNativeMoveSlot
no_native_move:
    jmp CheckNativeDoorCollisions
AllowTreeInDoorPlan ENDP

PUBLIC DispatchClearance
DispatchClearance PROC
    mov eax, dword ptr [rdx+28h]
    cmp eax, PendingStatus
    je check_clearance_kind
    cmp eax, ActiveStatus
    jne stock_dispatch
check_clearance_kind:
    cmp dword ptr [rdx+58h], 0
    jne stock_dispatch
    cmp dword ptr [rdx+80h], 0
    jl stock_dispatch
    mov eax, dword ptr [rdx]
    cmp eax, WallCommand
    je dispatch_with_clearance
    cmp eax, ObjectCommand
    jne stock_dispatch
dispatch_with_clearance:
    jmp ClearBeforeDispatch
stock_dispatch:
    mov eax, dword ptr [rdx]
    add eax, 0Ah
    jmp ContinueCommandDispatch
DispatchClearance ENDP

PUBLIC CancelPendingClearance
CancelPendingClearance PROC
    ; RAX is the matched pending command; EDX still holds its UI tracking ID.
    cmp dword ptr [rax+28h], PendingStatus
    je check_cancelled_position
    cmp dword ptr [rax+28h], ActiveStatus
    jne stock_cancel
check_cancelled_position:
    cmp dword ptr [rax+58h], 0
    jne stock_cancel
    cmp dword ptr [rax+80h], 0
    jl stock_cancel
    cmp dword ptr [rax+0D4h], 0
    jle stock_cancel
    cmp dword ptr [rax], WallCommand
    je cancel_clearance_batch
    cmp dword ptr [rax], ObjectCommand
    jne stock_cancel
    cmp dword ptr [rax+14h], 1
    jne stock_cancel
    cmp dword ptr [rax+18h], 1
    jne stock_cancel
    mov ecx, dword ptr [rax+4h]
    CHECK_SMALL_DOOR ecx, rcx, stock_cancel
cancel_clearance_batch:
    ; The enclosing native frame is already aligned and has Win64 home space.
    mov rdx, rax
    mov rcx, r13
    call CancelMatchedBatch
    test al, al
    jz restore_tracking_id
    jmp FinishPendingCancellation
restore_tracking_id:
    mov edx, dword ptr [r14]
stock_cancel:
    mov rax, Game
    jmp ContinuePendingCancellation
CancelPendingClearance ENDP

PUBLIC CancelMatchedBatch
CancelMatchedBatch PROC
    sub rsp, 38h
    mov qword ptr [rsp+20h], rcx
    mov eax, dword ptr [rdx+80h]
    mov dword ptr [rsp+28h], eax
    cmp dword ptr [rdx], WallCommand
    jne cancel_eligible_batch
    mov ecx, dword ptr [rdx+4h]
    call IsWallMaterial
    test al, al
    jz leave_stock_cancellation
cancel_eligible_batch:
    mov rax, Game
    mov rcx, qword ptr [rax+198h]
    add rcx, 0E8h
    mov edx, dword ptr [rsp+28h]
    call CancelWorkBatch
    mov rcx, qword ptr [rsp+20h]
    mov edx, dword ptr [rsp+28h]
    call CancelConstructionBatch
    mov al, 1
leave_stock_cancellation:
    add rsp, 38h
    ret
CancelMatchedBatch ENDP

PUBLIC ClearBeforeDispatch
ClearBeforeDispatch PROC
    sub rsp, 68h
    mov qword ptr [rsp+38h], rcx
    mov qword ptr [rsp+40h], rdx
    mov byte ptr [rsp+61h], 0
    cmp dword ptr [rdx], WallCommand
    jne check_queued_door
    mov ecx, dword ptr [rdx+4h]
    call IsWallMaterial
    test al, al
    jz clear_and_dispatch
    jmp check_clearance_tiles
check_queued_door:
    cmp dword ptr [rdx+14h], 1
    jne clear_and_dispatch
    cmp dword ptr [rdx+18h], 1
    jne clear_and_dispatch
    ; Placement validation already scoped newly accepted tree collisions to new
    ; doors. A door replacement can fill its native Move handle after validation.
    mov ecx, dword ptr [rdx+4h]
    CHECK_SMALL_DOOR ecx, rcx, clear_and_dispatch
    cmp dword ptr [rcx+40h], 1
    jne measure_door_rotation
    cmp dword ptr [rcx+44h], 1
    je check_clearance_tiles
measure_door_rotation:
    ; Construction stores the accepted anchor only. Stock validation starts its
    ; footprint scan at that anchor, with dimensions from the rotated sprite.
    mov ecx, dword ptr [rdx+4h]
    mov r8, qword ptr [rdx+20h]
    xor edx, edx
    lea r9, [rsp+48h]
    lea rax, [rsp+4Ch]
    mov qword ptr [rsp+20h], rax
    lea rax, [rsp+50h]
    mov qword ptr [rsp+28h], rax
    lea rax, [rsp+54h]
    mov qword ptr [rsp+30h], rax
    call GetObjectFootprint
    cmp dword ptr [rsp+50h], 40000000h ; exact float 2.0
    jne measure_door_height
    mov byte ptr [rsp+61h], 1
    jmp check_clearance_tiles
measure_door_height:
    cmp dword ptr [rsp+54h], 40000000h
    jne clear_and_dispatch
    mov byte ptr [rsp+61h], 2
check_clearance_tiles:
    mov rdx, qword ptr [rsp+40h]
    mov eax, dword ptr [rdx+0D4h]
    test eax, eax
    jle clear_and_dispatch
    mov dword ptr [rsp+50h], eax
    mov rax, qword ptr [rdx+0C8h]
    test rax, rax
    jz clear_and_dispatch
    mov qword ptr [rsp+58h], rax
    mov rax, Game
    test rax, rax
    jz clear_and_dispatch
    mov rax, qword ptr [rax+198h]
    test rax, rax
    jz clear_and_dispatch
    mov qword ptr [rsp+48h], rax
    mov byte ptr [rsp+60h], 0
    ; Inspect the authoritative accepted positions, not the original selection rectangle.
clearance_tile_loop:
    mov rax, qword ptr [rsp+40h]
    mov r9d, dword ptr [rax+80h]
    mov rax, qword ptr [rsp+58h]
    mov edx, dword ptr [rax]
    mov r8d, dword ptr [rax+4h]
    mov rcx, qword ptr [rsp+48h]
    call ClearTileVegetation
    or byte ptr [rsp+60h], al
    cmp byte ptr [rsp+61h], 0
    je next_clearance_tile
    mov rax, qword ptr [rsp+40h]
    mov r9d, dword ptr [rax+80h]
    mov rax, qword ptr [rsp+58h]
    mov edx, dword ptr [rax]
    mov r8d, dword ptr [rax+4h]
    cmp byte ptr [rsp+61h], 1
    jne clearance_door_y
    inc edx
    jmp clear_adjacent_door_tile
clearance_door_y:
    inc r8d
clear_adjacent_door_tile:
    mov rcx, qword ptr [rsp+48h]
    call ClearTileVegetation
    or byte ptr [rsp+60h], al
next_clearance_tile:
    add qword ptr [rsp+58h], 0Ch
    dec dword ptr [rsp+50h]
    jne clearance_tile_loop
    cmp byte ptr [rsp+60h], 0
    je clear_and_dispatch
    ; Retain the accepted native command, with untouched status, cost and tiles.
    add rsp, 68h
    ret
clear_and_dispatch:
    mov rcx, qword ptr [rsp+38h]
    mov rdx, qword ptr [rsp+40h]
    mov eax, dword ptr [rdx]
    add eax, 0Ah
    add rsp, 68h
    jmp ContinueCommandDispatch
ClearBeforeDispatch ENDP

PUBLIC ClearTileVegetation
ClearTileVegetation PROC
    sub rsp, 68h
    mov qword ptr [rsp+28h], rcx
    mov dword ptr [rsp+40h], r9d
    mov byte ptr [rsp+58h], 0
    test edx, edx
    js clearance_tile_done
    test r8d, r8d
    js clearance_tile_done
    mov eax, dword ptr [rcx+60h]
    cmp edx, eax
    jge clearance_tile_done
    cmp r8d, dword ptr [rcx+64h]
    jge clearance_tile_done
    imul eax, r8d
    add eax, edx
    cdqe
    imul rax, rax, 0E0h
    add rax, qword ptr [rcx+48E8h]
    mov qword ptr [rsp+30h], rax
    mov dword ptr [rsp+38h], 0
clearance_object_loop:
    mov rax, qword ptr [rsp+30h]
    mov edx, dword ptr [rsp+38h]
    cmp edx, dword ptr [rax+5Ch]
    jge clearance_tile_done
    mov r8, qword ptr [rax+68h]
    cmp byte ptr [r8+rdx], 0
    je clearance_next_object
    mov r8, qword ptr [rax+60h]
    mov rax, qword ptr [r8+rdx*8]
    mov qword ptr [rsp+48h], rax
    lea rdx, [rsp+48h]
    mov rcx, qword ptr [rsp+28h]
    call ResolveObjectHandle
    test rax, rax
    jz clearance_next_object
    mov ecx, dword ptr [rax+40h]
    cmp ecx, TreeObject
    je set_tree_job_type
    cmp ecx, TreeStumpObject
    jne clearance_next_object
    mov dword ptr [rsp+50h], StumpRemovalJob
    jmp check_clearance_object
set_tree_job_type:
    mov dword ptr [rsp+50h], TreeDismantleJob
check_clearance_object:
    mov rcx, rax
    call IsObjectCarried
    test al, al
    jnz clearance_next_object
    mov byte ptr [rsp+58h], 1
    ; The exact native handle/type lookup also sees previously scheduled manual jobs.
    lea rdx, [rsp+48h]
    mov rcx, qword ptr [rsp+28h]
    add rcx, 0E8h
    mov r8d, dword ptr [rsp+50h]
    call FindObjectJob
    test rax, rax
    jnz clearance_next_object
    lea rdx, [rsp+48h]
    mov rcx, qword ptr [rsp+28h]
    add rcx, 0E8h
    mov r8d, dword ptr [rsp+40h]
    cmp dword ptr [rsp+50h], StumpRemovalJob
    je queue_stump_removal
    xor r9d, r9d
    mov byte ptr [rsp+20h], 1
    call ScheduleDismantle
    jmp clearance_next_object
queue_stump_removal:
    mov r9d, 1
    call ScheduleStumpRemoval
clearance_next_object:
    inc dword ptr [rsp+38h]
    jmp clearance_object_loop
clearance_tile_done:
    movzx eax, byte ptr [rsp+58h]
    add rsp, 68h
    ret
ClearTileVegetation ENDP

END

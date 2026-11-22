; Keep wall selection, pricing, reservations and cancellation in the native tool.
OPTION CASEMAP:NONE

EXTERN Game:QWORD
EXTERN InputManager:QWORD
EXTERN ObjectDefCount:DWORD
EXTERN ObjectDefTable:QWORD
EXTERN ScopedWallWorld:QWORD
EXTERN BuildWall:PROC
EXTERN ResolveWorldObject:PROC
EXTERN ObjectFootprint:PROC
EXTERN HalfCell:DWORD
EXTERN IsWallMaterial:PROC
EXTERN ValidateConstruction:PROC
EXTERN CommitConstruction:PROC
EXTERN MaterialValidatorReturn:PROC
EXTERN OrdinaryWallValidatorReturn:PROC
EXTERN ClearToBuild:PROC
EXTERN AdvanceBlocker:PROC
EXTERN MaterialCaller:PROC
EXTERN InsertMaterialJob:PROC
EXTERN ApplyMaterial:PROC
EXTERN RecoverOldDoor:PROC

; QRWallType is a persisted integer, otherwise used by QuickRoom commands.
WallPlanMarker EQU 514F4C57h

.code

PUBLIC WallSelection
WallSelection PROC
    mov eax, dword ptr [rcx+70h]
    sub eax, 2
    cmp eax, 1
    ja ordinary_selection
    cmp dword ptr [rcx+78h], 3
    jne ordinary_selection
    cmp edx, dword ptr [rcx+74h]
    jne ordinary_selection
    mov ecx, edx
    jmp IsWallMaterial
ordinary_selection:
    xor eax, eax
    ret
WallSelection ENDP

PUBLIC EligibleDoorUid
EligibleDoorUid PROC
    ; RCX is the installed object. Return its UID, or zero for an unsupported door.
    test rcx, rcx
    jz ineligible_door
    cmp byte ptr [rcx+6Ch], 0
    jne ineligible_door
    mov edx, dword ptr [rcx+40h]
    test edx, edx
    js ineligible_door
    cmp edx, ObjectDefCount
    jge ineligible_door
    movsxd rdx, edx
    imul rdx, rdx, 198h
    add rdx, ObjectDefTable
    test byte ptr [rdx+98h], 40h
    jz ineligible_door
    ; A double door is a single native object in both cell handle lists.
    ; Accept either oriented footprint without exempting larger road gates.
    mov eax, dword ptr [rdx+40h]
    mov edx, dword ptr [rdx+44h]
    cmp eax, 1
    jne check_double_width
    sub edx, 1
    cmp edx, 1
    jbe eligible_footprint
    jmp ineligible_door
check_double_width:
    cmp eax, 2
    jne ineligible_door
    cmp edx, 1
    jne ineligible_door
eligible_footprint:
    mov eax, dword ptr [rcx+38h]
    test eax, eax
    jle ineligible_door
    cmp eax, 7FFFFFFFh
    je ineligible_door
    ret
ineligible_door:
    xor eax, eax
    ret
EligibleDoorUid ENDP

PUBLIC WallDoorCoversCell
WallDoorCoversCell PROC
    ; RCX is a native object and EDX/R8d are the integer cell coordinates.
    sub rsp, 58h
    mov qword ptr [rsp+28h], rcx
    mov dword ptr [rsp+30h], edx
    mov dword ptr [rsp+34h], r8d
    call EligibleDoorUid
    test eax, eax
    jz outside_footprint
    mov dword ptr [rsp+38h], eax
    mov rcx, qword ptr [rsp+28h]
    lea rdx, [rsp+3Ch]
    lea r8, [rsp+40h]
    lea r9, [rsp+44h]
    lea rax, [rsp+48h]
    mov qword ptr [rsp+20h], rax
    call ObjectFootprint

    ; The real placed footprint, rather than a padded spatial-index hit.
    cvtsi2ss xmm0, dword ptr [rsp+30h]
    addss xmm0, HalfCell
    movss xmm1, dword ptr [rsp+3Ch]
    ucomiss xmm0, xmm1
    jb outside_footprint
    addss xmm1, dword ptr [rsp+44h]
    ucomiss xmm1, xmm0
    jbe outside_footprint
    cvtsi2ss xmm0, dword ptr [rsp+34h]
    addss xmm0, HalfCell
    movss xmm1, dword ptr [rsp+40h]
    ucomiss xmm0, xmm1
    jb outside_footprint
    addss xmm1, dword ptr [rsp+48h]
    ucomiss xmm1, xmm0
    jbe outside_footprint
    mov eax, dword ptr [rsp+38h]
    add rsp, 58h
    ret
outside_footprint:
    xor eax, eax
    add rsp, 58h
    ret
WallDoorCoversCell ENDP

PUBLIC GetWallDoorAt
GetWallDoorAt PROC
    ; Resolve native cell handles. Search the selected tile first and then
    ; the four possible neighbor anchor tiles for a two-cell footprint.
    sub rsp, 48h
    mov qword ptr [rsp+20h], rcx
    mov dword ptr [rsp+28h], edx
    mov dword ptr [rsp+2Ch], r8d
    cmp edx, dword ptr [rcx+60h]
    jae missing_wall_door
    cmp r8d, dword ptr [rcx+64h]
    jae missing_wall_door
    mov dword ptr [rsp+3Ch], 0
wall_anchor_tile:
    mov edx, dword ptr [rsp+28h]
    mov r8d, dword ptr [rsp+2Ch]
    mov eax, dword ptr [rsp+3Ch]
    test eax, eax
    jz locate_wall_anchor
    cmp eax, 1
    jne right_wall_anchor
    dec edx
    jmp locate_wall_anchor
right_wall_anchor:
    cmp eax, 2
    jne upper_wall_anchor
    inc edx
    jmp locate_wall_anchor
upper_wall_anchor:
    cmp eax, 3
    jne lower_wall_anchor
    dec r8d
    jmp locate_wall_anchor
lower_wall_anchor:
    inc r8d
locate_wall_anchor:
    mov rcx, qword ptr [rsp+20h]
    cmp edx, dword ptr [rcx+60h]
    jae next_wall_anchor
    cmp r8d, dword ptr [rcx+64h]
    jae next_wall_anchor
    mov eax, dword ptr [rcx+60h]
    imul eax, r8d
    add eax, edx
    cdqe
    imul rax, rax, 0E0h
    add rax, qword ptr [rcx+48E8h]
    mov qword ptr [rsp+30h], rax
    mov dword ptr [rsp+38h], 0
wall_door_loop:
    mov rax, qword ptr [rsp+30h]
    movsxd rdx, dword ptr [rsp+38h]
    cmp edx, dword ptr [rax+5Ch]
    jge next_wall_anchor
    mov rcx, qword ptr [rax+68h]
    cmp byte ptr [rcx+rdx], 0
    je next_wall_door
    mov rax, qword ptr [rax+60h]
    lea rdx, [rax+rdx*8]
    mov rcx, qword ptr [rsp+20h]
    call ResolveWorldObject
    test rax, rax
    jz next_wall_door
    mov qword ptr [rsp+40h], rax
    mov rcx, rax
    mov edx, dword ptr [rsp+28h]
    mov r8d, dword ptr [rsp+2Ch]
    call WallDoorCoversCell
    test eax, eax
    jnz found_wall_door
next_wall_door:
    inc dword ptr [rsp+38h]
    jmp wall_door_loop
next_wall_anchor:
    inc dword ptr [rsp+3Ch]
    cmp dword ptr [rsp+3Ch], 4
    jbe wall_anchor_tile
    jmp missing_wall_door
found_wall_door:
    mov rax, qword ptr [rsp+40h]
    add rsp, 48h
    ret
missing_wall_door:
    xor eax, eax
    add rsp, 48h
    ret
GetWallDoorAt ENDP

PUBLIC PreviewWall
PreviewWall PROC
    sub rsp, 68h
    mov qword ptr [rsp+40h], rcx
    mov dword ptr [rsp+48h], edx
    mov dword ptr [rsp+4Ch], r8d
    mov dword ptr [rsp+50h], r9d
    mov rax, ScopedWallWorld
    mov qword ptr [rsp+58h], rax
    mov byte ptr [rsp+60h], 0
    mov rcx, rdi
    call WallSelection
    test al, al
    jz build_preview
    mov rax, Game
    mov rax, qword ptr [rax+198h]
    mov ScopedWallWorld, rax
    mov byte ptr [rsp+60h], 1
build_preview:
    mov rcx, qword ptr [rsp+40h]
    mov edx, dword ptr [rsp+48h]
    mov r8d, dword ptr [rsp+4Ch]
    mov r9d, dword ptr [rsp+50h]
    mov eax, dword ptr [rsp+90h]
    mov dword ptr [rsp+20h], eax
    mov eax, dword ptr [rsp+98h]
    mov dword ptr [rsp+28h], eax
    mov eax, dword ptr [rsp+0A0h]
    mov dword ptr [rsp+30h], eax
    movzx eax, byte ptr [rsp+0A8h]
    mov byte ptr [rsp+38h], al
    call BuildWall
    mov rcx, qword ptr [rsp+58h]
    mov ScopedWallWorld, rcx
    cmp byte ptr [rsp+60h], 0
    je preview_done
    mov rcx, qword ptr [rsp+40h]
    cmp dword ptr [rcx+30h], 3
    jne preview_done
    mov edx, dword ptr [rsp+48h]
    cmp dword ptr [rcx+34h], edx
    jne preview_done
    mov dword ptr [rcx+0BCh], WallPlanMarker
preview_done:
    add rsp, 68h
    ret
PreviewWall ENDP

PUBLIC RevalidateWallPreview
RevalidateWallPreview PROC
    ; The construction update validates the live preview again between mouse events.
    sub rsp, 48h
    mov qword ptr [rsp+20h], rcx
    mov qword ptr [rsp+28h], rdx
    cmp dword ptr [rdx], 3
    jne revalidate_stock
    cmp dword ptr [rdx+8Ch], WallPlanMarker
    jne revalidate_stock
    mov rax, Game
    test rax, rax
    jz revalidate_stock
    mov r8, qword ptr [rax+198h]
    test r8, r8
    jz revalidate_stock
    lea r9, [r8+1288h]
    cmp rcx, r9
    jne revalidate_stock
    lea r9, [rcx+30h]
    cmp rdx, r9
    jne revalidate_stock
    mov qword ptr [rsp+30h], r8
    lea rcx, [rax+0C68h]
    mov edx, dword ptr [rdx+4h]
    call WallSelection
    test al, al
    jz revalidate_stock

    mov rax, ScopedWallWorld
    mov qword ptr [rsp+38h], rax
    mov rax, qword ptr [rsp+30h]
    mov ScopedWallWorld, rax
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rsp+28h]
    call ValidateConstruction
    mov rcx, qword ptr [rsp+38h]
    mov ScopedWallWorld, rcx
    add rsp, 48h
    ret
revalidate_stock:
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rsp+28h]
    add rsp, 48h
    jmp ValidateConstruction
RevalidateWallPreview ENDP

PUBLIC CommitWall
CommitWall PROC
    sub rsp, 48h
    mov qword ptr [rsp+20h], rcx
    mov dword ptr [rsp+28h], edx
    mov dword ptr [rsp+2Ch], r8d
    mov dword ptr [rsp+30h], r9d
    mov rax, ScopedWallWorld
    mov qword ptr [rsp+38h], rax
    mov rax, InputManager
    cmp byte ptr [rax+150h], 0
    je stock_commit
    cmp dword ptr [rcx+30h], 3
    jne stock_commit
    cmp dword ptr [rcx+0BCh], WallPlanMarker
    jne stock_commit
    mov edx, dword ptr [rcx+34h]
    mov rcx, rdi
    call WallSelection
    test al, al
    jz stock_commit
    ; Native CommitConstruction uses this virtual check to apply locally.
    mov rax, Game
    mov rcx, qword ptr [rax+0F78h]
    mov rax, qword ptr [rcx]
    call qword ptr [rax+38h]
    test al, al
    jz stock_commit
    mov rax, Game
    mov rax, qword ptr [rax+198h]
    mov ScopedWallWorld, rax
    jmp commit_plan
stock_commit:
    ; A preview flag must not be carried into a different input action.
    mov rcx, qword ptr [rsp+20h]
    cmp dword ptr [rcx+30h], 3
    jne commit_plan
    cmp dword ptr [rcx+0BCh], WallPlanMarker
    jne commit_plan
    mov dword ptr [rcx+0BCh], -1
commit_plan:
    mov rcx, qword ptr [rsp+20h]
    mov edx, dword ptr [rsp+28h]
    mov r8d, dword ptr [rsp+2Ch]
    mov r9d, dword ptr [rsp+30h]
    call CommitConstruction
    mov rcx, qword ptr [rsp+38h]
    mov ScopedWallWorld, rcx
    add rsp, 48h
    ret
CommitWall ENDP

PUBLIC ExcludeWallDoor
ExcludeWallDoor PROC
    ; Restrict the exception to native material validation of the selected wall.
    cmp rbp, ScopedWallWorld
    jne stock_blocker
    lea rax, MaterialValidatorReturn
    cmp qword ptr [rsp+98h], rax
    je wall_blocker
    lea rax, OrdinaryWallValidatorReturn
    cmp qword ptr [rsp+98h], rax
    jne stock_blocker
wall_blocker:
    call MatchWallDoor
    test al, al
    jnz advance
stock_blocker:
    cmp r8d, 3Dh
    jne blocked
advance:
    jmp AdvanceBlocker
blocked:
    jmp ClearToBuild
ExcludeWallDoor ENDP

PUBLIC MatchWallDoor
MatchWallDoor PROC
    ; Preserve the collision loop's volatile state across the stock cell lookup.
    sub rsp, 58h
    mov qword ptr [rsp+20h], rcx
    mov qword ptr [rsp+28h], rdx
    mov qword ptr [rsp+30h], r8
    mov qword ptr [rsp+38h], r9
    mov qword ptr [rsp+40h], r10
    mov qword ptr [rsp+48h], r11
    mov rcx, r10
    call EligibleDoorUid
    test eax, eax
    jz match_done
    mov rcx, rbp
    mov edx, r13d
    mov r8d, r12d
    call GetWallDoorAt
    cmp rax, qword ptr [rsp+40h]
    sete al
match_done:
    mov rcx, qword ptr [rsp+20h]
    mov rdx, qword ptr [rsp+28h]
    mov r8, qword ptr [rsp+30h]
    mov r9, qword ptr [rsp+38h]
    mov r10, qword ptr [rsp+40h]
    mov r11, qword ptr [rsp+48h]
    add rsp, 58h
    ret
MatchWallDoor ENDP

PUBLIC TagMaterialJob
TagMaterialJob PROC
    ; rbp = incoming RSP - 3Fh. Original caller R12 is saved at RSP - 10h.
    mov rax, qword ptr [rbp+3Fh]
    lea rdx, MaterialCaller
    cmp rax, rdx
    jne stock_insert
    mov r10, qword ptr [rbp+2Fh]
    cmp dword ptr [r10], 3
    jne stock_insert
    cmp dword ptr [r10+8Ch], WallPlanMarker
    jne check_prior_plan
    mov rax, Game
    mov rcx, qword ptr [rax+198h]
    mov edx, r15d
    mov r8d, r14d
    call GetWallDoorAt
    mov rcx, rax
    call EligibleDoorUid
    test eax, eax
    jz stock_insert
    jmp mark_old_door
check_prior_plan:
    ; Preserve already-accepted one-cell requests from the earlier release.
    cmp dword ptr [r10+14h], 1
    jne stock_insert
    cmp dword ptr [r10+18h], 1
    jne stock_insert
    mov eax, dword ptr [r10+34h]
    test eax, eax
    jle stock_insert
    cmp eax, 7FFFFFFFh
    je stock_insert
mark_old_door:
    ; Preserve the material stack's ObjAssigned handle.
    or eax, 80000000h
    mov dword ptr [rbx+0B4h], eax
stock_insert:
    mov rdx, rbx
    mov rcx, r13
    jmp InsertMaterialJob
TagMaterialJob ENDP
PUBLIC CompleteWall
CompleteWall PROC
    sub rsp, 68h
    mov qword ptr [rsp+30h], rcx
    mov dword ptr [rsp+38h], edx
    mov dword ptr [rsp+3Ch], r8d
    mov dword ptr [rsp+40h], r9d
    mov qword ptr [rsp+48h], -1
    mov eax, dword ptr [rdi+0B4h]
    test eax, eax
    jns apply_wall
    and eax, 7FFFFFFFh
    jz apply_wall
    cmp eax, 7FFFFFFFh
    je apply_wall
    mov dword ptr [rsp+44h], eax
    mov rax, Game
    mov rcx, qword ptr [rax+198h]
    call GetWallDoorAt
    test rax, rax
    jz apply_wall
    mov ecx, dword ptr [rsp+44h]
    cmp ecx, dword ptr [rax+38h]
    jne apply_wall
    ; Both halves can queue the same UID. The first completed wall job packs
    ; the shared door. The other still places its selected tile.
    mov rax, qword ptr [rax+38h]
    mov qword ptr [rsp+48h], rax
apply_wall:
    mov rcx, qword ptr [rsp+30h]
    mov edx, dword ptr [rsp+38h]
    mov r8d, dword ptr [rsp+3Ch]
    mov r9d, dword ptr [rsp+40h]
    mov eax, dword ptr [rsp+90h]
    mov dword ptr [rsp+20h], eax
    movzx eax, byte ptr [rsp+98h]
    mov byte ptr [rsp+28h], al
    call ApplyMaterial
    cmp qword ptr [rsp+48h], -1
    je wall_done
    mov eax, dword ptr [rsp+40h]
    cmp dword ptr [r14+18h], eax
    jne wall_done
    mov rax, Game
    mov rcx, qword ptr [rax+198h]
    lea rdx, [rsp+48h]
    call RecoverOldDoor
wall_done:
    add rsp, 68h
    ret
CompleteWall ENDP

END

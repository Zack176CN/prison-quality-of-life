option casemap:none

EXTERN GetTruckCapacity:PROC
EXTERN OriginalSpawnSpacing:PROC
EXTERN OneCell:DWORD
EXTERN TwoCells:DWORD

PUBLIC VehicleFootprintY, VehicleFootprintRotatedX, VehicleFrontExtent
PUBLIC RoadMotionSelfY, RoadMotionNeighborY, RoadQueueNeighborY
PUBLIC SpatialIndexInsertY, SpatialIndexRemoveY, CursorOriginY, CursorHitTestY
PUBLIC SpawnNeighborBack, SpawnNewTruckCenter

.code

; Displaced read is unchanged unless this individual vehicle has a long-truck tag.
; Each hook is entered by CALL from an aligned native frame.
ReadTaggedHeight MACRO procname, object, definition, destination
LOCAL useNativeHeight, mapCapacity, restoreVolatiles
procname PROC
    sub rsp, 38h
    movd destination, DWORD PTR [definition+44h]
    cmp DWORD PTR [object+40h], 8Bh
    jne useNativeHeight
    mov QWORD PTR [rsp+20h], rax
    mov QWORD PTR [rsp+28h], rcx
    mov QWORD PTR [rsp+30h], rdx
    IFIDNI <object>, <rcx>
    ELSE
        mov rcx, object
    ENDIF
    call GetTruckCapacity
    cmp eax, 12
    je mapCapacity
    cmp eax, 16
    jne restoreVolatiles
mapCapacity:
    shr eax, 1
    add eax, 4
    movd destination, eax
restoreVolatiles:
    mov rax, QWORD PTR [rsp+20h]
    mov rcx, QWORD PTR [rsp+28h]
    mov rdx, QWORD PTR [rsp+30h]
useNativeHeight:
    add rsp, 38h
    ret
procname ENDP
ENDM

ReadTaggedHeight VehicleFootprintY, rbx, rdi, xmm9
ReadTaggedHeight VehicleFootprintRotatedX, rbx, rdi, xmm10
ReadTaggedHeight VehicleFrontExtent, rsi, rbx, xmm6
ReadTaggedHeight RoadMotionSelfY, r13, rbx, xmm6
ReadTaggedHeight RoadMotionNeighborY, rax, rdi, xmm6
ReadTaggedHeight RoadQueueNeighborY, rdx, rdi, xmm6
ReadTaggedHeight SpatialIndexInsertY, rdx, rbx, xmm7
ReadTaggedHeight SpatialIndexRemoveY, rdx, rbx, xmm7
ReadTaggedHeight CursorOriginY, r10, rbx, xmm7
ReadTaggedHeight CursorHitTestY, rcx, rbx, xmm7

; The stock spawn loop takes the minimum of neighboring centers. Subtract
; only the extra rear half-length before the minimum and keep the stock gap.
SpawnNeighborBack PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], rax
    mov QWORD PTR [rsp+28h], rcx
    mov QWORD PTR [rsp+30h], rdx
    movss xmm0, DWORD PTR [rdx+4Ch]
    mov rcx, rdx
    call GetTruckCapacity
    cmp eax, 12
    je neighborOneCell
    cmp eax, 16
    jne neighborDone
    subss xmm0, DWORD PTR [TwoCells]
    jmp neighborDone
neighborOneCell:
    subss xmm0, DWORD PTR [OneCell]
neighborDone:
    mov rax, QWORD PTR [rsp+20h]
    mov rcx, QWORD PTR [rsp+28h]
    mov rdx, QWORD PTR [rsp+30h]
    add rsp, 38h
    ret
SpawnNeighborBack ENDP

; The incoming half-length also moves its center back, including at an empty
; entrance. Stock always passes the newly constructed native vehicle in RCX.
SpawnNewTruckCenter PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], rcx
    call OriginalSpawnSpacing
    mov rcx, QWORD PTR [rsp+20h]
    call GetTruckCapacity
    cmp eax, 12
    je newTruckOneCell
    cmp eax, 16
    jne truckCenterDone
    subss xmm0, DWORD PTR [TwoCells]
    jmp truckCenterDone
newTruckOneCell:
    subss xmm0, DWORD PTR [OneCell]
truckCenterDone:
    add rsp, 38h
    ret
SpawnNewTruckCenter ENDP

END

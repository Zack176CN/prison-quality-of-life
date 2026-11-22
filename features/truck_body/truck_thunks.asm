option casemap:none

EXTERN Game:QWORD
EXTERN DrawObject:PROC
EXTERN NextObject:PROC

PUBLIC SkipUnanchoredTruckCargo

.code

; RBX is the object about to contribute meshes to the world sprite batch.
; Match both halves of its carrier handle and find the object's actual slot.
; Keep the original first eight anchor meshes and skip only overflow meshes.
SkipUnanchoredTruckCargo PROC
    cmp BYTE PTR [rbx+6Eh], 1
    jne drawNativeObject
    mov r8, QWORD PTR [rbx+98h]
    cmp r8d, -1
    je drawNativeObject
    mov r9, r8
    shr r9, 32

    mov r11, QWORD PTR [Game]
    test r11, r11
    jz drawNativeObject
    mov r11, QWORD PTR [r11+198h]
    test r11, r11
    jz drawNativeObject
    mov r10d, DWORD PTR [r11+44B4h]
    test r10d, r10d
    jle drawNativeObject
    cmp r9d, r10d
    jae drawNativeObject
    mov r10, QWORD PTR [r11+44C0h]
    test r10, r10
    jz drawNativeObject
    cmp BYTE PTR [r10+r9], 0
    je drawNativeObject
    mov r10, QWORD PTR [r11+44B8h]
    test r10, r10
    jz drawNativeObject
    mov r10, QWORD PTR [r10+r9*8]
    test r10, r10
    jz drawNativeObject
    cmp QWORD PTR [r10+38h], r8
    jne drawNativeObject
    cmp DWORD PTR [r10+40h], 8Bh  ; SupplyTruck
    jne drawNativeObject

    mov r8, QWORD PTR [rbx+38h]
    cmp r8d, -1
    je drawNativeObject
    cmp DWORD PTR [rbx+3Ch], -1
    je drawNativeObject
    xor r9d, r9d
findCargoSlot:
    cmp QWORD PTR [r10+r9*8+0D8h], r8
    je testAnchor
    inc r9d
    cmp r9d, 20                ; Bounded by the native World's slot storage.
    jb findCargoSlot
drawNativeObject:
    cmp DWORD PTR [rbx+40h], 24Dh  ; Displaced check for the stock special renderer.
    jmp DrawObject
testAnchor:
    cmp r9d, 8
    jb drawNativeObject
    jmp NextObject
SkipUnanchoredTruckCargo ENDP

END

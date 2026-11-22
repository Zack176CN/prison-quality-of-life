option casemap:none

EXTERN ContinueWastePickup:PROC
EXTERN ContinueExportsPickup:PROC

PUBLIC CheckWastePickup
PUBLIC CheckExportsPickup

.code

; The native SupplyTruck name carries a pickup category. Accept both the
; original eight-byte tag and the same tag with a valid long-truck suffix.
PICKUP_CHECK MACRO procname, disallowedName, resume
LOCAL stockPermission, compareName, denyPickup
procname PROC
    mov edx, DWORD PTR [rcx+40h]
    cmp edx, 8Bh
    jne stockPermission
    cmp QWORD PTR [rcx+90h], 15
    jne stockPermission
    cmp QWORD PTR [rcx+88h], 8
    je compareName
    cmp QWORD PTR [rcx+88h], 12
    jne stockPermission
    cmp BYTE PTR [rcx+84h], 0
    jne stockPermission
    cmp DWORD PTR [rcx+80h], 4C32312Dh
    je compareName
    cmp DWORD PTR [rcx+80h], 4C36312Dh
    jne stockPermission
compareName:
    mov r8, disallowedName
    cmp QWORD PTR [rcx+78h], r8
    je denyPickup
stockPermission:
    cmp edx, 9Eh
    jmp resume
denyPickup:
    xor eax, eax
    ret
procname ENDP
ENDM

; PAOD_E01 selects exports. PAOD_G01 selects garbage.
PICKUP_CHECK CheckWastePickup, 3130455F444F4150h, ContinueWastePickup
PICKUP_CHECK CheckExportsPickup, 3130475F444F4150h, ContinueExportsPickup

END

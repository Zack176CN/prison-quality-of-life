option casemap:none

EXTERN DispatchObjectKind:DWORD
EXTERN LoadingDispatchResource:BYTE
EXTERN OwnedDispatchSprite:DWORD
EXTERN Game:QWORD
EXTERN ObjectDefCount:DWORD
EXTERN ObjectDefTable:QWORD
EXTERN RoomDefCount:DWORD
EXTERN RoomDefTable:QWORD
EXTERN SpriteEnumList:QWORD
EXTERN ReadMaterials:PROC
EXTERN CollectMaterialPaths:PROC
EXTERN AppendMaterialPath:PROC
EXTERN OpenTextFile:PROC
EXTERN NativeNew:PROC
EXTERN TextReaderFromMemory:PROC
EXTERN FindObjectKind:PROC
EXTERN FindRoomKind:PROC
EXTERN InsertLikelyObject:PROC
EXTERN FindSpriteId:PROC
EXTERN FindSpriteDescriptor:PROC
EXTERN RegisterSpriteDescriptor:PROC
EXTERN CompareNativeString:PROC
EXTERN ObjectNameText:BYTE
EXTERN ResourceName:BYTE
EXTERN StockSpriteName:BYTE
EXTERN AliasSpriteName:BYTE
EXTERN AliasSpriteNameHeader:BYTE
EXTERN DispatchMaterialText:BYTE
EXTERN DispatchMaterialSize:DWORD
EXTERN DispatchArtworkReady:BYTE
EXTERN DispatchSpriteOrigin:QWORD
EXTERN RegisterDispatchTranslations:PROC
EXTERN DeliveriesRoomName:BYTE
EXTERN GarbageRoomName:BYTE
EXTERN ExportsRoomName:BYTE

PUBLIC RegisterBaseDispatch, CollectBaseDispatchPaths, OpenBaseDispatchText, RegisterDispatchSprite
PUBLIC EnsureDispatchSpriteEnum, IsNativeDispatchResource
PUBLIC RegisterDispatchRoomHint

.code

; Once stock/DLC materials have loaded, read an immutable second base resource.
; A preexisting name can belong to an active Workshop item. Never overwrite it.
RegisterBaseDispatch PROC
    sub rsp, 68h
    call ReadMaterials
    cmp DWORD PTR [DispatchSpriteOrigin], -1
    je checkObjectName
    cmp BYTE PTR [DispatchArtworkReady], 1
    jne disableDispatch
checkObjectName:
    lea rax, ObjectNameText
    mov QWORD PTR [rsp+20h], rax
    mov QWORD PTR [rsp+30h], 17
    mov QWORD PTR [rsp+38h], 17
    lea rcx, [rsp+20h]
    call FindObjectKind
    cmp eax, -1
    jne existingDefinition

    call RegisterDispatchSprite
    test eax, eax
    js disableDispatch
    mov DWORD PTR [rsp+40h], eax
    mov BYTE PTR [LoadingDispatchResource], 1
    lea rdx, ResourceName
    call ReadMaterials
    mov BYTE PTR [LoadingDispatchResource], 0

    lea rcx, [rsp+20h]
    call FindObjectKind
    jmp validateDefinition

existingDefinition:
    cmp eax, DWORD PTR [DispatchObjectKind]
    jne disableDispatch
    test eax, eax
    jle disableDispatch
    mov DWORD PTR [rsp+44h], eax
    call RegisterDispatchSprite
    test eax, eax
    js disableDispatch
    mov DWORD PTR [rsp+40h], eax
    mov eax, DWORD PTR [rsp+44h]
validateDefinition:
    test eax, eax
    jle disableDispatch
    cmp eax, DWORD PTR [ObjectDefCount]
    jge disableDispatch
    mov rdx, QWORD PTR [ObjectDefTable]
    test rdx, rdx
    jz disableDispatch
    movsxd rcx, eax
    imul rcx, rcx, 198h
    mov r8d, DWORD PTR [rsp+40h]
    cmp DWORD PTR [rdx+rcx+0A4h], r8d
    jne disableDispatch
    cmp DWORD PTR [rdx+rcx+0B0h], r8d
    jne disableDispatch
    mov DWORD PTR [DispatchObjectKind], eax
    call RegisterDispatchTranslations
    lea rcx, DeliveriesRoomName
    call RegisterDispatchRoomHint
    lea rcx, GarbageRoomName
    call RegisterDispatchRoomHint
    lea rcx, ExportsRoomName
    call RegisterDispatchRoomHint
    jmp registrationDone
disableDispatch:
    mov DWORD PTR [DispatchObjectKind], 0
registrationDone:
    add rsp, 68h
    ret
RegisterBaseDispatch ENDP

; Keep this synthetic filename out of the mod search path entirely. The stock
; vector insertion owns its string exactly as for a built-in materials path.
CollectBaseDispatchPaths PROC
    sub rsp, 28h
    call IsNativeDispatchResource
    test al, al
    jz collectNativePaths
    mov rcx, r8
    mov r8d, DWORD PTR [r8+0Ch]
    add rsp, 28h
    jmp AppendMaterialPath
collectNativePaths:
    add rsp, 28h
    jmp CollectMaterialPaths
CollectBaseDispatchPaths ENDP

; Return the same owning TextReader type as OpenTextFile. Its BinaryDataReader
; wraps our read-only bytes and the game's existing cleanup releases the reader.
OpenBaseDispatchText PROC
    sub rsp, 38h
    call IsNativeDispatchResource
    test al, al
    jz openNativeFile
    mov QWORD PTR [rsp+20h], rdx
    mov ecx, 2888h
    call NativeNew
    mov rcx, rax
    mov r9, QWORD PTR [rsp+20h]
    lea rdx, DispatchMaterialText
    mov r8d, DWORD PTR [DispatchMaterialSize]
    call TextReaderFromMemory
    add rsp, 38h
    ret
openNativeFile:
    add rsp, 38h
    jmp OpenTextFile
OpenBaseDispatchText ENDP

; The object and its model have independent native indices and definitions.
; Reuse the local stock PhoneMonitor UVs, leaving its original descriptor intact.
RegisterDispatchSprite PROC
    sub rsp, 78h
    mov rcx, QWORD PTR [Game]
    test rcx, rcx
    jz spriteUnavailable
    add rcx, 730h
    mov QWORD PTR [rsp+20h], rcx
    lea rdx, AliasSpriteName
    call FindSpriteId
    test eax, eax
    js registerNewAlias
    lea edx, [rax+1]
    cmp edx, DWORD PTR [OwnedDispatchSprite]
    jne spriteUnavailable
    jmp spriteRegistered
registerNewAlias:
    mov rcx, QWORD PTR [rsp+20h]
    lea rdx, StockSpriteName
    call FindSpriteDescriptor
    test rax, rax
    jz spriteUnavailable
    cmp DWORD PTR [DispatchSpriteOrigin], -1
    je cloneDescriptor
    cmp DWORD PTR [rax+28h], 2
    jne spriteUnavailable
    cmp DWORD PTR [rax+2Ch], 3
    jne spriteUnavailable
    cmp DWORD PTR [rax+30h], 3
    jne spriteUnavailable
cloneDescriptor:
    movups xmm0, XMMWORD PTR [AliasSpriteName]
    movups xmm1, XMMWORD PTR [AliasSpriteNameHeader]
    movups XMMWORD PTR [rsp+28h], xmm0
    movups XMMWORD PTR [rsp+38h], xmm1
    movups xmm0, XMMWORD PTR [rax+20h]
    movups xmm1, XMMWORD PTR [rax+30h]
    movups XMMWORD PTR [rsp+48h], xmm0
    movups XMMWORD PTR [rsp+58h], xmm1
    movzx edx, WORD PTR [rax+40h]
    mov QWORD PTR [rsp+68h], rdx
    mov rdx, QWORD PTR [DispatchSpriteOrigin]
    cmp edx, -1
    je appendDescriptor
    mov QWORD PTR [rsp+48h], rdx
appendDescriptor:
    mov rcx, QWORD PTR [rsp+20h]
    lea rdx, [rsp+28h]
    call RegisterSpriteDescriptor
    test eax, eax
    js spriteDone
    lea edx, [rax+1]
    mov DWORD PTR [OwnedDispatchSprite], edx
spriteRegistered:
    call EnsureDispatchSpriteEnum
    jmp spriteDone
spriteUnavailable:
    mov eax, -1
spriteDone:
    add rsp, 78h
    ret
RegisterDispatchSprite ENDP

; Material Sprite and ToolbarSprite values use the global enumeration, while
; drawing uses the same numeric index in the atlas bank. Claim only the next
; enum slot or confirm a matching previously registered alias.
EnsureDispatchSpriteEnum PROC
    sub rsp, 38h
    lea rcx, SpriteEnumList
    mov r10, QWORD PTR [rcx]
    test r10, r10
    jz spriteEnumUnavailable
    cmp eax, DWORD PTR [rcx+0Ch]
    ja spriteEnumUnavailable
    je appendSpriteEnum
    mov DWORD PTR [rsp+20h], eax
    shl rax, 5
    lea rcx, [r10+rax]
    lea rdx, AliasSpriteName
    call CompareNativeString
    test eax, eax
    jne spriteEnumUnavailable
    mov eax, DWORD PTR [rsp+20h]
    jmp spriteEnumDone
appendSpriteEnum:
    mov r8d, eax
    lea rdx, AliasSpriteName
    call AppendMaterialPath
    jmp spriteEnumDone
spriteEnumUnavailable:
    mov eax, -1
spriteEnumDone:
    add rsp, 38h
    ret
EnsureDispatchSpriteEnum ENDP

; Extend the room's stock LikelyObject list without replacing its definition.
RegisterDispatchRoomHint PROC
    sub rsp, 28h
    call FindRoomKind
    test eax, eax
    js roomHintDone
    cmp eax, DWORD PTR [RoomDefCount]
    jge roomHintDone
    mov rcx, QWORD PTR [RoomDefTable]
    test rcx, rcx
    jz roomHintDone
    imul rax, rax, 668h
    lea rcx, [rcx+rax+648h]
    mov r8d, DWORD PTR [rcx+0Ch]
    test r8d, r8d
    js roomHintDone
    cmp r8d, DWORD PTR [rcx+8]
    ja roomHintDone
    test r8d, r8d
    jz appendRoomHint
    mov rdx, QWORD PTR [rcx]
    test rdx, rdx
    jz roomHintDone
    mov r9d, DWORD PTR [DispatchObjectKind]
    xor eax, eax
findExistingHint:
    cmp DWORD PTR [rdx+rax*4], r9d
    je roomHintDone
    inc eax
    cmp eax, r8d
    jb findExistingHint
appendRoomHint:
    lea rdx, DispatchObjectKind
    call InsertLikelyObject
roomHintDone:
    add rsp, 28h
    ret
RegisterDispatchRoomHint ENDP

; RDX is a native std::string. Compare only its 14 meaningful inline bytes.
IsNativeDispatchResource PROC
    xor eax, eax
    cmp BYTE PTR [LoadingDispatchResource], 1
    jne resourceTestDone
    test rdx, rdx
    jz resourceTestDone
    cmp QWORD PTR [rdx+10h], 14
    jne resourceTestDone
    cmp QWORD PTR [rdx+18h], 16
    jae resourceTestDone
    lea r10, ResourceName
    mov r11, QWORD PTR [r10]
    cmp QWORD PTR [rdx], r11
    jne resourceTestDone
    mov r11d, DWORD PTR [r10+8]
    cmp DWORD PTR [rdx+8], r11d
    jne resourceTestDone
    movzx r11d, WORD PTR [r10+0Ch]
    cmp WORD PTR [rdx+0Ch], r11w
    sete al
resourceTestDone:
    ret
IsNativeDispatchResource ENDP

END

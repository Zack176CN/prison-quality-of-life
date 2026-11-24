option casemap:none

EXTERN Game:QWORD
EXTERN InputManager:QWORD
EXTERN KeysHeld:BYTE
EXTERN KeysPressed:BYTE
EXTERN WindowManager:QWORD
EXTERN ObjectDefinitions:QWORD
EXTERN ObjectDefinitionCount:DWORD
EXTERN MaterialDefinitions:QWORD
EXTERN MaterialDefinitionCount:DWORD
EXTERN GameEntitlements:QWORD
EXTERN MapObjectPickerKey:DWORD
EXTERN PendingPickerMiddleButton:BYTE
EXTERN FramePickerMiddleButton:BYTE
EXTERN PickerHoverTool:QWORD
EXTERN PickerScrollIconBox:QWORD
EXTERN PickerScrollOwner:DWORD
EXTERN PickerScrollKind:DWORD
EXTERN PickerScrollSubtype:DWORD
EXTERN SubToolbarName:BYTE
EXTERN IconBoxName:BYTE
EXTERN SearchControlName:BYTE
EXTERN EmptyToolbarSearch:BYTE
EXTERN ObjectTypeControlName:BYTE
EXTERN ObjectPackControlName:BYTE
EXTERN GetFocusedWindowId:PROC
EXTERN GetWindowIdByName:PROC
EXTERN GetWindowById:PROC
EXTERN GetControlById:PROC
EXTERN GetControlByName:PROC
EXTERN ResolveWorldObject:PROC
EXTERN IsObjectMenuItem:PROC
EXTERN IsDoorMenuItem:PROC
EXTERN IsWallMenuItem:PROC
EXTERN IsFloorMenuItem:PROC
EXTERN IsRoadTabMaterial:PROC
EXTERN IsSharedFloorMaterial:PROC
EXTERN HasContentEntitlement:PROC
EXTERN RequiresExtendedContent:PROC
EXTERN IsUtilityBuildItem:PROC
EXTERN CanUseToolbarItem:PROC
EXTERN ClickToolbarCategory:PROC
EXTERN RebuildToolbar:PROC
EXTERN AssignToolbarSearch:PROC
EXTERN RefreshToolbarSearchControl:PROC
EXTERN IsObjectPackMatch:PROC
EXTERN SetToolbarDropdownValue:PROC
EXTERN ScrollToolbarIconIntoView:PROC
EXTERN FinishIconBoxDraw:PROC
EXTERN ContinueIconBoxDraw:PROC
EXTERN SetMapTool:PROC
EXTERN SetBuildItem:PROC
EXTERN ReadStockHover:PROC
EXTERN ContinueStockHoverCandidate:PROC
EXTERN RejectStockHoverCandidate:PROC
EXTERN ContinueStockHoverResult:PROC
EXTERN TryStockActorHover:PROC
EXTERN FinishStockHover:PROC
EXTERN ContinueMapInput:PROC
EXTERN FinishMapInput:PROC
EXTERN ContinueMiddleButtonDown:PROC
EXTERN ContinueFrameMiddleEdge:PROC
EXTERN ContinueFocusLost:PROC

PUBLIC PickMapObjectFrame
PUBLIC TryPickMapObject
PUBLIC ClassifyPickerObject
PUBLIC FindPickerObject
PUBLIC FindPickerSubToolbar
PUBLIC FocusPickerToolbarItem
PUBLIC RevealPickerObjectFilters
PUBLIC UpdatePickerDropdown
PUBLIC FindPickerToolbarRow
PUBLIC ScrollPickedItemAfterLayout
PUBLIC CheckPickerHoverCandidate
PUBLIC KeepPickerHoverResult
PUBLIC CaptureMapPickerMiddleButton
PUBLIC PublishMapPickerMiddleButton
PUBLIC ClearMapPickerMiddleButton

MiddleMouse EQU 4
DoorTool EQU 2
FloorTool EQU 3
ObjectTool EQU 5
UtilityTool EQU 7
ObjectBuildSubtype EQU 2
MaterialBuildSubtype EQU 3

.code

; The stock update has already calculated the mouse hit and filtered UI and modal overlays.
; RDI is the mouse tool. ECX and R8B remain live in the regular path.
PickMapObjectFrame PROC
    mov eax, DWORD PTR [MapObjectPickerKey]
    cmp eax, MiddleMouse
    jne checkKeyboardEdge
    cmp BYTE PTR [FramePickerMiddleButton], 0
    je stockMapInput
    mov BYTE PTR [FramePickerMiddleButton], 0
    jmp tryPick
checkKeyboardEdge:
    cmp eax, 255
    ja stockMapInput
    lea r11, KeysPressed
    cmp BYTE PTR [r11+rax], 0
    je stockMapInput
tryPick:
    call TryPickMapObject
    test al, al
    jnz pickedObject
stockMapInput:
    mov edx, DWORD PTR [rdi+74h]
    cmp edx, -1
    jmp ContinueMapInput
pickedObject:
    jmp FinishMapInput
PickMapObjectFrame ENDP

TryPickMapObject PROC
    sub rsp, 58h
    mov QWORD PTR [rsp+48h], rcx
    mov QWORD PTR [rsp+50h], r8
    cmp DWORD PTR [rdi+84h], 0          ; A placement or selection drag is active.
    jne rejectPick
    mov rax, QWORD PTR [InputManager]
    test rax, rax
    jz rejectPick
    cmp BYTE PTR [rax+148h], 0          ; Native window focus.
    je rejectPick
    cmp BYTE PTR [rax+14Ah], 0          ; Left mouse button held.
    jne rejectPick
    cmp BYTE PTR [rax+14Ch], 0          ; Right mouse button held.
    jne rejectPick
    lea rax, KeysHeld
    cmp WORD PTR [rax+11h], 0           ; Ctrl or Alt holds a native shortcut.
    jne rejectPick
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz rejectPick
    cmp BYTE PTR [rax+0E4Fh], 0
    jne rejectPick
    mov rcx, QWORD PTR [rax+198h]
    test rcx, rcx
    jz rejectPick
    cmp BYTE PTR [rcx+46E2h], 0        ; Native guided selection.
    jne rejectPick

    mov rcx, QWORD PTR [WindowManager]
    test rcx, rcx
    jz rejectPick
    ; A middle click on the map does not type into a previously focused search field.
    cmp DWORD PTR [MapObjectPickerKey], MiddleMouse
    je findTarget
    call GetFocusedWindowId
    mov edx, eax
    mov rcx, QWORD PTR [WindowManager]
    call GetWindowById
    test rax, rax
    jz findTarget
    mov edx, DWORD PTR [rax+2Ch]
    cmp edx, -1
    je findTarget
    mov rcx, rax
    call GetControlById
    test rax, rax
    jz findTarget
    cmp DWORD PTR [rax+10h], 6
    je rejectPick

findTarget:
    mov rax, QWORD PTR [Game]
    mov rcx, QWORD PTR [rax+198h]
    lea rdx, [rdi+0B0h]
    call ResolveWorldObject
    mov rcx, rax
    call ClassifyPickerObject
    test eax, eax
    jnz foundObject

    ; Validate the cursor before using either the spatial query or the tile grid.
    mov rax, QWORD PTR [Game]
    mov rcx, QWORD PTR [rax+198h]
    mov rax, QWORD PTR [rcx+48E8h]
    test rax, rax
    jz rejectPick
    xorps xmm0, xmm0
    movss xmm1, DWORD PTR [rdi+30h]
    ucomiss xmm1, xmm0
    jb rejectPick
    movss xmm2, DWORD PTR [rdi+34h]
    ucomiss xmm2, xmm0
    jb rejectPick
    cvttss2si edx, xmm1
    cvttss2si r8d, xmm2
    cmp edx, DWORD PTR [rcx+60h]
    jae rejectPick
    cmp r8d, DWORD PTR [rcx+64h]
    jae rejectPick
    imul r8d, DWORD PTR [rcx+60h]
    add r8d, edx
    imul r8, r8, 0E0h
    mov edx, DWORD PTR [rax+r8+18h]
    mov DWORD PTR [rsp+30h], edx

    ; Foreground people and some tool-specific hover filters can hide a built object.
    call FindPickerObject
    mov rcx, rax
    call ClassifyPickerObject
    test eax, eax
    jz findTileMaterial

foundObject:
    mov DWORD PTR [rsp+30h], edx
    mov DWORD PTR [rsp+34h], ObjectBuildSubtype
    mov DWORD PTR [rsp+40h], eax
    mov DWORD PTR [rsp+2Ch], -1
    cmp eax, DoorTool
    je selectDoorsTab
    cmp eax, UtilityTool
    jne checkOpenToolbar
    imul rax, rdx, 198h
    add rax, QWORD PTR [ObjectDefinitions]
    mov rax, QWORD PTR [rax+98h]
    mov DWORD PTR [rsp+2Ch], 1         ; Plumbing.
    bt rax, 36
    jc checkOpenToolbar
    mov DWORD PTR [rsp+2Ch], 0         ; General utilities, including large water pipe.
    bt rax, 18
    jnc checkOpenToolbar
    cmp edx, 0F4h
    je checkOpenToolbar
    mov DWORD PTR [rsp+2Ch], 2         ; Power.
    jmp checkOpenToolbar
selectDoorsTab:
    mov DWORD PTR [rsp+2Ch], 1
    jmp checkOpenToolbar

findTileMaterial:
    mov edx, DWORD PTR [rsp+30h]
    cmp edx, 9                         ; The stock default Dirt tile is also the empty map state.
    jl rejectPick
    cmp edx, DWORD PTR [MaterialDefinitionCount]
    jge rejectPick
    mov rcx, QWORD PTR [MaterialDefinitions]
    test rcx, rcx
    jz rejectPick
    imul rax, rdx, 248h
    add rcx, rax
    mov QWORD PTR [rsp+38h], rcx
    call IsWallMenuItem
    test al, al
    jnz selectWallMaterial

    ; The stock floor list treats the four grass corners and material 98 separately.
    mov edx, DWORD PTR [rsp+30h]
    lea eax, [rdx-12]
    cmp eax, 3
    jbe checkFloorTime
    cmp edx, 98
    je checkFloorTime
    mov rcx, QWORD PTR [rsp+38h]
    call IsFloorMenuItem
    test al, al
    jz rejectPick
checkFloorTime:
    mov rax, QWORD PTR [rsp+38h]
    xorps xmm0, xmm0
    ucomiss xmm0, DWORD PTR [rax+44h]
    jp rejectPick
    jbe selectFloorTab
    mov eax, DWORD PTR [rsp+30h]
    cmp eax, 35h
    je selectFloorTab
    lea ecx, [rax-8Eh]
    cmp ecx, 2
    jbe selectFloorTab
    lea ecx, [rax-37h]
    cmp ecx, 1
    jbe selectFloorTab
    mov rax, QWORD PTR [Game]
    mov rax, QWORD PTR [rax+198h]
    cmp BYTE PTR [rax+46E8h], 0
    je rejectPick
selectFloorTab:
    mov DWORD PTR [rsp+2Ch], 0
    mov ecx, DWORD PTR [rsp+30h]
    call IsRoadTabMaterial
    test al, al
    jz selectFloorMaterial
    mov ecx, DWORD PTR [rsp+30h]
    call IsSharedFloorMaterial
    test al, al
    jnz selectFloorMaterial
    mov DWORD PTR [rsp+2Ch], 1
selectFloorMaterial:
    mov edx, FloorTool
    jmp checkMaterialAvailability
selectWallMaterial:
    mov DWORD PTR [rsp+2Ch], 0         ; Walls tab.
    mov edx, DoorTool
checkMaterialAvailability:
    mov DWORD PTR [rsp+40h], edx
    mov DWORD PTR [rsp+34h], MaterialBuildSubtype
    mov rcx, QWORD PTR [Game]
    mov r8d, DWORD PTR [rsp+30h]
    call CanUseToolbarItem
    test al, al
    jz rejectPick

checkOpenToolbar:
    ; The stock category click closes an already open category. Keep its window and filter.
    mov eax, DWORD PTR [rsp+40h]
    cmp DWORD PTR [rdi+70h], eax
    jne findToolbarCategory
    call FindPickerSubToolbar
    test rax, rax
    jz findToolbarCategory
    mov edx, DWORD PTR [rsp+40h]
    cmp DWORD PTR [rax+0C0h], edx
    je selectBuildItem

findToolbarCategory:
    mov rax, QWORD PTR [Game]
    mov rcx, QWORD PTR [rax+0CB8h]
    test rcx, rcx
    jz rejectPick
    cmp DWORD PTR [rcx+0C0h], 0
    jne rejectPick
    mov rax, QWORD PTR [rcx+0C8h]
    mov edx, DWORD PTR [rcx+0D4h]
    test rax, rax
    jz rejectPick
    test edx, edx
    jle rejectPick
    mov r8d, DWORD PTR [rsp+40h]
    xor r9d, r9d
findCategoryRow:
    cmp DWORD PTR [rax], r8d
    je openCategoryRow
    add rax, 0Ch
    inc r9d
    cmp r9d, edx
    jl findCategoryRow
    jmp rejectPick

openCategoryRow:
    mov DWORD PTR [rsp+28h], r9d
    cmp DWORD PTR [rdi+70h], r8d
    jne clickCategoryRow
    ; The tool may be active with no matching window. Reset it before the stock toggle.
    mov rcx, rdi
    xor edx, edx
    call SetMapTool
    mov rax, QWORD PTR [Game]
    mov rcx, QWORD PTR [rax+0CB8h]
clickCategoryRow:
    mov edx, DWORD PTR [rsp+28h]
    xor r8d, r8d
    xor r9d, r9d
    mov eax, DWORD PTR [rsp+2Ch]
    mov DWORD PTR [rsp+20h], eax
    call ClickToolbarCategory
    mov eax, DWORD PTR [rsp+40h]
    cmp DWORD PTR [rdi+70h], eax
    jne rejectPick
    call FindPickerSubToolbar
    test rax, rax
    jz rejectPick
    mov edx, DWORD PTR [rsp+40h]
    cmp DWORD PTR [rax+0C0h], edx
    jne rejectPick
selectBuildItem:
    mov QWORD PTR [rsp+38h], rax        ; The native submenu stays open during SetBuildItem.
    mov edx, DWORD PTR [rsp+2Ch]
    test edx, edx
    js applyBuildItem
    xor r9d, r9d
    cmp DWORD PTR [rax+140h], edx
    je checkFloorVariant
    mov DWORD PTR [rax+140h], edx
    mov r9b, 1                         ; Same refresh as a stock category tab click.
checkFloorVariant:
    cmp DWORD PTR [rsp+40h], FloorTool
    jne refreshBuildToolbar
    mov ecx, DWORD PTR [rsp+30h]
    sub ecx, 12
    cmp ecx, 3
    ja refreshBuildToolbar
    cmp DWORD PTR [rax+170h], ecx
    je refreshBuildToolbar
    mov DWORD PTR [rax+170h], ecx
    jmp rebuildBuildToolbar
refreshBuildToolbar:
    test r9b, r9b
    jz applyBuildItem
rebuildBuildToolbar:
    mov rcx, rax
    mov dl, r9b
    call RebuildToolbar
applyBuildItem:
    cmp DWORD PTR [rsp+40h], UtilityTool
    jne commitBuildItem
    ; The stock Utilities tab also chooses the corresponding map overlay.
    mov rax, QWORD PTR [Game]
    mov edx, DWORD PTR [rsp+2Ch]
    mov DWORD PTR [rax+0D00h], edx
    cmp edx, 0
    sete BYTE PTR [rax+8E4h]
    cmp edx, 1
    sete BYTE PTR [rax+8E5h]
commitBuildItem:
    mov rcx, rdi
    mov edx, DWORD PTR [rsp+30h]
    mov r8d, DWORD PTR [rsp+34h]
    call SetBuildItem
    mov rcx, QWORD PTR [rsp+38h]
    mov edx, DWORD PTR [rsp+30h]
    mov r8d, DWORD PTR [rsp+34h]
    call FocusPickerToolbarItem
    mov eax, 1
    jmp finishPick
rejectPick:
    xor eax, eax
finishPick:
    mov rcx, QWORD PTR [rsp+48h]
    mov r8, QWORD PTR [rsp+50h]
    add rsp, 58h
    ret
TryPickMapObject ENDP

; RCX is a live map object. Return toolbar category in EAX and object kind in EDX.
ClassifyPickerObject PROC
    sub rsp, 38h
    test rcx, rcx
    jz rejectObject
    cmp WORD PTR [rcx+6Ch], 0           ; Removing or unavailable as a map hit.
    jne rejectObject
    mov eax, DWORD PTR [rcx+40h]
    test eax, eax
    jle rejectObject
    cmp eax, DWORD PTR [ObjectDefinitionCount]
    jge rejectObject
    mov DWORD PTR [rsp+20h], eax
    mov rcx, QWORD PTR [ObjectDefinitions]
    test rcx, rcx
    jz rejectObject
    movsxd rdx, eax
    imul rax, rdx, 198h
    add rax, rcx
    mov QWORD PTR [rsp+28h], rax
    mov rcx, rax
    call IsObjectMenuItem
    mov edx, ObjectTool
    test al, al
    jnz checkToolbarAvailability
    mov rcx, QWORD PTR [rsp+28h]
    mov edx, DWORD PTR [rsp+20h]
    call IsDoorMenuItem
    mov edx, DoorTool
    test al, al
    jnz checkToolbarAvailability

    ; The utility menu has separate item categories, all using the same build tool.
    mov rax, QWORD PTR [rsp+28h]
    xorps xmm0, xmm0
    ucomiss xmm0, DWORD PTR [rax+4Ch]    ; Negative construction time is absent from the utility menu.
    ja rejectObject
    jp rejectObject
    mov rcx, QWORD PTR [rax+98h]
    mov r8, 1000040010h                 ; Utility, power, or plumbing category.
    test rcx, r8
    jz rejectObject
    mov ecx, DWORD PTR [rax+120h]
    cmp ecx, -1
    je checkContent
    mov dl, 1
    call HasContentEntitlement
    test al, al
    jz rejectObject
checkContent:
    mov rax, QWORD PTR [GameEntitlements]
    test rax, rax
    jz rejectObject
    cmp DWORD PTR [rax+4638h], 2
    jge checkBuildKind
    mov ecx, DWORD PTR [rsp+20h]
    call RequiresExtendedContent
    test al, al
    jnz rejectObject

checkBuildKind:
    mov ecx, DWORD PTR [rsp+20h]
    ; The menu omits these special tools from its ordinary object rows.
    cmp ecx, 1B5h
    je rejectObject
    lea eax, [rcx-110h]
    cmp eax, 3Fh
    ja checkBuildFlag
    mov r8, 0A000000000000007h
    bt r8, rax
    jc rejectObject
checkBuildFlag:
    mov rax, QWORD PTR [rsp+28h]
    test BYTE PTR [rax+98h], 10h
    jnz selectUtilityTool
    call IsUtilityBuildItem
    test al, al
    jz rejectObject
selectUtilityTool:
    mov edx, UtilityTool
checkToolbarAvailability:
    mov DWORD PTR [rsp+30h], edx
    mov rcx, QWORD PTR [Game]
    cmp edx, DoorTool
    jne checkNativeAvailability
    mov edx, ObjectTool                ; Check the item's construction research as well.
checkNativeAvailability:
    mov r8d, DWORD PTR [rsp+20h]
    call CanUseToolbarItem
    test al, al
    jz rejectObject
    mov eax, DWORD PTR [rsp+30h]
    mov edx, DWORD PTR [rsp+20h]
    jmp finishObject
rejectObject:
    xor eax, eax
finishObject:
    add rsp, 38h
    ret
ClassifyPickerObject ENDP

; Run a buildable-only hit test with the stock spatial query and a neutral scratch cursor.
FindPickerObject PROC
    sub rsp, 0E8h
    lea rcx, [rsp+20h]
    mov DWORD PTR [rcx+4], 0
    mov DWORD PTR [rcx+70h], 0
    mov QWORD PTR [rcx+0B0h], -1
    lea rdx, [rdi+30h]
    mov QWORD PTR [PickerHoverTool], rcx
    call ReadStockHover
    mov QWORD PTR [PickerHoverTool], 0
    mov rcx, QWORD PTR [Game]
    mov rcx, QWORD PTR [rcx+198h]
    lea rdx, [rsp+0D0h]
    call ResolveWorldObject
    add rsp, 0E8h
    ret
FindPickerObject ENDP

FindPickerSubToolbar PROC
    sub rsp, 28h
    lea rdx, SubToolbarName
    call GetWindowIdByName
    mov edx, eax
    mov rcx, QWORD PTR [WindowManager]
    call GetWindowById
    add rsp, 28h
    ret
FindPickerSubToolbar ENDP

; RCX is the native submenu, EDX the picked kind, R8D the construction subtype.
FocusPickerToolbarItem PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], rcx
    mov DWORD PTR [rsp+28h], edx
    mov DWORD PTR [rsp+2Ch], r8d
    ; Apply the same keyboard-focus cleanup as a regular map click.
    cmp BYTE PTR [rcx+114h], 0
    je findVisibleRow
    mov DWORD PTR [rcx+2Ch], -1
findVisibleRow:
    mov BYTE PTR [rcx+16Ch], 0
    mov DWORD PTR [rcx+168h], -1       ; Remove the old keyboard cursor. The build item owns the highlight.
    call FindPickerToolbarRow
    test eax, eax
    jns scrollToRow

    mov rcx, QWORD PTR [rsp+20h]
    cmp DWORD PTR [rcx+0C0h], ObjectTool
    jne checkSearchFilter
    mov edx, DWORD PTR [rsp+28h]
    call RevealPickerObjectFilters
    test al, al
    jz checkSearchFilter
    mov rcx, QWORD PTR [rsp+20h]
    mov edx, 1
    call RebuildToolbar
    mov rcx, QWORD PTR [rsp+20h]
    mov edx, DWORD PTR [rsp+28h]
    mov r8d, DWORD PTR [rsp+2Ch]
    call FindPickerToolbarRow
    test eax, eax
    jns scrollToRow

checkSearchFilter:
    ; A matching active search stays in place. Clear it only when it hides the pick.
    mov rcx, QWORD PTR [rsp+20h]
    cmp BYTE PTR [rcx+114h], 0
    je finishToolbarFocus
    cmp QWORD PTR [rcx+128h], 0
    je finishToolbarFocus
    add rcx, 118h
    lea rdx, EmptyToolbarSearch        ; Native search uses 32-bit Unicode code points.
    xor r8d, r8d
    mov r9, -1
    call AssignToolbarSearch
    mov rcx, QWORD PTR [rsp+20h]
    mov QWORD PTR [rcx+138h], 0
    lea rdx, SearchControlName
    call GetControlByName
    test rax, rax
    jz rebuildUnfilteredToolbar
    cmp DWORD PTR [rax+10h], 6
    jne rebuildUnfilteredToolbar
    cmp DWORD PTR [rax+98h], 6
    jne rebuildUnfilteredToolbar
    mov rcx, QWORD PTR [rsp+20h]
    add rcx, 118h
    cmp QWORD PTR [rax+0E8h], rcx
    jne rebuildUnfilteredToolbar
    mov rcx, rax
    call RefreshToolbarSearchControl
rebuildUnfilteredToolbar:
    mov rcx, QWORD PTR [rsp+20h]
    mov edx, 1
    call RebuildToolbar
    mov rcx, QWORD PTR [rsp+20h]
    mov edx, DWORD PTR [rsp+28h]
    mov r8d, DWORD PTR [rsp+2Ch]
    call FindPickerToolbarRow
    test eax, eax
    js finishToolbarFocus
scrollToRow:
    mov rcx, QWORD PTR [rsp+20h]
    lea rdx, IconBoxName
    call GetControlByName
    test rax, rax
    jz finishToolbarFocus
    cmp DWORD PTR [rax+10h], 0Eh
    jne finishToolbarFocus
    ; A new or rebuilt icon grid only has item coordinates after its first layout.
    mov edx, DWORD PTR [rax+0Ch]
    mov DWORD PTR [PickerScrollOwner], edx
    mov edx, DWORD PTR [rsp+28h]
    mov DWORD PTR [PickerScrollKind], edx
    mov edx, DWORD PTR [rsp+2Ch]
    mov DWORD PTR [PickerScrollSubtype], edx
    mov QWORD PTR [PickerScrollIconBox], rax
finishToolbarFocus:
    add rsp, 38h
    ret
FocusPickerToolbarItem ENDP

; Relax only incompatible type and content-pack dropdowns before clearing a search.
RevealPickerObjectFilters PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], rcx
    imul rax, rdx, 198h
    add rax, QWORD PTR [ObjectDefinitions]
    mov QWORD PTR [rsp+28h], rax
    mov BYTE PTR [rsp+30h], 0
    mov ecx, DWORD PTR [rax+64h]
    mov rdx, QWORD PTR [rsp+20h]
    mov eax, DWORD PTR [rdx+148h]
    cmp eax, 999
    jne testObjectType
    test ecx, 100h
    jz checkObjectPack
testObjectType:
    bt ecx, eax
    jc checkObjectPack
    test ecx, ecx
    jnz selectObjectType
    cmp eax, 11
    je checkObjectPack
selectObjectType:
    mov r9d, 999
    test ecx, 100h
    jz setObjectType
    mov r9d, 8
setObjectType:
    mov rcx, QWORD PTR [rsp+20h]
    lea r8, [rcx+148h]
    lea rdx, ObjectTypeControlName
    call UpdatePickerDropdown
    mov BYTE PTR [rsp+30h], 1
checkObjectPack:
    mov rcx, QWORD PTR [rsp+20h]
    cmp DWORD PTR [rcx+14Ch], 0
    je finishObjectFilters
    mov rdx, QWORD PTR [rsp+28h]
    call IsObjectPackMatch
    test al, al
    jnz finishObjectFilters
    mov rcx, QWORD PTR [rsp+20h]
    lea r8, [rcx+14Ch]
    lea rdx, ObjectPackControlName
    xor r9d, r9d
    call UpdatePickerDropdown
    mov BYTE PTR [rsp+30h], 1
finishObjectFilters:
    movzx eax, BYTE PTR [rsp+30h]
    add rsp, 38h
    ret
RevealPickerObjectFilters ENDP

; Update the model even if the native toolbar has no visible dropdown control.
UpdatePickerDropdown PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], r8
    mov DWORD PTR [rsp+28h], r9d
    mov DWORD PTR [r8], r9d
    call GetControlByName
    test rax, rax
    jz finishDropdown
    cmp DWORD PTR [rax+10h], 8
    jne finishDropdown
    mov rdx, QWORD PTR [rsp+20h]
    cmp QWORD PTR [rax+0B8h], rdx
    jne finishDropdown
    mov rcx, rax
    mov edx, DWORD PTR [rsp+28h]
    call SetToolbarDropdownValue
finishDropdown:
    add rsp, 38h
    ret
UpdatePickerDropdown ENDP

; A row is 12 bytes. Object and material IDs can overlap, so match both fields.
FindPickerToolbarRow PROC
    mov r9, QWORD PTR [rcx+0C8h]
    mov ecx, DWORD PTR [rcx+0D4h]
    test r9, r9
    jz noToolbarRow
    test ecx, ecx
    jle noToolbarRow
    xor eax, eax
nextToolbarRow:
    cmp DWORD PTR [r9], edx
    jne advanceToolbarRow
    cmp DWORD PTR [r9+4], r8d
    je returnToolbarRow
advanceToolbarRow:
    add r9, 0Ch
    inc eax
    cmp eax, ecx
    jl nextToolbarRow
noToolbarRow:
    mov eax, -1
returnToolbarRow:
    ret
FindPickerToolbarRow ENDP

ScrollPickedItemAfterLayout PROC
    cmp QWORD PTR [PickerScrollIconBox], rbx
    jne finishDraw
    mov QWORD PTR [PickerScrollIconBox], 0
    mov edx, DWORD PTR [rbx+0Ch]
    cmp edx, DWORD PTR [PickerScrollOwner]
    jne finishDraw
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz finishDraw
    mov ecx, DWORD PTR [PickerScrollKind]
    cmp ecx, DWORD PTR [rax+0CDCh]
    jne finishDraw
    mov ecx, DWORD PTR [PickerScrollSubtype]
    cmp ecx, DWORD PTR [rax+0CE0h]
    jne finishDraw
    mov rcx, QWORD PTR [WindowManager]
    call GetWindowById
    test rax, rax
    jz finishDraw
    mov rcx, rax
    mov edx, DWORD PTR [PickerScrollKind]
    mov r8d, DWORD PTR [PickerScrollSubtype]
    call FindPickerToolbarRow
    mov rcx, rbx
    mov edx, eax
    call ScrollToolbarIconIntoView
finishDraw:
    call FinishIconBoxDraw
    jmp ContinueIconBoxDraw
ScrollPickedItemAfterLayout ENDP

; Stock hover has checked visibility, carry state and the rendered bounds of RDI.
CheckPickerHoverCandidate PROC
    cmp BYTE PTR [rdi+6Dh], 0
    jne rejectHoverCandidate
    mov rdx, QWORD PTR [PickerHoverTool]
    test rdx, rdx
    jz continueHoverCandidate
    cmp QWORD PTR [rsp+120h], rdx
    jne continueHoverCandidate
    mov rcx, rdi
    call ClassifyPickerObject
    test eax, eax
    jz rejectHoverCandidate
continueHoverCandidate:
    jmp ContinueStockHoverCandidate
rejectHoverCandidate:
    jmp RejectStockHoverCandidate
CheckPickerHoverCandidate ENDP

; The private query already has its result. Skip the stock fallback for nearby people.
KeepPickerHoverResult PROC
    cmp QWORD PTR [PickerHoverTool], rsi
    je finishPickerHover
    test r13, r13
    je tryActorHover
    jmp ContinueStockHoverResult
tryActorHover:
    jmp TryStockActorHover
finishPickerHover:
    jmp FinishStockHover
KeepPickerHoverResult ENDP

; Keep the delivered down message even if an up message arrives before the next update.
CaptureMapPickerMiddleButton PROC
    mov BYTE PTR [rcx+14Bh], 1
    mov BYTE PTR [PendingPickerMiddleButton], 1
    jmp ContinueMiddleButtonDown
CaptureMapPickerMiddleButton ENDP

; Publish for exactly one frame, independently of the game's held-state edge.
PublishMapPickerMiddleButton PROC
    mov BYTE PTR [rsi+14Eh], cl
    mov r11b, 0
    xchg BYTE PTR [PendingPickerMiddleButton], r11b
    mov BYTE PTR [FramePickerMiddleButton], r11b
    jmp ContinueFrameMiddleEdge
PublishMapPickerMiddleButton ENDP

ClearMapPickerMiddleButton PROC
    mov BYTE PTR [rdi+148h], bpl
    mov BYTE PTR [PendingPickerMiddleButton], 0
    mov BYTE PTR [FramePickerMiddleButton], 0
    jmp ContinueFocusLost
ClearMapPickerMiddleButton ENDP

END

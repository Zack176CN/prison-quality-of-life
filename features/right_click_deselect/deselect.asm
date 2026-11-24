option casemap:none

EXTERN Game:QWORD
EXTERN InputManager:QWORD
EXTERN WindowManager:QWORD
EXTERN ShiftAndControlKeys:WORD
EXTERN ControlKey:BYTE
EXTERN AltKey:BYTE
EXTERN SubToolbarName:BYTE
EXTERN BuildToolbarVtable:BYTE
EXTERN TapArmed:BYTE
EXTERN PendingTap:BYTE
EXTERN FrameTap:WORD
EXTERN DeselectAfterStock:BYTE
EXTERN TapOrigin:DWORD
EXTERN TapWorld:QWORD
EXTERN TapSelection:QWORD
EXTERN TapMode:DWORD

EXTERN ContinueLowMessage:PROC
EXTERN ContinueHighMessage:PROC
EXTERN ContinueInputFrame:PROC
EXTERN ContinueControlCheck:PROC
EXTERN ContinueMapInput:PROC
EXTERN ContinueMapEpilogue:PROC
EXTERN StopPreviewSound:PROC
EXTERN GetWindowIdByName:PROC
EXTERN GetWindowById:PROC
EXTERN SetBuildItem:PROC

PUBLIC ObserveRightClick
PUBLIC PublishRightClick
PUBLIC StageRightClickDeselect
PUBLIC CanDeselectBuildItem
PUBLIC FinishRightClickDeselect
PUBLIC DeselectBuildItem

KillFocus EQU 8
CancelMode EQU 1Fh
MouseMove EQU 200h
LeftDown EQU 201h
RightDown EQU 204h
RightUp EQU 205h
CaptureChanged EQU 215h
ClickTolerance EQU 4

.code

; EDX is the Win32 message and R10D holds its signed client coordinates.
ObserveRightClick PROC
    cmp edx, RightDown
    je pressRight
    cmp edx, RightUp
    je releaseRight
    cmp edx, MouseMove
    je moveMouse
    cmp edx, KillFocus
    je clearClick
    cmp edx, CancelMode
    je clearClick
    cmp edx, LeftDown
    je clearClick
    cmp edx, CaptureChanged
    jne replayMessageDispatch
    mov BYTE PTR [TapArmed], 0          ; A completed up may itself release capture.
    jmp replayMessageDispatch

pressRight:
    mov WORD PTR [TapArmed], 0
    mov WORD PTR [FrameTap], 0
    test sil, 1                        ; Do not arm a second action during a left click.
    jnz replayMessageDispatch
    cmp BYTE PTR [rcx+148h], 0
    je replayMessageDispatch
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz replayMessageDispatch
    mov r11, QWORD PTR [rax+198h]
    test r11, r11
    jz replayMessageDispatch
    cmp DWORD PTR [rax+0CDCh], -1
    je replayMessageDispatch
    mov QWORD PTR [TapWorld], r11
    mov r11, QWORD PTR [rax+0CDCh]
    mov QWORD PTR [TapSelection], r11
    mov r11d, DWORD PTR [rax+0CD8h]
    mov DWORD PTR [TapMode], r11d
    mov DWORD PTR [TapOrigin], r10d
    mov BYTE PTR [TapArmed], 1
    jmp replayMessageDispatch

moveMouse:
    cmp BYTE PTR [TapArmed], 0
    jne checkMotion
    cmp BYTE PTR [PendingTap], 0
    jne checkReleasedPosition
    cmp BYTE PTR [FrameTap], 0
    je replayMessageDispatch
checkReleasedPosition:
    ; A completed tap cannot migrate from an interface panel into the map.
    cmp DWORD PTR [TapOrigin], r10d
    je replayMessageDispatch
    jmp clearClick

releaseRight:
    cmp BYTE PTR [TapArmed], 0
    je replayMessageDispatch
checkMotion:
    movsx r11d, r10w
    movsx eax, WORD PTR [TapOrigin]
    sub r11d, eax
    add r11d, ClickTolerance
    cmp r11d, 2 * ClickTolerance
    ja clearClick
    mov r11d, r10d
    sar r11d, 16
    mov eax, DWORD PTR [TapOrigin]
    sar eax, 16
    sub r11d, eax
    add r11d, ClickTolerance
    cmp r11d, 2 * ClickTolerance
    ja clearClick
    cmp edx, RightUp
    jne replayMessageDispatch
    mov DWORD PTR [TapOrigin], r10d
    mov WORD PTR [TapArmed], 100h       ; down = 0, pending release = 1
    jmp replayMessageDispatch

clearClick:
    mov WORD PTR [TapArmed], 0
    mov WORD PTR [FrameTap], 0
replayMessageDispatch:
    cmp edx, 7
    ja highMessage
    jmp ContinueLowMessage
highMessage:
    jmp ContinueHighMessage
ObserveRightClick ENDP

PublishRightClick PROC
    mov BYTE PTR [rsi+152h], al
    mov r11b, 0
    xchg BYTE PTR [PendingTap], r11b
    mov BYTE PTR [FrameTap], r11b
    mov BYTE PTR [DeselectAfterStock], 0
    jmp ContinueInputFrame
PublishRightClick ENDP

; Accept a tap after the native map gates, then let the game process its input.
StageRightClickDeselect PROC
    cmp BYTE PTR [ControlKey], 0
    jne stockControlCheck
    cmp BYTE PTR [FrameTap], 0
    je trackWorldMotion
    mov BYTE PTR [FrameTap], 0
    call CanDeselectBuildItem
    mov BYTE PTR [DeselectAfterStock], al
    jmp ContinueMapInput

trackWorldMotion:
    cmp BYTE PTR [TapArmed], 0
    je resumeMapInput
    cmp DWORD PTR [rdi+84h], 3
    jne resumeMapInput
    ; Camera movement can create a real drag even if screen coordinates stay still.
    cvttss2si eax, DWORD PTR [rdi+30h]
    cvttss2si r11d, DWORD PTR [rdi+38h]
    cmp eax, r11d
    jne abandonTap
    cvttss2si eax, DWORD PTR [rdi+34h]
    cvttss2si r11d, DWORD PTR [rdi+3Ch]
    cmp eax, r11d
    je resumeMapInput
abandonTap:
    mov BYTE PTR [TapArmed], 0
resumeMapInput:
    jmp ContinueMapInput
stockControlCheck:
    jmp ContinueControlCheck           ; Retain condition flags for the original Ctrl branch.
StageRightClickDeselect ENDP

CanDeselectBuildItem PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+20h], rcx
    mov QWORD PTR [rsp+28h], r8
    mov r9, QWORD PTR [InputManager]
    test r9, r9
    jz rejectDeselect
    cmp BYTE PTR [r9+148h], 0
    je rejectDeselect
    cmp BYTE PTR [r9+14Ah], 0
    jne rejectDeselect
    cmp BYTE PTR [r9+14Ch], 0
    jne rejectDeselect
    cmp BYTE PTR [r9+14Dh], 0
    jne rejectDeselect
    cmp BYTE PTR [r9+150h], 0
    jne rejectDeselect
    cmp WORD PTR [ShiftAndControlKeys], 0
    jne rejectDeselect
    cmp BYTE PTR [AltKey], 0
    jne rejectDeselect

    mov rax, QWORD PTR [Game]
    test rax, rax
    jz rejectDeselect
    cmp BYTE PTR [rax+0E4Fh], 0
    jne rejectDeselect
    mov rax, QWORD PTR [rax+198h]
    test rax, rax
    jz rejectDeselect
    cmp rax, QWORD PTR [TapWorld]
    jne rejectDeselect
    cmp BYTE PTR [rax+46E2h], 0
    jne rejectDeselect
    cmp DWORD PTR [rax+29E4h], -1
    jne rejectDeselect

    mov edx, DWORD PTR [rdi+70h]
    cmp edx, DWORD PTR [TapMode]
    jne rejectDeselect
    mov rcx, QWORD PTR [rdi+74h]
    cmp rcx, QWORD PTR [TapSelection]
    jne rejectDeselect
    test ecx, ecx
    js rejectDeselect
    cmp edx, 2                        ; Walls & Doors
    je checkConstructionSubtype
    cmp edx, 3                        ; Flooring
    je checkConstructionSubtype
    cmp edx, 5                        ; Objects
    je checkObjectSubtype
    cmp edx, 7                        ; Ordinary utility objects
    jne rejectDeselect
    cmp ecx, 110h                     ; Native network and management actions.
    je rejectDeselect
    cmp ecx, 111h
    je rejectDeselect
    cmp ecx, 1B5h
    je rejectDeselect
checkObjectSubtype:
    cmp DWORD PTR [rdi+78h], 2
    jne rejectDeselect
    jmp checkMovingObject
checkConstructionSubtype:
    cmp DWORD PTR [rdi+78h], 2
    je checkMovingObject
    cmp DWORD PTR [rdi+78h], 3
    jne rejectDeselect

checkMovingObject:
    cmp DWORD PTR [rdi+228h], 1
    jne checkGesture
    cmp DWORD PTR [rdi+22Ch], -1
    je checkGesture
    cmp DWORD PTR [rdi+230h], -1
    jne rejectDeselect

checkGesture:
    cmp BYTE PTR [rdi+1E4h], 0          ; Leave an already finalized native action alone.
    jne rejectDeselect
    cmp DWORD PTR [rdi+84h], 0
    je allowDeselect
    cmp DWORD PTR [rdi+84h], 3
    jne rejectDeselect
    cmp BYTE PTR [r9+152h], 0          ; Do not interrupt a right drag still awaiting its release.
    je rejectDeselect
    cvttss2si edx, DWORD PTR [rdi+30h]
    cvttss2si r11d, DWORD PTR [rdi+38h]
    cmp edx, r11d
    jne rejectDeselect
    cvttss2si edx, DWORD PTR [rdi+34h]
    cvttss2si r11d, DWORD PTR [rdi+3Ch]
    cmp edx, r11d
    jne rejectDeselect
allowDeselect:
    mov eax, 1
    jmp finishCanDeselect
rejectDeselect:
    xor eax, eax
finishCanDeselect:
    mov rcx, QWORD PTR [rsp+20h]
    mov r8, QWORD PTR [rsp+28h]
    add rsp, 38h
    ret
CanDeselectBuildItem ENDP

; Run only at the end of the stock map update, after any cancellation command.
FinishRightClickDeselect PROC
    cmp BYTE PTR [DeselectAfterStock], 0
    je stockMapEpilogue
    mov BYTE PTR [DeselectAfterStock], 0
    mov QWORD PTR [rsp+20h], rax
    mov rax, QWORD PTR [Game]
    test rax, rax
    jz restoreMapResult
    lea rdi, [rax+0C68h]               ; The stock tail may have advanced its local RDI.
    call DeselectBuildItem
restoreMapResult:
    mov rax, QWORD PTR [rsp+20h]
stockMapEpilogue:
    lea r11, [rsp+158h]
    jmp ContinueMapEpilogue
FinishRightClickDeselect ENDP

DeselectBuildItem PROC
    sub rsp, 28h
    mov rax, QWORD PTR [rax+198h]
    cmp rax, QWORD PTR [TapWorld]
    jne finishDeselect
    mov eax, DWORD PTR [rdi+70h]
    cmp eax, DWORD PTR [TapMode]
    jne finishDeselect
    mov rax, QWORD PTR [rdi+74h]
    cmp rax, QWORD PTR [TapSelection]
    jne finishDeselect
    cmp DWORD PTR [rdi+84h], 0
    je clearSelection
    cmp DWORD PTR [rdi+84h], 3
    jne finishDeselect
    cmp BYTE PTR [rdi+1E4h], 0
    je finishDeselect
    mov DWORD PTR [rdi+84h], 0         ; Finish the already submitted native release.
    mov BYTE PTR [rdi+1E4h], 0

clearSelection:
    mov edx, DWORD PTR [rdi+1E0h]
    test edx, edx
    jle clearToolbarCursor
    mov DWORD PTR [rdi+1E0h], -1
    xor r8d, r8d
    call StopPreviewSound

clearToolbarCursor:
    mov rcx, QWORD PTR [WindowManager]
    test rcx, rcx
    jz resetBuildItem
    lea rdx, SubToolbarName
    call GetWindowIdByName
    mov edx, eax
    mov rcx, QWORD PTR [WindowManager]
    call GetWindowById
    test rax, rax
    jz resetBuildItem
    lea rcx, BuildToolbarVtable
    cmp QWORD PTR [rax], rcx
    jne resetBuildItem
    mov ecx, DWORD PTR [rdi+70h]
    cmp DWORD PTR [rax+0C0h], ecx
    jne resetBuildItem
    mov BYTE PTR [rax+16Ch], 0
    mov DWORD PTR [rax+168h], -1

resetBuildItem:
    mov rcx, rdi
    mov edx, -1
    mov r8d, -1
    call SetBuildItem
finishDeselect:
    add rsp, 28h
    ret
DeselectBuildItem ENDP

END

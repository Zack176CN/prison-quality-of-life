; Native context-menu controls for the independent dispatch console prototype.
OPTION CASEMAP:NONE

EXTERN DispatchKind:DWORD
EXTERN AppendContextItem:PROC
EXTERN ContinueContextMenu:PROC
EXTERN StockClick:PROC
EXTERN EnqueueNativeDispatch:PROC
EXTERN GetNativeDispatchState:PROC
EXTERN ConfigureNativeDispatch:PROC
EXTERN CopyNativeCaption:PROC
EXTERN GameLanguage:QWORD
EXTERN DispatchCaptionTable:DWORD
EXTERN NativeWastePermission:PROC
EXTERN NativeExportsPermission:PROC
EXTERN LongTruckMode:PROC
EXTERN PreferredTruckCapacity:DWORD
EXTERN DispatchState:QWORD
EXTERN DispatchLabelCache:QWORD
EXTERN NativeWidgetRenderer:QWORD
EXTERN ContinueWidgetRender:PROC

OneKey EQU 0031716552445150h
TwoKey EQU 0032716552445150h
AutoKey EQU 006F747541445150h
LimitKey EQU 005478614D445150h
BalanceKey EQU 00546C6142445150h
ThresholdKey EQU 00546B7453445150h
StatusKey EQU 0054415453445150h
LengthKey EQU 0054684C54445150h
WasteKey EQU 0074736157445150h
ExportsKey EQU 0074707845445150h
DefaultDispatchConfig EQU 080200h
CaptionRowBytes EQU 96

APPEND_DYNAMIC_BUTTON MACRO key:req, getter:req, widget:req
    mov rax, key
    mov qword ptr [rsp+20h], rax
    mov ecx, dword ptr [rsp+68h]
    call getter
    mov qword ptr [rsp+40h], rax
    mov qword ptr [rsp+50h], rdx
    mov qword ptr [rsp+58h], rdx
    mov rcx, qword ptr [rsp+60h]
    lea rdx, [rsp+20h]
    mov r8d, widget
    lea r9, [rsp+40h]
    call AppendContextItem
ENDM

.code

PUBLIC BuildDispatchMenu
BuildDispatchMenu PROC
    mov eax, DispatchKind
    test eax, eax
    jle stock_components
    cmp dword ptr [rsi+40h], eax
    jne stock_components
    mov rcx, rdi
    call AppendDispatchButtons
stock_components:
    cmp dword ptr [rsi+1D4h], ebx
    jmp ContinueContextMenu
BuildDispatchMenu ENDP

PUBLIC AppendDispatchButtons
AppendDispatchButtons PROC
    sub rsp, 78h
    mov qword ptr [rsp+60h], rcx
    mov qword ptr [rsp+28h], 0
    mov qword ptr [rsp+30h], 7
    mov qword ptr [rsp+38h], 15
    ; The native GUI caption is std::basic_string<UTF32>. The API copies it.
    mov qword ptr [rsp+48h], 0
    mov dword ptr [rsp+68h], 0
    APPEND_DYNAMIC_BUTTON OneKey, GetLocalizedCaption, 1
    mov dword ptr [rsp+68h], 1
    APPEND_DYNAMIC_BUTTON TwoKey, GetLocalizedCaption, 1
    call ReadDispatchConfig
    mov dword ptr [rsp+68h], eax
    APPEND_DYNAMIC_BUTTON AutoKey, GetAutoCaption, 1
    APPEND_DYNAMIC_BUTTON LimitKey, GetLimitCaption, 1
    APPEND_DYNAMIC_BUTTON ThresholdKey, GetThresholdCaption, 1
    call CanBalanceDispatch
    test eax, eax
    jz no_balance_button
    APPEND_DYNAMIC_BUTTON BalanceKey, GetBalanceCaption, 1
no_balance_button:
    cmp byte ptr [LongTruckMode], 0E9h
    jne no_length_button
    APPEND_DYNAMIC_BUTTON LengthKey, GetFleetLengthCaption, 1
no_length_button:
    ; Clear only the cached widget identities. Nothing retains a live
    ; component pointer across construction of a replacement object menu.
    lea rax, DispatchLabelCache
    mov qword ptr [rax], 0
    mov qword ptr [rax+10h], 0
    mov qword ptr [rax+20h], 0
    mov dword ptr [rsp+68h], 30
    APPEND_DYNAMIC_BUTTON WasteKey, GetLocalizedCaption, 3
    mov dword ptr [rsp+68h], 31
    APPEND_DYNAMIC_BUTTON ExportsKey, GetLocalizedCaption, 3
    APPEND_DYNAMIC_BUTTON StatusKey, GetLastStatusCaption, 3
    add rsp, 78h
    ret
AppendDispatchButtons ENDP

PUBLIC GetLocalizedCaption
GetLocalizedCaption PROC
    imul ecx, 2 * CaptionRowBytes
    lea rax, DispatchCaptionTable
    add rax, rcx
    ; Native persisted ASCII setting, including the long-string layout of zh-CN.
    lea r8, GameLanguage
    cmp qword ptr [r8+10h], 17
    jne localized_caption_done
    cmp qword ptr [r8+18h], 16
    jb localized_caption_done
    mov r8, qword ptr [r8]
    test r8, r8
    jz localized_caption_done
    mov r9, 6966696C706D6973h
    cmp qword ptr [r8], r9
    jne localized_caption_done
    mov r9, 73656E6968636465h
    cmp qword ptr [r8+8], r9
    jne localized_caption_done
    cmp byte ptr [r8+10h], 65h
    jne localized_caption_done
    add rax, CaptionRowBytes
localized_caption_done:
    mov edx, dword ptr [rax]
    add rax, 4
    ret
GetLocalizedCaption ENDP

PUBLIC CanBalanceDispatch
CanBalanceDispatch PROC
    xor eax, eax
    cmp byte ptr [NativeWastePermission], 0E9h
    jne check_balance_done
    cmp byte ptr [NativeExportsPermission], 0E9h
    sete al
check_balance_done:
    ret
CanBalanceDispatch ENDP


PUBLIC ReadDispatchConfig
ReadDispatchConfig PROC
    sub rsp, 28h
    call GetNativeDispatchState
    test rax, rax
    jz use_dispatch_default
    mov eax, dword ptr [rax+10h]
    test eax, eax
    jne dispatch_config_ready
use_dispatch_default:
    mov eax, DefaultDispatchConfig
dispatch_config_ready:
    add rsp, 28h
    ret
ReadDispatchConfig ENDP

PUBLIC GetAutoCaption
GetAutoCaption PROC
    movzx eax, cl
    mov ecx, 5
    cmp eax, 15
    je auto_caption
    mov ecx, 6
    cmp eax, 30
    je auto_caption
    mov ecx, 7
    cmp eax, 60
    je auto_caption
    mov ecx, 4
auto_caption:
    jmp GetLocalizedCaption
GetAutoCaption ENDP

PUBLIC GetLimitCaption
GetLimitCaption PROC
    shr ecx, 8
    movzx ecx, cl
    test ecx, ecx
    jz use_first_limit_caption
    cmp ecx, 5
    jbe limit_caption
use_first_limit_caption:
    mov ecx, 1
limit_caption:
    add ecx, 7
    jmp GetLocalizedCaption
GetLimitCaption ENDP

PUBLIC GetBalanceCaption
GetBalanceCaption PROC
    shr ecx, 24
    and ecx, 1
    add ecx, 13
    jmp GetLocalizedCaption
GetBalanceCaption ENDP

PUBLIC GetThresholdCaption
GetThresholdCaption PROC
    shr ecx, 16
    movzx eax, cl
    mov ecx, 15
    cmp eax, 4
    je threshold_caption
    mov ecx, 16
    cmp eax, 8
    je threshold_caption
    mov ecx, 17
    cmp eax, 16
    je threshold_caption
    mov ecx, 18
threshold_caption:
    jmp GetLocalizedCaption
GetThresholdCaption ENDP

PUBLIC GetFleetLengthCaption
GetFleetLengthCaption PROC
    mov eax, PreferredTruckCapacity
    mov ecx, 27
    cmp eax, 12
    je selected_length_caption
    mov ecx, 28
    cmp eax, 16
    je selected_length_caption
    mov ecx, 26
selected_length_caption:
    jmp GetLocalizedCaption
GetFleetLengthCaption ENDP

PUBLIC GetLastStatusCaption
GetLastStatusCaption PROC
    mov ecx, 2
    jmp ReadAndLocalizeDispatchOutcome
GetLastStatusCaption ENDP

PUBLIC ReadAndLocalizeDispatchOutcome
ReadAndLocalizeDispatchOutcome PROC
    sub rsp, 28h
    call ReadDispatchLabelValue
    mov ecx, eax
    add rsp, 28h
    jmp LocalizeDispatchOutcome
ReadAndLocalizeDispatchOutcome ENDP

PUBLIC ReadDispatchLabelValue
ReadDispatchLabelValue PROC
    lea rax, DispatchState
    cmp ecx, 2
    je read_recent_outcome
    cmp dword ptr [rax+48h], 0
    je wait_for_room_counts
    mov rax, qword ptr [rax+50h]
    test ecx, ecx
    jz label_value_ready
    shr rax, 32
label_value_ready:
    ret
wait_for_room_counts:
    mov eax, -1
    ret
read_recent_outcome:
    mov edx, dword ptr [rax+58h]
    test edx, edx
    jne return_outcome
    cmp dword ptr [rax+0Ch], 0
    jle return_outcome
    mov edx, 7
return_outcome:
    mov eax, edx
    ret
ReadDispatchLabelValue ENDP

PUBLIC LocalizeDispatchOutcome
LocalizeDispatchOutcome PROC
    cmp ecx, 7
    je queued_caption
    cmp ecx, 6
    jbe choose_outcome
    xor ecx, ecx
choose_outcome:
    add ecx, 19
    jmp GetLocalizedCaption
queued_caption:
    mov ecx, 29
    jmp GetLocalizedCaption
LocalizeDispatchOutcome ENDP

; The generic widget renderer receives its actual widget in RCX. Match only
; our read-only labels, with no collection or map traversal in rendering.
PUBLIC RenderDispatchLabels
RenderDispatchLabels PROC
    cmp dword ptr [rcx+10h], 3
    jne RenderNativeWidget
    cmp qword ptr [rcx+80h], 7
    jne RenderNativeWidget
    cmp qword ptr [rcx+88h], 15
    jne RenderNativeWidget
    mov rax, qword ptr [rcx+70h]
    mov r8d, 0
    mov r9, WasteKey
    cmp rax, r9
    je RefreshDispatchLabel
    inc r8d
    mov r9, ExportsKey
    cmp rax, r9
    je RefreshDispatchLabel
    inc r8d
    mov r9, StatusKey
    cmp rax, r9
    je RefreshDispatchLabel
    jmp RenderNativeWidget
RenderDispatchLabels ENDP

PUBLIC RenderNativeWidget
RenderNativeWidget PROC
    mov rax, NativeWidgetRenderer
    jmp ContinueWidgetRender
RenderNativeWidget ENDP

PUBLIC RefreshDispatchLabel
RefreshDispatchLabel PROC
    sub rsp, 78h
    mov qword ptr [rsp+80h], rcx
    mov qword ptr [rsp+88h], rdx
    mov dword ptr [rsp+98h], r8d
    mov ecx, r8d
    shl r8d, 4
    lea rax, DispatchLabelCache
    add rax, r8
    mov qword ptr [rsp+90h], rax
    call ReadDispatchLabelValue
    mov r10, qword ptr [rsp+90h]
    mov rcx, qword ptr [rsp+80h]
    cmp qword ptr [r10], rcx
    jne replace_label_text
    cmp dword ptr [r10+8], eax
    je label_render_ready
replace_label_text:
    mov qword ptr [r10], rcx
    mov dword ptr [r10+8], eax
    mov ecx, dword ptr [rsp+98h]
    cmp ecx, 2
    jne format_room_caption
    mov ecx, eax
    call LocalizeDispatchOutcome
    jmp assign_live_caption
format_room_caption:
    mov r8d, eax
    lea rdx, [rsp+20h]
    call FormatDispatchBacklog
assign_live_caption:
    mov r8d, edx
    mov rdx, rax
    mov rcx, qword ptr [rsp+80h]
    call AssignButtonCaption
label_render_ready:
    mov rcx, qword ptr [rsp+80h]
    mov rdx, qword ptr [rsp+88h]
    add rsp, 78h
    jmp RenderNativeWidget
RefreshDispatchLabel ENDP

; ECX selects the room, RDX is the caller's UTF-32 buffer, R8D is the count.
; Create text only when the value changes, using at most ten decimal digits.
PUBLIC FormatDispatchBacklog
FormatDispatchBacklog PROC
    cmp r8d, -1
    jne format_available_count
    add ecx, 30
    jmp GetLocalizedCaption
format_available_count:
    jmp FormatDispatchCount
FormatDispatchBacklog ENDP

PUBLIC FormatDispatchCount
FormatDispatchCount PROC
    sub rsp, 48h
    mov qword ptr [rsp+20h], rdx
    mov dword ptr [rsp+28h], r8d
    add ecx, 32
    call GetLocalizedCaption
    mov r8, qword ptr [rsp+20h]
    mov r9, r8
    mov ecx, edx
copy_room_prefix:
    mov edx, dword ptr [rax]
    mov dword ptr [r9], edx
    add rax, 4
    add r9, 4
    dec ecx
    jnz copy_room_prefix
    mov eax, dword ptr [rsp+28h]
    mov ecx, 10
    xor r10d, r10d
collect_decimal_digits:
    xor edx, edx
    div ecx
    add dl, '0'
    mov byte ptr [rsp+r10+30h], dl
    inc r10d
    test eax, eax
    jnz collect_decimal_digits
write_decimal_digits:
    dec r10d
    movzx eax, byte ptr [rsp+r10+30h]
    mov dword ptr [r9], eax
    add r9, 4
    test r10d, r10d
    jnz write_decimal_digits
    mov dword ptr [r9], 0
    mov rax, r8
    sub r9, r8
    shr r9, 2
    mov edx, r9d
    add rsp, 48h
    ret
FormatDispatchCount ENDP

PUBLIC DispatchClick
DispatchClick PROC
    mov eax, DispatchKind
    test eax, eax
    jle stock_click
    cmp dword ptr [rcx+40h], eax
    jne stock_click
    cmp qword ptr [rdx+80h], 7
    jne stock_click
    cmp qword ptr [rdx+88h], 15
    jne stock_click
    mov r8, OneKey
    cmp qword ptr [rdx+70h], r8
    je request_one
    mov r8, TwoKey
    cmp qword ptr [rdx+70h], r8
    je request_two
    mov r8, AutoKey
    cmp qword ptr [rdx+70h], r8
    je choose_auto
    mov r8, LimitKey
    cmp qword ptr [rdx+70h], r8
    jne check_balance_key
    xor ecx, ecx
    jmp DispatchClickSettings
check_balance_key:
    mov r8, BalanceKey
    cmp qword ptr [rdx+70h], r8
    jne check_threshold_key
    mov ecx, 2
    jmp DispatchClickSettings
check_threshold_key:
    mov r8, ThresholdKey
    cmp qword ptr [rdx+70h], r8
    jne check_length_key
    mov ecx, 3
    jmp DispatchClickSettings
check_length_key:
    mov r8, LengthKey
    cmp qword ptr [rdx+70h], r8
    jne stock_click
    cmp byte ptr [LongTruckMode], 0E9h
    jne stock_click
    jmp DispatchClickLength
choose_auto:
    mov ecx, 1
    jmp DispatchClickSettings
request_two:
    mov ecx, 2
    jmp DispatchClickEnqueue
request_one:
    mov ecx, 1
    jmp DispatchClickEnqueue
stock_click:
    jmp StockClick
DispatchClick ENDP

PUBLIC DispatchClickEnqueue
DispatchClickEnqueue PROC
    sub rsp, 38h
    mov qword ptr [rsp+20h], rdx
    mov dword ptr [rsp+28h], ecx
    call EnqueueNativeDispatch
    test eax, eax
    je show_queue_denied
    cmp dword ptr [rsp+28h], 1
    je restore_first_caption
    mov ecx, 1
    jmp finish_dispatch_click
restore_first_caption:
    xor ecx, ecx
    jmp finish_dispatch_click
show_queue_denied:
    mov ecx, 2
finish_dispatch_click:
    call GetLocalizedCaption
    mov r8d, edx
    mov rdx, rax
    mov rcx, qword ptr [rsp+20h]
    add rsp, 38h
    jmp AssignButtonCaption
DispatchClickEnqueue ENDP

PUBLIC DispatchClickLength
DispatchClickLength PROC
    sub rsp, 38h
    mov qword ptr [rsp+20h], rdx
    mov eax, PreferredTruckCapacity
retry_length:
    mov ecx, 12
    test eax, eax
    jz set_length
    cmp eax, 8
    je set_length
    mov ecx, 16
    cmp eax, 12
    je set_length
    mov ecx, 8
set_length:
    lock cmpxchg PreferredTruckCapacity, ecx
    jne retry_length
    call GetFleetLengthCaption
    mov r8d, edx
    mov rdx, rax
    mov rcx, qword ptr [rsp+20h]
    add rsp, 38h
    jmp AssignButtonCaption
DispatchClickLength ENDP


PUBLIC DispatchClickSettings
DispatchClickSettings PROC
    sub rsp, 38h
    mov qword ptr [rsp+20h], rdx
    mov dword ptr [rsp+28h], ecx
    cmp ecx, 2
    jne settings_supported
    call CanBalanceDispatch
    test eax, eax
    jz show_settings_unavailable
settings_supported:
    call ReadDispatchConfig
    mov ecx, eax
    mov edx, eax
    mov r8d, eax
    mov r9d, eax
    movzx ecx, cl
    shr edx, 8
    movzx edx, dl
    shr r8d, 16
    movzx r8d, r8b
    shr r9d, 24
    cmp dword ptr [rsp+28h], 3
    je cycle_threshold
    cmp dword ptr [rsp+28h], 2
    je toggle_current_balance
    cmp dword ptr [rsp+28h], 0
    jne cycle_auto
    inc edx
    cmp edx, 5
    jbe configure_settings
    mov edx, 1
    jmp configure_settings
cycle_auto:
    add ecx, 15
    cmp ecx, 45
    jb configure_settings
    mov eax, 60
    cmove ecx, eax
    je configure_settings
    xor ecx, ecx
    jmp configure_settings
toggle_current_balance:
    xor r9d, 1
    jmp configure_settings
cycle_threshold:
    mov eax, 8
    cmp r8d, 4
    je set_threshold
    mov eax, 16
    cmp r8d, 8
    je set_threshold
    mov eax, 4
set_threshold:
    mov r8d, eax
configure_settings:
    call ConfigureNativeDispatch
    test eax, eax
    jz show_settings_unavailable
    call ReadDispatchConfig
    mov ecx, eax
    cmp dword ptr [rsp+28h], 3
    je show_threshold_setting
    cmp dword ptr [rsp+28h], 2
    je show_balance_setting
    cmp dword ptr [rsp+28h], 0
    jne show_auto_setting
    call GetLimitCaption
    jmp assign_settings_caption
show_auto_setting:
    call GetAutoCaption
    jmp assign_settings_caption
show_balance_setting:
    call GetBalanceCaption
    jmp assign_settings_caption
show_threshold_setting:
    call GetThresholdCaption
    jmp assign_settings_caption
show_settings_unavailable:
    mov ecx, 3
    call GetLocalizedCaption
assign_settings_caption:
    mov r8d, edx
    mov rdx, rax
    mov rcx, qword ptr [rsp+20h]
    add rsp, 38h
    jmp AssignButtonCaption
DispatchClickSettings ENDP

PUBLIC AssignButtonCaption
AssignButtonCaption PROC
    sub rsp, 48h
    mov qword ptr [rsp+20h], rdx
    mov qword ptr [rsp+28h], 0
    mov qword ptr [rsp+30h], r8
    mov qword ptr [rsp+38h], r8
    add rcx, 30h
    lea rdx, [rsp+20h]
    xor r8d, r8d
    or r9, -1
    call CopyNativeCaption
    add rsp, 48h
    ret
AssignButtonCaption ENDP

END

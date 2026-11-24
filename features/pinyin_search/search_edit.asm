option casemap:none

EXTERN AssignWideString:PROC
EXTERN WindowManager:QWORD
EXTERN GetWindowById:PROC
EXTERN BuildToolbarVtable:BYTE

PUBLIC AssignAndRefreshToolbarSearch

.code

; Stock input edit call sites hold their text control in RDI.
AssignAndRefreshToolbarSearch PROC
    sub rsp, 38h
    mov QWORD PTR [rsp+28h], rcx
    call AssignWideString
    mov QWORD PTR [rsp+20h], rax

    cmp DWORD PTR [rdi+10h], 6
    jne finishAssign
    cmp DWORD PTR [rdi+98h], 6
    jne finishAssign
    mov rax, QWORD PTR [rsp+28h]
    cmp QWORD PTR [rdi+0E8h], rax
    jne finishAssign
    mov rcx, QWORD PTR [WindowManager]
    test rcx, rcx
    jz finishAssign
    mov edx, DWORD PTR [rdi+0Ch]
    call GetWindowById
    test rax, rax
    jz finishAssign
    lea rcx, BuildToolbarVtable
    cmp QWORD PTR [rax], rcx
    jne finishAssign
    cmp BYTE PTR [rax+114h], 0
    je finishAssign
    lea rcx, [rax+118h]
    cmp rcx, QWORD PTR [rsp+28h]
    jne finishAssign
    mov BYTE PTR [rax+17Ch], 1          ; Stock toolbar update rebuilds even at the same length.
finishAssign:
    mov rax, QWORD PTR [rsp+20h]
    add rsp, 38h
    ret
AssignAndRefreshToolbarSearch ENDP

END

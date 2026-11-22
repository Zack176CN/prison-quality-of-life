option casemap:none

EXTERN DispatchObjectKind:DWORD
EXTERN LanguagePreference:QWORD
EXTERN LanguageMap:QWORD
EXTERN HasTranslation:PROC
EXTERN GetOrInsertTranslation:PROC
EXTERN CopyTranslationValue:PROC
EXTERN LoadLanguageFile:PROC
EXTERN DispatchNameKey:BYTE
EXTERN DispatchTooltipKey:BYTE
EXTERN EnglishStrings:BYTE
EXTERN ChineseStrings:BYTE
EXTERN ChineseLocale:BYTE

PUBLIC ReloadDispatchLanguage, RegisterDispatchTranslations, AddDispatchTranslation

.code

ReloadDispatchLanguage PROC
    sub rsp, 28h
    call LoadLanguageFile
    call RegisterDispatchTranslations
    add rsp, 28h
    ret
ReloadDispatchLanguage ENDP

RegisterDispatchTranslations PROC
    sub rsp, 38h
    cmp DWORD PTR [DispatchObjectKind], 0
    jle localizedDone
    cmp QWORD PTR [LanguageMap], 0
    je localizedDone
    lea r10, EnglishStrings
    lea rax, LanguagePreference
    cmp QWORD PTR [rax+10h], 17
    jne chooseLocale
    cmp QWORD PTR [rax+18h], 16
    jb chooseLocale
    mov rax, QWORD PTR [rax]
    test rax, rax
    jz chooseLocale
    lea rdx, ChineseLocale
    mov r11, QWORD PTR [rdx]
    cmp QWORD PTR [rax], r11
    jne chooseLocale
    mov r11, QWORD PTR [rdx+8]
    cmp QWORD PTR [rax+8], r11
    jne chooseLocale
    cmp BYTE PTR [rax+10h], 'e'
    jne chooseLocale
    lea r10, ChineseStrings
chooseLocale:
    mov QWORD PTR [rsp+20h], r10
    mov ecx, 24
    lea rdx, DispatchNameKey
    mov r8d, DWORD PTR [r10]
    lea r9, [r10+8]
    call AddDispatchTranslation

    mov r10, QWORD PTR [rsp+20h]
    mov ecx, 40
    lea rdx, DispatchTooltipKey
    mov r8d, DWORD PTR [r10+4]
    mov eax, DWORD PTR [r10]
    lea r9, [r10+rax*4+12]
    call AddDispatchTranslation
localizedDone:
    add rsp, 38h
    ret
RegisterDispatchTranslations ENDP

; Native case-insensitive translation map takes MSVC std::string keys and owns
; the copied UTF-32 values. Leave another source's explicitly supplied key alone.
AddDispatchTranslation PROC
    sub rsp, 68h
    mov QWORD PTR [rsp+20h], rdx
    mov QWORD PTR [rsp+30h], rcx
    mov QWORD PTR [rsp+38h], rcx
    mov QWORD PTR [rsp+40h], r9
    mov QWORD PTR [rsp+50h], r8
    mov QWORD PTR [rsp+58h], r8
    lea rdx, [rsp+20h]
    call HasTranslation
    test al, al
    jnz translationDone
    mov rcx, QWORD PTR [LanguageMap]
    lea rdx, [rsp+20h]
    call GetOrInsertTranslation
    mov rcx, rax
    lea rdx, [rsp+40h]
    xor r8d, r8d
    mov r9, -1
    call CopyTranslationValue
translationDone:
    add rsp, 68h
    ret
AddDispatchTranslation ENDP

END

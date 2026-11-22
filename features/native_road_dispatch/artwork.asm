option casemap:none

EXTERN ReadStockBitmap:PROC
EXTERN DispatchArtworkReady:BYTE

PUBLIC DeriveDispatchArtwork

.code

SourceXBytes EQU 1216 * 4
TargetXBytes EQU 1856 * 4
FrameRunBytes EQU 192 * 4
FrameRows EQU 96
BitmapHeight EQU 2048
SourceYRows EQU BitmapHeight - 832 - FrameRows
TargetYRows EQU BitmapHeight - 448 - FrameRows

; Stock PNG decoding supplies RGBA rows in bottom-to-top order. Copy both
; rectangles in that order, keeping the atlas sprite's top-left coordinates.
DeriveDispatchArtwork PROC
    push rbx
    push rsi
    push rdi
    sub rsp, 30h
    mov rbx, rcx
    call ReadStockBitmap
    mov QWORD PTR [rsp+20h], rax
    mov BYTE PTR [DispatchArtworkReady], 0
    cmp DWORD PTR [rbx], 2048
    jne finished
    cmp DWORD PTR [rbx+4], BitmapHeight
    jne finished
    mov r9, QWORD PTR [rbx+18h] ; Bitmap row pointers.
    test r9, r9
    jz finished

    ; Check the stock wiring in each orientation before reading nearby pixels.
    mov r10, QWORD PTR [r9+(BitmapHeight-1-856)*8]
    test r10, r10
    jz finished
    cmp DWORD PTR [r10+1239*4], 0FF121163h
    jne finished
    mov r10, QWORD PTR [r9+(BitmapHeight-1-835)*8]
    test r10, r10
    jz finished
    cmp DWORD PTR [r10+1324*4], 0FF2120B8h
    jne finished
    mov r10, QWORD PTR [r9+(BitmapHeight-1-853)*8]
    test r10, r10
    jz finished
    cmp DWORD PTR [r10+1381*4], 0FF252351h
    jne finished

    xor r8d, r8d
validateRow:
    cmp QWORD PTR [r9+r8*8+SourceYRows*8], 0
    je finished
    mov r10, QWORD PTR [r9+r8*8+TargetYRows*8]
    test r10, r10
    jz finished
    xor esi, esi
validatePixel:
    cmp BYTE PTR [r10+rsi+TargetXBytes+3], 0
    jne finished
    add esi, 4
    cmp esi, FrameRunBytes
    jb validatePixel
    inc r8d
    cmp r8d, FrameRows
    jb validateRow

    xor r8d, r8d
copyRow:
    mov r10, QWORD PTR [r9+r8*8+TargetYRows*8]
    mov r11, QWORD PTR [r9+r8*8+SourceYRows*8]
    xor esi, esi
copyPixel:
    mov eax, DWORD PTR [r11+rsi+SourceXBytes]
    test eax, 0FF000000h
    jz storePixel
    movzx edx, al             ; Red.
    mov ecx, eax
    shr ecx, 8
    and ecx, 255              ; Green.
    lea edi, [rcx+18]
    cmp edx, edi
    jb storePixel
    mov edi, eax
    shr edi, 16
    and edi, 255              ; Blue.
    add edi, 18
    cmp edx, edi
    jb storePixel
    lea edx, [rdx+rcx*2]     ; Luminance estimate (R + 2G + B) / 4.
    lea edx, [rdx+rdi-18]
    shr edx, 2
    and eax, 0FF000000h
    mov ecx, edx
    shl ecx, 8
    or eax, ecx
    mov ecx, edx
    shr ecx, 3
    mov edi, edx
    sub edi, ecx
    or eax, edi
    mov ecx, edx
    shr ecx, 4
    sub edx, ecx
    shl edx, 16
    or eax, edx
storePixel:
    mov DWORD PTR [r10+rsi+TargetXBytes], eax
    add esi, 4
    cmp esi, FrameRunBytes
    jb copyPixel
    inc r8d
    cmp r8d, FrameRows
    jb copyRow
    mov BYTE PTR [DispatchArtworkReady], 1
finished:
    mov rax, QWORD PTR [rsp+20h]
    add rsp, 30h
    pop rdi
    pop rsi
    pop rbx
    ret
DeriveDispatchArtwork ENDP

END

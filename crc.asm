; AUTHOR: SZYMON KRUK

; Files in Linux can contain holes. This program calculates and displays
; CRC of file given as a first parameter with a polynomial of max degree 65 
; given as the second one.We do not write the most significant bit of 
; polynomial. For the purposes of this program, we assume that a holes
; containing file consists of continuous fragments. At the beginning of
; a fragment, there is a two-byte length indicating the number of bytes of data
; in the fragment. Then comes the data. The fragment ends with a four-byte
; offset, which tells how many bytes to skip from the end of this fragment to
; the beginning of the next fragment. The length of the data in the block is
; a 16-bit number in natural binary encoding. The offset is a 32-bit number in
; two's complement encoding. The numbers in the file are stored in 
; little-endian order. The first fragment starts at the beginning of the file.
; The last fragment is identified by its offset pointing to itself.
; Fragments in the file can be next to each other and overlap.

global _start

section .bss

buffer resq 2                   ; Lowest 4 bytes are used to hold offset
                                ; Next 2 bytes are used to hold data
                                ; amount in current fragment
                                ; Highest 9 bytes are used to perform
                                ; CRC calculation on loaded data
section .text

SYS_OPEN equ 2                  ; system function codes
SYS_CLOSE equ 3
SYS_READ equ 0
SYS_WRITE equ 1
SYS_EXIT equ 60
SYS_LSEEK equ 8
ERROR_EXIT_CODE equ 1           ; exit codes
PROPER_EXIT_CODE equ 0
STRING_BUFFER_SIZE equ 65       ; Biggest string possible we may have to write
FRAG_INFO_SIZE equ 6            ; Size of offset and data amount blocks added
NL equ 10                       ; ASCII code of new line sign
DATA_AMOUNT_SIZE equ 2          ; Size of data amount block 
OFFSET_BLOCK_SIZE equ 4         ; Size of offset block
CORRECT_PARAMS_NUM equ 3        ; Correct number of params on stack
STANDARD_OUTPUT equ 1
RELATIVE_TO_CURR equ 1          ; Mode of sys_lseek to move cursor by offset
                                ; from it's current postion           

_start:
    mov rax, [rsp]              ; Move number of paramaters to rax
    cmp rax, CORRECT_PARAMS_NUM ; Check if number of parameters is correct
    jne .forceExit

    mov rax, SYS_OPEN           ; Prepare for file opening                      
    mov rdi, [rsp + 16]         ; Move pointer to file name
    xor rsi, rsi                ; Set open flags to 0
    xor rdx, rdx                ; Set open mode to 0
    syscall
    cmp rax, 0                  ; Check for syscall error
    js .forceExit
    mov rdi, rax                ; Save file descriptor
    
    xor r8, r8                  ; Clean r8 to keep polynomial
    mov rcx, [rsp + 24]         ; Move pointer to string polynomial
    mov rdx, rcx                ; Memorize original adress to keep track
                                ; of polynomial's length
.convertPoly:
    cmp byte [rcx], 0           ; Check if string parameter has ended
    je .checkPolyLength
    inc rcx                     ; Continue iteration over parameter
    shl r8, 1                   ; Prepare next polynomial bit
    cmp byte [rcx - 1], '1'     ; Check if '1' occured in polynomial
    jne .checkForZero
    inc r8                      ; Copy '1' to polynomial
    jmp .convertPoly            ; Continue loading polynomial

.checkForZero:
    cmp byte [rcx - 1], '0'     ; Check if '0' occured in polynomial
    jz .convertPoly             ; Continue loading polynomial
    jmp .error                  ; Other sign than '1' or '0' occured

.checkPolyLength:
    sub rcx, rdx                ; Calculate polynomial's length
    test rcx, rcx               ; Check if polynomial is constant
    jz .error                       
    mov rbx, rcx                ; Memorize poly length
    sub rcx, 65                 ; Check if polynomial is not to big
    jns .error

    inc rcx                     ; Calculate 64 - "poly_length"
    neg rcx                     ; to shift it to the left side of register
    shl r8, cl                  ; Shift polynomial to the right side
                                ; of register to perform xor

    xor r9, r9                  ; Clear r9 to keep number of loaded data bytes
    xor r10, r10                ; Clear r10 to keep flag
    xor r14d, r14d              ; Clear r14 to keep amount of data loaded
                                ; from current fragment
    xor r13d, r13d              ; Clear r13 to keep amount of data left
                                ; in current fragment
.calculateCRC:
    cmp r9, 9                   ; Check if we have enough data to perfom XOR.
                                ; We need at least 8 bytes because of the max
                                ; poly length and reserve byte of data to
                                ; shift it in after every data shift.
    js .loadMoreData

.processNextByte:
    mov ecx, 8                  ; Prepare counter for next byte processing

.performXOR:
    shl qword [buffer + 8], 1   ; Shift data to the left
    jnc .skipXOR                ; Check if we should XOR the data
    inc r10                     ; Set flag to perform XOR

.skipXOR:
    shl byte [buffer + 7], 1    ; Shift in reserve data to the main buffer
    jnc .dontAdd                
    inc qword [buffer + 8]      

.dontAdd:
    shr r10, 1                  ; Check XOR flag
    jnc .dontXOR
    xor qword [buffer + 8], r8  ; XOR data with polynomial

.dontXOR:
    loop .performXOR            ; Continue byte processing
    dec r9                      ; Update amount of data bytes left
    cmp r9, 8                   ; Check if we should ask for mote data
                                ; If we got less than 8 bytes it means
                                ; we have loaded the whole file 
    jz .calculateCRC            
    test r9, r9                 ; Check if we finished processing
                                ; left over data with feeded zeros
    jnz .processNextByte        
    jmp .finalize               ; Quit calculating CRC

.loadMoreData:
    cmp r13w, 0                 ; Check if we have some data left
                                ; in the previous fragment
    jnz .loadDataFromPreviousFragment               
                                ; Go to the next fragment
    xor eax, eax                ; Clear rax to check if we are in the last frag
    movsx rax, dword [buffer]   ; Move signed extended offset to rax
    add rax, FRAG_INFO_SIZE     ; Add number of fragment info and data bytes
    add ax, r14w                ; Add amount of data in the fragment
    jz .processNextByte         ; Offset points to the beginning of the fragment

    mov rax, SYS_LSEEK          ; Prepare for moving file cursor
    movsx rsi, dword [buffer]   ; Move sign extended offset to rsi
    mov rdx, RELATIVE_TO_CURR   ; Configure sys_lseek mode
    syscall
    cmp rax, 0                  ; Check for syscall error
    js .error

    mov rax, SYS_READ           ; Prepare for reading number of data in new frag
    mov rsi, buffer             ; Move pointer to buffer to rsi
    add rsi, 4                  ; Set buffer to value mentioned in description
    mov rdx, DATA_AMOUNT_SIZE   ; Set reading size
    syscall
    cmp rax, 0                  ; Check for syscall error
    js .error                       

    mov r14w, word [buffer + 4]
    mov r13w, r14w

.loadDataFromPreviousFragment:
    dec r13w                    ; Update amount of data left in the fragment
    mov rax, SYS_READ           ; Prepare for reading data
    mov rsi, buffer             ; Move buffer to rsi
    add rsi, 15                 ; Calculate where to put next data byte
    sub rsi, r9
    mov edx, 1                  ; Read data by bytes
    syscall
    cmp rax, 0                  ; Check for syscall error
    js .error   
    add r9, rdx                 ; Update amount of loaded data bytes
    cmp r13w, 0                 ; Check if we got to the end of the fragment
    jnz .calculateCRC           ; Continue processing data

    mov rax, SYS_READ           ; Read offset for a future file cursor move
    mov rsi, buffer             ; Move buffer to rsi
    mov rdx, OFFSET_BLOCK_SIZE  ; Set read size 
    syscall
    cmp rax, 0                  ; Check for syscall error
    js .error                   
    jmp .calculateCRC           ; Continue processing data

.finalize:
    mov r8, [buffer + 8]        ; Move CRC to r8 as we don't need poly anymore

    xor ecx, ecx                ; Clean rcx for iteration purposes
    sub rsp, STRING_BUFFER_SIZE ; Create buffer for CRC string representation

.prepareWriteBuffer:
    mov byte [rsp + rcx], '0'   ; Initialize next buffer byte with zero 
    shl r8, 1                   ; Process next MSB of CRC
    jnc .movZeroToBuffer        ; Zero was loaded correctly
    inc byte [rsp + rcx]        ; Change zero into one

.movZeroToBuffer:
    inc ecx                     ; Increment iterator
    cmp ecx, ebx                ; Check if we processed the whole CRC
    jnz .prepareWriteBuffer     ; Continue CRC processing
    mov byte [rsp + rcx], NL    ; Add new line sign at the end of buffer

.writeResult:
    mov rax, SYS_WRITE          ; Prepare for writing the result
    mov r14, rdi                ; Memorize file descriptor
    mov rdi, STANDARD_OUTPUT    ; Set default output
    mov rsi, rsp                ; Set from where to write
    mov edx, ebx
    inc edx                     ; Write (poly length) + 1 bytes to include
                                ; new line sign
    syscall                     
    mov rdi, r14                ; Move file descriptor back to rdi
    cmp rax, 0                  ; Check for syscall error
    js .error                   

    add rsp, STRING_BUFFER_SIZE ; Reset rsp to previous state
    mov r14, PROPER_EXIT_CODE   ; Set exit code
    jmp .exit

.error:
    mov r14, ERROR_EXIT_CODE    ; Set exit code

.exit:
    mov rax, SYS_CLOSE          ; Close file
    syscall                     ; File decsriptor is already in rdi
    cmp rax, 0                  ; Check for syscall error
    js .forceExit
    mov rax, SYS_EXIT           ; Exit program
    mov rdi, r14                ; Load exit code to rdi
    syscall

.forceExit:
    mov rdi, ERROR_EXIT_CODE    ; Exit program without closing file
    mov rax, SYS_EXIT
    syscall
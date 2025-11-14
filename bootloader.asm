[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [drive], dl


    mov ah, 0x41
    mov bx, 0x55AA
    int 0x13
    jc halt


    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov cx, 64
    mov si, 1
    call read_lba


    mov ax, 0x2000
    mov es, ax
    mov cx, 126
    mov si, 65
    call read_lba


    mov ax, 0x7000
    mov es, ax
    mov cx, 64
    mov si, 191
    call read_lba


    mov ax, 0x13
    int 0x10


    in al, 0x92
    or al, 2
    out 0x92, al


    cli
    lgdt [gdt_desc]


    mov eax, cr0
    or al, 1
    mov cr0, eax

    jmp 0x08:pm_start



read_lba:
    pusha

.loop:
    test cx, cx
    jz .done


    mov byte [dap], 0x10
    mov byte [dap+1], 0
    mov word [dap+2], 1
    mov word [dap+4], bx
    mov word [dap+6], es
    mov dword [dap+8], esi
    mov dword [dap+12], 0


    push cx
    push si
    mov ah, 0x42
    mov dl, [drive]
    mov si, dap
    int 0x13
    pop si
    pop cx
    jc halt


    inc si
    add bx, 512
    jnc .no_wrap
    mov ax, es
    add ax, 0x1000
    mov es, ax
    xor bx, bx
.no_wrap:
    dec cx
    jmp .loop

.done:
    popa
    ret

halt:
    cli
    hlt
    jmp halt


drive: db 0

align 4
dap: times 16 db 0


[BITS 32]
pm_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000


    mov edi, 0xA0000
    mov ecx, 64000
    xor al, al
    rep stosb

    jmp 0x08:0x10000


align 8
gdt:
    dq 0
    dq 0x00CF9A000000FFFF
    dq 0x00CF92000000FFFF
gdt_end:

gdt_desc:
    dw gdt_end - gdt - 1
    dd gdt


times 510-($-$$) db 0
dw 0xAA55

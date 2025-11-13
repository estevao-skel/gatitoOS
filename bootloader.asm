; ===================================
;  BOOTLOADER 32-BIT - GATITO OS v3.0
;  bootloader.asm (LBA MODE)
; ===================================
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

    mov [boot_drive], dl

    ; Mostra mensagem de carregamento
    mov si, loading_msg
    call print_string

    ; Verifica suporte LBA
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc no_lba_support
    cmp bx, 0xAA55
    jne no_lba_support

    ; === CARREGA KERNEL: 64 setores a partir do LBA 1 ===
    mov si, loading_kernel
    call print_string

    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov dword [dap_lba], 1          ; Começa no setor 1
    mov word [dap_count], 64        ; 64 setores
    mov word [dap_offset], 0
    mov word [dap_segment], 0x1000

    call load_sectors_lba
    jc disk_error

    mov si, kernel_ok
    call print_string

    ; === CARREGA IMAGEM: 126 setores a partir do LBA 65 ===
    mov si, loading_image
    call print_string

    mov dword [dap_lba], 65         ; Começa no setor 65
    mov word [dap_count], 126       ; 126 setores
    mov word [dap_offset], 0
    mov word [dap_segment], 0x2000

    call load_sectors_lba
    jc .skip_image

    mov si, image_ok
    call print_string
    jmp .continue_boot

.skip_image:
    mov si, image_skip_msg
    call print_string

.continue_boot:
    ; *** CONFIGURA VGA MODO 13h (320x200x256) ***
    mov ax, 0x0013
    int 0x10

    ; Habilita linha A20 (método rápido)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Carrega GDT
    cli
    lgdt [gdt_descriptor]

    ; Entra em modo protegido
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Jump far para código 32-bit
    jmp 0x08:protected_start

; ---------------------------------
;  FUNÇÕES 16-BIT
; ---------------------------------
print_string:
    pusha
.loop:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp .loop
.done:
    popa
    ret

; Carrega setores usando LBA (em chunks de 127 setores)
load_sectors_lba:
    pusha
    mov si, dap

.read_loop:
    ; Verifica se ainda há setores para ler
    cmp word [dap_count], 0
    je .done

    ; Determina quantos setores ler (máximo 127 por vez)
    mov ax, [dap_count]
    cmp ax, 127
    jbe .read_amount_ok
    mov ax, 127
.read_amount_ok:
    mov [dap_sectors], ax

    ; Faz a leitura LBA
    mov ah, 0x42
    mov dl, [boot_drive]
    int 0x13
    jc .error

    ; Atualiza contadores
    mov ax, [dap_sectors]
    add [dap_lba], ax           ; Próximo LBA
    sub [dap_count], ax         ; Setores restantes

    ; Atualiza segmento de destino (ax * 32 parágrafos)
    mov cx, ax
    shl cx, 5
    mov ax, [dap_segment]
    add ax, cx
    mov [dap_segment], ax

    jmp .read_loop

.done:
    popa
    clc
    ret

.error:
    popa
    stc
    ret

no_lba_support:
    mov si, no_lba_msg
    call print_string
    jmp disk_error

disk_error:
    mov si, error_msg
    call print_string
    cli
    hlt

; ---------------------------------
;  DADOS
; ---------------------------------
boot_drive:      db 0
loading_msg:     db 'Gatito OS v3.0', 13, 10, 0
loading_kernel:  db 'Kernel...', 0
kernel_ok:       db 'OK', 13, 10, 0
loading_image:   db 'Imagem...', 0
image_ok:        db 'OK', 13, 10, 0
image_skip_msg:  db 'SKIP', 13, 10, 0
error_msg:       db 13, 10, 'ERRO!', 13, 10, 0
no_lba_msg:      db 13, 10, 'LBA nao suportado!', 13, 10, 0

; DAP (Disk Address Packet) para LBA
align 4
dap:
    db 0x10             ; Tamanho do DAP (16 bytes)
    db 0                ; Reservado (sempre 0)
dap_sectors:
    dw 0                ; Número de setores a ler
dap_offset:
    dw 0                ; Offset do buffer
dap_segment:
    dw 0                ; Segmento do buffer
dap_lba:
    dd 0                ; LBA baixo (32 bits)
    dd 0                ; LBA alto (32 bits) - sempre 0 para discos pequenos

; Variáveis de controle
dap_count:       dw 0   ; Total de setores a carregar

; ---------------------------------
;  MODO PROTEGIDO 32-BIT
; ---------------------------------
[BITS 32]
protected_start:
    ; Configura todos os segmentos de dados
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Limpa a tela VGA (preto)
    mov edi, 0xA0000
    mov ecx, 64000
    xor al, al
    rep stosb

    ; Salta para o kernel em 0x10000
    jmp 0x08:0x10000

; ---------------------------------
;  GDT (Global Descriptor Table)
; ---------------------------------
align 8
gdt_start:
    ; Descritor nulo
    dq 0

gdt_code:
    ; Segmento de código: base=0, limit=0xFFFFF
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10011010b    ; Flags: Present, Ring 0, Code, Executable, Readable
    db 11001111b    ; Flags: Granularity, 32-bit
    db 0x00         ; Base (bits 24-31)

gdt_data:
    ; Segmento de dados: base=0, limit=0xFFFFF
    dw 0xFFFF       ; Limit (bits 0-15)
    dw 0x0000       ; Base (bits 0-15)
    db 0x00         ; Base (bits 16-23)
    db 10010010b    ; Flags: Present, Ring 0, Data, Writable
    db 11001111b    ; Flags: Granularity, 32-bit
    db 0x00         ; Base (bits 24-31)

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; Tamanho da GDT
    dd gdt_start                ; Endereço da GDT

; ---------------------------------
;  ASSINATURA DE BOOT
; ---------------------------------
times 510-($-$$) db 0
dw 0xAA55

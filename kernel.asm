[BITS 32]
[ORG 0x10000]

; ============================================================================
; GATITO OS - SISTEMA OPERACIONAL MODERNO EM ASSEMBLY X86 32-BIT
; Inspirado no Windows 11 com interface moderna e funcionalidades completas
; ============================================================================

; Constantes de Hardware e Memória
VGA_MEMORY          equ 0xA0000
SCREEN_WIDTH        equ 320
SCREEN_HEIGHT       equ 200
SCREEN_SIZE         equ 64000

; Constantes de Buffers
CLIPBOARD_SIZE      equ 4096
TEXT_BUFFER_SIZE    equ 8192
CMD_BUFFER_SIZE     equ 1024
HISTORY_SIZE        equ 4096

; Constantes do Sistema de Arquivos
FS_MAX_FILES        equ 128
FS_FILENAME_LEN     equ 32
FS_CONTENT_LEN      equ 512
FS_ENTRY_SIZE       equ 544

; Endereços de Memória
IMAGE_BUFFER        equ 0x20000
SCREENSHOT_BUFFER   equ 0x30000
FILESYSTEM_BASE     equ 0x50000
WALLPAPER_BUFFER    equ 0x80000
TEMP_BUFFER         equ 0xB0000

; Portas de Hardware
PS2_DATA            equ 0x60
PS2_STATUS          equ 0x64
PS2_COMMAND         equ 0x64
PIC1_COMMAND        equ 0x20
PIC1_DATA           equ 0x21
PIC2_COMMAND        equ 0xA0
PIC2_DATA           equ 0xA1

; Identificadores de Telas
SCREEN_DESKTOP      equ 0
SCREEN_START_MENU   equ 1
SCREEN_NOTEPAD      equ 2
SCREEN_TERMINAL     equ 3
SCREEN_EXPLORER     equ 4
SCREEN_CALCULATOR   equ 5
SCREEN_PAINT        equ 6
SCREEN_SETTINGS     equ 7
SCREEN_CALENDAR     equ 8
SCREEN_CLOCK        equ 9

; Cores da Paleta Moderna (Windows 11 Style)
COLOR_BLACK         equ 0x00
COLOR_DARK_BG       equ 0x01    ; Azul escuro profundo
COLOR_BLUE_ACCENT   equ 0x02    ; Azul vibrante
COLOR_TASKBAR       equ 0x03    ; Cinza escuro translúcido
COLOR_WHITE         equ 0x04    ; Branco puro
COLOR_MENU_BG       equ 0x05    ; Fundo do menu start
COLOR_CARD_BG       equ 0x06    ; Cartões/janelas
COLOR_HOVER         equ 0x07    ; Estado hover
COLOR_TEXT_DARK     equ 0x08    ; Texto escuro
COLOR_GREEN         equ 0x09    ; Verde
COLOR_RED           equ 0x0A    ; Vermelho
COLOR_YELLOW        equ 0x0B    ; Amarelo
COLOR_PURPLE        equ 0x0C    ; Roxo
COLOR_CYAN          equ 0x0D    ; Ciano
COLOR_ORANGE        equ 0x0E    ; Laranja
COLOR_GRAY          equ 0x0F    ; Cinza médio

; ============================================================================
; PONTO DE ENTRADA DO SISTEMA
; ============================================================================

_start:
    cli                             ; Desabilita interrupções

    ; Configura segmentos
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000                ; Stack em 0x90000

    ; Inicializa subsistemas
    call init_video_mode            ; Configura modo VGA
    call init_palette               ; Paleta de cores moderna
    call init_interrupts            ; IDT e PIC
    call init_keyboard              ; Teclado PS/2
    call init_mouse                 ; Mouse PS/2
    call init_rtc                   ; Relógio de tempo real
    call init_filesystem            ; Sistema de arquivos
    call init_system_vars           ; Variáveis do sistema

    sti                             ; Habilita interrupções

    ; Desenha interface inicial
    call draw_boot_animation
    call load_desktop

    ; Loop principal do sistema
main_loop:
    hlt                             ; Espera por interrupção
    call process_events             ; Processa eventos
    call update_clock               ; Atualiza relógio
    call update_animations          ; Atualiza animações
    call render_screen              ; Renderiza tela
    jmp main_loop

; ============================================================================
; INICIALIZAÇÃO DE VÍDEO E PALETA
; ============================================================================

init_video_mode:
    pushad

    ; Limpa memória de vídeo
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    xor al, al
    cld
    rep stosb

    popad
    ret

init_palette:
    pushad

    mov dx, 0x03C8                  ; Registrador de índice da paleta
    xor al, al
    out dx, al

    mov dx, 0x03C9                  ; Registrador de dados RGB

    ; Cor 0: Preto (0,0,0)
    xor al, al
    out dx, al
    out dx, al
    out dx, al

    ; Cor 1: Azul escuro profundo (10,15,35)
    mov al, 10
    out dx, al
    mov al, 15
    out dx, al
    mov al, 35
    out dx, al

    ; Cor 2: Azul vibrante (0,120,212)
    xor al, al
    out dx, al
    mov al, 30
    out dx, al
    mov al, 53
    out dx, al

    ; Cor 3: Cinza escuro taskbar (25,25,30)
    mov al, 6
    out dx, al
    mov al, 6
    out dx, al
    mov al, 8
    out dx, al

    ; Cor 4: Branco (255,255,255)
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al
    mov al, 63
    out dx, al

    ; Cor 5: Fundo menu (32,32,38)
    mov al, 8
    out dx, al
    mov al, 8
    out dx, al
    mov al, 10
    out dx, al

    ; Cor 6: Cartões (45,45,52)
    mov al, 11
    out dx, al
    mov al, 11
    out dx, al
    mov al, 13
    out dx, al

    ; Cor 7: Hover (60,60,70)
    mov al, 15
    out dx, al
    mov al, 15
    out dx, al
    mov al, 18
    out dx, al

    ; Cor 8: Texto escuro (30,30,35)
    mov al, 8
    out dx, al
    mov al, 8
    out dx, al
    mov al, 9
    out dx, al

    ; Cor 9: Verde (16,185,129)
    mov al, 4
    out dx, al
    mov al, 46
    out dx, al
    mov al, 32
    out dx, al

    ; Cor 10: Vermelho (239,68,68)
    mov al, 60
    out dx, al
    mov al, 17
    out dx, al
    mov al, 17
    out dx, al

    ; Cor 11: Amarelo (250,204,21)
    mov al, 63
    out dx, al
    mov al, 51
    out dx, al
    mov al, 5
    out dx, al

    ; Cor 12: Roxo (168,85,247)
    mov al, 42
    out dx, al
    mov al, 21
    out dx, al
    mov al, 62
    out dx, al

    ; Cor 13: Ciano (6,182,212)
    mov al, 2
    out dx, al
    mov al, 45
    out dx, al
    mov al, 53
    out dx, al

    ; Cor 14: Laranja (251,146,60)
    mov al, 63
    out dx, al
    mov al, 36
    out dx, al
    mov al, 15
    out dx, al

    ; Cor 15: Cinza médio (128,128,128)
    mov al, 32
    out dx, al
    mov al, 32
    out dx, al
    mov al, 32
    out dx, al

    ; Preenche resto da paleta com tons de cinza
    mov ecx, 240
.fill_gray:
    mov al, 20
    out dx, al
    out dx, al
    out dx, al
    loop .fill_gray

    popad
    ret

; ============================================================================
; SISTEMA DE INTERRUPÇÕES (IDT E PIC)
; ============================================================================

init_interrupts:
    pushad

    ; Remapeia PIC
    call remap_pic

    ; Instala ISRs
    mov eax, keyboard_isr
    mov ebx, 0x21                   ; IRQ1 -> INT 0x21
    call install_isr

    mov eax, mouse_isr
    mov ebx, 0x2C                   ; IRQ12 -> INT 0x2C
    call install_isr

    mov eax, timer_isr
    mov ebx, 0x20                   ; IRQ0 -> INT 0x20
    call install_isr

    ; Carrega IDT
    lidt [idt_descriptor]

    ; Habilita IRQs do teclado e timer
    in al, PIC1_DATA
    and al, 0xFC                    ; Habilita IRQ0 e IRQ1
    out PIC1_DATA, al

    popad
    ret

remap_pic:
    pushad

    ; Salva máscaras
    in al, PIC1_DATA
    mov bl, al
    in al, PIC2_DATA
    mov bh, al

    ; Inicia sequência de inicialização
    mov al, 0x11
    out PIC1_COMMAND, al
    call io_wait
    out PIC2_COMMAND, al
    call io_wait

    ; Define offsets dos vetores
    mov al, 0x20
    out PIC1_DATA, al
    call io_wait
    mov al, 0x28
    out PIC2_DATA, al
    call io_wait

    ; Configura cascata
    mov al, 0x04
    out PIC1_DATA, al
    call io_wait
    mov al, 0x02
    out PIC2_DATA, al
    call io_wait

    ; Modo 8086
    mov al, 0x01
    out PIC1_DATA, al
    call io_wait
    out PIC2_DATA, al
    call io_wait

    ; Restaura máscaras
    mov al, bl
    out PIC1_DATA, al
    mov al, bh
    out PIC2_DATA, al

    popad
    ret

io_wait:
    push eax
    push ecx
    mov ecx, 100
.loop:
    in al, 0x80
    loop .loop
    pop ecx
    pop eax
    ret

install_isr:
    pushad

    mov edi, idt_table
    shl ebx, 3
    add edi, ebx

    mov word [edi], ax              ; Offset baixo
    mov word [edi+2], 0x08          ; Seletor de código
    mov byte [edi+4], 0             ; Reservado
    mov byte [edi+5], 0x8E          ; Atributos (presente, anel 0, gate de interrupção)
    shr eax, 16
    mov word [edi+6], ax            ; Offset alto

    popad
    ret

; ============================================================================
; TRATADORES DE INTERRUPÇÃO (ISRs)
; ============================================================================

timer_isr:
    pushad

    inc dword [system_ticks]

    ; Atualiza contador de FPS
    inc dword [frame_counter]
    mov eax, [system_ticks]
    and eax, 0x3F                   ; A cada ~1 segundo
    cmp eax, 0
    jne .no_fps_update

    mov eax, [frame_counter]
    mov [fps_value], eax
    mov dword [frame_counter], 0

.no_fps_update:
    mov al, 0x20
    out PIC1_COMMAND, al

    popad
    iret

keyboard_isr:
    pushad

    in al, PS2_DATA
    mov [last_scancode], al

    ; Processa tecla
    call process_keyboard

    mov al, 0x20
    out PIC1_COMMAND, al

    popad
    iret

mouse_isr:
    pushad

    in al, PS2_DATA

    movzx ebx, byte [mouse_cycle]
    mov [mouse_packet + ebx], al

    inc byte [mouse_cycle]
    cmp byte [mouse_cycle], 3
    jl .done

    mov byte [mouse_cycle], 0
    call process_mouse_packet

.done:
    mov al, 0x20
    out PIC2_COMMAND, al
    out PIC1_COMMAND, al

    popad
    iret

; ============================================================================
; INICIALIZAÇÃO DE DISPOSITIVOS
; ============================================================================

init_keyboard:
    pushad
    ; Teclado já inicializado pelo BIOS
    popad
    ret

init_mouse:
    pushad

    ; Habilita porta auxiliar
    call mouse_wait_write
    mov al, 0xA8
    out PS2_COMMAND, al

    ; Obtém byte de status
    call mouse_wait_write
    mov al, 0x20
    out PS2_COMMAND, al
    call mouse_wait_read
    in al, PS2_DATA

    ; Habilita interrupções do mouse
    or al, 0x02
    push eax

    call mouse_wait_write
    mov al, 0x60
    out PS2_COMMAND, al
    call mouse_wait_write
    pop eax
    out PS2_DATA, al

    ; Usa padrões padrão
    call mouse_wait_write
    mov al, 0xD4
    out PS2_COMMAND, al
    call mouse_wait_write
    mov al, 0xF6
    out PS2_DATA, al
    call mouse_wait_read
    in al, PS2_DATA

    ; Habilita streaming de dados
    call mouse_wait_write
    mov al, 0xD4
    out PS2_COMMAND, al
    call mouse_wait_write
    mov al, 0xF4
    out PS2_DATA, al
    call mouse_wait_read
    in al, PS2_DATA

    ; Habilita IRQ12
    in al, PIC2_DATA
    and al, 0xEF
    out PIC2_DATA, al

    popad
    ret

mouse_wait_read:
    push ecx
    mov ecx, 100000
.loop:
    in al, PS2_STATUS
    test al, 1
    jnz .done
    loop .loop
.done:
    pop ecx
    ret

mouse_wait_write:
    push ecx
    mov ecx, 100000
.loop:
    in al, PS2_STATUS
    test al, 2
    jz .done
    loop .loop
.done:
    pop ecx
    ret

init_rtc:
    pushad

    ; Lê hora atual do RTC
    mov al, 0x04                    ; Hora
    out 0x70, al
    in al, 0x71
    mov [rtc_hour], al

    mov al, 0x02                    ; Minuto
    out 0x70, al
    in al, 0x71
    mov [rtc_minute], al

    mov al, 0x00                    ; Segundo
    out 0x70, al
    in al, 0x71
    mov [rtc_second], al

    popad
    ret

; ============================================================================
; SISTEMA DE ARQUIVOS
; ============================================================================

init_filesystem:
    pushad

    mov dword [fs_file_count], 0

    ; Cria arquivos de demonstração
    call create_sample_files

    popad
    ret

create_sample_files:
    pushad

    ; Arquivo 1: README.TXT
    call fs_create_file
    mov esi, file1_name
    mov edi, eax
    mov ecx, FS_FILENAME_LEN
    rep movsb
    mov esi, file1_content
    mov ecx, FS_CONTENT_LEN
    rep movsb

    ; Arquivo 2: WELCOME.TXT
    call fs_create_file
    mov esi, file2_name
    mov edi, eax
    mov ecx, FS_FILENAME_LEN
    rep movsb
    mov esi, file2_content
    mov ecx, FS_CONTENT_LEN
    rep movsb

    ; Arquivo 3: SYSTEM.INI
    call fs_create_file
    mov esi, file3_name
    mov edi, eax
    mov ecx, FS_FILENAME_LEN
    rep movsb
    mov esi, file3_content
    mov ecx, FS_CONTENT_LEN
    rep movsb

    popad
    ret

fs_create_file:
    pushad

    mov eax, [fs_file_count]
    cmp eax, FS_MAX_FILES
    jge .error

    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE

    mov [esp+28], eax
    inc dword [fs_file_count]
    popad
    ret

.error:
    popad
    xor eax, eax
    ret

; ============================================================================
; VARIÁVEIS DO SISTEMA
; ============================================================================

init_system_vars:
    pushad

    mov dword [current_screen], SCREEN_DESKTOP
    mov dword [mouse_x], 160
    mov dword [mouse_y], 100
    mov byte [mouse_buttons], 0
    mov byte [mouse_cycle], 0
    mov byte [start_menu_open], 0
    mov byte [ctrl_pressed], 0
    mov byte [shift_pressed], 0
    mov byte [alt_pressed], 0
    mov dword [system_ticks], 0
    mov dword [frame_counter], 0
    mov dword [fps_value], 0
    mov dword [animation_phase], 0
    mov byte [wallpaper_enabled], 0
    mov dword [active_window], 0
    mov dword [window_count], 0

    popad
    ret

; ============================================================================
; PROCESSAMENTO DE EVENTOS
; ============================================================================

process_events:
    pushad

    ; Processa eventos do mouse
    call handle_mouse_events

    ; Processa comandos pendentes
    call process_pending_commands

    popad
    ret

process_keyboard:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    test al, 0x80                   ; Tecla liberada?
    jnz .key_release

    ; Teclas de controle
    cmp al, 0x1D                    ; Ctrl
    je .ctrl_press
    cmp al, 0x2A                    ; Shift esquerdo
    je .shift_press
    cmp al, 0x36                    ; Shift direito
    je .shift_press
    cmp al, 0x38                    ; Alt
    je .alt_press

    ; Tecla Windows (abre menu start)
    cmp al, 0x5B
    je .windows_key

    ; Processa baseado na tela atual
    mov ebx, [current_screen]
    cmp ebx, SCREEN_DESKTOP
    je .desktop_key
    cmp ebx, SCREEN_NOTEPAD
    je .notepad_key
    cmp ebx, SCREEN_TERMINAL
    je .terminal_key
    cmp ebx, SCREEN_CALCULATOR
    je .calculator_key
    cmp ebx, SCREEN_PAINT
    je .paint_key

    jmp .done

.key_release:
    and al, 0x7F
    cmp al, 0x1D
    je .ctrl_release
    cmp al, 0x2A
    je .shift_release
    cmp al, 0x36
    je .shift_release
    cmp al, 0x38
    je .alt_release
    jmp .done

.ctrl_press:
    mov byte [ctrl_pressed], 1
    jmp .done

.ctrl_release:
    mov byte [ctrl_pressed], 0
    jmp .done

.shift_press:
    mov byte [shift_pressed], 1
    jmp .done

.shift_release:
    mov byte [shift_pressed], 0
    jmp .done

.alt_press:
    mov byte [alt_pressed], 1
    jmp .done

.alt_release:
    mov byte [alt_pressed], 0
    jmp .done

.windows_key:
    mov al, [start_menu_open]
    xor al, 1
    mov [start_menu_open], al
    call render_screen
    jmp .done

.desktop_key:
    ; ESC fecha menu start
    cmp al, 0x01
    jne .done
    mov byte [start_menu_open], 0
    call render_screen
    jmp .done

.notepad_key:
    call handle_notepad_key
    jmp .done

.terminal_key:
    call handle_terminal_key
    jmp .done

.calculator_key:
    call handle_calculator_key
    jmp .done

.paint_key:
    call handle_paint_key
    jmp .done

.done:
    popad
    ret

process_mouse_packet:
    pushad

    ; Atualiza botões
    mov al, [mouse_packet]
    and al, 0x07
    mov [mouse_buttons], al

    ; Atualiza X
    movsx eax, byte [mouse_packet + 1]
    add [mouse_x], eax

    cmp dword [mouse_x], 0
    jge .x_ok1
    mov dword [mouse_x], 0
.x_ok1:
    cmp dword [mouse_x], SCREEN_WIDTH-1
    jle .x_ok2
    mov dword [mouse_x], SCREEN_WIDTH-1
.x_ok2:

    ; Atualiza Y
    movsx eax, byte [mouse_packet + 2]
    neg eax
    add [mouse_y], eax

    cmp dword [mouse_y], 0
    jge .y_ok1
    mov dword [mouse_y], 0
.y_ok1:
    cmp dword [mouse_y], SCREEN_HEIGHT-1
    jle .y_ok2
    mov dword [mouse_y], SCREEN_HEIGHT-1
.y_ok2:

    ; Processa clique
    test byte [mouse_buttons], 1
    jz .no_click

    cmp byte [mouse_was_pressed], 0
    jne .no_click

    mov byte [mouse_was_pressed], 1
    call handle_mouse_click
    jmp .done

.no_click:
    mov byte [mouse_was_pressed], 0

.done:
    popad
    ret

handle_mouse_events:
    pushad

    ; Atualiza hover
    call update_hover_state

    popad
    ret

handle_mouse_click:
    pushad

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    ; Verifica clique na taskbar (y >= 180)
    cmp ebx, 180
    jl .not_taskbar

    ; Botão Start (x: 130-170)
    cmp eax, 130
    jl .not_start
    cmp eax, 170
    jg .not_start

    mov al, [start_menu_open]
    xor al, 1
    mov [start_menu_open], al
    call render_screen
    jmp .done

.not_start:
    ; Outros ícones da taskbar
    ; TODO: Implementar
    jmp .done

.not_taskbar:
    ; Verifica clique no menu start
    cmp byte [start_menu_open], 1
    jne .not_in_menu

    ; Área do menu start (x: 80-240, y: 20-170)
    cmp eax, 80
    jl .close_menu
    cmp eax, 240
    jg .close_menu
    cmp ebx, 20
    jl .close_menu
    cmp ebx, 170
    jg .close_menu

    ; Calcula qual app foi clicado
    call handle_start_menu_click
    jmp .done

.close_menu:
    mov byte [start_menu_open], 0
    call render_screen
    jmp .done

.not_in_menu:
    ; Cliques em janelas abertas
    call handle_window_click

.done:
    popad
    ret

handle_start_menu_click:
    pushad

    mov eax, [mouse_x]
    mov ebx, [mouse_y]

    ; Grid de aplicativos: 3 colunas x 3 linhas
    ; Posição base: x=90, y=60
    ; Tamanho de cada célula: 45x30

    sub ebx, 60
    cmp ebx, 0
    jl .done
    cmp ebx, 90
    jg .done

    sub eax, 90
    cmp eax, 0
    jl .done
    cmp eax, 135
    jg .done

    ; Calcula linha e coluna
    xor edx, edx
    mov ecx, 30
    mov eax, ebx
    div ecx
    mov ebx, eax                    ; linha em ebx

    mov eax, [mouse_x]
    sub eax, 90
    xor edx, edx
    mov ecx, 45
    div ecx                         ; coluna em eax

    ; Índice do app = linha * 3 + coluna
    imul ebx, 3
    add eax, ebx

    ; Abre aplicativo baseado no índice
    cmp eax, 0
    je .open_notepad
    cmp eax, 1
    je .open_terminal
    cmp eax, 2
    je .open_calculator
    cmp eax, 3
    je .open_paint
    cmp eax, 4
    je .open_explorer
    cmp eax, 5
    je .open_settings
    cmp eax, 6
    je .open_calendar
    cmp eax, 7
    je .open_clock

    jmp .done

.open_notepad:
    mov dword [current_screen], SCREEN_NOTEPAD
    mov byte [start_menu_open], 0
    call load_notepad
    jmp .done

.open_terminal:
    mov dword [current_screen], SCREEN_TERMINAL
    mov byte [start_menu_open], 0
    call load_terminal
    jmp .done

.open_calculator:
    mov dword [current_screen], SCREEN_CALCULATOR
    mov byte [start_menu_open], 0
    call load_calculator
    jmp .done

.open_paint:
    mov dword [current_screen], SCREEN_PAINT
    mov byte [start_menu_open], 0
    call load_paint
    jmp .done

.open_explorer:
    mov dword [current_screen], SCREEN_EXPLORER
    mov byte [start_menu_open], 0
    call load_explorer
    jmp .done

.open_settings:
    mov dword [current_screen], SCREEN_SETTINGS
    mov byte [start_menu_open], 0
    call load_settings
    jmp .done

.open_calendar:
    mov dword [current_screen], SCREEN_CALENDAR
    mov byte [start_menu_open], 0
    call load_calendar
    jmp .done

.open_clock:
    mov dword [current_screen], SCREEN_CLOCK
    mov byte [start_menu_open], 0
    call load_clock
    jmp .done

.done:
    popad
    ret

; ============================================================================
; RENDERIZAÇÃO E INTERFACE GRÁFICA
; ============================================================================

render_screen:
    pushad

    mov eax, [current_screen]

    cmp eax, SCREEN_DESKTOP
    je .render_desktop
    cmp eax, SCREEN_NOTEPAD
    je .render_notepad
    cmp eax, SCREEN_TERMINAL
    je .render_terminal
    cmp eax, SCREEN_CALCULATOR
    je .render_calculator
    cmp eax, SCREEN_PAINT
    je .render_paint
    cmp eax, SCREEN_EXPLORER
    je .render_explorer
    cmp eax, SCREEN_SETTINGS
    je .render_settings
    cmp eax, SCREEN_CALENDAR
    je .render_calendar
    cmp eax, SCREEN_CLOCK
    je .render_clock

    jmp .done

.render_desktop:
    call draw_desktop
    jmp .finish

.render_notepad:
    call draw_notepad_window
    jmp .finish

.render_terminal:
    call draw_terminal_window
    jmp .finish

.render_calculator:
    call draw_calculator_window
    jmp .finish

.render_paint:
    call draw_paint_window
    jmp .finish

.render_explorer:
    call draw_explorer_window
    jmp .finish

.render_settings:
    call draw_settings_window
    jmp .finish

.render_calendar:
    call draw_calendar_window
    jmp .finish

.render_clock:
    call draw_clock_window
    jmp .finish

.finish:
    ; Sempre desenha a taskbar por cima
    call draw_taskbar

    ; Desenha menu start se estiver aberto
    cmp byte [start_menu_open], 1
    jne .no_menu
    call draw_start_menu

.no_menu:
    ; Desenha cursor do mouse
    call draw_mouse_cursor

.done:
    popad
    ret

; ============================================================================
; DESKTOP - Tela Principal
; ============================================================================

load_desktop:
    pushad

    mov dword [current_screen], SCREEN_DESKTOP
    call draw_desktop

    popad
    ret

draw_desktop:
    pushad

    ; Desenha wallpaper ou fundo gradiente
    cmp byte [wallpaper_enabled], 1
    je .draw_wallpaper

    ; Fundo gradiente azul escuro
    call draw_gradient_background
    jmp .draw_icons

.draw_wallpaper:
    mov esi, WALLPAPER_BUFFER
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

.draw_icons:
    ; Desenha ícones na área de trabalho
    ; TODO: Implementar ícones do desktop

    popad
    ret

draw_gradient_background:
    pushad

    mov ecx, 0                      ; linha Y

.line_loop:
    cmp ecx, 180                    ; Até a taskbar
    jge .done

    ; Calcula cor do gradiente baseado em Y
    mov eax, ecx
    shr eax, 3                      ; Divide por 8
    cmp eax, 15
    jle .color_ok
    mov eax, 15
.color_ok:
    add al, COLOR_DARK_BG

    ; Desenha linha horizontal
    mov ebx, 0
.pixel_loop:
    cmp ebx, SCREEN_WIDTH
    jge .next_line

    push eax
    push ebx
    push ecx
    call draw_pixel
    pop ecx
    pop ebx
    pop eax

    inc ebx
    jmp .pixel_loop

.next_line:
    inc ecx
    jmp .line_loop

.done:
    popad
    ret

; ============================================================================
; TASKBAR - Barra de Tarefas
; ============================================================================

draw_taskbar:
    pushad

    ; Fundo da taskbar (semi-transparente simulado)
    mov ebx, 0
    mov ecx, 180
    mov edx, SCREEN_WIDTH
    mov esi, 20
    mov al, COLOR_TASKBAR
    call draw_filled_rect

    ; Linha superior da taskbar
    mov ebx, 0
    mov ecx, 180
    mov edx, SCREEN_WIDTH
    mov esi, 1
    mov al, COLOR_GRAY
    call draw_filled_rect

    ; Botão Start (Windows) - centralizado
    mov ebx, 130
    mov ecx, 184
    mov edx, 40
    mov esi, 12

    ; Verifica hover
    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover_start
    mov al, COLOR_HOVER
    jmp .draw_start_btn
.not_hover_start:
    mov al, COLOR_CARD_BG

.draw_start_btn:
    call draw_filled_rect

    ; Ícone do Windows (4 quadrados)
    ; Quadrado superior esquerdo
    mov ebx, 140
    mov ecx, 188
    mov edx, 3
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Quadrado superior direito
    mov ebx, 145
    mov ecx, 188
    mov edx, 3
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Quadrado inferior esquerdo
    mov ebx, 140
    mov ecx, 192
    mov edx, 3
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Quadrado inferior direito
    mov ebx, 145
    mov ecx, 192
    mov edx, 3
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Relógio na direita
    call draw_taskbar_clock

    ; Ícones de sistema
    call draw_system_tray

    popad
    ret

draw_taskbar_clock:
    pushad

    ; Fundo do relógio
    mov ebx, 270
    mov ecx, 184
    mov edx, 45
    mov esi, 12

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover_clock
    mov al, COLOR_HOVER
    jmp .draw_clock_bg
.not_hover_clock:
    mov al, COLOR_CARD_BG

.draw_clock_bg:
    call draw_filled_rect

    ; Desenha hora
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 275
    mov dword [text_y], 186

    ; Converte hora para string
    movzx eax, byte [rtc_hour]
    call bcd_to_ascii
    mov [time_str], al
    mov [time_str+1], ah

    mov byte [time_str+2], ':'

    movzx eax, byte [rtc_minute]
    call bcd_to_ascii
    mov [time_str+3], al
    mov [time_str+4], ah

    mov byte [time_str+5], 0

    mov esi, time_str
    call draw_text

    popad
    ret

draw_system_tray:
    pushad

    ; Ícone de volume
    mov ebx, 245
    mov ecx, 188
    mov edx, 8
    mov esi, 6
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Ícone de rede
    mov ebx, 257
    mov ecx, 188

    ; Desenha 3 barrinhas
    mov edx, 2
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    mov ebx, 260
    mov esi, 5
    call draw_filled_rect

    mov ebx, 263
    mov esi, 7
    call draw_filled_rect

    popad
    ret

; ============================================================================
; MENU START
; ============================================================================

draw_start_menu:
    pushad

    ; Fundo do menu (com bordas arredondadas simuladas)
    mov ebx, 80
    mov ecx, 20
    mov edx, 160
    mov esi, 150
    mov al, COLOR_MENU_BG
    call draw_filled_rect

    ; Borda superior
    mov ebx, 80
    mov ecx, 20
    mov edx, 160
    mov esi, 1
    mov al, COLOR_GRAY
    call draw_filled_rect

    ; Seção "Pinned Apps"
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 90
    mov dword [text_y], 30
    mov esi, str_pinned_apps
    call draw_text

    ; Grid de aplicativos (3x3)
    ; Linha 1
    call draw_app_icon_notepad
    call draw_app_icon_terminal
    call draw_app_icon_calculator

    ; Linha 2
    call draw_app_icon_paint
    call draw_app_icon_explorer
    call draw_app_icon_settings

    ; Linha 3
    call draw_app_icon_calendar
    call draw_app_icon_clock

    ; Seção "Recommended"
    mov dword [text_y], 140
    mov esi, str_recommended
    call draw_text

    ; Item recomendado
    mov ebx, 85
    mov ecx, 150
    mov edx, 150
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov dword [text_x], 95
    mov dword [text_y], 154
    mov esi, str_recent_file
    call draw_text

    popad
    ret

draw_app_icon_notepad:
    pushad

    ; Posição: (90, 60)
    mov ebx, 90
    mov ecx, 60
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (retângulo representando documento)
    mov ebx, 102
    mov ecx, 65
    mov edx, 16
    mov esi, 12
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 95
    mov dword [text_y], 80
    mov esi, str_notepad
    call draw_text

    popad
    ret

draw_app_icon_terminal:
    pushad

    ; Posição: (135, 60)
    mov ebx, 135
    mov ecx, 60
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (retângulo preto representando terminal)
    mov ebx, 147
    mov ecx, 65
    mov edx, 16
    mov esi, 12
    mov al, COLOR_BLACK
    call draw_filled_rect

    ; Linha verde simulando prompt
    mov ebx, 149
    mov ecx, 67
    mov edx, 6
    mov esi, 1
    mov al, COLOR_GREEN
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 137
    mov dword [text_y], 80
    mov esi, str_terminal
    call draw_text

    popad
    ret

draw_app_icon_calculator:
    pushad

    ; Posição: (180, 60)
    mov ebx, 180
    mov ecx, 60
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (retângulo com grid)
    mov ebx, 192
    mov ecx, 65
    mov edx, 16
    mov esi, 12
    mov al, COLOR_CYAN
    call draw_filled_rect

    ; Grid simulado
    mov ebx, 194
    mov ecx, 67
    mov edx, 5
    mov esi, 3
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 185
    mov dword [text_y], 80
    mov esi, str_calc
    call draw_text

    popad
    ret

draw_app_icon_paint:
    pushad

    ; Posição: (90, 90)
    mov ebx, 90
    mov ecx, 90
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (pincel colorido)
    mov ebx, 102
    mov ecx, 95
    mov edx, 16
    mov esi, 12
    mov al, COLOR_PURPLE
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 97
    mov dword [text_y], 110
    mov esi, str_paint
    call draw_text

    popad
    ret

draw_app_icon_explorer:
    pushad

    ; Posição: (135, 90)
    mov ebx, 135
    mov ecx, 90
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (pasta)
    mov ebx, 147
    mov ecx, 95
    mov edx, 16
    mov esi, 12
    mov al, COLOR_YELLOW
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 138
    mov dword [text_y], 110
    mov esi, str_files
    call draw_text

    popad
    ret

draw_app_icon_settings:
    pushad

    ; Posição: (180, 90)
    mov ebx, 180
    mov ecx, 90
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (engrenagem)
    mov ebx, 192
    mov ecx, 95
    mov edx, 16
    mov esi, 12
    mov al, COLOR_GRAY
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 183
    mov dword [text_y], 110
    mov esi, str_settings
    call draw_text

    popad
    ret

draw_app_icon_calendar:
    pushad

    ; Posição: (90, 120)
    mov ebx, 90
    mov ecx, 120
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (calendário)
    mov ebx, 102
    mov ecx, 125
    mov edx, 16
    mov esi, 12
    mov al, COLOR_RED
    call draw_filled_rect

    ; Número do dia
    mov ebx, 107
    mov ecx, 130
    mov edx, 6
    mov esi, 5
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 92
    mov dword [text_y], 140
    mov esi, str_calendar
    call draw_text

    popad
    ret

draw_app_icon_clock:
    pushad

    ; Posição: (135, 120)
    mov ebx, 135
    mov ecx, 120
    mov edx, 40
    mov esi, 25

    call is_mouse_over_rect
    cmp eax, 1
    jne .not_hover
    mov al, COLOR_HOVER
    jmp .draw_bg
.not_hover:
    mov al, COLOR_CARD_BG

.draw_bg:
    call draw_filled_rect

    ; Ícone (relógio circular)
    mov ebx, 147
    mov ecx, 125
    mov edx, 16
    mov esi, 12
    mov al, COLOR_ORANGE
    call draw_filled_rect

    ; Ponteiros
    mov ebx, 155
    mov ecx, 128
    mov edx, 1
    mov esi, 6
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Texto
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 140
    mov dword [text_y], 140
    mov esi, str_clock
    call draw_text

    popad
    ret

; ============================================================================
; NOTEPAD - Editor de Texto
; ============================================================================

load_notepad:
    pushad

    ; Limpa buffer de texto
    mov edi, notepad_buffer
    mov ecx, TEXT_BUFFER_SIZE
    xor al, al
    rep stosb

    mov dword [notepad_cursor_pos], 0
    mov dword [notepad_scroll], 0

    call draw_notepad_window

    popad
    ret

draw_notepad_window:
    pushad

    ; Fundo da janela
    mov al, COLOR_WHITE
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    ; Título
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_notepad_title
    call draw_text

    ; Botões de janela (fechar, minimizar, maximizar)
    call draw_window_buttons

    ; Área de texto
    mov byte [text_color], COLOR_TEXT_DARK
    mov dword [text_x], 5
    mov dword [text_y], 20

    ; Renderiza texto do buffer
    mov esi, notepad_buffer
    mov ecx, [notepad_cursor_pos]

.text_loop:
    cmp ecx, 0
    je .done

    lodsb

    cmp al, 10                      ; Newline
    je .newline

    push ecx
    push esi
    call draw_char
    pop esi
    pop ecx

    add dword [text_x], 8

    cmp dword [text_x], 315
    jl .no_wrap

.newline:
    mov dword [text_x], 5
    add dword [text_y], 10

.no_wrap:
    dec ecx
    jmp .text_loop

.done:
    ; Cursor piscante
    mov eax, [system_ticks]
    and eax, 0x10
    cmp eax, 0
    je .no_cursor

    mov ebx, [text_x]
    mov ecx, [text_y]
    mov edx, 2
    mov esi, 8
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect

.no_cursor:
    popad
    ret

handle_notepad_key:
    pushad

    mov al, [last_scancode]

    ; ESC fecha
    cmp al, 0x01
    je .close

    ; Backspace
    cmp al, 0x0E
    je .backspace

    ; Enter
    cmp al, 0x1C
    je .enter

    ; Space
    cmp al, 0x39
    je .space

    ; Converte scancode para char
    call scancode_to_ascii
    test al, al
    jz .done

    ; Adiciona ao buffer
    cmp dword [notepad_cursor_pos], TEXT_BUFFER_SIZE-1
    jge .done

    mov ebx, [notepad_cursor_pos]
    mov [notepad_buffer + ebx], al
    inc dword [notepad_cursor_pos]

    call draw_notepad_window
    jmp .done

.backspace:
    cmp dword [notepad_cursor_pos], 0
    je .done
    dec dword [notepad_cursor_pos]
    call draw_notepad_window
    jmp .done

.enter:
    mov al, 10
    cmp dword [notepad_cursor_pos], TEXT_BUFFER_SIZE-1
    jge .done
    mov ebx, [notepad_cursor_pos]
    mov [notepad_buffer + ebx], al
    inc dword [notepad_cursor_pos]
    call draw_notepad_window
    jmp .done

.space:
    mov al, ' '
    cmp dword [notepad_cursor_pos], TEXT_BUFFER_SIZE-1
    jge .done
    mov ebx, [notepad_cursor_pos]
    mov [notepad_buffer + ebx], al
    inc dword [notepad_cursor_pos]
    call draw_notepad_window
    jmp .done

.close:
    mov dword [current_screen], SCREEN_DESKTOP
    call draw_desktop
    jmp .done

.done:
    popad
    ret

; ============================================================================
; TERMINAL - Linha de Comando
; ============================================================================

load_terminal:
    pushad

    ; Limpa buffer
    mov edi, terminal_buffer
    mov ecx, CMD_BUFFER_SIZE
    xor al, al
    rep stosb

    mov dword [terminal_cursor], 0
    mov dword [terminal_line], 0

    call draw_terminal_window

    popad
    ret

draw_terminal_window:
    pushad

    ; Fundo preto
    mov al, COLOR_BLACK
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    ; Título
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_terminal_title
    call draw_text

    call draw_window_buttons

    ; Banner do terminal
    mov byte [text_color], COLOR_GREEN
    mov dword [text_x], 5
    mov dword [text_y], 20
    mov esi, str_terminal_banner
    call draw_text

    ; Prompt
    mov dword [text_y], 35
    mov esi, str_terminal_prompt
    call draw_text

    ; Comando atual
    mov esi, terminal_buffer
    mov ecx, [terminal_cursor]

.cmd_loop:
    cmp ecx, 0
    je .cursor

    lodsb
    push ecx
    push esi
    call draw_char
    pop esi
    pop ecx

    add dword [text_x], 8
    dec ecx
    jmp .cmd_loop

.cursor:
    ; Cursor piscante
    mov eax, [system_ticks]
    and eax, 0x10
    cmp eax, 0
    je .done

    mov ebx, [text_x]
    mov ecx, [text_y]
    mov edx, 8
    mov esi, 1
    mov al, COLOR_GREEN
    call draw_filled_rect

.done:
    popad
    ret

handle_terminal_key:
    pushad

    mov al, [last_scancode]

    ; ESC fecha
    cmp al, 0x01
    je .close

    ; Backspace
    cmp al, 0x0E
    je .backspace

    ; Enter
    cmp al, 0x1C
    je .enter

    ; Space
    cmp al, 0x39
    je .space

    ; Converte scancode
    call scancode_to_ascii
    test al, al
    jz .done

    ; Adiciona ao buffer
    cmp dword [terminal_cursor], CMD_BUFFER_SIZE-1
    jge .done

    mov ebx, [terminal_cursor]
    mov [terminal_buffer + ebx], al
    inc dword [terminal_cursor]

    call draw_terminal_window
    jmp .done

.backspace:
    cmp dword [terminal_cursor], 0
    je .done
    dec dword [terminal_cursor]
    call draw_terminal_window
    jmp .done

.enter:
    call execute_terminal_command

    ; Limpa buffer
    mov edi, terminal_buffer
    mov ecx, CMD_BUFFER_SIZE
    xor al, al
    rep stosb
    mov dword [terminal_cursor], 0

    call draw_terminal_window
    jmp .done

.space:
    mov al, ' '
    cmp dword [terminal_cursor], CMD_BUFFER_SIZE-1
    jge .done
    mov ebx, [terminal_cursor]
    mov [terminal_buffer + ebx], al
    inc dword [terminal_cursor]
    call draw_terminal_window
    jmp .done

.close:
    mov dword [current_screen], SCREEN_DESKTOP
    call draw_desktop
    jmp .done

.done:
    popad
    ret

execute_terminal_command:
    pushad

    ; Compara comandos
    mov esi, terminal_buffer
    mov edi, cmd_help
    call compare_strings
    je .cmd_help

    mov esi, terminal_buffer
    mov edi, cmd_clear
    call compare_strings
    je .cmd_clear

    mov esi, terminal_buffer
    mov edi, cmd_ls
    call compare_strings
    je .cmd_ls

    mov esi, terminal_buffer
    mov edi, cmd_ver
    call compare_strings
    je .cmd_ver

    ; Comando não encontrado
    jmp .done

.cmd_help:
    ; TODO: Mostrar ajuda
    jmp .done

.cmd_clear:
    call load_terminal
    jmp .done

.cmd_ls:
    ; TODO: Listar arquivos
    jmp .done

.cmd_ver:
    ; TODO: Mostrar versão
    jmp .done

.done:
    popad
    ret

compare_strings:
    pushad

    mov ecx, 16                     ; Máximo de chars para comparar

.loop:
    lodsb
    mov bl, [edi]
    inc edi

    ; Converte para maiúscula
    cmp al, 'a'
    jl .not_lower_a
    cmp al, 'z'
    jg .not_lower_a
    sub al, 32
.not_lower_a:

    cmp bl, 'a'
    jl .not_lower_b
    cmp bl, 'z'
    jg .not_lower_b
    sub bl, 32
.not_lower_b:

    cmp al, bl
    jne .not_equal

    test al, al
    jz .equal

    loop .loop

.equal:
    popad
    xor eax, eax
    ret

.not_equal:
    popad
    mov eax, 1
    ret

; ============================================================================
; CALCULADORA
; ============================================================================

load_calculator:
    pushad

    mov dword [calc_display], 0
    mov dword [calc_accumulator], 0
    mov byte [calc_operation], 0
    mov byte [calc_new_number], 1

    call draw_calculator_window

    popad
    ret

draw_calculator_window:
    pushad

    ; Fundo
    mov al, COLOR_CARD_BG
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_calc_title
    call draw_text

    call draw_window_buttons

    ; Display
    mov ebx, 20
    mov ecx, 25
    mov edx, 280
    mov esi, 30
    mov al, COLOR_WHITE
    call draw_filled_rect

    ; Valor no display
    mov byte [text_color], COLOR_TEXT_DARK
    mov dword [text_x], 30
    mov dword [text_y], 32

    mov eax, [calc_display]
    call number_to_string
    mov esi, number_str
    call draw_text

    ; Grid simplificado de botões 4x4
    ; Linha 1: 7 8 9 /
    mov ebx, 40
    mov ecx, 70
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 55
    mov dword [text_y], 77
    mov esi, str_btn_7
    call draw_text

    mov ebx, 100
    mov ecx, 70
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 115
    mov esi, str_btn_8
    call draw_text

    mov ebx, 160
    mov ecx, 70
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 175
    mov esi, str_btn_9
    call draw_text

    mov ebx, 220
    mov ecx, 70
    mov edx, 50
    mov esi, 25
    mov al, COLOR_ORANGE
    call draw_filled_rect
    mov dword [text_x], 235
    mov esi, str_btn_div
    call draw_text

    ; Linha 2: 4 5 6 *
    mov ebx, 40
    mov ecx, 105
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 55
    mov dword [text_y], 112
    mov esi, str_btn_4
    call draw_text

    mov ebx, 100
    mov ecx, 105
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 115
    mov esi, str_btn_5
    call draw_text

    mov ebx, 160
    mov ecx, 105
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 175
    mov esi, str_btn_6
    call draw_text

    mov ebx, 220
    mov ecx, 105
    mov edx, 50
    mov esi, 25
    mov al, COLOR_ORANGE
    call draw_filled_rect
    mov dword [text_x], 235
    mov esi, str_btn_mul
    call draw_text

    ; Linha 3: 1 2 3 -
    mov ebx, 40
    mov ecx, 140
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 55
    mov dword [text_y], 147
    mov esi, str_btn_1
    call draw_text

    mov ebx, 100
    mov ecx, 140
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 115
    mov esi, str_btn_2
    call draw_text

    mov ebx, 160
    mov ecx, 140
    mov edx, 50
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 175
    mov esi, str_btn_3
    call draw_text

    mov ebx, 220
    mov ecx, 140
    mov edx, 50
    mov esi, 25
    mov al, COLOR_ORANGE
    call draw_filled_rect
    mov dword [text_x], 235
    mov esi, str_btn_sub
    call draw_text

    ; Linha 4: 0 = +
    mov ebx, 40
    mov ecx, 175
    mov edx, 110
    mov esi, 25
    mov al, COLOR_GRAY
    call draw_filled_rect
    mov dword [text_x], 85
    mov dword [text_y], 182
    mov esi, str_btn_0
    call draw_text

    mov ebx, 160
    mov ecx, 175
    mov edx, 50
    mov esi, 25
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect
    mov dword [text_x], 175
    mov esi, str_btn_equ
    call draw_text

    mov ebx, 220
    mov ecx, 175
    mov edx, 50
    mov esi, 25
    mov al, COLOR_ORANGE
    call draw_filled_rect
    mov dword [text_x], 235
    mov esi, str_btn_add
    call draw_text

    popad
    ret

handle_calculator_key:
    pushad

    mov al, [last_scancode]

    ; ESC fecha
    cmp al, 0x01
    je .close

    ; Números 0-9
    cmp al, 0x0B                    ; 0
    je .num_0
    cmp al, 0x02                    ; 1
    je .num_1
    cmp al, 0x03                    ; 2
    je .num_2
    cmp al, 0x04                    ; 3
    je .num_3
    cmp al, 0x05                    ; 4
    je .num_4
    cmp al, 0x06                    ; 5
    je .num_5
    cmp al, 0x07                    ; 6
    je .num_6
    cmp al, 0x08                    ; 7
    je .num_7
    cmp al, 0x09                    ; 8
    je .num_8
    cmp al, 0x0A                    ; 9
    je .num_9

    ; Operações
    cmp al, 0x1C                    ; Enter (=)
    je .equals
    cmp al, 0x4E                    ; +
    je .add
    cmp al, 0x4A                    ; -
    je .subtract
    cmp al, 0x37                    ; *
    je .multiply
    cmp al, 0x35                    ; /
    je .divide

    jmp .done

.num_0:
    mov al, 0
    jmp .add_digit
.num_1:
    mov al, 1
    jmp .add_digit
.num_2:
    mov al, 2
    jmp .add_digit
.num_3:
    mov al, 3
    jmp .add_digit
.num_4:
    mov al, 4
    jmp .add_digit
.num_5:
    mov al, 5
    jmp .add_digit
.num_6:
    mov al, 6
    jmp .add_digit
.num_7:
    mov al, 7
    jmp .add_digit
.num_8:
    mov al, 8
    jmp .add_digit
.num_9:
    mov al, 9
    jmp .add_digit

.add_digit:
    cmp byte [calc_new_number], 1
    jne .not_new

    movzx eax, al
    mov [calc_display], eax
    mov byte [calc_new_number], 0
    jmp .refresh

.not_new:
    mov eax, [calc_display]
    imul eax, 10
    movzx ebx, al
    add eax, ebx
    mov [calc_display], eax
    jmp .refresh

.add:
    call calc_do_operation
    mov byte [calc_operation], '+'
    mov byte [calc_new_number], 1
    jmp .refresh

.subtract:
    call calc_do_operation
    mov byte [calc_operation], '-'
    mov byte [calc_new_number], 1
    jmp .refresh

.multiply:
    call calc_do_operation
    mov byte [calc_operation], '*'
    mov byte [calc_new_number], 1
    jmp .refresh

.divide:
    call calc_do_operation
    mov byte [calc_operation], '/'
    mov byte [calc_new_number], 1
    jmp .refresh

.equals:
    call calc_do_operation
    mov byte [calc_operation], 0
    mov byte [calc_new_number], 1
    jmp .refresh

.refresh:
    call draw_calculator_window
    jmp .done

.close:
    mov dword [current_screen], SCREEN_DESKTOP
    call draw_desktop

.done:
    popad
    ret

calc_do_operation:
    pushad

    mov al, [calc_operation]
    test al, al
    jz .first_number

    mov eax, [calc_accumulator]
    mov ebx, [calc_display]

    cmp byte [calc_operation], '+'
    je .do_add
    cmp byte [calc_operation], '-'
    je .do_sub
    cmp byte [calc_operation], '*'
    je .do_mul
    cmp byte [calc_operation], '/'
    je .do_div
    jmp .store_result

.do_add:
    add eax, ebx
    jmp .store_result

.do_sub:
    sub eax, ebx
    jmp .store_result

.do_mul:
    imul eax, ebx
    jmp .store_result

.do_div:
    test ebx, ebx
    jz .store_result
    xor edx, edx
    idiv ebx
    jmp .store_result

.first_number:
    mov eax, [calc_display]

.store_result:
    mov [calc_accumulator], eax
    mov [calc_display], eax

    popad
    ret

; ============================================================================
; PAINT - Aplicativo de Desenho
; ============================================================================

load_paint:
    pushad

    ; Limpa canvas
    mov edi, TEMP_BUFFER
    mov ecx, SCREEN_SIZE
    mov al, COLOR_WHITE
    rep stosb

    mov byte [paint_color], COLOR_BLACK
    mov byte [paint_brush_size], 2
    mov byte [paint_drawing], 0

    call draw_paint_window

    popad
    ret

draw_paint_window:
    pushad

    ; Copia canvas do buffer
    mov esi, TEMP_BUFFER
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_paint_title
    call draw_text

    call draw_window_buttons

    ; Paleta de cores (topo)
    mov ebx, 10
    mov ecx, 20
    mov edx, 0

.color_loop:
    cmp edx, 16
    jge .color_done

    push edx

    mov eax, edx
    add al, COLOR_BLACK

    push ebx
    push ecx
    mov esi, 15
    mov edx, 15
    call draw_filled_rect
    pop ecx
    pop ebx

    add ebx, 18
    pop edx
    inc edx
    jmp .color_loop

.color_done:
    ; Indicador de cor atual
    mov ebx, 295
    mov ecx, 20
    mov edx, 20
    mov esi, 15
    mov al, [paint_color]
    call draw_filled_rect

    popad
    ret

handle_paint_key:
    pushad

    mov al, [last_scancode]

    ; ESC fecha
    cmp al, 0x01
    je .close

    ; C limpa canvas
    cmp al, 0x2E
    je .clear_canvas

    ; 1-9 muda tamanho do pincel
    cmp al, 0x02
    je .brush_1
    cmp al, 0x03
    je .brush_2
    cmp al, 0x04
    je .brush_3

    jmp .done

.clear_canvas:
    mov edi, TEMP_BUFFER
    mov ecx, SCREEN_SIZE
    mov al, COLOR_WHITE
    rep stosb
    call draw_paint_window
    jmp .done

.brush_1:
    mov byte [paint_brush_size], 1
    jmp .done

.brush_2:
    mov byte [paint_brush_size], 2
    jmp .done

.brush_3:
    mov byte [paint_brush_size], 3
    jmp .done

.close:
    mov dword [current_screen], SCREEN_DESKTOP
    call draw_desktop

.done:
    popad
    ret

; ============================================================================
; EXPLORER - Gerenciador de Arquivos
; ============================================================================

load_explorer:
    pushad

    mov dword [explorer_selected], 0
    mov dword [explorer_scroll], 0

    call draw_explorer_window

    popad
    ret

draw_explorer_window:
    pushad

    ; Fundo
    mov al, COLOR_WHITE
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_explorer_title
    call draw_text

    call draw_window_buttons

    ; Barra de navegação
    mov ebx, 10
    mov ecx, 20
    mov edx, 300
    mov esi, 20
    mov al, COLOR_GRAY
    call draw_filled_rect

    mov byte [text_color], COLOR_TEXT_DARK
    mov dword [text_x], 15
    mov dword [text_y], 26
    mov esi, str_path
    call draw_text

    ; Lista de arquivos
    mov dword [text_y], 50
    mov ebx, 0

.file_loop:
    cmp ebx, [fs_file_count]
    jge .done

    ; Verifica se está visível (scroll)
    mov eax, ebx
    sub eax, [explorer_scroll]
    cmp eax, 0
    jl .next_file
    cmp eax, 12
    jge .next_file

    ; Desenha item
    push ebx

    ; Background se selecionado
    cmp ebx, [explorer_selected]
    jne .not_selected

    push ebx
    mov eax, [text_y]
    mov ecx, eax
    mov ebx, 10
    mov edx, 300
    mov esi, 12
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect
    pop ebx

    mov byte [text_color], COLOR_WHITE
    jmp .draw_name

.not_selected:
    mov byte [text_color], COLOR_TEXT_DARK

.draw_name:
    mov dword [text_x], 15

    ; Obtém nome do arquivo
    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov esi, eax

    call draw_text

    pop ebx
    add dword [text_y], 13

.next_file:
    inc ebx
    jmp .file_loop

.done:
    popad
    ret

; ============================================================================
; SETTINGS - Configurações
; ============================================================================

load_settings:
    pushad
    call draw_settings_window
    popad
    ret

draw_settings_window:
    pushad

    ; Fundo
    mov al, COLOR_WHITE
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_settings_title
    call draw_text

    call draw_window_buttons

    ; Opções de configuração
    mov byte [text_color], COLOR_TEXT_DARK

    mov dword [text_x], 20
    mov dword [text_y], 30
    mov esi, str_setting_display
    call draw_text

    mov dword [text_y], 50
    mov esi, str_setting_sound
    call draw_text

    mov dword [text_y], 70
    mov esi, str_setting_system
    call draw_text

    mov dword [text_y], 90
    mov esi, str_setting_about
    call draw_text

    popad
    ret

; ============================================================================
; CALENDAR - Calendário
; ============================================================================

load_calendar:
    pushad
    call draw_calendar_window
    popad
    ret

draw_calendar_window:
    pushad

    ; Fundo
    mov al, COLOR_WHITE
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_calendar_title
    call draw_text

    call draw_window_buttons

    ; Mês e Ano
    mov byte [text_color], COLOR_TEXT_DARK
    mov dword [text_x], 100
    mov dword [text_y], 25
    mov esi, str_month_year
    call draw_text

    ; Grid do calendário (7x6)
    mov dword [text_y], 45

    ; Cabeçalhos dos dias
    mov dword [text_x], 20
    mov esi, str_sun
    call draw_text

    mov dword [text_x], 60
    mov esi, str_mon
    call draw_text

    mov dword [text_x], 100
    mov esi, str_tue
    call draw_text

    mov dword [text_x], 140
    mov esi, str_wed
    call draw_text

    mov dword [text_x], 180
    mov esi, str_thu
    call draw_text

    mov dword [text_x], 220
    mov esi, str_fri
    call draw_text

    mov dword [text_x], 260
    mov esi, str_sat
    call draw_text

    ; Dias do mês (exemplo simplificado)
    mov dword [text_y], 65
    mov dword [text_x], 20
    mov ecx, 1

.day_loop:
    cmp ecx, 32
    jge .done

    push ecx

    ; Desenha número do dia
    mov eax, ecx
    call number_to_string
    mov esi, number_str
    call draw_text

    add dword [text_x], 40
    cmp dword [text_x], 280
    jl .same_line

    mov dword [text_x], 20
    add dword [text_y], 15

.same_line:
    pop ecx
    inc ecx
    jmp .day_loop

.done:
    popad
    ret

; ============================================================================
; CLOCK - Relógio
; ============================================================================

load_clock:
    pushad
    call draw_clock_window
    popad
    ret

draw_clock_window:
    pushad

    ; Fundo
    mov al, COLOR_BLACK
    call clear_screen_color

    ; Barra de título
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, COLOR_CARD_BG
    call draw_filled_rect

    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 5
    mov dword [text_y], 3
    mov esi, str_clock_title
    call draw_text

    call draw_window_buttons

    ; Relógio analógico (círculo no centro)
    mov ebx, 160
    mov ecx, 100
    mov edx, 60
    call draw_circle

    ; Hora digital grande
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 120
    mov dword [text_y], 155

    movzx eax, byte [rtc_hour]
    call bcd_to_ascii
    mov [time_large_str], al
    mov [time_large_str+1], ah
    mov byte [time_large_str+2], ':'

    movzx eax, byte [rtc_minute]
    call bcd_to_ascii
    mov [time_large_str+3], al
    mov [time_large_str+4], ah
    mov byte [time_large_str+5], ':'

    movzx eax, byte [rtc_second]
    call bcd_to_ascii
    mov [time_large_str+6], al
    mov [time_large_str+7], ah
    mov byte [time_large_str+8], 0

    mov esi, time_large_str
    call draw_text

    popad
    ret

; ============================================================================
; FUNÇÕES DE DESENHO
; ============================================================================

draw_window_buttons:
    pushad

    ; Botão fechar (X)
    mov ebx, 295
    mov ecx, 3
    mov edx, 20
    mov esi, 9
    mov al, COLOR_RED
    call draw_filled_rect

    ; X branco
    mov byte [text_color], COLOR_WHITE
    mov dword [text_x], 300
    mov dword [text_y], 3
    mov esi, str_x
    call draw_text

    ; Botão minimizar (_)
    mov ebx, 270
    mov ecx, 3
    mov edx, 20
    mov esi, 9
    mov al, COLOR_YELLOW
    call draw_filled_rect

    ; Botão maximizar (□)
    mov ebx, 245
    mov ecx, 3
    mov edx, 20
    mov esi, 9
    mov al, COLOR_GREEN
    call draw_filled_rect

    popad
    ret

draw_mouse_cursor:
    pushad

    mov ebx, [mouse_x]
    mov ecx, [mouse_y]

    ; Desenha seta do cursor (10x16 pixels)
    mov esi, 0

.cursor_y:
    cmp esi, 16
    jge .done

    mov edi, 0

.cursor_x:
    cmp edi, 10
    jge .next_y

    ; Formato de seta simples
    cmp edi, esi
    jg .skip

    push ebx
    push ecx
    add ebx, edi
    add ecx, esi

    ; Borda preta
    cmp edi, 0
    je .draw_border
    cmp edi, esi
    je .draw_border
    cmp esi, 15
    je .draw_border

    ; Interior branco
    mov al, COLOR_WHITE
    jmp .draw_pixel

.draw_border:
    mov al, COLOR_BLACK

.draw_pixel:
    call draw_pixel

    pop ecx
    pop ebx

.skip:
    inc edi
    jmp .cursor_x

.next_y:
    inc esi
    jmp .cursor_y

.done:
    popad
    ret

draw_pixel:
    pushad

    cmp ebx, 0
    jl .done
    cmp ebx, SCREEN_WIDTH
    jge .done
    cmp ecx, 0
    jl .done
    cmp ecx, SCREEN_HEIGHT
    jge .done

    mov eax, ecx
    imul eax, SCREEN_WIDTH
    add eax, ebx

    mov edi, VGA_MEMORY
    add edi, eax

    pop eax
    push eax
    mov [edi], al

.done:
    popad
    ret

draw_filled_rect:
    pushad

    mov [.x], ebx
    mov [.y], ecx
    mov [.width], edx
    mov [.height], esi
    mov [.color], al

.loop_y:
    cmp dword [.height], 0
    je .done

    mov ebx, [.x]
    mov edx, [.width]

.loop_x:
    cmp edx, 0
    je .next_line

    mov ecx, [.y]
    mov al, [.color]
    call draw_pixel

    inc ebx
    dec edx
    jmp .loop_x

.next_line:
    inc dword [.y]
    dec dword [.height]
    jmp .loop_y

.done:
    popad
    ret

.x dd 0
.y dd 0
.width dd 0
.height dd 0
.color db 0

draw_circle:
    pushad

    ; Algoritmo de Bresenham para círculos
    ; ebx = center_x, ecx = center_y, edx = radius

    mov [.cx], ebx
    mov [.cy], ecx
    mov [.r], edx

    mov dword [.x], 0
    mov eax, [.r]
    mov [.y], eax

    mov eax, [.r]
    imul eax, eax
    mov [.d], eax
    neg dword [.d]
    shr dword [.d], 1

.loop:
    mov eax, [.x]
    cmp eax, [.y]
    jg .done

    ; Desenha 8 pontos simétricos
    call .plot_8_points

    ; Atualiza d
    mov eax, [.d]
    cmp eax, 0
    jge .d_positive

    ; d < 0
    mov eax, [.x]
    shl eax, 1
    add eax, 3
    add [.d], eax
    jmp .inc_x

.d_positive:
    mov eax, [.x]
    sub eax, [.y]
    shl eax, 1
    add eax, 5
    add [.d], eax
    dec dword [.y]

.inc_x:
    inc dword [.x]
    jmp .loop

.plot_8_points:
    pushad

    mov ebx, [.cx]
    mov ecx, [.cy]
    mov esi, [.x]
    mov edi, [.y]

    ; (cx+x, cy+y)
    push ebx
    push ecx
    add ebx, esi
    add ecx, edi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx-x, cy+y)
    push ebx
    push ecx
    sub ebx, esi
    add ecx, edi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx+x, cy-y)
    push ebx
    push ecx
    add ebx, esi
    sub ecx, edi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx-x, cy-y)
    push ebx
    push ecx
    sub ebx, esi
    sub ecx, edi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx+y, cy+x)
    push ebx
    push ecx
    add ebx, edi
    add ecx, esi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx-y, cy+x)
    push ebx
    push ecx
    sub ebx, edi
    add ecx, esi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx+y, cy-x)
    push ebx
    push ecx
    add ebx, edi
    sub ecx, esi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    ; (cx-y, cy-x)
    push ebx
    push ecx
    sub ebx, edi
    sub ecx, esi
    mov al, COLOR_WHITE
    call draw_pixel
    pop ecx
    pop ebx

    popad
    ret

.cx dd 0
.cy dd 0
.r dd 0
.x dd 0
.y dd 0
.d dd 0

.done:
    popad
    ret

; ============================================================================
; FUNÇÕES DE TEXTO
; ============================================================================

draw_text:
    pushad

.loop:
    lodsb
    test al, al
    jz .done

    call draw_char
    add dword [text_x], 8

    jmp .loop

.done:
    popad
    ret

draw_char:
    pushad

    ; Obtém dados da fonte
    cmp al, 32
    jl .done
    cmp al, 126
    jg .done

    sub al, 32
    movzx eax, al
    shl eax, 3
    add eax, font_data
    mov esi, eax

    ; Desenha 8x8
    mov ecx, 8
    mov edi, [text_y]

.row_loop:
    lodsb
    push ecx
    mov ecx, 8
    mov ebx, [text_x]
    mov ah, al

.col_loop:
    shl ah, 1
    jnc .no_pixel

    push eax
    push ecx
    mov ecx, edi
    mov al, [text_color]
    call draw_pixel
    pop ecx
    pop eax

.no_pixel:
    inc ebx
    loop .col_loop

    inc edi
    pop ecx
    loop .row_loop

.done:
    popad
    ret

; ============================================================================
; FUNÇÕES UTILITÁRIAS
; ============================================================================

clear_screen_color:
    pushad

    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep stosb

    popad
    ret

is_mouse_over_rect:
    ; ebx=x, ecx=y, edx=width, esi=height
    ; Retorna eax=1 se mouse está sobre, 0 caso contrário
    pushad

    mov eax, [mouse_x]
    cmp eax, ebx
    jl .not_over

    add edx, ebx
    cmp eax, edx
    jge .not_over

    mov eax, [mouse_y]
    cmp eax, ecx
    jl .not_over

    add esi, ecx
    cmp eax, esi
    jge .not_over

    mov dword [esp+28], 1
    popad
    ret

.not_over:
    mov dword [esp+28], 0
    popad
    ret

update_hover_state:
    pushad
    ; TODO: Implementar estados de hover para elementos interativos
    popad
    ret

update_clock:
    pushad

    ; Atualiza a cada segundo (18.2 ticks = ~1 segundo)
    mov eax, [system_ticks]
    and eax, 0x1F
    cmp eax, 0
    jne .done

    ; Lê RTC
    mov al, 0x00
    out 0x70, al
    in al, 0x71
    mov [rtc_second], al

    mov al, 0x02
    out 0x70, al
    in al, 0x71
    mov [rtc_minute], al

    mov al, 0x04
    out 0x70, al
    in al, 0x71
    mov [rtc_hour], al

.done:
    popad
    ret

update_animations:
    pushad

    ; Atualiza fase de animação
    mov eax, [system_ticks]
    and eax, 0x0F
    mov [animation_phase], eax

    popad
    ret

process_pending_commands:
    pushad
    ; TODO: Processar comandos em fila
    popad
    ret

handle_window_click:
    pushad
    ; TODO: Gerenciar cliques em janelas
    popad
    ret

draw_boot_animation:
    pushad

    ; Fundo preto
    mov al, COLOR_BLACK
    call clear_screen_color

    ; Logo "GatitoOS" no centro
    mov byte [text_color], COLOR_BLUE_ACCENT
    mov dword [text_x], 120
    mov dword [text_y], 90
    mov esi, str_gatito_logo
    call draw_text

    ; Barra de carregamento
    mov ebx, 80
    mov ecx, 110
    mov edx, 160
    mov esi, 4
    mov al, COLOR_GRAY
    call draw_filled_rect

    ; Progresso
    mov ebx, 80
    mov ecx, 110
    mov edx, 40
    mov esi, 4
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect

    call delay_boot

    mov edx, 80
    mov al, COLOR_BLUE_ACCENT
    call draw_filled_rect

    call delay_boot

    mov edx, 120
    call draw_filled_rect

    call delay_boot

    mov edx, 160
    call draw_filled_rect

    call delay_boot

    popad
    ret

delay_boot:
    push ecx
    mov ecx, 0x3FFFFFF
.loop:
    nop
    loop .loop
    pop ecx
    ret

scancode_to_ascii:
    pushad

    mov bl, [shift_pressed]

    ; Letras A-Z
    cmp al, 0x1E
    jne .not_a
    mov al, 'A'
    jmp .apply_shift
.not_a:
    cmp al, 0x30
    jne .not_b
    mov al, 'B'
    jmp .apply_shift
.not_b:
    cmp al, 0x2E
    jne .not_c
    mov al, 'C'
    jmp .apply_shift
.not_c:
    cmp al, 0x20
    jne .not_d
    mov al, 'D'
    jmp .apply_shift
.not_d:
    cmp al, 0x12
    jne .not_e
    mov al, 'E'
    jmp .apply_shift
.not_e:
    cmp al, 0x21
    jne .not_f
    mov al, 'F'
    jmp .apply_shift
.not_f:
    cmp al, 0x22
    jne .not_g
    mov al, 'G'
    jmp .apply_shift
.not_g:
    cmp al, 0x23
    jne .not_h
    mov al, 'H'
    jmp .apply_shift
.not_h:
    cmp al, 0x17
    jne .not_i
    mov al, 'I'
    jmp .apply_shift
.not_i:
    cmp al, 0x24
    jne .not_j
    mov al, 'J'
    jmp .apply_shift
.not_j:
    cmp al, 0x25
    jne .not_k
    mov al, 'K'
    jmp .apply_shift
.not_k:
    cmp al, 0x26
    jne .not_l
    mov al, 'L'
    jmp .apply_shift
.not_l:
    cmp al, 0x32
    jne .not_m
    mov al, 'M'
    jmp .apply_shift
.not_m:
    cmp al, 0x31
    jne .not_n
    mov al, 'N'
    jmp .apply_shift
.not_n:
    cmp al, 0x18
    jne .not_o
    mov al, 'O'
    jmp .apply_shift
.not_o:
    cmp al, 0x19
    jne .not_p
    mov al, 'P'
    jmp .apply_shift
.not_p:
    cmp al, 0x10
    jne .not_q
    mov al, 'Q'
    jmp .apply_shift
.not_q:
    cmp al, 0x13
    jne .not_r
    mov al, 'R'
    jmp .apply_shift
.not_r:
    cmp al, 0x1F
    jne .not_s
    mov al, 'S'
    jmp .apply_shift
.not_s:
    cmp al, 0x14
    jne .not_t
    mov al, 'T'
    jmp .apply_shift
.not_t:
    cmp al, 0x16
    jne .not_u
    mov al, 'U'
    jmp .apply_shift
.not_u:
    cmp al, 0x2F
    jne .not_v
    mov al, 'V'
    jmp .apply_shift
.not_v:
    cmp al, 0x11
    jne .not_w
    mov al, 'W'
    jmp .apply_shift
.not_w:
    cmp al, 0x2D
    jne .not_x
    mov al, 'X'
    jmp .apply_shift
.not_x:
    cmp al, 0x15
    jne .not_y
    mov al, 'Y'
    jmp .apply_shift
.not_y:
    cmp al, 0x2C
    jne .not_z
    mov al, 'Z'
    jmp .apply_shift
.not_z:

    ; Números 0-9
    cmp al, 0x0B
    jne .not_0
    mov al, '0'
    jmp .done
.not_0:
    cmp al, 0x02
    jne .not_1
    mov al, '1'
    jmp .done
.not_1:
    cmp al, 0x03
    jne .not_2
    mov al, '2'
    jmp .done
.not_2:
    cmp al, 0x04
    jne .not_3
    mov al, '3'
    jmp .done
.not_3:
    cmp al, 0x05
    jne .not_4
    mov al, '4'
    jmp .done
.not_4:
    cmp al, 0x06
    jne .not_5
    mov al, '5'
    jmp .done
.not_5:
    cmp al, 0x07
    jne .not_6
    mov al, '6'
    jmp .done
.not_6:
    cmp al, 0x08
    jne .not_7
    mov al, '7'
    jmp .done
.not_7:
    cmp al, 0x09
    jne .not_8
    mov al, '8'
    jmp .done
.not_8:
    cmp al, 0x0A
    jne .not_9
    mov al, '9'
    jmp .done
.not_9:

    xor al, al
    jmp .done

.apply_shift:
    test bl, bl
    jnz .done
    add al, 32                      ; Minúscula

.done:
    mov [esp+28], al
    popad
    ret

bcd_to_ascii:
    ; Converte BCD em eax para ASCII em ah:al
    push ebx
    push ecx

    mov ebx, eax
    and ebx, 0x0F
    add bl, '0'

    shr eax, 4
    and eax, 0x0F
    add al, '0'

    mov ah, bl

    pop ecx
    pop ebx
    ret

number_to_string:
    ; Converte número em eax para string em number_str
    pushad

    mov edi, number_str
    mov ecx, 10

    ; Trata zero especial
    test eax, eax
    jnz .convert

    mov byte [edi], '0'
    inc edi
    mov byte [edi], 0
    jmp .done

.convert:
    ; Conta dígitos primeiro
    mov ebx, eax
    xor edx, edx

.count_loop:
    test ebx, ebx
    jz .reverse

    xor edx, edx
    mov ecx, 10
    div ecx
    push edx
    inc esi
    mov ebx, eax
    jmp .count_loop

.reverse:
    ; Reconstrói da pilha
    mov ecx, esi
    test ecx, ecx
    jz .done

.pop_loop:
    pop eax
    add al, '0'
    stosb
    loop .pop_loop

    mov byte [edi], 0

.done:
    popad
    ret

; ============================================================================
; DADOS DA FONTE (8x8 Bitmap Font)
; ============================================================================

align 4
font_data:
    ; Espaço (32)
    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    ; ! (33)
    db 0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x00
    ; " (34)
    db 0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00
    ; # (35)
    db 0x66,0xFF,0x66,0x66,0xFF,0x66,0x66,0x00
    ; $ (36)
    db 0x18,0x3E,0x60,0x3C,0x06,0x7C,0x18,0x00
    ; % (37)
    db 0x62,0x66,0x0C,0x18,0x30,0x66,0x46,0x00
    ; & (38)
    db 0x3C,0x66,0x3C,0x38,0x67,0x66,0x3F,0x00
    ; ' (39)
    db 0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00
    ; ( (40)
    db 0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00
    ; ) (41)
    db 0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00
    ; * (42)
    db 0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00
    ; + (43)
    db 0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00
    ; , (44)
    db 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30
    ; - (45)
    db 0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00
    ; . (46)
    db 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00
    ; / (47)
    db 0x00,0x03,0x06,0x0C,0x18,0x30,0x60,0x00
    ; 0 (48)
    db 0x3C,0x66,0x6E,0x76,0x66,0x66,0x3C,0x00
    ; 1 (49)
    db 0x18,0x38,0x18,0x18,0x18,0x18,0x7E,0x00
    ; 2 (50)
    db 0x3C,0x66,0x06,0x0C,0x18,0x30,0x7E,0x00
    ; 3 (51)
    db 0x3C,0x66,0x06,0x1C,0x06,0x66,0x3C,0x00
    ; 4 (52)
    db 0x0C,0x1C,0x3C,0x6C,0x7E,0x0C,0x0C,0x00
    ; 5 (53)
    db 0x7E,0x60,0x7C,0x06,0x06,0x66,0x3C,0x00
    ; 6 (54)
    db 0x1C,0x30,0x60,0x7C,0x66,0x66,0x3C,0x00
    ; 7 (55)
    db 0x7E,0x06,0x0C,0x18,0x30,0x30,0x30,0x00
    ; 8 (56)
    db 0x3C,0x66,0x66,0x3C,0x66,0x66,0x3C,0x00
    ; 9 (57)
    db 0x3C,0x66,0x66,0x3E,0x06,0x0C,0x38,0x00
    ; : (58)
    db 0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00
    ; ; (59)
    db 0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30
    ; < (60)
    db 0x0C,0x18,0x30,0x60,0x30,0x18,0x0C,0x00
    ; = (61)
    db 0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00
    ; > (62)
    db 0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x00
    ; ? (63)
    db 0x3C,0x66,0x06,0x0C,0x18,0x00,0x18,0x00
    ; @ (64)
    db 0x3C,0x66,0x6E,0x6A,0x6E,0x60,0x3C,0x00
    ; A (65)
    db 0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00
    ; B (66)
    db 0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00
    ; C (67)
    db 0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00
    ; D (68)
    db 0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00
    ; E (69)
    db 0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00
    ; F (70)
    db 0x7E,0x60,0x60,0x7C,0x60,0x60,0x60,0x00
    ; G (71)
    db 0x3C,0x66,0x60,0x6E,0x66,0x66,0x3C,0x00
    ; H (72)
    db 0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00
    ; I (73)
    db 0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00
    ; J (74)
    db 0x1E,0x0C,0x0C,0x0C,0x0C,0x6C,0x38,0x00
    ; K (75)
    db 0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00
    ; L (76)
    db 0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00
    ; M (77)
    db 0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00
    ; N (78)
    db 0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00
    ; O (79)
    db 0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
    ; P (80)
    db 0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00
    ; Q (81)
    db 0x3C,0x66,0x66,0x66,0x6A,0x6C,0x36,0x00
    ; R (82)
    db 0x7C,0x66,0x66,0x7C,0x78,0x6C,0x66,0x00
    ; S (83)
    db 0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00
    ; T (84)
    db 0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00
    ; U (85)
    db 0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
    ; V (86)
    db 0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00
    ; W (87)
    db 0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00
    ; X (88)
    db 0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00
    ; Y (89)
    db 0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00
    ; Z (90)
    db 0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00
    ; Restante até 126...
    times ((126-90)*8) db 0x00

; ============================================================================
; STRINGS E MENSAGENS
; ============================================================================

str_gatito_logo         db 'GATITO OS',0
str_pinned_apps         db 'PINNED APPS',0
str_recommended         db 'RECOMMENDED',0
str_recent_file         db 'README.TXT',0

str_notepad             db 'NOTEPAD',0
str_terminal            db 'TERMINAL',0
str_calc                db 'CALC',0
str_paint               db 'PAINT',0
str_files               db 'FILES',0
str_settings            db 'SETTINGS',0
str_calendar            db 'CALENDAR',0
str_clock               db 'CLOCK',0

str_notepad_title       db 'NOTEPAD',0
str_terminal_title      db 'TERMINAL',0
str_calc_title          db 'CALCULATOR',0
str_paint_title         db 'PAINT',0
str_explorer_title      db 'FILE EXPLORER',0
str_settings_title      db 'SETTINGS',0
str_calendar_title      db 'CALENDAR',0
str_clock_title         db 'CLOCK',0

str_terminal_banner     db 'GATITO OS V1.0 - READY',0
str_terminal_prompt     db '> ',0

str_path                db 'C:\\USERS\\',0
str_x                   db 'X',0

str_setting_display     db 'DISPLAY',0
str_setting_sound       db 'SOUND',0
str_setting_system      db 'SYSTEM',0
str_setting_about       db 'ABOUT',0

str_month_year          db 'JANUARY 2025',0
str_sun                 db 'SUN',0
str_mon                 db 'MON',0
str_tue                 db 'TUE',0
str_wed                 db 'WED',0
str_thu                 db 'THU',0
str_fri                 db 'FRI',0
str_sat                 db 'SAT',0

str_btn_7               db '7',0
str_btn_8               db '8',0
str_btn_9               db '9',0
str_btn_div             db '/',0
str_btn_4               db '4',0
str_btn_5               db '5',0
str_btn_6               db '6',0
str_btn_mul             db '*',0
str_btn_1               db '1',0
str_btn_2               db '2',0
str_btn_3               db '3',0
str_btn_sub             db '-',0
str_btn_0               db '0',0
str_btn_equ             db '=',0
str_btn_add             db '+',0

cmd_help                db 'HELP',0
cmd_clear               db 'CLEAR',0
cmd_ls                  db 'LS',0
cmd_ver                 db 'VER',0

file1_name              db 'README.TXT',0
                        times (FS_FILENAME_LEN-11) db 0
file1_content           db 'WELCOME TO GATITO OS - A MODERN 32-BIT OPERATING SYSTEM',0
                        times (FS_CONTENT_LEN-57) db 0

file2_name              db 'WELCOME.TXT',0
                        times (FS_FILENAME_LEN-12) db 0
file2_content           db 'THIS IS A FULLY FUNCTIONAL OS WRITTEN IN PURE ASSEMBLY',0
                        times (FS_CONTENT_LEN-56) db 0

file3_name              db 'SYSTEM.INI',0
                        times (FS_FILENAME_LEN-11) db 0
file3_content           db '[SYSTEM] VERSION=1.0 ARCH=X86',0
                        times (FS_CONTENT_LEN-31) db 0

; ============================================================================
; VARIÁVEIS GLOBAIS
; ============================================================================

align 4

; Sistema
current_screen          dd SCREEN_DESKTOP
system_ticks            dd 0
frame_counter           dd 0
fps_value               dd 0
animation_phase         dd 0
last_scancode           db 0

; Teclado
ctrl_pressed            db 0
shift_pressed           db 0
alt_pressed             db 0

; Mouse
mouse_x                 dd 160
mouse_y                 dd 100
mouse_buttons           db 0
mouse_cycle             db 0
mouse_packet            times 3 db 0
mouse_was_pressed       db 0

; Interface
start_menu_open         db 0
wallpaper_enabled       db 0
active_window           dd 0
window_count            dd 0

; RTC
rtc_hour                db 0
rtc_minute              db 0
rtc_second              db 0

; Texto
text_x                  dd 0
text_y                  dd 0
text_color              db COLOR_WHITE

; Buffers de texto
time_str                times 16 db 0
time_large_str          times 16 db 0
number_str              times 16 db 0

; Notepad
notepad_buffer          times TEXT_BUFFER_SIZE db 0
notepad_cursor_pos      dd 0
notepad_scroll          dd 0

; Terminal
terminal_buffer         times CMD_BUFFER_SIZE db 0
terminal_cursor         dd 0
terminal_line           dd 0

; Calculadora
calc_display            dd 0
calc_accumulator        dd 0
calc_operation          db 0
calc_new_number         db 1

; Paint
paint_color             db COLOR_BLACK
paint_brush_size        db 2
paint_drawing           db 0

; Explorer
explorer_selected       dd 0
explorer_scroll         dd 0

; Sistema de arquivos
fs_file_count           dd 0

; ============================================================================
; IDT (Interrupt Descriptor Table)
; ============================================================================

align 8
idt_table:
    times 256*8 db 0

idt_descriptor:
    dw (256*8)-1
    dd idt_table

; ============================================================================
; PADDING FINAL
; ============================================================================

align 512
times 65536-($-$) db 0

; FIM DO GATITO OS

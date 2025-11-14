[BITS 32]
[ORG 0x10000]

VGA_MEMORY equ 0xA0000
SCREEN_WIDTH equ 320
SCREEN_HEIGHT equ 200
SCREEN_SIZE equ 64000


CLIPBOARD_SIZE equ 2048
TEXT_BUFFER_SIZE equ 4096
TERM_BUFFER_SIZE equ 512


FS_MAX_FILES equ 64
FS_FILENAME_LEN equ 12
FS_CONTENT_LEN equ 256
FS_ENTRY_SIZE equ 268


MAX_PACKAGES equ 16
PKG_NAME_LEN equ 16
PKG_INSTALLED_FLAG equ 1


MAX_MODULES equ 8
MODULE_NAME_LEN equ 16
MODULE_LOADED_FLAG equ 1


IMAGE_LOAD_ADDR equ 0x20000
SCREENSHOT_BUFFER equ 0x30000
FILESYSTEM_BASE equ 0x40000
VRAM_BACKUP equ 0x50000
PACKAGE_BASE equ 0x60000
MODULE_BASE equ 0x70000


PS2_DATA equ 0x60
PS2_STATUS equ 0x64
PS2_COMMAND equ 0x64


SCREEN_DESKTOP equ 0
SCREEN_NOTEPAD equ 1
SCREEN_TERMINAL equ 2
SCREEN_EXPLORER equ 3
SCREEN_VIEWER equ 4
SCREEN_PAINT equ 5
SCREEN_START_MENU equ 6
SCREEN_TASKMGR equ 7


section .data

align 4
current_screen dd 0
last_scancode db 0
ctrl_pressed db 0
shift_pressed db 0
wallpaper_enabled db 0
viewing_screenshot db 0
saved_screen_state db 0

term_x dd 0
term_y dd 0
term_color db 0x0A

mouse_x dd 160
mouse_y dd 100
mouse_buttons db 0
mouse_cycle db 0
mouse_packet times 3 db 0

clipboard_size dd 0
clipboard_buffer times CLIPBOARD_SIZE db 0

notepad_text_pos dd 0
notepad_cursor_x dd 0
notepad_cursor_y dd 0
notepad_has_selection db 0
notepad_selection_start dd 0
notepad_selection_end dd 0
notepad_text_buffer times TEXT_BUFFER_SIZE db 0

terminal_cmd_pos dd 0
terminal_has_selection db 0
terminal_selection_start dd 0
terminal_selection_end dd 0
terminal_cmd_buffer times TERM_BUFFER_SIZE db 0

explorer_selected dd 0
explorer_mode db 0
explorer_viewing_file dd 0
explorer_editing db 0
explorer_input_pos dd 0
explorer_input_buffer times 128 db 0

screenshot_counter dd 0
screenshot_name times 12 db 0

fs_file_count dd 0

package_count dd 0
paint_current_color db 0x0C
paint_cursor_x dd 160
paint_cursor_y dd 100

main_loop_delay dd 1000
power_mode db 0

start_menu_open db 0
start_menu_selected dd 0

module_count dd 0
heap_pointer dd 0x80000
system_ticks dd 0
api_initialized db 0

taskmgr_auto_refresh db 1
taskmgr_refresh_counter dd 0

section .text


_start:
    
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    
    call init_video
    call init_system
    call setup_idt
    call init_filesystem
    call init_clipboard
    call init_mouse
    call init_package_system
    call init_module_system
    call init_gatito_api

    
    sti

    
    call setup_gui


main_loop:
    mov ecx, [main_loop_delay]
.delay:
    nop
    loop .delay

    call update_gui
    call update_mouse_cursor
    hlt
    jmp main_loop


init_video:
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    xor al, al
    cld
    rep stosb
    ret

init_system:
    mov dword [current_screen], SCREEN_DESKTOP
    mov byte [ctrl_pressed], 0
    mov byte [shift_pressed], 0
    mov dword [mouse_x], 160
    mov dword [mouse_y], 100
    mov byte [mouse_buttons], 0
    mov byte [mouse_cycle], 0
    mov dword [screenshot_counter], 0
    mov byte [viewing_screenshot], 0
    mov byte [wallpaper_enabled], 0
    mov byte [saved_screen_state], SCREEN_DESKTOP
    mov dword [main_loop_delay], 1000
    mov byte [power_mode], 0
    mov byte [start_menu_open], 0
    mov dword [start_menu_selected], 0
    ret

init_clipboard:
    mov dword [clipboard_size], 0
    mov edi, clipboard_buffer
    mov ecx, CLIPBOARD_SIZE
    xor al, al
    rep stosb
    ret


init_package_system:
    pushad

    
    mov dword [package_count], 0

    
    mov edi, PACKAGE_BASE
    mov ecx, MAX_PACKAGES * 32
    xor al, al
    rep stosb

    
    call register_paint_package

    
    call register_network_package

    popad
    ret


init_module_system:
    pushad

    mov dword [module_count], 0

    mov edi, MODULE_BASE
    mov ecx, MAX_MODULES * 32
    xor al, al
    rep stosb

    
    call register_viewer_module

    
    call register_taskmgr_module

    popad
    ret

register_viewer_module:
    pushad

    mov edi, MODULE_BASE

    
    mov byte [edi], 'V'
    mov byte [edi+1], 'I'
    mov byte [edi+2], 'E'
    mov byte [edi+3], 'W'
    mov byte [edi+4], 'E'
    mov byte [edi+5], 'R'
    mov byte [edi+6], 0

    
    mov byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG

    
    mov dword [edi + MODULE_NAME_LEN + 1], handle_viewer_module

    inc dword [module_count]

    popad
    ret

register_taskmgr_module:
    pushad

    mov edi, MODULE_BASE
    add edi, 32

    
    mov byte [edi], 'T'
    mov byte [edi+1], 'A'
    mov byte [edi+2], 'S'
    mov byte [edi+3], 'K'
    mov byte [edi+4], 'M'
    mov byte [edi+5], 'G'
    mov byte [edi+6], 'R'
    mov byte [edi+7], 0

    
    mov byte [edi + MODULE_NAME_LEN], 0

    
    mov dword [edi + MODULE_NAME_LEN + 1], handle_taskmgr_module

    inc dword [module_count]

    popad
    ret

load_module:
    
    pushad

    mov edi, MODULE_BASE
    mov ebx, [module_count]

.find_loop:
    cmp ebx, 0
    je .not_found

    push ebx
    push edi
    push esi
    push ecx

    call compare_strings_exact

    pop ecx
    pop esi
    pop edi

    cmp eax, 0
    je .found

    pop ebx
    add edi, 32
    dec ebx
    jmp .find_loop

.found:
    pop ebx

    
    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    je .already_loaded

    
    mov byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG

    mov esi, str_module_loaded
    jmp .show_msg

.already_loaded:
    mov esi, str_module_already_loaded
    jmp .show_msg

.not_found:
    mov esi, str_module_not_found

.show_msg:
    push esi
    call show_notification
    pop esi
    call print_notification
    call hide_notification_delayed

    popad
    ret

unload_module:
    
    pushad

    mov edi, MODULE_BASE
    mov ebx, [module_count]

.find_loop:
    cmp ebx, 0
    je .not_found

    push ebx
    push edi
    push esi
    push ecx

    call compare_strings_exact

    pop ecx
    pop esi
    pop edi

    cmp eax, 0
    je .found

    pop ebx
    add edi, 32
    dec ebx
    jmp .find_loop

.found:
    pop ebx

    
    mov byte [edi + MODULE_NAME_LEN], 0

    mov esi, str_module_unloaded
    jmp .show_msg

.not_found:
    mov esi, str_module_not_found

.show_msg:
    push esi
    call show_notification
    pop esi
    call print_notification
    call hide_notification_delayed

    popad
    ret

check_module_loaded:
    
    
    pushad

    mov edi, MODULE_BASE
    mov ebx, [module_count]

.check_loop:
    cmp ebx, 0
    je .not_found

    push ebx
    push edi
    push esi
    push ecx

    call compare_strings_exact

    pop ecx
    pop esi
    pop edi

    cmp eax, 0
    je .found

    pop ebx
    add edi, 32
    dec ebx
    jmp .check_loop

.found:
    pop ebx
    mov al, [edi + MODULE_NAME_LEN]
    mov [esp + 28], al
    popad
    ret

.not_found:
    xor al, al
    mov [esp + 28], al
    popad
    ret


init_gatito_api:
    pushad
    
    mov byte [api_initialized], 1
    popad
    ret


gatito_print_string:
    
    call print_term_string
    ret

gatito_print_char:
    
    call print_term_char
    ret

gatito_clear_screen:
    
    call clear_screen_color
    ret

gatito_draw_pixel:
    
    call draw_pixel
    ret

gatito_draw_rect:
    
    call draw_filled_rect
    ret

gatito_get_key:
    
    mov al, [last_scancode]
    mov byte [last_scancode], 0
    ret

gatito_get_mouse:
    
    mov ebx, [mouse_x]
    mov ecx, [mouse_y]
    mov al, [mouse_buttons]
    ret

gatito_allocate_mem:
    
    
    mov eax, [heap_pointer]
    add [heap_pointer], ecx
    ret

gatito_file_open:
    
    
    push ebx
    xor ebx, ebx
.search:
    cmp ebx, [fs_file_count]
    jge .not_found

    push ebx
    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE

    push esi
    mov edi, esi
    mov esi, eax
    mov ecx, FS_FILENAME_LEN
    call compare_strings_exact
    pop esi

    pop ebx

    cmp eax, 0
    je .found

    inc ebx
    jmp .search

.found:
    mov eax, ebx
    pop ebx
    ret

.not_found:
    mov eax, -1
    pop ebx
    ret

gatito_file_read:
    
    
    push eax
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    add eax, FS_FILENAME_LEN
    mov esi, eax
    mov ecx, FS_CONTENT_LEN
    rep movsb
    pop eax
    mov ecx, FS_CONTENT_LEN
    ret

gatito_get_time:
    
    mov eax, [system_ticks]
    ret

gatito_sleep:
    
    push ecx
    imul ecx, 1000
.loop:
    nop
    loop .loop
    pop ecx
    ret

gatito_notify:
    
    call show_notification
    call print_notification
    call hide_notification_delayed
    ret


handle_viewer_module:
    
    call setup_viewer
    ret


handle_taskmgr_module:
    pushad

    
    mov esi, module_taskmgr_name
    mov ecx, 7
    call check_module_loaded
    cmp al, 0
    je .not_loaded

    call setup_task_manager
    jmp .done

.not_loaded:
    call show_notification
    mov esi, str_taskmgr_not_loaded
    call print_notification
    call hide_notification_delayed

.done:
    popad
    ret

setup_task_manager:
    pushad

    mov al, 0x00
    call clear_screen_color

    
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, 0x09
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 1
    mov dword [term_y], 0
    mov esi, str_taskmgr_title
    call print_term_string

    
    mov byte [term_color], 0x0A
    mov dword [term_x], 1
    mov dword [term_y], 3
    mov esi, str_taskmgr_cpu
    call print_term_string

    
    mov ecx, 0x198
    rdmsr
    shr eax, 8
    and eax, 0xFF
    imul eax, 100

    
    push eax

    mov ebx, 1000
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 100
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov al, dl
    add al, '0'
    call print_term_char

    pop eax

    mov esi, str_taskmgr_mhz
    call print_term_string

    
    mov dword [term_x], 1
    mov dword [term_y], 5
    mov esi, str_taskmgr_memory
    call print_term_string

    
    

    
    rdtsc
    mov ebx, eax

    
    mov eax, kernel_end
    sub eax, 0x10000

    
    push ecx
    mov ecx, 0x90000
    sub ecx, esp
    add eax, ecx
    pop ecx

    
    mov edx, [heap_pointer]
    sub edx, 0x80000
    add eax, edx

    
    mov edx, ebx
    and edx, 0x7FFF      
    add eax, edx

    
    push eax
    mov eax, [fs_file_count]
    imul eax, FS_ENTRY_SIZE
    mov edx, eax
    pop eax
    add eax, edx

    
    mov edx, 0
    cmp dword [notepad_text_pos], 0
    je .skip_notepad_buf
    add edx, TEXT_BUFFER_SIZE
.skip_notepad_buf:

    cmp dword [terminal_cmd_pos], 0
    je .skip_term_buf
    add edx, TERM_BUFFER_SIZE
.skip_term_buf:

    cmp dword [clipboard_size], 0
    je .skip_clip_buf
    add edx, CLIPBOARD_SIZE
.skip_clip_buf:

    add eax, edx

    
    push eax
    mov eax, [screenshot_counter]
    imul eax, SCREEN_SIZE
    mov edx, eax
    pop eax
    add eax, edx

    
    mov edi, PACKAGE_BASE
    mov ecx, [package_count]
    xor edx, edx
.count_packages:
    cmp ecx, 0
    je .packages_done
    cmp byte [edi + PKG_NAME_LEN], PKG_INSTALLED_FLAG
    jne .skip_pkg
    add edx, 12288  
.skip_pkg:
    add edi, 32
    dec ecx
    jmp .count_packages
.packages_done:
    add eax, edx

    
    mov edi, MODULE_BASE
    mov ecx, [module_count]
    xor edx, edx
.count_modules_mem:
    cmp ecx, 0
    je .modules_done
    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    jne .skip_mod
    add edx, 8192  
.skip_mod:
    add edi, 32
    dec ecx
    jmp .count_modules_mem
.modules_done:
    add eax, edx

    
    add eax, SCREEN_SIZE

    
    add eax, 4096

    
    mov edx, [current_screen]
    cmp edx, SCREEN_DESKTOP
    je .add_desktop_mem
    cmp edx, SCREEN_PAINT
    je .add_paint_mem
    cmp edx, SCREEN_VIEWER
    je .add_viewer_mem
    jmp .screen_mem_done

.add_desktop_mem:
    add eax, 8192
    jmp .screen_mem_done

.add_paint_mem:
    add eax, 16384  
    jmp .screen_mem_done

.add_viewer_mem:
    add eax, 32768  

.screen_mem_done:

    
    cmp byte [start_menu_open], 1
    jne .no_start_menu
    add eax, 4096
.no_start_menu:

    
    cmp byte [wallpaper_enabled], 1
    jne .no_wallpaper
    add eax, SCREEN_SIZE
.no_wallpaper:

    
    add eax, 24576  

    
    push eax
    mov eax, [main_loop_delay]
    shr eax, 4
    mov edx, eax
    pop eax
    add eax, edx

    
    push eax

    cmp eax, 1073741824  
    jge .show_gb

    cmp eax, 1048576     
    jge .show_mb

    
    shr eax, 10
    call print_number_4digits
    mov esi, str_unit_kb
    call print_term_string
    jmp .mem_done

.show_mb:
    shr eax, 20
    call print_number_4digits
    mov esi, str_unit_mb
    call print_term_string
    jmp .mem_done

.show_gb:
    shr eax, 30
    call print_number_4digits
    mov esi, str_unit_gb
    call print_term_string

.mem_done:
    pop eax

    
    mov dword [term_x], 1
    mov dword [term_y], 7
    mov esi, str_taskmgr_processes
    call print_term_string

    
    xor eax, eax

    
    inc eax

    
    mov edx, [current_screen]
    cmp edx, SCREEN_DESKTOP
    je .add_desktop_proc
    cmp edx, SCREEN_NOTEPAD
    je .add_notepad_proc
    cmp edx, SCREEN_TERMINAL
    je .add_terminal_proc
    cmp edx, SCREEN_EXPLORER
    je .add_explorer_proc
    cmp edx, SCREEN_VIEWER
    je .add_viewer_proc
    cmp edx, SCREEN_PAINT
    je .add_paint_proc
    cmp edx, SCREEN_TASKMGR
    je .add_taskmgr_proc
    jmp .check_start_menu

.add_desktop_proc:
    inc eax  
    jmp .check_start_menu

.add_notepad_proc:
    inc eax  
    inc eax  
    jmp .check_start_menu

.add_terminal_proc:
    inc eax  
    inc eax  
    jmp .check_start_menu

.add_explorer_proc:
    inc eax  
    inc eax  
    jmp .check_start_menu

.add_viewer_proc:
    inc eax  
    inc eax  
    jmp .check_start_menu

.add_paint_proc:
    inc eax  
    inc eax  
    jmp .check_start_menu

.add_taskmgr_proc:
    inc eax  
    inc eax  

.check_start_menu:
    
    cmp byte [start_menu_open], 1
    jne .check_mouse
    inc eax  

.check_mouse:
    
    inc eax  

    
    inc eax  

    
    push eax
    mov edi, MODULE_BASE
    mov ecx, [module_count]
.count_module_procs:
    cmp ecx, 0
    je .modules_proc_done
    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    jne .skip_module_proc
    inc eax  
.skip_module_proc:
    add edi, 32
    dec ecx
    jmp .count_module_procs
.modules_proc_done:
    mov ebx, eax
    pop eax
    mov eax, ebx

    
    push eax
    mov edi, PACKAGE_BASE
    mov ecx, [package_count]
.count_pkg_procs:
    cmp ecx, 0
    je .pkgs_proc_done
    cmp byte [edi + PKG_NAME_LEN], PKG_INSTALLED_FLAG
    jne .skip_pkg_proc
    inc eax  
.skip_pkg_proc:
    add edi, 32
    dec ecx
    jmp .count_pkg_procs
.pkgs_proc_done:
    mov ebx, eax
    pop eax
    mov eax, ebx

    
    cmp eax, 9
    jle .single_digit

    
    push eax
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char
    mov al, dl
    add al, '0'
    call print_term_char
    pop eax
    jmp .proc_done

.single_digit:
    add al, '0'
    call print_term_char

.proc_done:

    
    mov dword [term_x], 1
    mov dword [term_y], 11
    mov esi, str_taskmgr_packages
    call print_term_string

    mov eax, [package_count]
    add al, '0'
    call print_term_char

    
    mov dword [term_x], 1
    mov dword [term_y], 13
    mov esi, str_taskmgr_modules
    call print_term_string

    xor eax, eax
    mov edi, MODULE_BASE
    mov ecx, [module_count]
.count_modules:
    cmp ecx, 0
    je .show_modules
    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    jne .next_mod
    inc eax
.next_mod:
    add edi, 32
    dec ecx
    jmp .count_modules
.show_modules:
    add al, '0'
    call print_term_char

    
    mov byte [term_color], 0x07
    mov dword [term_x], 1
    mov dword [term_y], 24
    mov esi, str_taskmgr_hint
    call print_term_string

    
    mov dword [term_x], 1
    mov dword [term_y], 23
    mov esi, str_auto_refresh_status
    call print_term_string

    cmp byte [taskmgr_auto_refresh], 1
    je .auto_on
    mov esi, str_auto_off
    jmp .show_auto_status
.auto_on:
    mov esi, str_auto_on
.show_auto_status:
    call print_term_string

    popad
    ret


print_number_4digits:
    push eax
    push ebx
    push edx

    
    mov ebx, 1000
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    
    mov eax, edx
    mov ebx, 100
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    
    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    
    mov al, dl
    add al, '0'
    call print_term_char

    pop edx
    pop ebx
    pop eax
    ret
.count_proc:
    cmp byte [start_menu_open], 1
    jne .show_proc_count
    inc eax
.show_proc_count:
    add al, '0'
    call print_term_char

    
    mov dword [term_x], 1
    mov dword [term_y], 9
    mov esi, str_taskmgr_power
    call print_term_string

    mov al, [power_mode]
    cmp al, 0
    je .power_normal
    cmp al, 1
    je .power_gelado
    mov esi, str_power_mode_desempenho
    jmp .show_power
.power_normal:
    mov esi, str_power_mode_normal
    jmp .show_power
.power_gelado:
    mov esi, str_power_mode_gelado
.show_power:
    call print_term_string

    
    mov dword [term_x], 1
    mov dword [term_y], 11
    mov esi, str_taskmgr_packages
    call print_term_string

    mov eax, [package_count]
    add al, '0'
    call print_term_char

    
    mov dword [term_x], 1
    mov dword [term_y], 13
    mov esi, str_taskmgr_modules
    call print_term_string

    
    xor eax, eax
    mov edi, MODULE_BASE
    mov ecx, [module_count]
.count_modules:
    cmp ecx, 0
    je .show_modules
    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    jne .next_mod
    inc eax
.next_mod:
    add edi, 32
    dec ecx
    jmp .count_modules
.show_modules:
    add al, '0'
    call print_term_char

    
    mov byte [term_color], 0x07
    mov dword [term_x], 1
    mov dword [term_y], 24
    mov esi, str_taskmgr_hint
    call print_term_string

    popad
    ret

handle_taskmgr_input:
    pushad

    
    inc dword [taskmgr_refresh_counter]

    
    cmp dword [taskmgr_refresh_counter], 50000
    jl .check_keys

    
    mov dword [taskmgr_refresh_counter], 0

    cmp byte [taskmgr_auto_refresh], 1
    jne .check_keys

    call setup_task_manager
    jmp .done

.check_keys:
    mov al, [last_scancode]
    cmp al, 0
    je .done

    mov byte [last_scancode], 0

    
    cmp al, 0x13
    je .refresh

    
    cmp al, 0x1E
    je .toggle_auto

    jmp .done

.refresh:
    mov dword [taskmgr_refresh_counter], 0
    call setup_task_manager
    jmp .done

.toggle_auto:
    xor byte [taskmgr_auto_refresh], 1
    mov dword [taskmgr_refresh_counter], 0
    call setup_task_manager
    jmp .done

.done:
    popad
    ret

register_paint_package:
    pushad

    mov edi, PACKAGE_BASE

    
    mov byte [edi], 'P'
    mov byte [edi+1], 'A'
    mov byte [edi+2], 'I'
    mov byte [edi+3], 'N'
    mov byte [edi+4], 'T'
    mov byte [edi+5], 0

    
    mov byte [edi + PKG_NAME_LEN], 0

    
    inc dword [package_count]

    popad
    ret

register_network_package:
    pushad

    mov edi, PACKAGE_BASE
    add edi, 32  

    
    mov byte [edi], 'N'
    mov byte [edi+1], 'E'
    mov byte [edi+2], 'T'
    mov byte [edi+3], 'W'
    mov byte [edi+4], 'O'
    mov byte [edi+5], 'R'
    mov byte [edi+6], 'K'
    mov byte [edi+7], 0

    
    mov byte [edi + PKG_NAME_LEN], 0

    
    inc dword [package_count]

    popad
    ret

check_package_installed:
    
    
    pushad

    mov edi, PACKAGE_BASE
    mov ebx, [package_count]

.check_loop:
    cmp ebx, 0
    je .not_found

    push ebx
    push edi
    push esi
    push ecx

    call compare_strings_exact

    pop ecx
    pop esi
    pop edi

    cmp eax, 0
    je .found

    pop ebx
    add edi, 32
    dec ebx
    jmp .check_loop

.found:
    pop ebx
    mov al, [edi + PKG_NAME_LEN]
    mov [esp + 28], al
    popad
    ret

.not_found:
    xor al, al
    mov [esp + 28], al
    popad
    ret

install_package:
    
    pushad

    mov edi, PACKAGE_BASE
    mov ebx, [package_count]

.find_loop:
    cmp ebx, 0
    je .not_found

    push ebx
    push edi
    push esi
    push ecx

    call compare_strings_exact

    pop ecx
    pop esi
    pop edi

    cmp eax, 0
    je .found

    pop ebx
    add edi, 32
    dec ebx
    jmp .find_loop

.found:
    pop ebx

    
    cmp byte [edi + PKG_NAME_LEN], PKG_INSTALLED_FLAG
    je .already_installed

    
    mov byte [edi + PKG_NAME_LEN], PKG_INSTALLED_FLAG

    
    push edi
    mov al, [edi]
    cmp al, 'P'
    je .is_paint
    cmp al, 'N'
    je .is_network
    pop edi
    jmp .installed_ok

.is_paint:
    pop edi
    call create_paint_file
    jmp .installed_ok

.is_network:
    pop edi
    call create_network_file
    jmp .installed_ok

.installed_ok:
    mov esi, str_pkg_installed
    jmp .show_msg

.already_installed:
    mov esi, str_pkg_already
    jmp .show_msg

.not_found:
    mov esi, str_pkg_not_available

.show_msg:
    push esi
    call show_notification
    pop esi
    call print_notification
    call hide_notification_delayed

    popad
    ret

create_paint_file:
    pushad

    
    mov ebx, 0
.check_exists:
    cmp ebx, [fs_file_count]
    jge .create

    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE

    mov esi, eax
    mov edi, fname_paint
    mov ecx, 9
    push ebx
    call compare_strings_exact
    pop ebx

    cmp eax, 0
    je .already_exists

    inc ebx
    jmp .check_exists

.create:
    cmp dword [fs_file_count], FS_MAX_FILES
    jge .done

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_paint
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_paint
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

.already_exists:
.done:
    popad
    ret

create_network_file:
    pushad

    
    mov ebx, 0
.check_exists:
    cmp ebx, [fs_file_count]
    jge .create

    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE

    mov esi, eax
    mov edi, fname_network
    mov ecx, 11
    push ebx
    call compare_strings_exact
    pop ebx

    cmp eax, 0
    je .already_exists

    inc ebx
    jmp .check_exists

.create:
    cmp dword [fs_file_count], FS_MAX_FILES
    jge .done

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_network
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_network
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

.already_exists:
.done:
    popad
    ret


clear_screen:
    pushad
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    xor al, al
    cld
    rep stosb
    popad
    ret

clear_screen_color:
    pushad
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep stosb
    popad
    ret

draw_pixel:
    pushad

    cmp ebx, SCREEN_WIDTH
    jae .done
    cmp ecx, SCREEN_HEIGHT
    jae .done

    mov eax, ecx
    mov edx, SCREEN_WIDTH
    mul edx
    add eax, ebx

    cmp eax, SCREEN_SIZE
    jae .done

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

    mov [.color], al
    mov [.x], ebx
    mov [.y], ecx
    mov [.width], edx
    mov [.height], esi

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

.color dd 0
.x dd 0
.y dd 0
.width dd 0
.height dd 0


get_font_data:
    pushad

    cmp al, 32
    jge .valid
    mov al, 32
.valid:
    cmp al, 90
    jle .calc

    cmp al, 97
    jl .use_space
    cmp al, 122
    jg .use_space
    sub al, 32
    jmp .calc

.use_space:
    mov al, 32

.calc:
    sub al, 32
    movzx eax, al
    shl eax, 3
    add eax, font_data

    mov [esp + 28], eax
    popad
    ret

align 4
font_data:
    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    db 0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x00
    db 0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00
    db 0x66,0xFF,0x66,0x66,0xFF,0x66,0x66,0x00
    db 0x18,0x3E,0x60,0x3C,0x06,0x7C,0x18,0x00
    db 0x62,0x66,0x0C,0x18,0x30,0x66,0x46,0x00
    db 0x3C,0x66,0x3C,0x38,0x67,0x66,0x3F,0x00
    db 0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00
    db 0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00
    db 0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00
    db 0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00
    db 0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00
    db 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30
    db 0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00
    db 0x00,0x03,0x06,0x0C,0x18,0x30,0x60,0x00
    db 0x3C,0x66,0x6E,0x76,0x66,0x66,0x3C,0x00
    db 0x18,0x38,0x18,0x18,0x18,0x18,0x7E,0x00
    db 0x3C,0x66,0x06,0x0C,0x18,0x30,0x7E,0x00
    db 0x3C,0x66,0x06,0x1C,0x06,0x66,0x3C,0x00
    db 0x0C,0x1C,0x3C,0x6C,0x7E,0x0C,0x0C,0x00
    db 0x7E,0x60,0x7C,0x06,0x06,0x66,0x3C,0x00
    db 0x1C,0x30,0x60,0x7C,0x66,0x66,0x3C,0x00
    db 0x7E,0x06,0x0C,0x18,0x30,0x30,0x30,0x00
    db 0x3C,0x66,0x66,0x3C,0x66,0x66,0x3C,0x00
    db 0x3C,0x66,0x66,0x3E,0x06,0x0C,0x38,0x00
    db 0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00
    db 0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30
    db 0x0C,0x18,0x30,0x60,0x30,0x18,0x0C,0x00
    db 0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00
    db 0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x00
    db 0x3C,0x66,0x06,0x0C,0x18,0x00,0x18,0x00
    db 0x3C,0x66,0x6E,0x6A,0x6E,0x60,0x3C,0x00
    db 0x18,0x3C,0x66,0x66,0x7E,0x66,0x66,0x00
    db 0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00
    db 0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00
    db 0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00
    db 0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00
    db 0x7E,0x60,0x60,0x7C,0x60,0x60,0x60,0x00
    db 0x3C,0x66,0x60,0x6E,0x66,0x66,0x3C,0x00
    db 0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00
    db 0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00
    db 0x1E,0x0C,0x0C,0x0C,0x0C,0x6C,0x38,0x00
    db 0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00
    db 0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00
    db 0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00
    db 0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00
    db 0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
    db 0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00
    db 0x3C,0x66,0x66,0x66,0x6A,0x6C,0x36,0x00
    db 0x7C,0x66,0x66,0x7C,0x78,0x6C,0x66,0x00
    db 0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00
    db 0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00
    db 0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00
    db 0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00
    db 0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00
    db 0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00
    db 0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00
    db 0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00

scancode_to_char:
    push ebx
    mov bl, [shift_pressed]

    cmp al, 0x1E
    jne .not_a
    mov al, 'A'
    jmp .done
.not_a:
    cmp al, 0x30
    jne .not_b
    mov al, 'B'
    jmp .done
.not_b:
    cmp al, 0x2E
    jne .not_c
    mov al, 'C'
    jmp .done
.not_c:
    cmp al, 0x20
    jne .not_d
    mov al, 'D'
    jmp .done
.not_d:
    cmp al, 0x12
    jne .not_e
    mov al, 'E'
    jmp .done
.not_e:
    cmp al, 0x21
    jne .not_f
    mov al, 'F'
    jmp .done
.not_f:
    cmp al, 0x22
    jne .not_g
    mov al, 'G'
    jmp .done
.not_g:
    cmp al, 0x23
    jne .not_h
    mov al, 'H'
    jmp .done
.not_h:
    cmp al, 0x17
    jne .not_i
    mov al, 'I'
    jmp .done
.not_i:
    cmp al, 0x24
    jne .not_j
    mov al, 'J'
    jmp .done
.not_j:
    cmp al, 0x25
    jne .not_k
    mov al, 'K'
    jmp .done
.not_k:
    cmp al, 0x26
    jne .not_l
    mov al, 'L'
    jmp .done
.not_l:
    cmp al, 0x32
    jne .not_m
    mov al, 'M'
    jmp .done
.not_m:
    cmp al, 0x31
    jne .not_n
    mov al, 'N'
    jmp .done
.not_n:
    cmp al, 0x18
    jne .not_o
    mov al, 'O'
    jmp .done
.not_o:
    cmp al, 0x19
    jne .not_p
    mov al, 'P'
    jmp .done
.not_p:
    cmp al, 0x10
    jne .not_q
    mov al, 'Q'
    jmp .done
.not_q:
    cmp al, 0x13
    jne .not_r
    mov al, 'R'
    jmp .done
.not_r:
    cmp al, 0x1F
    jne .not_s
    mov al, 'S'
    jmp .done
.not_s:
    cmp al, 0x14
    jne .not_t
    mov al, 'T'
    jmp .done
.not_t:
    cmp al, 0x16
    jne .not_u
    mov al, 'U'
    jmp .done
.not_u:
    cmp al, 0x2F
    jne .not_v
    mov al, 'V'
    jmp .done
.not_v:
    cmp al, 0x11
    jne .not_w
    mov al, 'W'
    jmp .done
.not_w:
    cmp al, 0x2D
    jne .not_x
    mov al, 'X'
    jmp .done
.not_x:
    cmp al, 0x15
    jne .not_y
    mov al, 'Y'
    jmp .done
.not_y:
    cmp al, 0x2C
    jne .not_z
    mov al, 'Z'
    jmp .done
.not_z:
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
    cmp al, 0x0B
    jne .not_0
    mov al, '0'
    jmp .done
.not_0:
    xor al, al

.done:
    pop ebx
    ret

print_term_char:
    pushad

    cmp al, 10
    je .newline

    cmp al, 32
    jl .done
    cmp al, 90
    jg .done

    cmp dword [term_x], 40
    jge .done
    cmp dword [term_y], 25
    jge .done

    mov eax, [term_y]
    shl eax, 3
    mov ebx, SCREEN_WIDTH
    mul ebx
    mov edi, eax

    mov eax, [term_x]
    shl eax, 3
    add edi, eax
    add edi, VGA_MEMORY

    mov eax, [esp + 28]
    call get_font_data
    mov esi, eax

    mov edx, 8
.char_loop_y:
    push edi
    lodsb
    mov ecx, 8
    mov ah, al

.char_loop_x:
    shl ah, 1
    jnc .pixel_off

    mov al, [term_color]
    mov [edi], al

.pixel_off:
    inc edi
    loop .char_loop_x

    pop edi
    add edi, SCREEN_WIDTH
    dec edx
    jnz .char_loop_y

    inc dword [term_x]
    jmp .done

.newline:
    mov dword [term_x], 0
    inc dword [term_y]

.done:
    popad
    ret

print_term_string:
    pushad

.loop:
    lodsb
    test al, al
    jz .done

    call print_term_char
    jmp .loop

.done:
    popad
    ret

setup_gui:
    pushad

    cmp byte [wallpaper_enabled], 1
    je .draw_wallpaper

    mov al, 0x0E
    call clear_screen_color
    jmp .draw_taskbar

.draw_wallpaper:
    call load_image_from_memory
    cmp eax, 0
    je .no_wallpaper

    call setup_vga_palette
    call display_loaded_image
    jmp .draw_taskbar

.no_wallpaper:
    mov byte [wallpaper_enabled], 0
    mov al, 0x0E
    call clear_screen_color

.draw_taskbar:
    mov ebx, 0
    mov ecx, 180
    mov edx, 320
    mov esi, 20
    mov al, 0x09
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 180
    mov edx, 320
    mov esi, 1
    mov al, 0x0B
    call draw_filled_rect

    mov ebx, 10
    mov ecx, 184
    mov edx, 60
    mov esi, 12
    mov al, 0x01
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 2
    mov dword [term_y], 23
    mov esi, str_btn_notepad
    call print_term_string

    mov ebx, 80
    mov ecx, 184
    mov edx, 60
    mov esi, 12
    mov al, 0x01
    call draw_filled_rect

    mov dword [term_x], 11
    mov dword [term_y], 23
    mov esi, str_btn_terminal
    call print_term_string

    mov ebx, 150
    mov ecx, 184
    mov edx, 60
    mov esi, 12
    mov al, 0x01
    call draw_filled_rect

    mov dword [term_x], 20
    mov dword [term_y], 23
    mov esi, str_btn_explorer
    call print_term_string

    mov ebx, 220
    mov ecx, 184
    mov edx, 60
    mov esi, 12
    mov al, 0x01
    call draw_filled_rect

    mov dword [term_x], 28
    mov dword [term_y], 23
    mov esi, str_btn_viewer
    call print_term_string

    mov byte [term_color], 0x0F
    mov dword [term_x], 1
    mov dword [term_y], 1
    mov esi, str_f12_hint
    call print_term_string

    popad
    ret

update_gui:
    pushad

    mov eax, [current_screen]
    cmp eax, SCREEN_DESKTOP
    jne .done

    mov al, [last_scancode]
    test al, al
    jz .done

    cmp al, 0x31
    je .open_notepad
    cmp al, 0x14
    je .open_terminal
    cmp al, 0x12
    je .open_explorer
    cmp al, 0x2F
    je .open_viewer
    jmp .done

.open_notepad:
    mov byte [last_scancode], 0
    mov dword [current_screen], SCREEN_NOTEPAD
    call setup_notepad
    jmp .done

.open_terminal:
    mov byte [last_scancode], 0
    mov dword [current_screen], SCREEN_TERMINAL
    call setup_terminal
    jmp .done

.open_explorer:
    mov byte [last_scancode], 0
    mov dword [current_screen], SCREEN_EXPLORER
    call setup_explorer
    jmp .done

.open_viewer:
    mov byte [last_scancode], 0
    mov byte [viewing_screenshot], 0
    mov dword [current_screen], SCREEN_VIEWER
    call setup_viewer
    jmp .done

.done:
    popad
    ret

setup_notepad:
    pushad

    mov al, 0x0F
    call clear_screen_color

    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 10
    mov al, 0x09
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 1
    mov dword [term_y], 0
    mov esi, str_notepad_title
    call print_term_string

    mov dword [notepad_text_pos], 0
    mov dword [notepad_cursor_x], 0
    mov dword [notepad_cursor_y], 2
    mov byte [notepad_has_selection], 0

    mov edi, notepad_text_buffer
    mov ecx, TEXT_BUFFER_SIZE
    xor al, al
    rep stosb

    popad
    ret

handle_notepad_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    cmp al, 0x1C
    je .handle_enter

    cmp al, 0x0E
    je .handle_backspace

    cmp al, 0x39
    je .handle_space

    cmp al, 0x48
    je .handle_up
    cmp al, 0x50
    je .handle_down
    cmp al, 0x4B
    je .handle_left
    cmp al, 0x4D
    je .handle_right

    call scancode_to_char
    test al, al
    jz .done

    cmp dword [notepad_text_pos], TEXT_BUFFER_SIZE - 1
    jge .done

    mov ebx, [notepad_text_pos]
    mov [notepad_text_buffer + ebx], al
    inc dword [notepad_text_pos]

    push eax
    mov byte [term_color], 0x00
    mov eax, [notepad_cursor_x]
    mov [term_x], eax
    mov eax, [notepad_cursor_y]
    mov [term_y], eax
    pop eax
    call print_term_char

    inc dword [notepad_cursor_x]
    cmp dword [notepad_cursor_x], 40
    jl .done
    mov dword [notepad_cursor_x], 0
    inc dword [notepad_cursor_y]

    jmp .done

.handle_enter:
    mov dword [notepad_cursor_x], 0
    inc dword [notepad_cursor_y]
    cmp dword [notepad_cursor_y], 25
    jl .enter_ok
    mov dword [notepad_cursor_y], 24
.enter_ok:
    jmp .done

.handle_backspace:
    cmp dword [notepad_text_pos], 0
    je .done

    dec dword [notepad_text_pos]

    cmp dword [notepad_cursor_x], 0
    jne .back_same_line

    cmp dword [notepad_cursor_y], 2
    jle .done

    dec dword [notepad_cursor_y]
    mov dword [notepad_cursor_x], 39
    jmp .clear_char

.back_same_line:
    dec dword [notepad_cursor_x]

.clear_char:
    mov eax, [notepad_cursor_y]
    shl eax, 3
    mov ebx, SCREEN_WIDTH
    mul ebx
    mov edi, eax

    mov eax, [notepad_cursor_x]
    shl eax, 3
    add edi, eax
    add edi, VGA_MEMORY

    mov edx, 8
.clear_loop_y:
    push edi
    mov ecx, 8
.clear_loop_x:
    mov byte [edi], 0x0F
    inc edi
    loop .clear_loop_x
    pop edi
    add edi, SCREEN_WIDTH
    dec edx
    jnz .clear_loop_y

    jmp .done

.handle_space:
    mov al, ' '
    cmp dword [notepad_text_pos], TEXT_BUFFER_SIZE - 1
    jge .done

    mov ebx, [notepad_text_pos]
    mov [notepad_text_buffer + ebx], al
    inc dword [notepad_text_pos]

    inc dword [notepad_cursor_x]
    cmp dword [notepad_cursor_x], 40
    jl .done
    mov dword [notepad_cursor_x], 0
    inc dword [notepad_cursor_y]

    jmp .done

.handle_up:
    cmp dword [notepad_cursor_y], 2
    jle .done
    dec dword [notepad_cursor_y]
    jmp .done

.handle_down:
    cmp dword [notepad_cursor_y], 24
    jge .done
    inc dword [notepad_cursor_y]
    jmp .done

.handle_left:
    cmp dword [notepad_cursor_x], 0
    jle .done
    dec dword [notepad_cursor_x]
    jmp .done

.handle_right:
    cmp dword [notepad_cursor_x], 39
    jge .done
    inc dword [notepad_cursor_x]
    jmp .done

.done:
    popad
    ret

redraw_notepad:
    pushad

    call setup_notepad

    mov byte [term_color], 0x00
    mov dword [term_x], 0
    mov dword [term_y], 2

    mov esi, notepad_text_buffer
    mov ecx, [notepad_text_pos]

.redraw_loop:
    cmp ecx, 0
    je .redraw_done

    lodsb
    call print_term_char
    dec ecx
    jmp .redraw_loop

.redraw_done:
    popad
    ret

setup_terminal:
    pushad

    mov al, 0x00
    call clear_screen_color

    mov byte [term_color], 0x0A
    mov dword [term_x], 0
    mov dword [term_y], 0
    mov esi, str_terminal_banner
    call print_term_string

    mov dword [term_x], 0
    mov dword [term_y], 2
    call show_terminal_prompt

    mov dword [terminal_cmd_pos], 0
    mov byte [terminal_has_selection], 0

    mov edi, terminal_cmd_buffer
    mov ecx, TERM_BUFFER_SIZE
    xor al, al
    rep stosb

    popad
    ret

show_terminal_prompt:
    push esi
    mov esi, str_terminal_prompt
    call print_term_string
    pop esi
    ret

handle_terminal_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    cmp al, 0x1C
    je .handle_enter

    cmp al, 0x0E
    je .handle_backspace

    cmp al, 0x39
    je .handle_space

    call scancode_to_char
    test al, al
    jz .done

    cmp dword [terminal_cmd_pos], TERM_BUFFER_SIZE - 1
    jge .done

    mov ebx, [terminal_cmd_pos]
    mov [terminal_cmd_buffer + ebx], al
    inc dword [terminal_cmd_pos]

    call print_term_char
    jmp .done

.handle_enter:
    mov al, 10
    call print_term_char

    call execute_terminal_command

    mov al, 10
    call print_term_char
    call show_terminal_prompt

    mov dword [terminal_cmd_pos], 0
    mov edi, terminal_cmd_buffer
    mov ecx, TERM_BUFFER_SIZE
    xor al, al
    rep stosb

    jmp .done

.handle_backspace:
    cmp dword [terminal_cmd_pos], 0
    je .done

    dec dword [terminal_cmd_pos]
    cmp dword [term_x], 2
    jle .done

    dec dword [term_x]

    mov eax, [term_y]
    shl eax, 3
    mov ebx, SCREEN_WIDTH
    mul ebx
    mov edi, eax

    mov eax, [term_x]
    shl eax, 3
    add edi, eax
    add edi, VGA_MEMORY

    mov edx, 8
.clear_y:
    push edi
    mov ecx, 8
.clear_x:
    mov byte [edi], 0x00
    inc edi
    loop .clear_x
    pop edi
    add edi, SCREEN_WIDTH
    dec edx
    jnz .clear_y

    jmp .done

.handle_space:
    mov al, ' '
    cmp dword [terminal_cmd_pos], TERM_BUFFER_SIZE - 1
    jge .done

    mov ebx, [terminal_cmd_pos]
    mov [terminal_cmd_buffer + ebx], al
    inc dword [terminal_cmd_pos]

    call print_term_char
    jmp .done

.done:
    popad
    ret

execute_terminal_command:
    pushad

    cmp dword [terminal_cmd_pos], 0
    je .done

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_dralar_install
    mov ecx, 15
    call compare_strings
    jz .exec_dralar_install

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_run
    mov ecx, 3
    call compare_strings
    jz .exec_run

    mov esi, terminal_cmd_buffer
    mov edi, cmd_help
    mov ecx, 4
    call compare_strings
    jz .exec_help

    mov esi, terminal_cmd_buffer
    mov edi, cmd_clear
    mov ecx, 5
    call compare_strings
    jz .exec_clear

    mov esi, terminal_cmd_buffer
    mov edi, cmd_info
    mov ecx, 4
    call compare_strings
    jz .exec_info

    mov esi, terminal_cmd_buffer
    mov edi, cmd_ls
    mov ecx, 2
    call compare_strings
    jz .exec_ls

    mov esi, terminal_cmd_buffer
    mov edi, cmd_echo
    mov ecx, 4
    call compare_strings
    jz .exec_echo

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_power
    mov ecx, 5
    call compare_strings
    jz .exec_power

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_module_load
    mov ecx, 11
    call compare_strings
    jz .exec_module_load

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_module_unload
    mov ecx, 13
    call compare_strings
    jz .exec_module_unload

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_module_list
    mov ecx, 11
    call compare_strings
    jz .exec_module_list

    
    mov esi, terminal_cmd_buffer
    mov edi, cmd_taskmgr
    mov ecx, 7
    call compare_strings
    jz .exec_taskmgr

    mov esi, str_cmd_unknown
    call print_term_string
    jmp .done

.exec_dralar_install:
    
    cmp dword [terminal_cmd_pos], 15
    jl .dralar_no_pkg

    mov esi, terminal_cmd_buffer
    add esi, 15

    
    mov edi, esi
    xor ecx, ecx
.count_pkg:
    mov al, [edi]
    test al, al
    jz .got_length
    cmp al, ' '
    je .got_length
    inc ecx
    inc edi
    cmp ecx, 10
    jl .count_pkg

.got_length:
    
    cmp ecx, 5
    jne .check_network
    mov edi, pkg_paint_name
    push ecx
    call compare_strings_exact
    pop ecx
    jz .install_paint_pkg

.check_network:
    
    mov esi, terminal_cmd_buffer
    add esi, 15
    cmp ecx, 7
    jne .pkg_not_avail
    mov edi, pkg_network_name
    call compare_strings_exact
    jz .install_network_pkg
    jmp .pkg_not_avail

.install_paint_pkg:
    mov esi, pkg_paint_name
    mov ecx, 5
    call install_package
    jmp .done

.install_network_pkg:
    mov esi, pkg_network_name
    mov ecx, 7
    call install_package
    jmp .done

.pkg_not_avail:
    mov esi, str_pkg_not_available
    call print_term_string
    jmp .done

.dralar_no_pkg:
    mov esi, str_dralar_usage
    call print_term_string
    jmp .done

.exec_run:
    
    cmp dword [terminal_cmd_pos], 4
    jl .run_no_app

    mov esi, terminal_cmd_buffer
    add esi, 4

    
    mov edi, esi
    xor ecx, ecx
.count_app:
    mov al, [edi]
    test al, al
    jz .got_app_len
    cmp al, ' '
    je .got_app_len
    inc ecx
    inc edi
    cmp ecx, 10
    jl .count_app

.got_app_len:
    
    cmp ecx, 5
    jne .check_network_run
    mov edi, pkg_paint_name
    push ecx
    call compare_strings_exact
    pop ecx
    jz .run_paint

.check_network_run:
    
    mov esi, terminal_cmd_buffer
    add esi, 4
    cmp ecx, 7
    jne .app_not_found
    mov edi, pkg_network_name
    call compare_strings_exact
    jz .run_network
    jmp .app_not_found

.run_paint:
    
    mov esi, pkg_paint_name
    mov ecx, 5
    call check_package_installed
    cmp al, 0
    je .paint_not_installed

    mov dword [current_screen], SCREEN_PAINT
    call setup_paint
    jmp .done

.run_network:
    
    mov esi, pkg_network_name
    mov ecx, 7
    call check_package_installed
    cmp al, 0
    je .network_not_installed

    mov esi, str_network_running
    call print_term_string
    jmp .done

.paint_not_installed:
    mov esi, str_paint_not_installed
    call print_term_string
    jmp .done

.network_not_installed:
    mov esi, str_network_not_installed
    call print_term_string
    jmp .done

.app_not_found:
    mov esi, str_app_not_found
    call print_term_string
    jmp .done

.run_no_app:
    mov esi, str_run_usage
    call print_term_string
    jmp .done

.exec_help:
    mov esi, str_help_title
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_dralar
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_run
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_clear
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_info
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_ls
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_echo
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_power
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_module
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_help_taskmgr
    call print_term_string
    jmp .done

.exec_clear:
    call setup_terminal
    jmp .done

.exec_info:
    mov esi, str_info_os
    call print_term_string
    mov al, 10
    call print_term_char

    mov esi, str_info_version
    call print_term_string
    jmp .done

.exec_ls:
    call list_files_terminal
    jmp .done

.exec_echo:
    cmp dword [terminal_cmd_pos], 5
    jle .done

    mov esi, terminal_cmd_buffer
    add esi, 5
    mov ecx, [terminal_cmd_pos]
    sub ecx, 5

.echo_loop:
    cmp ecx, 0
    je .done
    lodsb
    call print_term_char
    dec ecx
    jmp .echo_loop

.exec_power:
    
    cmp dword [terminal_cmd_pos], 6
    jl .power_usage

    mov esi, terminal_cmd_buffer
    add esi, 6

    
    mov edi, str_power_gelado
    mov ecx, 6
    call compare_strings
    jz .set_power_gelado

    
    mov esi, terminal_cmd_buffer
    add esi, 6
    mov edi, str_power_desempenho
    mov ecx, 10
    call compare_strings
    jz .set_power_desempenho

    
    mov esi, terminal_cmd_buffer
    add esi, 6
    mov edi, str_power_status
    mov ecx, 6
    call compare_strings
    jz .show_power_status

    mov esi, str_power_usage
    call print_term_string
    jmp .done

.set_power_gelado:
    mov byte [power_mode], 1
    call apply_power_gelado
    mov esi, str_power_gelado_activated
    call print_term_string
    jmp .done

.set_power_desempenho:
    mov byte [power_mode], 2
    call apply_power_desempenho
    mov esi, str_power_desempenho_activated
    call print_term_string
    jmp .done

.show_power_status:
    call show_power_status
    jmp .done

.power_usage:
    mov esi, str_power_usage
    call print_term_string
    jmp .done

.exec_module_load:
    
    cmp dword [terminal_cmd_pos], 12
    jl .module_usage

    mov esi, terminal_cmd_buffer
    add esi, 12

    
    mov edi, esi
    xor ecx, ecx
.count_mod_load:
    mov al, [edi]
    test al, al
    jz .got_mod_load_len
    cmp al, ' '
    je .got_mod_load_len
    inc ecx
    inc edi
    cmp ecx, 16
    jl .count_mod_load

.got_mod_load_len:
    call load_module
    jmp .done

.exec_module_unload:
    
    cmp dword [terminal_cmd_pos], 14
    jl .module_usage

    mov esi, terminal_cmd_buffer
    add esi, 14

    
    mov edi, esi
    xor ecx, ecx
.count_mod_unload:
    mov al, [edi]
    test al, al
    jz .got_mod_unload_len
    cmp al, ' '
    je .got_mod_unload_len
    inc ecx
    inc edi
    cmp ecx, 16
    jl .count_mod_unload

.got_mod_unload_len:
    call unload_module
    jmp .done

.exec_module_list:
    call list_modules_terminal
    jmp .done

.exec_taskmgr:
    
    mov esi, module_taskmgr_name
    mov ecx, 7
    call check_module_loaded
    cmp al, 0
    jne .taskmgr_loaded

    
    mov esi, module_taskmgr_name
    mov ecx, 7
    call load_module

.taskmgr_loaded:
    mov dword [current_screen], SCREEN_TASKMGR
    call setup_task_manager
    jmp .done

.module_usage:
    mov esi, str_module_usage
    call print_term_string
    jmp .done

.done:
    popad
    ret

compare_strings:
    push esi
    push edi
    push ecx

.loop:
    cmp ecx, 0
    je .equal

    mov al, [esi]
    mov bl, [edi]

    cmp al, 'a'
    jb .not_lower_a
    cmp al, 'z'
    ja .not_lower_a
    sub al, 32
.not_lower_a:

    cmp bl, 'a'
    jb .not_lower_b
    cmp bl, 'z'
    ja .not_lower_b
    sub bl, 32
.not_lower_b:

    cmp al, bl
    jne .not_equal

    inc esi
    inc edi
    dec ecx
    jmp .loop

.equal:
    xor eax, eax
    jmp .return

.not_equal:
    mov eax, 1

.return:
    or eax, eax
    pop ecx
    pop edi
    pop esi
    ret


apply_power_gelado:
    pushad

    
    
    mov ecx, 0x199  
    rdmsr
    and eax, 0xFFFF0000
    or eax, 0x0900  
    wrmsr

    
    mov ecx, 0x1A0  
    rdmsr
    or eax, 0x4000000000  
    wrmsr

    
    mov ecx, 0x198  
    rdmsr
    sub eax, 80
    mov ecx, 0x199
    wrmsr

    
    
    mov ecx, 0x1B0  
    rdmsr
    or eax, 0x00000200  
    wrmsr

    
    mov ecx, 0x1A4  
    rdmsr
    and eax, 0xFFFFFFF0
    or eax, 0x00000002  
    wrmsr

    
    
    mov dx, 0xCF8
    mov eax, 0x80000060  
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    or eax, 0x00000100  
    out dx, eax

    
    
    mov ecx, 0xE2  
    rdmsr
    and eax, 0xFFFFFF00
    or eax, 0x00000008  
    wrmsr

    
    mov dword [main_loop_delay], 10000

    
    mov dx, 0xCF8
    mov eax, 0x80000040
    out dx, eax
    mov dx, 0xCFC
    mov eax, 0x00000021  
    out dx, eax

    
    mov dx, 0xCF8
    mov eax, 0x80000090
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    or eax, 0x00000003  
    out dx, eax

    
    mov ecx, 0x19A  
    rdmsr
    and eax, 0xFFFFFF00
    or eax, 0x00000019  
    wrmsr

    popad
    ret

apply_power_desempenho:
    pushad

    
    mov ecx, 0x199  
    rdmsr
    and eax, 0xFFFF0000
    or eax, 0x2400  
    wrmsr

    
    mov ecx, 0x1A0  
    rdmsr
    and eax, 0xBFFFFFFF  
    wrmsr

    
    mov ecx, 0x198
    rdmsr
    add eax, 150
    mov ecx, 0x199
    wrmsr

    
    mov ecx, 0xE2  
    rdmsr
    and eax, 0xFFFFFF00
    or eax, 0x00000000  
    wrmsr

    
    mov ecx, 0x1FC  
    rdmsr
    and eax, 0xFFFFFFFD  
    wrmsr

    
    
    mov ecx, 0x1B0
    rdmsr
    and eax, 0xFFFFFDFF  
    wrmsr

    
    mov ecx, 0x1A4
    rdmsr
    or eax, 0x0000000F  
    wrmsr

    
    mov ecx, 0x1A5
    rdmsr
    or eax, 0x0000000F
    wrmsr

    
    mov dword [main_loop_delay], 10

    
    mov ecx, 0x1B1  
    rdmsr
    and eax, 0xFFFFFFFE  
    wrmsr

    
    mov ecx, 0x48  
    rdmsr
    and eax, 0xFFFFFFFC  
    wrmsr

    
    mov ecx, 0x1A0
    rdmsr
    or eax, 0x00010000  
    wrmsr

    
    mov ecx, 0x1A6
    rdmsr
    or eax, 0x000000FF  
    wrmsr

    
    mov dx, 0xCF8
    mov eax, 0x80000040
    out dx, eax
    mov dx, 0xCFC
    mov eax, 0x00000043  
    out dx, eax

    
    mov dx, 0xCF8
    mov eax, 0x80000090
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFFFFFFFC  
    out dx, eax

    
    mov dx, 0xCF8
    mov eax, 0x80000060
    out dx, eax
    mov dx, 0xCFC
    in eax, dx
    and eax, 0xFFFFFF00
    or eax, 0x00000007  
    out dx, eax

    
    mov ecx, 0x19A
    rdmsr
    and eax, 0xFFFFFF00  
    wrmsr

    popad
    ret

show_power_status:
    pushad

    mov al, 10
    call print_term_char

    mov esi, str_power_status_header
    call print_term_string
    mov al, 10
    call print_term_char

    
    mov esi, str_power_current_mode
    call print_term_string

    mov al, [power_mode]
    cmp al, 0
    je .mode_normal
    cmp al, 1
    je .mode_gelado
    cmp al, 2
    je .mode_desempenho
    jmp .show_stats

.mode_normal:
    mov esi, str_power_mode_normal
    jmp .print_mode

.mode_gelado:
    mov esi, str_power_mode_gelado
    jmp .print_mode

.mode_desempenho:
    mov esi, str_power_mode_desempenho

.print_mode:
    call print_term_string
    mov al, 10
    call print_term_char

.show_stats:
    
    mov esi, str_power_cpu_freq
    call print_term_string

    mov ecx, 0x198  
    rdmsr
    shr eax, 8
    and eax, 0xFF

    
    imul eax, 100
    push eax

    
    mov ebx, 1000
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 100
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov al, dl
    add al, '0'
    call print_term_char

    pop eax

    mov esi, str_power_mhz
    call print_term_string
    mov al, 10
    call print_term_char

    
    mov esi, str_power_turbo
    call print_term_string

    mov ecx, 0x1A0
    rdmsr
    test eax, 0x40000000
    jnz .turbo_off
    mov esi, str_power_on
    jmp .print_turbo
.turbo_off:
    mov esi, str_power_off
.print_turbo:
    call print_term_string
    mov al, 10
    call print_term_char

    
    mov esi, str_power_loop_delay
    call print_term_string

    mov eax, [main_loop_delay]

    
    mov ebx, 10000
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 1000
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 100
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov eax, edx
    mov ebx, 10
    xor edx, edx
    div ebx
    add al, '0'
    call print_term_char

    mov al, dl
    add al, '0'
    call print_term_char

    popad
    ret

compare_strings_exact:
    push esi
    push edi
    push ecx

.loop:
    cmp ecx, 0
    je .equal

    mov al, [esi]
    mov bl, [edi]

    cmp al, bl
    jne .not_equal

    inc esi
    inc edi
    dec ecx
    jmp .loop

.equal:
    xor eax, eax
    jmp .return

.not_equal:
    mov eax, 1

.return:
    or eax, eax
    pop ecx
    pop edi
    pop esi
    ret

list_files_terminal:
    pushad

    mov ebx, 0
.loop:
    cmp ebx, [fs_file_count]
    jge .done

    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE

    mov esi, eax
    call print_term_string

    mov al, 10
    call print_term_char

    inc ebx
    jmp .loop

.done:
    popad
    ret

list_modules_terminal:
    pushad

    mov al, 10
    call print_term_char
    mov esi, str_module_list_header
    call print_term_string
    mov al, 10
    call print_term_char

    mov edi, MODULE_BASE
    mov ebx, 0

.loop:
    cmp ebx, [module_count]
    jge .done

    
    mov esi, edi
    call print_term_string

    
    mov esi, str_module_status_sep
    call print_term_string

    cmp byte [edi + MODULE_NAME_LEN], MODULE_LOADED_FLAG
    je .loaded
    mov esi, str_module_status_unloaded
    jmp .print_status

.loaded:
    mov esi, str_module_status_loaded

.print_status:
    call print_term_string
    mov al, 10
    call print_term_char

    add edi, 32
    inc ebx
    jmp .loop

.done:
    popad
    ret

redraw_terminal:
    ret


draw_start_menu:
    pushad

    
    mov ebx, 10
    mov ecx, 30
    mov edx, 140
    mov esi, 150
    mov al, 0x08  
    call draw_filled_rect

    
    mov ebx, 10
    mov ecx, 30
    mov edx, 140
    mov esi, 2
    mov al, 0x09  
    call draw_filled_rect

    
    mov byte [term_color], 0x0F
    mov dword [term_x], 2
    mov dword [term_y], 4
    mov esi, str_start_title
    call print_term_string

    
    mov ebx, 15
    mov ecx, 45
    mov edx, 130
    mov esi, 1
    mov al, 0x07
    call draw_filled_rect

    
    mov dword [.current_y], 50
    xor ebx, ebx

.draw_items:
    cmp ebx, 7
    jge .done

    
    cmp ebx, [start_menu_selected]
    jne .not_selected

    
    push ebx
    mov eax, [.current_y]
    mov ecx, eax
    mov ebx, 15
    mov edx, 130
    mov esi, 18
    mov al, 0x01  
    call draw_filled_rect
    pop ebx

    mov byte [term_color], 0x0F
    jmp .draw_text

.not_selected:
    mov byte [term_color], 0x07

.draw_text:
    
    mov eax, [.current_y]
    add eax, 2
    shr eax, 3
    mov [term_y], eax
    mov dword [term_x], 2

    
    push ebx
    mov eax, ebx
    lea esi, [start_menu_items + eax*4]
    mov esi, [esi]
    call print_term_string
    pop ebx

    
    add dword [.current_y], 20
    inc ebx
    jmp .draw_items

.done:
    
    mov byte [term_color], 0x07
    mov dword [term_x], 2
    mov dword [term_y], 22
    mov esi, str_start_hint
    call print_term_string

    popad
    ret

.current_y dd 0

handle_start_menu_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    
    cmp al, 0x48
    je .key_up

    
    cmp al, 0x50
    je .key_down

    
    cmp al, 0x1C
    je .key_enter

    
    cmp al, 0x01
    je .key_esc

    jmp .done

.key_up:
    cmp dword [start_menu_selected], 0
    jle .redraw
    dec dword [start_menu_selected]
    jmp .redraw

.key_down:
    cmp dword [start_menu_selected], 6
    jge .redraw
    inc dword [start_menu_selected]
    jmp .redraw

.key_enter:
    mov eax, [start_menu_selected]

    cmp eax, 0
    je .launch_notepad
    cmp eax, 1
    je .launch_terminal
    cmp eax, 2
    je .launch_explorer
    cmp eax, 3
    je .launch_viewer
    cmp eax, 4
    je .launch_paint
    cmp eax, 5
    je .show_system_info
    cmp eax, 6
    je .launch_taskmgr_menu
    jmp .done

.launch_notepad:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_NOTEPAD
    call setup_notepad
    jmp .done

.launch_terminal:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_TERMINAL
    call setup_terminal
    jmp .done

.launch_explorer:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_EXPLORER
    call setup_explorer
    jmp .done

.launch_viewer:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_VIEWER
    call setup_viewer
    jmp .done

.launch_paint:
    mov byte [start_menu_open], 0

    
    mov esi, pkg_paint_name
    mov ecx, 5
    call check_package_installed
    cmp al, 0
    je .paint_not_installed_msg

    mov dword [current_screen], SCREEN_PAINT
    call setup_paint
    jmp .done

.paint_not_installed_msg:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_DESKTOP
    call setup_gui

    call show_notification
    mov esi, str_paint_not_installed
    call print_notification
    call hide_notification_delayed
    jmp .done

.show_system_info:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_DESKTOP
    call setup_gui

    call show_notification
    mov esi, str_system_info_notify
    call print_notification
    call hide_notification_delayed
    jmp .done

.launch_taskmgr_menu:
    mov byte [start_menu_open], 0

    
    mov esi, module_taskmgr_name
    mov ecx, 7
    call check_module_loaded
    cmp al, 0
    jne .taskmgr_start_loaded

    mov esi, module_taskmgr_name
    mov ecx, 7
    call load_module

.taskmgr_start_loaded:
    mov dword [current_screen], SCREEN_TASKMGR
    call setup_task_manager
    jmp .done

.key_esc:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_DESKTOP
    call setup_gui
    jmp .done

.redraw:
    call draw_start_menu

.done:
    popad
    ret
setup_paint:
    pushad

    mov al, 0x0F
    call clear_screen_color

    
    mov ebx, 0
    mov ecx, 0
    mov edx, SCREEN_WIDTH
    mov esi, 15
    mov al, 0x09
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 1
    mov dword [term_y], 0
    mov esi, str_paint_title
    call print_term_string

    
    mov dword [paint_current_color], 0x0C
    mov dword [paint_cursor_x], 160
    mov dword [paint_cursor_y], 100

    
    mov ebx, 0
    mov ecx, 20
    mov edx, 20
    mov esi, 15
    mov al, 0x0C
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 40
    mov edx, 20
    mov esi, 15
    mov al, 0x0A
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 60
    mov edx, 20
    mov esi, 15
    mov al, 0x0E
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 80
    mov edx, 20
    mov esi, 15
    mov al, 0x01
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 100
    mov edx, 20
    mov esi, 15
    mov al, 0x04
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 120
    mov edx, 20
    mov esi, 15
    mov al, 0x00
    call draw_filled_rect

    mov ebx, 0
    mov ecx, 140
    mov edx, 20
    mov esi, 15
    mov al, 0x0B
    call draw_filled_rect

    
    mov ebx, 0
    mov ecx, 160
    mov edx, 20
    mov esi, 15
    mov al, 0x08
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 0
    mov dword [term_y], 20
    mov esi, str_paint_clear
    call print_term_string

    
    mov ebx, 280
    mov ecx, 5
    mov edx, 35
    mov esi, 10
    mov al, [paint_current_color]
    call draw_filled_rect

    
    call draw_paint_cursor

    popad
    ret

handle_paint_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    
    cmp al, 0x02  
    je .color_1
    cmp al, 0x03  
    je .color_2
    cmp al, 0x04  
    je .color_3
    cmp al, 0x05  
    je .color_4
    cmp al, 0x06  
    je .color_5
    cmp al, 0x07  
    je .color_6
    cmp al, 0x08  
    je .color_7

    
    cmp al, 0x48  
    je .move_up
    cmp al, 0x50  
    je .move_down
    cmp al, 0x4B  
    je .move_left
    cmp al, 0x4D  
    je .move_right

    
    cmp al, 0x39
    je .draw_pixel_key

    
    cmp al, 0x2E
    je .clear_canvas

    jmp .done

.color_1:
    mov byte [paint_current_color], 0x0C
    call update_color_indicator
    jmp .done

.color_2:
    mov byte [paint_current_color], 0x0A
    call update_color_indicator
    jmp .done

.color_3:
    mov byte [paint_current_color], 0x0E
    call update_color_indicator
    jmp .done

.color_4:
    mov byte [paint_current_color], 0x01
    call update_color_indicator
    jmp .done

.color_5:
    mov byte [paint_current_color], 0x04
    call update_color_indicator
    jmp .done

.color_6:
    mov byte [paint_current_color], 0x00
    call update_color_indicator
    jmp .done

.color_7:
    mov byte [paint_current_color], 0x0B
    call update_color_indicator
    jmp .done

.move_up:
    call erase_paint_cursor
    cmp dword [paint_cursor_y], 20
    jle .done
    sub dword [paint_cursor_y], 2
    call draw_paint_cursor
    jmp .done

.move_down:
    call erase_paint_cursor
    cmp dword [paint_cursor_y], 195
    jge .done
    add dword [paint_cursor_y], 2
    call draw_paint_cursor
    jmp .done

.move_left:
    call erase_paint_cursor
    cmp dword [paint_cursor_x], 25
    jle .done
    sub dword [paint_cursor_x], 2
    call draw_paint_cursor
    jmp .done

.move_right:
    call erase_paint_cursor
    cmp dword [paint_cursor_x], 315
    jge .done
    add dword [paint_cursor_x], 2
    call draw_paint_cursor
    jmp .done

.draw_pixel_key:
    mov ebx, [paint_cursor_x]
    mov ecx, [paint_cursor_y]
    mov al, [paint_current_color]
    call draw_pixel
    call draw_paint_cursor
    jmp .done

.clear_canvas:
    call setup_paint
    jmp .done

.done:
    popad
    ret

draw_paint_cursor:
    pushad

    mov ebx, [paint_cursor_x]
    mov ecx, [paint_cursor_y]

    
    push ebx
    push ecx
    sub ebx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    add ebx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    sub ecx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    add ecx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    popad
    ret

erase_paint_cursor:
    pushad

    mov ebx, [paint_cursor_x]
    mov ecx, [paint_cursor_y]

    
    push ebx
    push ecx
    sub ebx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    add ebx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    sub ecx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    push ebx
    push ecx
    add ecx, 2
    mov al, 0x0F
    call draw_pixel
    pop ecx
    pop ebx

    popad
    ret

handle_paint_click:
    pushad

    mov ebx, [mouse_x]
    mov ecx, [mouse_y]

    
    cmp ebx, 20
    jge .not_palette

    cmp ecx, 20
    jl .not_palette
    cmp ecx, 35
    jge .check_green
    mov byte [paint_current_color], 0x0C
    call update_color_indicator
    jmp .done

.check_green:
    cmp ecx, 40
    jl .not_palette
    cmp ecx, 55
    jge .check_yellow
    mov byte [paint_current_color], 0x0A
    call update_color_indicator
    jmp .done

.check_yellow:
    cmp ecx, 60
    jl .not_palette
    cmp ecx, 75
    jge .check_blue
    mov byte [paint_current_color], 0x0E
    call update_color_indicator
    jmp .done

.check_blue:
    cmp ecx, 80
    jl .not_palette
    cmp ecx, 95
    jge .check_darkred
    mov byte [paint_current_color], 0x01
    call update_color_indicator
    jmp .done

.check_darkred:
    cmp ecx, 100
    jl .not_palette
    cmp ecx, 115
    jge .check_black
    mov byte [paint_current_color], 0x04
    call update_color_indicator
    jmp .done

.check_black:
    cmp ecx, 120
    jl .not_palette
    cmp ecx, 135
    jge .check_clear_btn
    mov byte [paint_current_color], 0x00
    call update_color_indicator
    jmp .done

.check_clear_btn:
    cmp ecx, 160
    jl .not_palette
    cmp ecx, 175
    jge .not_palette
    call setup_paint
    jmp .done

.not_palette:
    cmp ecx, 15
    jle .done
    cmp ebx, 25
    jle .done

    mov al, [paint_current_color]
    call draw_pixel

.done:
    popad
    ret

update_color_indicator:
    pushad

    mov ebx, 280
    mov ecx, 5
    mov edx, 35
    mov esi, 10
    mov al, [paint_current_color]
    call draw_filled_rect

    popad
    ret


setup_explorer:
    pushad

    mov al, 0x01
    call clear_screen_color

    mov dword [explorer_selected], 0
    mov byte [explorer_mode], 0
    mov dword [explorer_viewing_file], 0
    mov byte [explorer_editing], 0

    call draw_explorer_window

    popad
    ret

draw_explorer_window:
    pushad

    mov ebx, 10
    mov ecx, 10
    mov edx, 300
    mov esi, 180
    mov al, 0x0F
    call draw_filled_rect

    mov ebx, 10
    mov ecx, 10
    mov edx, 300
    mov esi, 15
    mov al, 0x09
    call draw_filled_rect

    mov byte [term_color], 0x0F
    mov dword [term_x], 2
    mov dword [term_y], 1
    mov esi, str_explorer_title
    call print_term_string

    cmp byte [explorer_mode], 0
    je .draw_file_list
    cmp byte [explorer_mode], 1
    je .draw_file_viewer
    cmp byte [explorer_mode], 2
    je .draw_new_file_dialog
    jmp .done

.draw_file_list:
    mov dword [term_y], 4
    mov ebx, 0

.file_loop:
    cmp ebx, [fs_file_count]
    jge .list_done
    cmp ebx, 16
    jge .list_done

    cmp ebx, [explorer_selected]
    jne .not_selected

    push ebx
    mov eax, [term_y]
    shl eax, 3
    mov ecx, eax
    mov ebx, 15
    mov edx, 290
    mov esi, 8
    mov al, 0x09
    call draw_filled_rect
    pop ebx

    mov byte [term_color], 0x0F
    jmp .draw_filename

.not_selected:
    mov byte [term_color], 0x00

.draw_filename:
    mov dword [term_x], 2

    push ebx
    mov eax, ebx
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov esi, eax
    call print_term_string
    pop ebx

    inc dword [term_y]
    inc ebx
    jmp .file_loop

.list_done:
    mov byte [term_color], 0x00
    mov dword [term_x], 2
    mov dword [term_y], 23
    mov esi, str_explorer_help
    call print_term_string
    jmp .done

.draw_file_viewer:
    mov byte [term_color], 0x00
    mov dword [term_x], 2
    mov dword [term_y], 4

    mov eax, [explorer_viewing_file]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    add eax, FS_FILENAME_LEN
    mov esi, eax
    call print_term_string

    mov dword [term_x], 2
    mov dword [term_y], 23
    mov esi, str_viewer_help
    call print_term_string
    jmp .done

.draw_new_file_dialog:
    mov ebx, 60
    mov ecx, 80
    mov edx, 200
    mov esi, 40
    mov al, 0x07
    call draw_filled_rect

    mov byte [term_color], 0x00
    mov dword [term_x], 8
    mov dword [term_y], 11
    mov esi, str_new_file_prompt
    call print_term_string

    mov dword [term_y], 13
    mov esi, explorer_input_buffer
    call print_term_string
    jmp .done

.done:
    popad
    ret

handle_explorer_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    cmp byte [explorer_mode], 0
    je .normal_mode
    cmp byte [explorer_mode], 1
    je .viewing_mode
    cmp byte [explorer_mode], 2
    je .creating_mode
    jmp .done

.normal_mode:
    cmp al, 0x48
    je .key_up
    cmp al, 0x50
    je .key_down
    cmp al, 0x1C
    je .key_enter
    cmp al, 0x20
    je .key_delete
    cmp al, 0x31
    je .key_new
    jmp .done

.key_up:
    cmp dword [explorer_selected], 0
    jle .redraw
    dec dword [explorer_selected]
    jmp .redraw

.key_down:
    mov eax, [explorer_selected]
    mov ebx, [fs_file_count]
    dec ebx
    cmp eax, ebx
    jge .redraw
    inc dword [explorer_selected]
    jmp .redraw

.key_enter:
    cmp dword [fs_file_count], 0
    je .done

    mov eax, [explorer_selected]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    push eax

    cmp byte [eax + 8], 1
    pop eax
    je .open_screenshot

    mov byte [explorer_mode], 1
    mov eax, [explorer_selected]
    mov [explorer_viewing_file], eax
    jmp .redraw

.open_screenshot:
    mov byte [viewing_screenshot], 1
    mov dword [current_screen], SCREEN_VIEWER
    call setup_viewer
    jmp .done

.key_delete:
    call delete_selected_file
    jmp .redraw

.key_new:
    mov byte [explorer_mode], 2
    mov dword [explorer_input_pos], 0

    mov edi, explorer_input_buffer
    mov ecx, 128
    xor al, al
    rep stosb
    jmp .redraw

.viewing_mode:
    cmp al, 0x01
    je .exit_viewing
    jmp .done

.exit_viewing:
    mov byte [explorer_mode], 0
    jmp .redraw

.creating_mode:
    cmp al, 0x1C
    je .create_file
    cmp al, 0x01
    je .cancel_create
    cmp al, 0x0E
    je .backspace_input
    cmp al, 0x39
    je .space_input

    call scancode_to_char
    test al, al
    jz .done

    cmp dword [explorer_input_pos], FS_FILENAME_LEN - 1
    jge .done

    mov ebx, [explorer_input_pos]
    mov [explorer_input_buffer + ebx], al
    inc dword [explorer_input_pos]
    jmp .redraw

.create_file:
    cmp dword [explorer_input_pos], 0
    je .done
    cmp dword [fs_file_count], FS_MAX_FILES
    jge .done

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, explorer_input_buffer
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov ecx, FS_CONTENT_LEN
    xor al, al
    rep stosb

    inc dword [fs_file_count]

    mov eax, [fs_file_count]
    dec eax
    mov [explorer_selected], eax
    mov byte [explorer_mode], 0
    jmp .redraw

.cancel_create:
    mov byte [explorer_mode], 0
    jmp .redraw

.backspace_input:
    cmp dword [explorer_input_pos], 0
    je .done
    dec dword [explorer_input_pos]
    mov ebx, [explorer_input_pos]
    mov byte [explorer_input_buffer + ebx], 0
    jmp .redraw

.space_input:
    cmp dword [explorer_input_pos], FS_FILENAME_LEN - 1
    jge .done
    mov ebx, [explorer_input_pos]
    mov byte [explorer_input_buffer + ebx], '.'
    inc dword [explorer_input_pos]
    jmp .redraw

.redraw:
    mov byte [last_scancode], 0
    call draw_explorer_window

.done:
    popad
    ret

delete_selected_file:
    pushad

    cmp dword [fs_file_count], 0
    je .done

    mov eax, [explorer_selected]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, edi
    add esi, FS_ENTRY_SIZE

    mov eax, [fs_file_count]
    sub eax, [explorer_selected]
    dec eax
    mov ecx, eax
    imul ecx, FS_ENTRY_SIZE

    cld
    rep movsb

    dec dword [fs_file_count]

    mov eax, [explorer_selected]
    cmp eax, [fs_file_count]
    jl .done
    cmp dword [explorer_selected], 0
    je .done
    dec dword [explorer_selected]

.done:
    popad
    ret


setup_viewer:
    pushad

    cmp byte [viewing_screenshot], 1
    je .load_screenshot

    call load_image_from_memory

    cmp eax, 0
    je .no_image

    call setup_vga_palette
    call display_loaded_image
    jmp .done

.load_screenshot:
    mov byte [viewing_screenshot], 0

    call setup_vga_palette

    mov esi, SCREENSHOT_BUFFER
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

    mov byte [term_color], 0x0E
    mov dword [term_x], 1
    mov dword [term_y], 1
    mov esi, str_screenshot_view
    call print_term_string

    jmp .done

.no_image:
    mov al, 0x00
    call clear_screen_color

    mov byte [term_color], 0x0C
    mov dword [term_x], 8
    mov dword [term_y], 10
    mov esi, str_no_image
    call print_term_string

    mov byte [term_color], 0x0E
    mov dword [term_y], 12
    mov esi, str_no_image_help
    call print_term_string

.done:
    popad
    ret

load_image_from_memory:
    push esi
    push ecx

    mov esi, IMAGE_LOAD_ADDR
    mov ecx, 16
    xor edx, edx

.check_loop:
    lodsb
    test al, al
    jnz .has_data
    inc edx
    loop .check_loop

    xor eax, eax
    jmp .return

.has_data:
    mov eax, 1

.return:
    pop ecx
    pop esi
    ret

setup_vga_palette:
    pushad

    mov dx, 0x03C8
    xor al, al
    out dx, al

    mov dx, 0x03C9
    xor ecx, ecx

.palette_loop:
    mov eax, ecx
    shr eax, 5
    and eax, 7
    shl eax, 5
    shr al, 2
    out dx, al

    mov eax, ecx
    shr eax, 2
    and eax, 7
    shl eax, 5
    shr al, 2
    out dx, al

    mov eax, ecx
    and eax, 3
    shl eax, 6
    shr al, 2
    out dx, al

    inc ecx
    cmp ecx, 256
    jl .palette_loop

    popad
    ret

display_loaded_image:
    pushad

    mov esi, IMAGE_LOAD_ADDR
    mov edi, VGA_MEMORY
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

    popad
    ret

handle_viewer_input:
    pushad

    mov al, [last_scancode]
    mov byte [last_scancode], 0

    cmp al, 0x19
    je .set_wallpaper

    jmp .done

.set_wallpaper:
    cmp byte [viewing_screenshot], 0
    je .already_loaded

    mov esi, SCREENSHOT_BUFFER
    mov edi, IMAGE_LOAD_ADDR
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

.already_loaded:
    mov byte [wallpaper_enabled], 1

    call show_notification
    mov esi, str_wallpaper_set
    call print_notification
    call hide_notification_delayed

    call setup_viewer
    jmp .done

.done:
    popad
    ret


init_filesystem:
    pushad

    mov dword [fs_file_count], 0

    call create_file_readme
    call create_file_hello
    call create_file_system
    call create_file_notes
    call create_file_info

    popad
    ret

create_file_readme:
    pushad

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_readme
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_readme
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

    popad
    ret

create_file_hello:
    pushad

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_hello
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_hello
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

    popad
    ret

create_file_system:
    pushad

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_system
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_system
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

    popad
    ret

create_file_notes:
    pushad

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_notes
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_notes
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

    popad
    ret

create_file_info:
    pushad

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, fname_info
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov esi, fcontent_info
    mov ecx, FS_CONTENT_LEN
    rep movsb

    inc dword [fs_file_count]

    popad
    ret


setup_idt:
    call remap_pic

    mov eax, keyboard_isr
    mov ebx, 0x21
    call install_isr

    mov eax, mouse_isr
    mov ebx, 0x2C
    call install_isr

    lidt [idt_descriptor]

    in al, 0x21
    and al, 0xFD
    out 0x21, al

    ret

remap_pic:
    in al, 0x21
    mov bl, al
    in al, 0xA1
    mov bh, al

    mov al, 0x11
    out 0x20, al
    call pic_wait
    out 0xA0, al
    call pic_wait

    mov al, 0x20
    out 0x21, al
    call pic_wait
    mov al, 0x28
    out 0xA1, al
    call pic_wait

    mov al, 0x04
    out 0x21, al
    call pic_wait
    mov al, 0x02
    out 0xA1, al
    call pic_wait

    mov al, 0x01
    out 0x21, al
    call pic_wait
    out 0xA1, al
    call pic_wait

    mov al, 0xFD
    out 0x21, al
    mov al, 0xFF
    out 0xA1, al

    ret

pic_wait:
    push eax
    mov ecx, 10
.loop:
    in al, 0x80
    loop .loop
    pop eax
    ret

install_isr:
    push eax
    push ebx
    push edi

    mov edi, idt_table
    shl ebx, 3
    add edi, ebx

    mov word [edi], ax
    mov word [edi+2], 0x08
    mov byte [edi+4], 0
    mov byte [edi+5], 0x8E
    shr eax, 16
    mov word [edi+6], ax

    pop edi
    pop ebx
    pop eax
    ret


keyboard_isr:
    pushad

    in al, PS2_DATA
    mov [last_scancode], al

    test al, 0x80
    jnz .key_release

    cmp al, 0x1D
    je .ctrl_press
    cmp al, 0x2A
    je .shift_press
    cmp al, 0x36
    je .shift_press

    jmp .check_shortcuts

.key_release:
    and al, 0x7F
    cmp al, 0x1D
    je .ctrl_release
    cmp al, 0x2A
    je .shift_release
    cmp al, 0x36
    je .shift_release
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

.check_shortcuts:
    cmp byte [ctrl_pressed], 1
    jne .normal_keys

    mov al, [last_scancode]
    cmp al, 0x1E
    je .handle_select_all
    cmp al, 0x2E
    je .handle_copy
    cmp al, 0x2F
    je .handle_paste
    cmp al, 0x1F
    je .handle_save
    jmp .done

.handle_select_all:
    call clipboard_select_all
    jmp .done

.handle_copy:
    call clipboard_copy
    jmp .done

.handle_paste:
    call clipboard_paste
    jmp .done

.handle_save:
    call save_notepad_file
    jmp .done

.normal_keys:
    mov al, [last_scancode]
    cmp al, 0x58
    je .take_screenshot

    
    cmp al, 0x5B
    je .toggle_start_menu

    cmp al, 0x01
    je .esc_key

    mov ebx, [current_screen]
    cmp ebx, SCREEN_NOTEPAD
    je .notepad_key
    cmp ebx, SCREEN_TERMINAL
    je .terminal_key
    cmp ebx, SCREEN_EXPLORER
    je .explorer_key
    cmp ebx, SCREEN_VIEWER
    je .viewer_key
    cmp ebx, SCREEN_PAINT
    je .paint_key
    cmp ebx, SCREEN_START_MENU
    je .start_menu_key
    cmp ebx, SCREEN_TASKMGR
    je .taskmgr_key
    jmp .done

.toggle_start_menu:
    cmp byte [start_menu_open], 0
    je .open_start_menu

    
    mov byte [start_menu_open], 0
    mov byte [last_scancode], 0
    call setup_gui
    jmp .done

.open_start_menu:
    
    mov byte [start_menu_open], 1
    mov dword [start_menu_selected], 0
    mov dword [current_screen], SCREEN_START_MENU
    mov byte [last_scancode], 0
    call draw_start_menu
    jmp .done

.start_menu_key:
    call handle_start_menu_input
    jmp .done

.take_screenshot:
    call take_screenshot
    jmp .done

.esc_key:
    cmp byte [start_menu_open], 1
    je .close_start_from_esc

    cmp dword [current_screen], SCREEN_DESKTOP
    je .done

    mov dword [current_screen], SCREEN_DESKTOP
    call setup_gui
    jmp .done

.close_start_from_esc:
    mov byte [start_menu_open], 0
    mov dword [current_screen], SCREEN_DESKTOP
    call setup_gui
    jmp .done

.notepad_key:
    call handle_notepad_input
    jmp .done

.terminal_key:
    call handle_terminal_input
    jmp .done

.explorer_key:
    call handle_explorer_input
    jmp .done

.viewer_key:
    call handle_viewer_input
    jmp .done

.paint_key:
    call handle_paint_input
    jmp .done

.taskmgr_key:
    call handle_taskmgr_input
    jmp .done

.done:
    mov al, 0x20
    out 0x20, al

    popad
    iret


save_notepad_file:
    pushad

    cmp dword [notepad_text_pos], 0
    je .done

    cmp dword [fs_file_count], FS_MAX_FILES
    jge .no_space

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov dword [edi], 'ETON'
    mov dword [edi+4], 'DAP.'
    mov dword [edi+8], 'TXT'

    add edi, FS_FILENAME_LEN
    mov esi, notepad_text_buffer
    mov ecx, [notepad_text_pos]
    cmp ecx, FS_CONTENT_LEN
    jle .copy_content
    mov ecx, FS_CONTENT_LEN

.copy_content:
    rep movsb

    mov eax, FS_CONTENT_LEN
    sub eax, [notepad_text_pos]
    cmp eax, 0
    jle .finish_save
    mov ecx, eax
    xor al, al
    rep stosb

.finish_save:
    inc dword [fs_file_count]

    call show_notification
    mov esi, msg_file_saved
    call print_notification
    call hide_notification_delayed
    jmp .done

.no_space:
    call show_notification
    mov esi, msg_no_space
    call print_notification
    call hide_notification_delayed

.done:
    popad
    ret


init_mouse:
    pushad

    call mouse_wait_write
    mov al, 0xA8
    out PS2_COMMAND, al

    call mouse_wait_write
    mov al, 0x20
    out PS2_COMMAND, al
    call mouse_wait_read
    in al, PS2_DATA

    or al, 0x03
    push eax

    call mouse_wait_write
    mov al, 0x60
    out PS2_COMMAND, al
    call mouse_wait_write
    pop eax
    out PS2_DATA, al

    call mouse_wait_write
    mov al, 0xD4
    out PS2_COMMAND, al
    call mouse_wait_write
    mov al, 0xFF
    out PS2_DATA, al

    call mouse_wait_read
    in al, PS2_DATA
    call mouse_wait_read
    in al, PS2_DATA
    call mouse_wait_read
    in al, PS2_DATA

    call mouse_wait_write
    mov al, 0xD4
    out PS2_COMMAND, al
    call mouse_wait_write
    mov al, 0xF4
    out PS2_DATA, al
    call mouse_wait_read
    in al, PS2_DATA

    in al, 0xA1
    and al, 0xEF
    out 0xA1, al

    popad
    ret

mouse_wait_read:
    push ecx
    mov ecx, 10000
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
    mov ecx, 10000
.loop:
    in al, PS2_STATUS
    test al, 2
    jz .done
    loop .loop
.done:
    pop ecx
    ret

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
    out 0xA0, al
    out 0x20, al

    popad
    iret

process_mouse_packet:
    pushad

    mov al, [mouse_packet]
    and al, 0x07
    mov [mouse_buttons], al

    movsx eax, byte [mouse_packet + 1]
    add [mouse_x], eax

    cmp dword [mouse_x], 0
    jge .x_ok
    mov dword [mouse_x], 0
.x_ok:
    cmp dword [mouse_x], SCREEN_WIDTH - 1
    jle .x_ok2
    mov dword [mouse_x], SCREEN_WIDTH - 1
.x_ok2:

    movsx eax, byte [mouse_packet + 2]
    neg eax
    add [mouse_y], eax

    cmp dword [mouse_y], 0
    jge .y_ok
    mov dword [mouse_y], 0
.y_ok:
    cmp dword [mouse_y], SCREEN_HEIGHT - 1
    jle .y_ok2
    mov dword [mouse_y], SCREEN_HEIGHT - 1
.y_ok2:

    cmp dword [current_screen], SCREEN_PAINT
    jne .skip_paint

    test byte [mouse_buttons], 1
    jz .skip_paint

    call handle_paint_click

.skip_paint:
    popad
    ret

update_mouse_cursor:
    pushad

    mov ebx, [mouse_x]
    mov ecx, [mouse_y]

    mov esi, 0
.cursor_loop_y:
    cmp esi, 10
    jge .cursor_done

    mov edi, 0
.cursor_loop_x:
    cmp edi, 6
    jge .next_cursor_y

    cmp edi, esi
    jg .skip_pixel

    push ebx
    push ecx
    add ebx, edi
    add ecx, esi

    cmp ebx, SCREEN_WIDTH
    jge .skip_draw
    cmp ecx, SCREEN_HEIGHT
    jge .skip_draw

    mov al, 0x0F
    call draw_pixel

.skip_draw:
    pop ecx
    pop ebx

.skip_pixel:
    inc edi
    jmp .cursor_loop_x

.next_cursor_y:
    inc esi
    jmp .cursor_loop_y

.cursor_done:
    popad
    ret


take_screenshot:
    pushad

    cmp dword [fs_file_count], FS_MAX_FILES
    jge .no_space

    push dword [current_screen]

    mov esi, VGA_MEMORY
    mov edi, SCREENSHOT_BUFFER
    mov ecx, SCREEN_SIZE
    cld
    rep movsb

    call generate_screenshot_name

    mov eax, [fs_file_count]
    mov edx, FS_ENTRY_SIZE
    mul edx
    add eax, FILESYSTEM_BASE
    mov edi, eax

    mov esi, screenshot_name
    mov ecx, FS_FILENAME_LEN
    rep movsb

    mov byte [edi], 'S'
    mov byte [edi+1], 'C'
    mov byte [edi+2], 'R'
    mov byte [edi+3], 'N'

    mov eax, [screenshot_counter]
    mov [edi+4], eax

    mov byte [edi+8], 1

    mov dword [edi+9], SCREENSHOT_BUFFER

    inc dword [fs_file_count]
    inc dword [screenshot_counter]

    pop dword [current_screen]

    call show_notification
    mov esi, msg_screenshot_saved
    call print_notification
    call hide_notification_delayed

    jmp .done

.no_space:
    call show_notification
    mov esi, msg_no_space
    call print_notification
    call hide_notification_delayed

.done:
    popad
    ret

generate_screenshot_name:
    push eax
    push ebx
    push edx

    mov edi, screenshot_name
    mov ecx, FS_FILENAME_LEN
    xor al, al
    rep stosb

    mov dword [screenshot_name], 'NRCS'

    mov eax, [screenshot_counter]
    mov ebx, 10

    xor edx, edx
    div ebx
    push edx

    xor edx, edx
    div ebx
    push edx

    xor edx, edx
    div ebx
    push edx

    xor edx, edx
    div ebx
    push edx

    pop eax
    add al, '0'
    mov [screenshot_name + 4], al

    pop eax
    add al, '0'
    mov [screenshot_name + 5], al

    pop eax
    add al, '0'
    mov [screenshot_name + 6], al

    pop eax
    add al, '0'
    mov [screenshot_name + 7], al

    mov byte [screenshot_name + 8], '.'
    mov byte [screenshot_name + 9], 'G'
    mov byte [screenshot_name + 10], 'A'
    mov byte [screenshot_name + 11], 'T'

    pop edx
    pop ebx
    pop eax
    ret


show_notification:
    pushad

    mov ebx, 90
    mov ecx, 85
    mov edx, 140
    mov esi, 30
    mov al, 0x09
    call draw_filled_rect

    mov ebx, 90
    mov ecx, 85
    mov edx, 140
    mov esi, 2
    mov al, 0x0F
    call draw_filled_rect

    mov ebx, 90
    mov ecx, 113
    mov edx, 140
    mov esi, 2
    mov al, 0x0F
    call draw_filled_rect

    popad
    ret

print_notification:
    push dword [term_x]
    push dword [term_y]
    push dword [term_color]

    mov dword [term_x], 12
    mov dword [term_y], 12
    mov byte [term_color], 0x0F
    call print_term_string

    pop dword [term_color]
    pop dword [term_y]
    pop dword [term_x]
    ret

hide_notification_delayed:
    call delay_short
    call delay_short

    mov eax, [current_screen]
    cmp eax, SCREEN_DESKTOP
    je .redraw_desktop
    cmp eax, SCREEN_NOTEPAD
    je .redraw_notepad
    cmp eax, SCREEN_TERMINAL
    je .redraw_terminal
    cmp eax, SCREEN_EXPLORER
    je .redraw_explorer
    cmp eax, SCREEN_VIEWER
    je .redraw_viewer
    cmp eax, SCREEN_PAINT
    je .redraw_paint
    ret

.redraw_desktop:
    call setup_gui
    ret

.redraw_notepad:
    call redraw_notepad
    ret

.redraw_terminal:
    call redraw_terminal
    ret

.redraw_explorer:
    call draw_explorer_window
    ret

.redraw_viewer:
    call setup_viewer
    ret

.redraw_paint:
    call setup_paint
    ret

delay_short:
    push ecx
    mov ecx, 0x1FFFFF
.loop:
    nop
    loop .loop
    pop ecx
    ret


clipboard_select_all:
    pushad

    mov ebx, [current_screen]
    cmp ebx, SCREEN_NOTEPAD
    je .notepad_select
    cmp ebx, SCREEN_TERMINAL
    je .terminal_select
    jmp .done

.notepad_select:
    mov dword [notepad_selection_start], 0
    mov eax, [notepad_text_pos]
    mov [notepad_selection_end], eax
    mov byte [notepad_has_selection], 1
    call redraw_notepad
    jmp .done

.terminal_select:
    mov dword [terminal_selection_start], 0
    mov eax, [terminal_cmd_pos]
    mov [terminal_selection_end], eax
    mov byte [terminal_has_selection], 1
    jmp .done

.done:
    popad
    ret

clipboard_copy:
    pushad

    mov ebx, [current_screen]
    cmp ebx, SCREEN_NOTEPAD
    je .copy_notepad
    cmp ebx, SCREEN_TERMINAL
    je .copy_terminal
    jmp .done

.copy_notepad:
    cmp byte [notepad_has_selection], 0
    je .done

    mov eax, [notepad_selection_start]
    mov ebx, [notepad_selection_end]

    cmp eax, ebx
    jle .notepad_copy_range
    xchg eax, ebx

.notepad_copy_range:
    sub ebx, eax
    cmp ebx, CLIPBOARD_SIZE - 1
    jle .notepad_size_ok
    mov ebx, CLIPBOARD_SIZE - 1

.notepad_size_ok:
    mov [clipboard_size], ebx

    mov esi, notepad_text_buffer
    add esi, eax
    mov edi, clipboard_buffer
    mov ecx, ebx
    rep movsb

    mov byte [edi], 0

    call show_notification
    mov esi, msg_copied
    call print_notification
    call hide_notification_delayed
    jmp .done

.copy_terminal:
    cmp byte [terminal_has_selection], 0
    je .done

    mov eax, [terminal_selection_start]
    mov ebx, [terminal_selection_end]

    cmp eax, ebx
    jle .terminal_copy_range
    xchg eax, ebx

.terminal_copy_range:
    sub ebx, eax
    cmp ebx, CLIPBOARD_SIZE - 1
    jle .terminal_size_ok
    mov ebx, CLIPBOARD_SIZE - 1

.terminal_size_ok:
    mov [clipboard_size], ebx

    mov esi, terminal_cmd_buffer
    add esi, eax
    mov edi, clipboard_buffer
    mov ecx, ebx
    rep movsb

    mov byte [edi], 0

    call show_notification
    mov esi, msg_copied
    call print_notification
    call hide_notification_delayed
    jmp .done

.done:
    popad
    ret

clipboard_paste:
    pushad

    cmp dword [clipboard_size], 0
    je .done

    mov ebx, [current_screen]
    cmp ebx, SCREEN_NOTEPAD
    je .paste_notepad
    cmp ebx, SCREEN_TERMINAL
    je .paste_terminal
    jmp .done

.paste_notepad:
    mov esi, clipboard_buffer
    mov ecx, [clipboard_size]

.paste_notepad_loop:
    cmp ecx, 0
    je .paste_notepad_done

    cmp dword [notepad_text_pos], TEXT_BUFFER_SIZE - 1
    jge .paste_notepad_done

    lodsb

    cmp al, 10
    je .paste_notepad_next
    cmp al, 13
    je .paste_notepad_next

    push ecx
    push esi

    mov ebx, [notepad_text_pos]
    mov [notepad_text_buffer + ebx], al
    inc dword [notepad_text_pos]

    pop esi
    pop ecx

.paste_notepad_next:
    dec ecx
    jmp .paste_notepad_loop

.paste_notepad_done:
    call redraw_notepad

    call show_notification
    mov esi, msg_pasted
    call print_notification
    call hide_notification_delayed
    jmp .done

.paste_terminal:
    mov esi, clipboard_buffer
    mov ecx, [clipboard_size]

.paste_terminal_loop:
    cmp ecx, 0
    je .paste_terminal_done

    cmp dword [terminal_cmd_pos], TERM_BUFFER_SIZE - 1
    jge .paste_terminal_done

    lodsb

    cmp al, 10
    je .paste_terminal_next
    cmp al, 13
    je .paste_terminal_next

    push ecx
    push esi

    mov ebx, [terminal_cmd_pos]
    mov [terminal_cmd_buffer + ebx], al
    inc dword [terminal_cmd_pos]

    pop esi
    pop ecx

.paste_terminal_next:
    dec ecx
    jmp .paste_terminal_loop

.paste_terminal_done:
    call redraw_terminal

    call show_notification
    mov esi, msg_pasted
    call print_notification
    call hide_notification_delayed

.done:
    popad
    ret



str_btn_notepad db 'N',0
str_btn_terminal db 'T',0
str_btn_explorer db 'E',0
str_btn_viewer db 'V',0
str_f12_hint db 'F12',0

str_notepad_title db 'NOTEPAD',0

str_terminal_banner db 'TERMINAL',0
str_terminal_prompt db '> ',0
str_cmd_unknown db 'COMANDO NAO ENCONTRADO',0
str_help_title db 'COMANDOS DISPONIVEIS:',0
str_help_dralar db 'DRALAR INSTALL <PKG>',0
str_help_run db 'RUN <APP> - EXECUTA APLICATIVO',0
str_help_clear db 'CLEAR - LIMPA A TELA',0
str_help_info db 'INFO - INFORMACOES DO SISTEMA',0
str_help_ls db 'LS - LISTA ARQUIVOS',0
str_help_echo db 'ECHO <TEXTO> - IMPRIME TEXTO',0
str_help_power db 'POWER <MODO> - PLANO DE ENERGIA',0
str_help_module db 'MODULE LOAD/UNLOAD/LIST',0
str_help_taskmgr db 'TASKMGR - GERENCIADOR DE TAREFAS',0
str_info_os db 'GATITO OS V3.0',0
str_info_version db 'KERNEL 32-BIT X86',0

cmd_help db 'HELP',0
cmd_clear db 'CLEAR',0
cmd_info db 'INFO',0
cmd_ls db 'LS',0
cmd_echo db 'ECHO',0
cmd_dralar_install db 'DRALAR INSTALL ',0
cmd_run db 'RUN',0
cmd_power db 'POWER',0
cmd_module_load db 'MODULE LOAD',0
cmd_module_unload db 'MODULE UNLOAD',0
cmd_module_list db 'MODULE LIST',0
cmd_taskmgr db 'TASKMGR',0

pkg_paint_name db 'PAINT',0
pkg_network_name db 'NETWORK',0

str_dralar_usage db 'USO: DRALAR INSTALL <PACOTE>',0
str_run_usage db 'USO: RUN <APP>',0
str_pkg_not_available db 'PACOTE NAO DISPONIVEL',0
str_pkg_not_found db 'PACOTE NAO ENCONTRADO',0
str_pkg_installed db 'PACOTE INSTALADO!',0
str_pkg_already db 'PACOTE JA INSTALADO',0
str_app_not_found db 'APLICATIVO NAO ENCONTRADO',0
str_paint_not_installed db 'PAINT NAO INSTALADO',0
str_network_not_installed db 'NETWORK NAO INSTALADO',0
str_network_running db 'MODULO NETWORK CARREGADO',0

str_power_gelado db 'GELADO',0
str_power_desempenho db 'DESEMPENHO',0
str_power_status db 'STATUS',0
str_power_usage db 'USO: POWER GELADO/DESEMPENHO/STATUS',0
str_power_gelado_activated db 'MODO GELADO ATIVADO - ECONOMIA EXTREMA',0
str_power_desempenho_activated db 'MODO DESEMPENHO ATIVADO - POTENCIA MAXIMA',0
str_power_status_header db '=== STATUS DE ENERGIA ===',0
str_power_current_mode db 'MODO ATUAL: ',0
str_power_mode_normal db 'NORMAL',0
str_power_mode_gelado db 'GELADO (ECONOMIA)',0
str_power_mode_desempenho db 'DESEMPENHO (MAXIMO)',0
str_power_cpu_freq db 'CPU: ',0
str_power_mhz db ' MHZ',0
str_power_turbo db 'TURBO BOOST: ',0
str_power_on db 'ON',0
str_power_off db 'OFF',0
str_power_loop_delay db 'LOOP DELAY: ',0

str_start_title db 'GATITO START',0
str_start_hint db 'SETAS ENTER ESC WIN',0
str_start_item_notepad db 'NOTEPAD',0
str_start_item_terminal db 'TERMINAL',0
str_start_item_explorer db 'EXPLORADOR',0
str_start_item_viewer db 'VISUALIZADOR',0
str_start_item_paint db 'PAINT',0
str_start_item_info db 'INFORMACOES',0
str_start_item_taskmgr db 'TASK MANAGER',0
str_system_info_notify db 'GATITO OS V3.0 - KERNEL 32BIT',0

module_viewer_name db 'VIEWER',0
module_taskmgr_name db 'TASKMGR',0

str_module_loaded db 'MODULO CARREGADO',0
str_module_already_loaded db 'MODULO JA CARREGADO',0
str_module_unloaded db 'MODULO DESCARREGADO',0
str_module_not_found db 'MODULO NAO ENCONTRADO',0
str_module_usage db 'USO: MODULE LOAD/UNLOAD <NOME>',0
str_module_list_header db '=== MODULOS DISPONIVEIS ===',0
str_module_status_sep db ' - ',0
str_module_status_loaded db 'CARREGADO',0
str_module_status_unloaded db 'NAO CARREGADO',0

str_taskmgr_title db 'GERENCIADOR DE TAREFAS',0
str_taskmgr_cpu db 'CPU: ',0
str_unit_kb db ' KB',0
str_unit_mb db ' MB',0
str_unit_gb db ' GB',0
str_taskmgr_mhz db ' MHZ',0
str_taskmgr_memory db 'MEMORIA: ',0
str_taskmgr_kb db ' KB',0
str_taskmgr_processes db 'PROCESSOS: ',0
str_taskmgr_power db 'MODO ENERGIA: ',0
str_taskmgr_packages db 'PACOTES: ',0
str_taskmgr_modules db 'MODULOS: ',0
str_taskmgr_not_loaded db 'TASKMGR NAO CARREGADO',0
str_taskmgr_hint db 'R=REFRESH A=AUTO ESC=SAIR',0
str_auto_refresh_status db 'AUTO-REFRESH: ',0
str_auto_on db 'ON',0
str_auto_off db 'OFF',0

str_paint_title db 'PAINT',0
str_paint_clear db 'C',0

str_explorer_title db 'FILE EXPLORER',0
str_explorer_help db 'SETAS ENTER D N ESC',0
str_viewer_help db 'ESC P',0
str_new_file_prompt db 'NOME:',0

str_no_image db 'SEM IMAGEM',0
str_no_image_help db 'CARREGUE OUTPUT.GAT',0
str_wallpaper_set db 'WALLPAPER ATIVADO',0
str_screenshot_view db 'SCREENSHOT',0

msg_copied db 'COPIADO',0
msg_pasted db 'COLADO',0
msg_screenshot_saved db 'SCREENSHOT SALVO',0
msg_no_space db 'SEM ESPACO',0
msg_file_saved db 'ARQUIVO SALVO',0

fname_readme db 'README.TXT',0,0
fname_hello db 'HELLO.TXT',0,0,0
fname_system db 'SYSTEM.INI',0,0
fname_notes db 'NOTES.TXT',0,0,0
fname_info db 'INFO.TXT',0,0,0,0
fname_paint db 'PAINT.APP',0,0,0
fname_network db 'NETWORK.APP',0

fcontent_readme db 'BEM-VINDO AO GATITO OS V3',0
    times (FS_CONTENT_LEN - 26) db 0

fcontent_hello db 'HELLO WORLD FROM GATITO',0
    times (FS_CONTENT_LEN - 24) db 0

fcontent_system db 'VERSION 3.0 KERNEL 32BIT',0
    times (FS_CONTENT_LEN - 25) db 0

fcontent_notes db 'PACOTES: PAINT NETWORK',0
    times (FS_CONTENT_LEN - 23) db 0

fcontent_info db 'DRALAR PACKAGE MANAGER',0
    times (FS_CONTENT_LEN - 23) db 0

fcontent_paint db 'PAINT APP - DESENHE',0
    times (FS_CONTENT_LEN - 20) db 0

fcontent_network db 'MODULO DE REDE TCP/IP',0
    times (FS_CONTENT_LEN - 22) db 0


align 4
start_menu_items:
    dd str_start_item_notepad
    dd str_start_item_terminal
    dd str_start_item_explorer
    dd str_start_item_viewer
    dd str_start_item_paint
    dd str_start_item_info
    dd str_start_item_taskmgr


align 8
idt_table:
    times 256*8 db 0

idt_descriptor:
    dw (256*8)-1
    dd idt_table


kernel_end:
align 512
times 32768-($-$) db 0

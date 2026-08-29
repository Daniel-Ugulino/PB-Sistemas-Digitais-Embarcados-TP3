.equ SYS_WRITE, 64
.equ STDOUT,    1

.section .data
clear_seq:        .ascii "\x1b[2J\x1b[H"
clear_len:        .quad . - clear_seq
hide_cursor:      .ascii "\x1b[?25l"
hide_cursor_len:  .quad . - hide_cursor
show_cursor:      .ascii "\x1b[?25h"
show_cursor_len:  .quad . - show_cursor

label_input:      .ascii "\x1b[2;2HUltima tecla: "
label_input_len:  .quad . - label_input

pos_key_echo:      .ascii "\x1b[2;19H"
pos_key_echo_len:  .quad . - pos_key_echo

quit_hint:      .ascii "\x1b[4;2HWASD para ajustar, 'q' para sair"
quit_hint_len:  .quad . - quit_hint

// posiciona o texto de ajuda na linha 6
pos_help:      .ascii "\x1b[6;2H"
pos_help_len:  .quad . - pos_help

help_text:      .ascii "W: +vel max | S: -vel max | A: +zona risco | D: -zona risco"
help_text_len:  .quad . - help_text

pos_config:     .ascii "\x1b[3;2H\x1b[K"
pos_config_len: .quad . - pos_config

prefix_free:    .ascii "Zona livre: "
prefix_free_len: .quad . - prefix_free
mid_att:        .ascii " m | Atencao: "
mid_att_len:    .quad . - mid_att
mid_vel:        .ascii " m | Vel. max: "
mid_vel_len:    .quad . - mid_vel
suffix_vel:     .ascii " km/h"
suffix_vel_len: .quad . - suffix_vel

config_buf:     .space 64

.extern cfg_dist_free
.extern cfg_dist_att
.extern cfg_vel_max

.section .text

.global ui_init
ui_init:
    stp x29, x30, [sp, #-16]!

    mov x0, #STDOUT
    ldr x1, =clear_seq
    ldr x2, =clear_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    mov x0, #STDOUT
    ldr x1, =hide_cursor
    ldr x2, =hide_cursor_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    mov x0, #STDOUT
    ldr x1, =label_input
    ldr x2, =label_input_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    mov x0, #STDOUT
    ldr x1, =quit_hint
    ldr x2, =quit_hint_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    // posiciona e escreve o texto de ajuda
    mov x0, #STDOUT
    ldr x1, =pos_help
    ldr x2, =pos_help_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    mov x0, #STDOUT
    ldr x1, =help_text
    ldr x2, =help_text_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    ldp x29, x30, [sp], #16
    ret

// void ui_show_key(uint8_t key) — mostra o caractere pressionado
.global ui_show_key
ui_show_key:
    stp x29, x30, [sp, #-16]!

    strb w0, [sp, #-16]!

    mov x0, #STDOUT
    ldr x1, =pos_key_echo
    ldr x2, =pos_key_echo_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0

    mov x0, #STDOUT
    mov x1, sp
    mov x2, #1
    mov x8, #SYS_WRITE
    svc #0

    add sp, sp, #16
    ldp x29, x30, [sp], #16
    ret

// copia w3 bytes de [x2] para [x1]; retorna x1 avancado
ui_copy_n:
    cbz     w3, ui_copy_n_done
ui_copy_n_loop:
    ldrb    w4, [x2], #1
    strb    w4, [x1], #1
    subs    w3, w3, #1
    b.ne    ui_copy_n_loop
ui_copy_n_done:
    ret

// w0 = 0..255, x1 = dest; retorna x1 avancado
ui_format_byte:
    mov     w2, w0

    mov     w4, #100
    udiv    w5, w2, w4
    msub    w2, w5, w4, w2
    mov     w4, #10
    udiv    w6, w2, w4
    msub    w7, w6, w4, w2

    cbz     w5, ui_format_byte_no_hund
    add     w5, w5, #'0'
    strb    w5, [x1], #1
    b       ui_format_byte_tens

ui_format_byte_no_hund:
    cbz     w6, ui_format_byte_ones

ui_format_byte_tens:
    add     w6, w6, #'0'
    strb    w6, [x1], #1

ui_format_byte_ones:
    add     w7, w7, #'0'
    strb    w7, [x1], #1
    ret

// void ui_show_config(void) — mostra dist_free, dist_att e vel_max atuais
.global ui_show_config
ui_show_config:
    stp     x29, x30, [sp, #-32]!

    adr     x20, config_buf
    mov     x1, x20

    ldr     x2, =prefix_free
    ldr     x3, =prefix_free_len
    ldr     w3, [x3]
    bl      ui_copy_n

    adr     x9, cfg_dist_free
    ldrb    w0, [x9]
    bl      ui_format_byte

    ldr     x2, =mid_att
    ldr     x3, =mid_att_len
    ldr     w3, [x3]
    bl      ui_copy_n

    adr     x9, cfg_dist_att
    ldrb    w0, [x9]
    bl      ui_format_byte

    ldr     x2, =mid_vel
    ldr     x3, =mid_vel_len
    ldr     w3, [x3]
    bl      ui_copy_n

    adr     x9, cfg_vel_max
    ldrb    w0, [x9]
    bl      ui_format_byte

    ldr     x2, =suffix_vel
    ldr     x3, =suffix_vel_len
    ldr     w3, [x3]
    bl      ui_copy_n

    sub     x21, x1, x20

    mov     x0, #STDOUT
    ldr     x1, =pos_config
    ldr     x2, =pos_config_len
    ldr     x2, [x2]
    mov     x8, #SYS_WRITE
    svc     #0

    mov     x0, #STDOUT
    mov     x1, x20
    mov     x2, x21
    mov     x8, #SYS_WRITE
    svc     #0

    ldp     x29, x30, [sp], #32
    ret

.global ui_restore
ui_restore:
    mov x0, #STDOUT
    ldr x1, =show_cursor
    ldr x2, =show_cursor_len
    ldr x2, [x2]
    mov x8, #SYS_WRITE
    svc #0
    ret
// Enlace Raspberry Pi (master) -> Tang Nano (slave) via SPI0.
//
// write()/read() do spidev: cada chamada e UMA transacao (CS baixo
// durante todos os bytes). Evita SPI_IOC_MESSAGE, cujo tamanho da
// struct muda entre kernels e pode transferir 0 bytes.
//
// Ligacao (Pi SPI0 -> Tang Nano 9K, pins do tangnano9k.cst):
//   GPIO11 SCLK -> spi_sck (79)    GPIO10 MOSI -> spi_mosi (80)
//   GPIO9  MISO <- spi_miso (81)   GPIO8  CE0  -> spi_cs_n (82)
//   GND comum
//
// No Pi (/boot/firmware/config.txt):
//   dtparam=spi=on
//   # NAO use dtoverlay=spi1-3cs
// sudo reboot && ls /dev/spidev0.0 && sudo ./road_shield

.equ SYS_OPENAT, 56
.equ SYS_READ,   63
.equ SYS_WRITE,  64
.equ SYS_IOCTL,  29
.equ SYS_CLOSE,  57

.equ AT_FDCWD,   -100
.equ O_RDWR,     0x0002

.equ SPI_IOC_WR_MODE,          0x40016B01
.equ SPI_IOC_WR_BITS_PER_WORD, 0x40016B03
.equ SPI_IOC_WR_MAX_SPEED_HZ,  0x40046B04

.section .data
spi_path:  .asciz "/dev/spidev0.0"

spi_mode:  .byte 0
spi_bits:  .byte 8
.align 2
spi_speed: .word 250000

.section .bss
.align 8
.global spi_fd
spi_fd: .skip 8

.section .text

.global spi_open
spi_open:
    stp x29, x30, [sp, #-16]!

    mov x0, #AT_FDCWD
    ldr x1, =spi_path
    mov x2, #O_RDWR
    mov x3, #0
    mov x8, #SYS_OPENAT
    svc #0

    ldr x1, =spi_fd
    str x0, [x1]

    ldp x29, x30, [sp], #16
    ret

// int spi_is_open(void) — 1 se fd >= 0
.global spi_is_open
spi_is_open:
    ldr x0, =spi_fd
    ldr x0, [x0]
    cmp x0, #0
    cset w0, ge
    ret

.global spi_configure
spi_configure:
    stp x29, x30, [sp, #-16]!

    ldr x1, =SPI_IOC_WR_MODE
    ldr x2, =spi_mode
    bl  spi_ioctl

    ldr x1, =SPI_IOC_WR_BITS_PER_WORD
    ldr x2, =spi_bits
    bl  spi_ioctl

    ldr x1, =SPI_IOC_WR_MAX_SPEED_HZ
    ldr x2, =spi_speed
    bl  spi_ioctl

    ldp x29, x30, [sp], #16
    ret

spi_ioctl:
    ldr x0, =spi_fd
    ldr x0, [x0]
    cmp x0, #0
    b.lt spi_ioctl_skip
    mov x8, #SYS_IOCTL
    svc #0
spi_ioctl_skip:
    ret

.global spi_write_buf
spi_write_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]

    ldr x2, =spi_fd
    ldr x0, [x2]
    cmp x0, #0
    b.lt spi_write_fail

    ldp x1, x2, [sp, #16]
    mov x8, #SYS_WRITE
    svc #0

    ldp x29, x30, [sp], #32
    ret

spi_write_fail:
    mov x0, #-1
    ldp x29, x30, [sp], #32
    ret

.global spi_read_buf
spi_read_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]

    ldr x2, =spi_fd
    ldr x0, [x2]
    cmp x0, #0
    b.lt spi_read_fail

    ldp x1, x2, [sp, #16]
    mov x8, #SYS_READ
    svc #0

    ldp x29, x30, [sp], #32
    ret

spi_read_fail:
    mov x0, #-1
    ldp x29, x30, [sp], #32
    ret

.global spi_close
spi_close:
    ldr x1, =spi_fd
    ldr x0, [x1]
    cmp x0, #0
    b.lt spi_close_skip
    mov x8, #SYS_CLOSE
    svc #0
spi_close_skip:
    ret

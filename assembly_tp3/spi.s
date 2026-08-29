// Enlace Raspberry Pi (master) -> Tang Nano (slave) via SPI.
//
// Usa SPI_IOC_MESSAGE(1): uma transacao, CS baixo durante todos os bytes.
// write()/read() do spidev sao instaveis no Pi — o read() muitas vezes
// manda 0xFF no MOSI, e o FPGA aborta o pacote de velocidade.
//
// Ligacao (Pi SPI0 -> Tang Nano 9K, pins do tangnano9k.cst):
//   GPIO11 SCLK -> spi_sck (79)    GPIO10 MOSI -> spi_mosi (80)
//   GPIO9  MISO <- spi_miso (81)   GPIO8  CE0  -> spi_cs_n (82)
//   GND comum

.equ SYS_OPENAT, 56
.equ SYS_IOCTL,  29
.equ SYS_CLOSE,  57

.equ AT_FDCWD,   -100
.equ O_RDWR,     0x0002

.equ SPI_IOC_WR_MODE,          0x40016B01
.equ SPI_IOC_WR_BITS_PER_WORD, 0x40016B03
.equ SPI_IOC_WR_MAX_SPEED_HZ,  0x40046B04
.equ SPI_IOC_MESSAGE_1,        0x40206B00

.section .data
spi_path:  .asciz "/dev/spidev0.0"

spi_mode:  .byte 0
spi_bits:  .byte 8
.align 2
spi_speed: .word 250000

.section .bss
.align 8
spi_fd:    .skip 8
spi_xfer:  .skip 32
spi_dummy: .skip 16

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
    mov x8, #SYS_IOCTL
    svc #0
    ret

// zera struct spi_ioc_transfer (32 bytes) em [x3]
spi_xfer_clear:
    str xzr, [x3]
    str xzr, [x3, #8]
    str xzr, [x3, #16]
    str xzr, [x3, #24]
    ret

// ioctl SPI_IOC_MESSAGE(1) com struct em spi_xfer
spi_xfer_run:
    ldr x0, =spi_fd
    ldr x0, [x0]
    ldr x1, =SPI_IOC_MESSAGE_1
    ldr x2, =spi_xfer
    mov x8, #SYS_IOCTL
    svc #0
    ret

// long spi_write_buf(const void *buf, size_t len)
.global spi_write_buf
spi_write_buf:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1

    ldr x3, =spi_xfer
    bl  spi_xfer_clear
    str x19, [x3]
    str w20, [x3, #16]
    bl  spi_xfer_run

    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// long spi_read_buf(void *buf, size_t len)
// MOSI = zeros (spi_dummy), MISO vai para buf.
.global spi_read_buf
spi_read_buf:
    stp x29, x30, [sp, #-32]!
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1

    ldr x3, =spi_dummy
    str xzr, [x3]
    str xzr, [x3, #8]

    ldr x3, =spi_xfer
    bl  spi_xfer_clear
    ldr x0, =spi_dummy
    str x0, [x3]
    str x19, [x3, #8]
    str w20, [x3, #16]
    bl  spi_xfer_run

    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

.global spi_close
spi_close:
    ldr x1, =spi_fd
    ldr x0, [x1]
    mov x8, #SYS_CLOSE
    svc #0
    ret

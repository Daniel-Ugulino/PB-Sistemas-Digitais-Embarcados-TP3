// Enlace Raspberry Pi (master) -> Tang Nano (slave) via SPI, usando spidev.
//
// O driver spidev expoe as duas metades do protocolo com syscalls comuns:
//   write(fd, buf, n) -> transferencia so de escrita (MISO descartado)
//   read (fd, buf, n) -> transferencia so de leitura (MOSI fica em zero)
//
// Cada chamada e UMA transacao completa: o driver baixa CS, troca os n bytes
// e sobe CS. Isso casa com o enquadramento por CS do spi_slave.v — por isso o
// pacote inteiro precisa sair em uma unica chamada, e nao byte a byte.
//
// Ligacao (Pi SPI0 -> Tang Nano 9K):
//   GPIO11 SCLK -> spi_sck    GPIO10 MOSI -> spi_mosi
//   GPIO9  MISO <- spi_miso   GPIO8  CE0  -> spi_cs_n    GND comum

.equ SYS_OPENAT, 56
.equ SYS_READ,   63
.equ SYS_WRITE,  64
.equ SYS_IOCTL,  29
.equ SYS_CLOSE,  57

.equ AT_FDCWD,   -100
.equ O_RDWR,     0x0002

// ioctls do spidev, montados como _IOW('k', n, tipo)
.equ SPI_IOC_WR_MODE,          0x40016B01
.equ SPI_IOC_WR_BITS_PER_WORD, 0x40016B03
.equ SPI_IOC_WR_MAX_SPEED_HZ,  0x40046B04

.section .data
spi_path:  .asciz "/dev/spidev0.0"

spi_mode:  .byte 0            // modo 0: CPOL=0, CPHA=0 (o que spi_slave.v espera)
spi_bits:  .byte 8
.align 2
spi_speed: .word 1000000      // 1 MHz; o escravo aguenta ate ~4 MHz com clk de 27 MHz

.section .bss
.align 8
spi_fd: .skip 8

.section .text

// void spi_open(void) — abre /dev/spidev0.0 e guarda o descritor
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

// void spi_configure(void) — modo 0, 8 bits por palavra, 1 MHz
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

// x1 = request, x2 = ponteiro para o argumento
spi_ioctl:
    ldr x0, =spi_fd
    ldr x0, [x0]
    mov x8, #SYS_IOCTL
    svc #0
    ret

// long spi_write_buf(const void *buf, size_t len) — x0=buf, x1=len
// Envia o buffer em uma transacao; retorno do write em x0.
.global spi_write_buf
spi_write_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]

    ldr x2, =spi_fd
    ldr x0, [x2]
    ldp x1, x2, [sp, #16]
    mov x8, #SYS_WRITE
    svc #0

    ldp x29, x30, [sp], #32
    ret

// long spi_read_buf(void *buf, size_t len) — x0=buf, x1=len
// Clocka len bytes com MOSI em zero; retorno do read em x0.
.global spi_read_buf
spi_read_buf:
    stp x29, x30, [sp, #-32]!
    stp x0, x1, [sp, #16]

    ldr x2, =spi_fd
    ldr x0, [x2]
    ldp x1, x2, [sp, #16]
    mov x8, #SYS_READ
    svc #0

    ldp x29, x30, [sp], #32
    ret

// void spi_close(void)
.global spi_close
spi_close:
    ldr x1, =spi_fd
    ldr x0, [x1]
    mov x8, #SYS_CLOSE
    svc #0
    ret

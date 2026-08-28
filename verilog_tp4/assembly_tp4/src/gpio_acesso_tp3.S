.global _start
.section .text

_start:
        adr     x1, sim_gpio_base       // x1 = base simulada do banco GPIO

        // 1. Configura GPIO17 como saida (GPFSEL1, campo FSEL17)
        ldr     w0, [x1, #0x04]
        bic     w0, w0, #(0b111 << 21)
        orr     w0, w0, #(0b001 << 21)
        str     w0, [x1, #0x04]
        mov     x9, x0                   // x9 = GPFSEL1 apos configuracao

        // 2. Ativa GPIO17 (nivel alto) via GPSET0, refletindo em GPLEV0
        mov     w0, #(1 << 17)
        str     w0, [x1, #0x1C]          // GPSET0
        ldr     w2, [x1, #0x34]
        orr     w2, w2, #(1 << 17)       // simula o efeito fisico do GPSET0
        str     w2, [x1, #0x34]

        // 3. Le o nivel atual do GPIO17 (esperado: 1)
        ldr     w0, [x1, #0x34]
        lsr     w0, w0, #17
        and     w0, w0, #1
        mov     x10, x0                  // x10 = nivel apos ativar

        // 4. Desativa GPIO17 (nivel baixo) via GPCLR0, refletindo em GPLEV0
        mov     w0, #(1 << 17)
        str     w0, [x1, #0x28]          // GPCLR0
        ldr     w2, [x1, #0x34]
        bic     w2, w2, #(1 << 17)
        str     w2, [x1, #0x34]

        // 5. Le o nivel atual do GPIO17 (esperado: 0)
        ldr     w0, [x1, #0x34]
        lsr     w0, w0, #17
        and     w0, w0, #1
        mov     x11, x0                  // x11 = nivel apos desativar

        mov     x0, #0                   // codigo de saida = 0
        mov     x8, #93                  // syscall exit
        svc     #0

.section .bss
.align 3
sim_gpio_base:
        .space 0x38

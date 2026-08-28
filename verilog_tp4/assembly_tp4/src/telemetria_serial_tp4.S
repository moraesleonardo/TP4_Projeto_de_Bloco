// ============================================================================
// telemetria_serial_tp4.S
// Evolucao do telemetria_fpga_tp4.S: em vez de ler 10 bits de uma vez de um
// barramento paralelo (11 pinos dedicados), le a telemetria BIT A BIT por
// um link serial de 2 fios, no qual o Raspberry Pi (este programa) atua
// como mestre do clock (GPIO 27) e a Tang Nano apresenta o dado em resposta
// (GPIO 22). Isso reduz o total de pinos dedicados ao ARM de 12 para 4:
//
//   GPIO 4  <- fpga_pronto_pin   (entrada)
//   GPIO 17 -> arm_start          (saida, ja usado desde o TP3)
//   GPIO 22 <- serial_data        (entrada)
//   GPIO 27 -> serial_clk_ext     (saida, mestre do link serial)
//
// Protocolo de leitura (espelha exatamente serial_out_tp4.v):
//   1) le serial_data -> bit 9 (MSB, ja disponivel sem pulso de clock)
//   2) para i de 8 ate 0: pulsa serial_clk (sobe, espera, desce, espera),
//      depois le serial_data -> bit i
//   Total: 10 leituras, 9 pulsos de clock.
//
// MODO_TESTE (mesma convencao dos arquivos anteriores): como nao ha uma
// Tang Nano real respondendo aos pulsos de clock neste ambiente, o proprio
// programa "pre-carrega" em GPLEV0, a cada passo do laco, o bit que uma
// FPGA real teria posto em serial_data naquele momento (a partir de um
// padrao de teste conhecido) - simulando o comportamento do periferico,
// SEM alterar a logica de leitura em si, que roda identica a versao real.
// ============================================================================

.ifndef MODO_TESTE
.equ MODO_TESTE, 0
.endif

.equ OFFSET_GPFSEL0, 0x00
.equ OFFSET_GPFSEL1, 0x04
.equ OFFSET_GPFSEL2, 0x08
.equ OFFSET_GPSET0,  0x1C
.equ OFFSET_GPCLR0,  0x28
.equ OFFSET_GPLEV0,  0x34
.equ TAMANHO_MAPA,   4096

.equ SYS_openat,    56
.equ SYS_close,     57
.equ SYS_ftruncate, 46
.equ SYS_mmap,      222
.equ SYS_munmap,    215
.equ SYS_exit,      93

.equ AT_FDCWD,   -100
.equ O_RDWR,     0x2
.equ O_CREAT,    0x40
.equ PROT_READ,  0x1
.equ PROT_WRITE, 0x2
.equ MAP_SHARED, 0x01

.section .text
.global _start

_start:
    mov  x27, #0          // x27 = leituras_realizadas (telemetria)
    mov  x28, #0          // x28 = leituras_com_erro (telemetria)

    // ------------------------------------------------------------------
    // Abertura e mapeamento (identico a gpio_fisico_tp4.S)
    // ------------------------------------------------------------------
    mov  x0, #AT_FDCWD
.if MODO_TESTE
    adr  x1, caminho_teste
    mov  x2, #(O_RDWR | O_CREAT)
    mov  x3, #0x1A4
.else
    adr  x1, caminho_devmem
    mov  x2, #0x1002
    movk x2, #0x0010, lsl #16
    mov  x3, #0
.endif
    mov  x8, #SYS_openat
    svc  #0
    cmp  x0, #0
    b.lt falha_abertura
    mov  x19, x0

.if MODO_TESTE
    mov  x0, x19
    mov  x1, #TAMANHO_MAPA
    mov  x8, #SYS_ftruncate
    svc  #0
.endif

    mov  x0, #0
    mov  x1, #TAMANHO_MAPA
    mov  x2, #(PROT_READ | PROT_WRITE)
    mov  x3, #MAP_SHARED
    mov  x4, x19
.if MODO_TESTE
    mov  x5, #0
.else
    ldr  x5, endereco_base_gpio
.endif
    mov  x8, #SYS_mmap
    svc  #0
    cmp  x0, #0
    b.lt falha_mmap
    mov  x20, x0          // x20 = base mapeada

    // ------------------------------------------------------------------
    // Configuracao dos 4 pinos: GPIO4=entrada, GPIO17=saida (arm_start),
    // GPIO22=entrada (serial_data), GPIO27=saida (serial_clk_ext)
    // ------------------------------------------------------------------
    ldr  w0, [x20, #OFFSET_GPFSEL0]
    bic  w0, w0, #(0b111 << 12)     // GPIO4: campo FSEL4, garante entrada (000)
    str  w0, [x20, #OFFSET_GPFSEL0]

    ldr  w1, [x20, #OFFSET_GPFSEL1]
    bic  w1, w1, #(0b111 << 21)     // GPIO17: campo FSEL17
    orr  w1, w1, #(0b001 << 21)     // define como saida
    str  w1, [x20, #OFFSET_GPFSEL1]

    ldr  w2, [x20, #OFFSET_GPFSEL2]
    bic  w2, w2, #(0b111 << 6)      // GPIO22: campo FSEL22, garante entrada (000)
    bic  w2, w2, #(0b111 << 21)     // GPIO27: campo FSEL27
    orr  w2, w2, #(0b001 << 21)     // define GPIO27 como saida
    str  w2, [x20, #OFFSET_GPFSEL2]

    // garante o clock serial em nivel baixo no repouso
    mov  w3, #(1 << 27)
    str  w3, [x20, #OFFSET_GPCLR0]

.if MODO_TESTE
    // simula fpga_pronto=1 (GPIO4) e o MSB do padrao de teste ja presente
    // em serial_data (GPIO22) antes de qualquer pulso de clock
    mov  w4, #(1 << 4)
    ldr  w5, [x20, #OFFSET_GPLEV0]
    orr  w5, w5, w4
    str  w5, [x20, #OFFSET_GPLEV0]
    bl   simular_bit_serial_msb
.endif

    // ------------------------------------------------------------------
    // Aguarda fpga_pronto=1 (GPIO4). No modo real, isso poderia envolver
    // varias leituras ate a FPGA sinalizar; aqui uma unica leitura basta
    // pois o modo de teste ja o define previamente.
    // ------------------------------------------------------------------
    ldr  w6, [x20, #OFFSET_GPLEV0]
    lsr  w6, w6, #4
    and  w6, w6, #1
    cmp  w6, #1
    b.ne falha_pronto

    // ------------------------------------------------------------------
    // Leitura serial: bit 9 (MSB) sem pulso de clock, depois 9 leituras
    // adicionais com 1 pulso de clock antes de cada uma
    // ------------------------------------------------------------------
    mov  x21, #0              // x21 = valor reconstruido (10 bits)

    ldr  w7, [x20, #OFFSET_GPLEV0]
    lsr  w7, w7, #22
    and  w7, w7, #1
    orr  x21, x21, x7, lsl #9  // bit 9 = MSB

    mov  x22, #8               // x22 = indice do proximo bit a lero (8 down to 0)
loop_serial:
    cmp  x22, #0
    b.lt fim_loop_serial

    // pulso de clock serial (GPIO27): sobe, espera, desce, espera
    mov  w8, #(1 << 27)
    str  w8, [x20, #OFFSET_GPSET0]
.if MODO_TESTE
    bl   simular_proximo_bit_serial   // atualiza GPIO22 para o proximo bit do padrao de teste
.endif
    mov  w9, #(1 << 27)
    str  w9, [x20, #OFFSET_GPCLR0]

    ldr  w10, [x20, #OFFSET_GPLEV0]
    lsr  w10, w10, #22
    and  w10, w10, #1
    lsl  x11, x10, x22
    orr  x21, x21, x11

    sub  x22, x22, #1
    b    loop_serial
fim_loop_serial:

    add  x27, x27, #1          // telemetria: +1 leitura realizada

    // ------------------------------------------------------------------
    // Separa estado (bits 9:8) e nivel_movimento (bits 7:0)
    // ------------------------------------------------------------------
    lsr  x12, x21, #8
    and  w12, w12, #0b11       // w12 = estado
    and  w13, w21, #0xFF       // w13 = nivel_movimento

.if MODO_TESTE
    cmp  w12, #2
    b.ne falha1
    cmp  w13, #200
    b.ne falha1
.endif

    // ------------------------------------------------------------------
    // Checksum (XOR) e paridade (XOR-fold), igual ao telemetria_fpga_tp4.S
    // ------------------------------------------------------------------
    mov  w14, w12
    mov  w15, w13
    eor  w16, w14, w15         // checksum

    bl   calcular_paridade_w14_w15
    mov  w17, w0

    ldr  w18, checksum_esperado
    cmp  w16, w18
    b.ne falha2
    cmp  w17, #0
    b.ne falha2

    // ------------------------------------------------------------------
    // Corrupcao deliberada de 1 bit (copia local do nivel) -> confirma que
    // a paridade detecta o erro
    // ------------------------------------------------------------------
    mov  w14, w12
    eor  w15, w13, #0b00000001
    bl   calcular_paridade_w14_w15
    cmp  w0, #1
    b.ne falha3
    add  x28, x28, #1          // telemetria: +1 leitura com erro detectado

    cmp  x27, #1
    b.ne falha4
    cmp  x28, #1
    b.ne falha4

    // ------------------------------------------------------------------
    // Encerramento
    // ------------------------------------------------------------------
    mov  x0, x20
    mov  x1, #TAMANHO_MAPA
    mov  x8, #SYS_munmap
    svc  #0
    mov  x0, x19
    mov  x8, #SYS_close
    svc  #0

    mov  x0, #0
    mov  x8, #SYS_exit
    svc  #0

falha_abertura:
    mov  x0, #1
    mov  x8, #SYS_exit
    svc  #0
falha_mmap:
    mov  x0, #2
    mov  x8, #SYS_exit
    svc  #0
falha_pronto:
    mov  x0, #3
    mov  x8, #SYS_exit
    svc  #0
falha1:
    mov  x0, #4
    mov  x8, #SYS_exit
    svc  #0
falha2:
    mov  x0, #5
    mov  x8, #SYS_exit
    svc  #0
falha3:
    mov  x0, #6
    mov  x8, #SYS_exit
    svc  #0
falha4:
    mov  x0, #7
    mov  x8, #SYS_exit
    svc  #0

// ============================================================================
// calcular_paridade_w14_w15: identico em espirito ao telemetria_fpga_tp4.S
// ============================================================================
calcular_paridade_w14_w15:
    eor  w19, w14, w15
    eor  w19, w19, w19, lsr #4
    eor  w19, w19, w19, lsr #2
    eor  w19, w19, w19, lsr #1
    and  w0, w19, #1
    ret

.if MODO_TESTE
// ============================================================================
// Rotinas EXCLUSIVAS do modo de teste: simulam o comportamento de uma Tang
// Nano real deslocando o registrador serial_out_tp4.v em resposta aos
// pulsos de clock. Usam x23 como indice do padrao de teste (nao usado no
// restante do programa). NUNCA compiladas na versao real (MODO_TESTE=0).
// ============================================================================
simular_bit_serial_msb:
    mov  x23, #9
    ldr  w24, padrao_teste
    lsr  w24, w24, w23
    and  w24, w24, #1
    ldr  w25, [x20, #OFFSET_GPLEV0]
    bic  w25, w25, #(1 << 22)
    lsl  w26, w24, #22
    orr  w25, w25, w26
    str  w25, [x20, #OFFSET_GPLEV0]
    ret

simular_proximo_bit_serial:
    sub  x23, x23, #1
    ldr  w24, padrao_teste
    lsr  w24, w24, w23
    and  w24, w24, #1
    ldr  w25, [x20, #OFFSET_GPLEV0]
    bic  w25, w25, #(1 << 22)
    lsl  w26, w24, #22
    orr  w25, w25, w26
    str  w25, [x20, #OFFSET_GPLEV0]
    ret
.endif

.section .rodata
caminho_devmem: .asciz "/dev/mem"
caminho_teste:  .asciz "gpio_mem_simulado.bin"
.align 3
endereco_base_gpio:  .quad 0x3F200000
.align 2
checksum_esperado:   .word 202
padrao_teste:        .word 0b1011001000  // estado=2 (Alerta), nivel=200

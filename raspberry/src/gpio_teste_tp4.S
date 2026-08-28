// gpio_teste_tp4.S
// TP4 - Teste basico de acesso fisico a GPIO via /dev/mem (secao 5.2)
//
// Demonstracao isolada dos primitivos de acesso a GPIO usados depois pelo
// protocolo completo de telemetria (telemetria_gpio_tp4.S, secao 5.4): abrir
// /dev/mem, mapear o bloco de registradores GPIO por mmap, configurar um pino
// como saida, escreve-lo em nivel alto e depois baixo, e ler de volta o
// nivel de cada vez para confirmar que a escrita teve efeito.
//
// Usa o pino GPIO17 (arm_start), o mesmo ja usado no protocolo completo, mas
// aqui de forma isolada e autocontida: nao depende de nenhuma resposta da
// Tang Nano, so verifica o proprio Raspberry Pi escrevendo e lendo seu
// proprio pino de volta.
//
// IMPORTANTE: assim como telemetria_gpio_tp4.S, precisa rodar com sudo.

.section .data
    caminho_dev_mem: .asciz "/dev/mem"
    leitura_apos_alto:  .word 0    // GPLEV0 lido logo apos escrever nivel alto
    leitura_apos_baixo: .word 0    // GPLEV0 lido logo apos escrever nivel baixo
    bit_alto_confere:   .byte 0    // 1 = o bit 17 realmente leu como 1
    bit_baixo_confere:  .byte 0    // 1 = o bit 17 realmente leu como 0

.section .text
.global _start

_start:
    // ---------------- Abre /dev/mem ----------------
    mov  x0, #-100
    adr  x1, caminho_dev_mem
    movz x2, #0x1002
    movk x2, #0x10, lsl #16
    mov  x3, #0
    mov  x8, #56
    svc  #0
    cmp  x0, #0
    b.lt erro_fatal
    mov  x19, x0

    // ---------------- Mapeia o bloco GPIO ----------------
    mov  x0, #0
    mov  x1, #4096
    mov  x2, #3
    mov  x3, #1
    mov  x4, x19
    movz x5, #0x0000
    movk x5, #0x3F20, lsl #16
    mov  x8, #222
    svc  #0
    cmn  x0, #4095
    b.hi erro_fatal
    mov  x20, x0

    // ---------------- Configura GPIO17 como saida (GPFSEL1) ----------------
    ldr  w1, [x20, #0x04]
    mov  w2, #0xE00000
    bic  w1, w1, w2
    orr  w1, w1, #0x200000
    str  w1, [x20, #0x04]

    // ---------------- Escreve nivel ALTO e le de volta ----------------
    mov  w1, #0x00020000
    str  w1, [x20, #0x1C]          // GPSET0
    ldr  w1, [x20, #0x34]          // GPLEV0
    adr  x2, leitura_apos_alto
    str  w1, [x2]
    ubfx w3, w1, #17, #1
    adr  x2, bit_alto_confere
    strb w3, [x2]                    // esperado: 1

    // ---------------- Escreve nivel BAIXO e le de volta ----------------
    mov  w1, #0x00020000
    str  w1, [x20, #0x28]           // GPCLR0
    ldr  w1, [x20, #0x34]           // GPLEV0
    adr  x2, leitura_apos_baixo
    str  w1, [x2]
    ubfx w3, w1, #17, #1
    mov  w4, #1
    eor  w3, w3, w4                   // inverte: esperado bit=0 -> confere=1
    adr  x2, bit_baixo_confere
    strb w3, [x2]

fim_calculos:
    // ---------------- Desmapeia e fecha ----------------
    mov  x0, x20
    mov  x1, #4096
    mov  x8, #215
    svc  #0
    mov  x0, x19
    mov  x8, #57
    svc  #0

    // codigo de saida: 0 = os dois testes conferem, 1 = algum divergiu
    adr  x1, bit_alto_confere
    ldrb w2, [x1]
    adr  x1, bit_baixo_confere
    ldrb w3, [x1]
    and  w2, w2, w3
    cmp  w2, #1
    mov  x0, #0
    b.eq sair
    mov  x0, #1
sair:
    mov  x8, #93
    svc  #0

erro_fatal:
    mov  x0, #3
    mov  x8, #93
    svc  #0

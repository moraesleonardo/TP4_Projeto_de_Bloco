// telemetria_gpio_tp4.S
// TP4 - Comunicacao fisica ARM-FPGA via GPIO (/dev/mem) e link serial de telemetria
//
// Implementa o lado Raspberry Pi Zero 2W do protocolo definido em
// serial_out_tp4.v: aciona o inicio do ciclo de captura na Tang Nano
// (arm_start), espera o resultado ficar pronto (fpga_pronto_pin), le o
// pacote de 15 bits (estado + nivel + checksum + paridade) gerando o
// clock serial (serial_clk_ext), e confere o checksum/paridade recebidos
// contra os valores recalculados aqui, atendendo ao item 4 da rubrica do
// TP4 (deteccao basica de erro na comunicacao ARM-FPGA).
//
// Mapeamento de pinos (GPIO do Raspberry Pi -> sinal da Tang Nano):
//   GPIO 17 (saida) -> arm_start
//   GPIO 27 (saida) -> serial_clk_ext
//   GPIO 22 (entrada) -> serial_data
//   GPIO 23 (entrada) -> fpga_pronto_pin
//
// Registradores do BCM2710A1 usados (base do bloco GPIO = 0x3F200000):
//   GPFSEL1 (offset 0x04): campos de funcao dos GPIO 10-19 (usado para GPIO17)
//   GPFSEL2 (offset 0x08): campos de funcao dos GPIO 20-29 (usado para GPIO22,23,27)
//   GPSET0  (offset 0x1C): escrita em 1 poe o pino em nivel alto
//   GPCLR0  (offset 0x28): escrita em 1 poe o pino em nivel baixo
//   GPLEV0  (offset 0x34): leitura do nivel atual de cada pino
//
// IMPORTANTE: este programa acessa memoria fisica via /dev/mem e por isso
// precisa ser executado com privilegios de root (sudo).

.section .data
    caminho_dev_mem: .asciz "/dev/mem"

    fd_dev_mem:       .quad 0      // descritor de arquivo de /dev/mem
    gpio_base_virtual: .quad 0     // endereco virtual retornado pelo mmap

    pacote_recebido:      .word 0  // os 15 bits lidos, nos bits [14:0]
    estado_recebido:      .byte 0  // 2 bits
    nivel_recebido:       .byte 0  // 8 bits
    checksum_recebido:    .byte 0  // 4 bits
    paridade_recebida:    .byte 0  // 1 bit

    checksum_calculado:   .byte 0
    paridade_calculada:   .byte 0
    checksum_confere:     .byte 0  // 1 = bateu, 0 = divergiu
    paridade_confere:     .byte 0  // 1 = bateu, 0 = divergiu

    timeout_ocorreu:      .byte 0  // 1 = o fpga_pronto_pin nunca subiu a tempo

.section .text
.global _start

// ============================================================================
// Sub-rotina de atraso por software: decrementa x9 ate zero. Usada para dar
// tempo do sincronizador de 2-3 estagios do serial_out_tp4.v (do lado da
// FPGA) capturar de forma estavel cada nivel do clock serial gerado aqui.
// ============================================================================
atraso:
    subs x9, x9, #1
    b.ne atraso
    ret

_start:
    // ---------------- Abre /dev/mem (openat, O_RDWR|O_SYNC) ----------------
    mov  x0, #-100              // AT_FDCWD (nao usado de fato, caminho e absoluto)
    adr  x1, caminho_dev_mem
    movz x2, #0x1002            // O_RDWR (0x2) | O_SYNC (0x101000), parte baixa
    movk x2, #0x10, lsl #16     // completa O_SYNC: flags = 0x101002
    mov  x3, #0                 // modo (ignorado, nao estamos criando arquivo)
    mov  x8, #56                // syscall openat
    svc  #0

    cmp  x0, #0
    b.lt erro_fatal              // fd negativo = falha ao abrir (provavelmente falta sudo)
    adr  x1, fd_dev_mem
    str  x0, [x1]
    mov  x19, x0                 // mantem o fd em x19 para uso posterior (fechar no final)

    // ---------------- Mapeia o bloco de registradores GPIO (mmap) ----------------
    mov  x0, #0                  // addr = NULL (deixa o kernel escolher)
    mov  x1, #4096                // length = 1 pagina (mais que suficiente)
    mov  x2, #3                   // prot = PROT_READ | PROT_WRITE
    mov  x3, #1                   // flags = MAP_SHARED
    mov  x4, x19                  // fd = /dev/mem
    movz x5, #0x0000               // offset (endereco fisico do bloco GPIO), parte baixa
    movk x5, #0x3F20, lsl #16      // offset = 0x3F200000
    mov  x8, #222                  // syscall mmap
    svc  #0

    cmn  x0, #4095                 // verifica se o retorno esta na faixa de erro (-4095..-1)
    b.hi erro_fatal
    adr  x1, gpio_base_virtual
    str  x0, [x1]
    mov  x20, x0                   // mantem o endereco base do GPIO em x20

    // ---------------- Configura GPFSEL1: GPIO17 como saida (arm_start) ----------------
    ldr  w1, [x20, #0x04]           // le GPFSEL1
    mov  w2, #0xE00000              // mascara do campo de 3 bits do GPIO17 (bits 23:21)
    bic  w1, w1, w2                  // limpa o campo (AND com o complemento da mascara)
    orr  w1, w1, #0x200000            // define o campo como 001 (saida)
    str  w1, [x20, #0x04]

    // ---------------- Configura GPFSEL2: GPIO22/23 entrada, GPIO27 saida ----------------
    ldr  w1, [x20, #0x08]            // le GPFSEL2
    movz w2, #0x0FC0                // mascara dos 3 campos (GPIO22, GPIO23, GPIO27), parte baixa
    movk w2, #0x00E0, lsl #16       // completa a mascara: 0xE00FC0
    bic  w1, w1, w2                    // limpa os 3 campos (22 e 23 ficam 000 = entrada)
    orr  w1, w1, #0x200000              // GPIO27 = 001 (saida); 22 e 23 permanecem entrada
    str  w1, [x20, #0x08]

    // ---------------- Aciona arm_start (GPIO17) em nivel alto ----------------
    mov  w1, #0x00020000                // mascara do bit 17
    str  w1, [x20, #0x1C]                // GPSET0

    // ---------------- Espera fpga_pronto_pin (GPIO23) subir, com timeout ----------------
    movz x21, #0x0000                     // contador de timeout, parte baixa
    movk x21, #0x0300, lsl #16            // ~50 milhoes de iteracoes de margem generosa
espera_pronto:
    ldr  w1, [x20, #0x34]                  // GPLEV0
    tst  w1, #0x00800000                    // testa o bit 23 (fpga_pronto_pin)
    b.ne pronto_detectado
    subs x21, x21, #1
    b.ne espera_pronto
    // esgotou o timeout sem ver o fpga_pronto_pin subir
    adr  x1, timeout_ocorreu
    mov  w2, #1
    strb w2, [x1]
    b    finalizar

pronto_detectado:
    // ---------------- Le o primeiro bit (MSB, bit 14 do pacote) ----------------
    ldr  w1, [x20, #0x34]                    // GPLEV0
    ubfx w2, w1, #22, #1                       // extrai o bit 22 (serial_data)
    lsl  x3, x2, #14                            // posiciona como bit 14 do pacote
    // x3 acumula o pacote sendo montado

    mov  x4, #14                                 // contador do loop: 14 bits restantes
loop_leitura_bits:
    // pulso de subida no clock serial (GPIO27)
    mov  w1, #0x08000000
    str  w1, [x20, #0x1C]                        // GPSET0: clock em alto
    mov  x9, #5000
    bl   atraso
    // le o bit atual (o registrador de deslocamento da FPGA ja avancou)
    ldr  w1, [x20, #0x34]                        // GPLEV0
    ubfx w2, w1, #22, #1                           // extrai serial_data
    sub  x5, x4, #1                                 // posicao do bit no pacote (0..13)
    lsl  x6, x2, x5
    orr  x3, x3, x6                                  // acumula o bit lido no pacote
    // desce o clock serial de volta a zero
    mov  w1, #0x08000000
    str  w1, [x20, #0x28]                             // GPCLR0: clock em baixo
    mov  x9, #5000
    bl   atraso

    subs x4, x4, #1
    b.ne loop_leitura_bits

    // ---------------- Pacote de 15 bits completo, agora em x3 ----------------
    adr  x1, pacote_recebido
    str  w3, [x1]

    // extrai os campos: estado (bits 14:13), nivel (bits 12:5), checksum (bits 4:1), paridade (bit 0)
    ubfx w5, w3, #13, #2
    adr  x1, estado_recebido
    strb w5, [x1]

    ubfx w6, w3, #5, #8
    adr  x1, nivel_recebido
    strb w6, [x1]

    ubfx w7, w3, #1, #4
    adr  x1, checksum_recebido
    strb w7, [x1]

    and  w8, w3, #1
    adr  x1, paridade_recebida
    strb w8, [x1]

    // ---------------- Recalcula checksum e paridade, e compara ----------------
    add  w10, w5, w6                    // soma = estado + nivel
    and  w10, w10, #0xF                  // checksum = soma mod 16
    adr  x1, checksum_calculado
    strb w10, [x1]

    cmp  w10, w7
    cset w11, eq
    adr  x1, checksum_confere
    strb w11, [x1]

    // paridade par sobre os 14 bits REALMENTE RECEBIDOS (estado + nivel +
    // checksum recebido): usa w7 (checksum recebido), NAO w10 (recalculado),
    // pois a paridade precisa detectar corrupcao nos bits de fato recebidos,
    // de forma independente do resultado da checagem de checksum
    eor  w12, w5, w6
    eor  w12, w12, w7
    // reduz w12 (ate 8 bits relevantes) a um unico bit de paridade
    eor  w13, w12, w12, lsr #4
    eor  w13, w13, w13, lsr #2
    eor  w13, w13, w13, lsr #1
    and  w13, w13, #1
    adr  x1, paridade_calculada
    strb w13, [x1]

    cmp  w13, w8
    cset w14, eq
    adr  x1, paridade_confere
    strb w14, [x1]

    // ---------------- arm_start permanece ligado (nao e desligado aqui) ----------------
    // Diferente de uma versao anterior deste programa, o arm_start NAO e
    // devolvido a zero ao final. Isso permite que a Tang Nano continue
    // monitorando movimento de forma continua e autonoma depois que o
    // Raspberry Pi "da a partida" uma unica vez -- necessario para a
    // demonstracao continua do MVP (LEDs reagindo a movimento), que nao
    // dependeria mais da chave DIP fisica.

finalizar:
    // ---------------- Desmapeia e fecha /dev/mem ----------------
    mov  x0, x20
    mov  x1, #4096
    mov  x8, #215                          // syscall munmap
    svc  #0

    mov  x0, x19
    mov  x8, #57                           // syscall close
    svc  #0

resultado_final:
    // Codigo de saida: 0 = sucesso (checksum E paridade batendo), 1 = timeout,
    // 2 = checksum ou paridade divergiu
    adr  x1, timeout_ocorreu
    ldrb w2, [x1]
    cmp  w2, #1
    mov  x0, #1
    b.eq sair

    adr  x1, checksum_confere
    ldrb w2, [x1]
    adr  x1, paridade_confere
    ldrb w3, [x1]
    and  w2, w2, w3
    cmp  w2, #1
    mov  x0, #0
    b.eq sair
    mov  x0, #2

sair:
    mov  x8, #93
    svc  #0

erro_fatal:
    // erro ao abrir /dev/mem ou ao mapear memoria (provavelmente falta sudo)
    mov  x0, #3
    mov  x8, #93
    svc  #0

// ============================================================================
// telemetria_fpga_tp4.S
// Unifica o acesso fisico a registradores GPIO (gpio_fisico_tp4.S) com a
// logica de checksum/paridade (comunicacao_fpga_tp4.S): le de fato os pinos
// de telemetria expostos por top_tp4.v (fpga_estado_pins, fpga_nivel_pins,
// fpga_pronto_pin) via mmap de GPLEV0, monta o pacote [estado, nivel],
// calcula checksum (XOR) e paridade (XOR-fold de todos os bits), verifica a
// integridade e atualiza contadores de telemetria em memoria.
//
// Mapeamento fisico de pinos proposto (Raspberry Pi Zero 2W <- Tang Nano 20K,
// a ser refletido no arquivo de restricoes .cst da Tang Nano na sintese):
//   GPIO 4      <- fpga_pronto_pin
//   GPIO 5,6    <- fpga_estado_pins[1:0]   (GPIO5=bit0, GPIO6=bit1)
//   GPIO 20..27 <- fpga_nivel_pins[7:0]    (GPIO20=bit0 ... GPIO27=bit7)
//   GPIO 17     -> arm_start (sentido ARM->FPGA, ja usado desde o TP3)
//
// MODO_TESTE (mesma convencao de gpio_fisico_tp4.S: montar com
// "as --defsym MODO_TESTE=1 ..."): usa um arquivo comum no lugar de
// /dev/mem e PRE-CARREGA um valor conhecido em GPLEV0 antes da leitura,
// simulando "como se o hardware tivesse deixado esse padrao nos pinos".
// Isso permite validar aqui a mecanica de extracao de bits e o calculo de
// checksum/paridade sobre um dado que passou pelo MESMO caminho de leitura
// fisica (mmap + GPLEV0) que sera usado no Raspberry Pi real - diferente de
// comunicacao_fpga_tp4.S, que testava a logica de checksum isoladamente,
// sem envolver a leitura de GPIO.
//
// O que este teste NAO pode confirmar (exige o hardware real): que os
// valores lidos em GPLEV0 correspondem de fato ao estado logico gerado
// pela FPGA no outro lado da conexao fisica.
// ============================================================================

.ifndef MODO_TESTE
.equ MODO_TESTE, 0
.endif

.equ OFFSET_GPLEV0, 0x34
.equ TAMANHO_MAPA,  4096

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
    // Abertura e mapeamento (identico em espirito a gpio_fisico_tp4.S)
    // ------------------------------------------------------------------
    mov  x0, #AT_FDCWD
.if MODO_TESTE
    adr  x1, caminho_teste
    mov  x2, #(O_RDWR | O_CREAT)
    mov  x3, #0x1A4
.else
    adr  x1, caminho_devmem
    mov  x2, #0x1002
    movk x2, #0x0010, lsl #16   // O_RDWR | O_SYNC = 0x101002 (ver gpio_fisico_tp4.S)
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

.if MODO_TESTE
    // ------------------------------------------------------------------
    // Apenas no modo de teste: pre-carrega em GPLEV0 o padrao de bits que,
    // no hardware real, corresponderia a estado=2 (Alerta) e nivel=200,
    // com fpga_pronto_pin=1. Valor calculado e conferido em Python antes
    // da escrita deste arquivo: 0x0C800050.
    // ------------------------------------------------------------------
    ldr  w0, valor_teste_gplev0
    str  w0, [x20, #OFFSET_GPLEV0]
.endif

    // ------------------------------------------------------------------
    // Leitura fisica real dos pinos de telemetria (GPLEV0) e extracao dos
    // 3 campos por deslocamento + mascara (mesma tecnica de bitwise_tp4.S)
    // ------------------------------------------------------------------
    ldr  w1, [x20, #OFFSET_GPLEV0]   // w1 = GPLEV0 completo

    lsr  w2, w1, #4                  // extrai fpga_pronto_pin (GPIO 4)
    and  w2, w2, #1                  // w2 = pronto

    lsr  w3, w1, #5                  // extrai fpga_estado_pins (GPIO 5,6)
    and  w3, w3, #0b11               // w3 = estado (0..2)

    lsr  w4, w1, #20                 // extrai fpga_nivel_pins (GPIO 20..27)
    and  w4, w4, #0xFF                // w4 = nivel_movimento (0..255)

    add  x27, x27, #1                // telemetria: +1 leitura realizada

    // ------------------------------------------------------------------
    // Teste 1 (leitura direta, sem corrupcao): confirma que a extracao
    // bateu com o padrao pre-carregado (apenas no modo de teste)
    // ------------------------------------------------------------------
.if MODO_TESTE
    cmp  w2, #1
    b.ne falha1
    cmp  w3, #2
    b.ne falha1
    cmp  w4, #200
    b.ne falha1
.endif

    // ------------------------------------------------------------------
    // Monta o pacote [estado, nivel], calcula checksum (XOR) e paridade
    // (XOR-fold de todos os bits de estado e nivel)
    // ------------------------------------------------------------------
    mov  w5, w3                      // w5 = byte0 = estado
    mov  w6, w4                      // w6 = byte1 = nivel_movimento
    eor  w7, w5, w6                  // w7 = checksum = byte0 XOR byte1

    bl   calcular_paridade_w5_w6      // w0 = bit de paridade (XOR-fold de w5,w6)
    mov  w8, w0                       // w8 = paridade calculada agora

    // valores esperados (calculados em Python): checksum=202 (0xCA), paridade=0
    ldr  w9, checksum_esperado
    cmp  w7, w9
    b.ne falha2
    cmp  w8, #0
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 2: corrompe deliberadamente 1 bit do "nivel" recebido e
    // confirma que a paridade DETECTA a corrupcao (muda de 0 para 1)
    // ------------------------------------------------------------------
    mov  w5, w3
    eor  w6, w4, #0b00000001          // corrompe 1 bit do nivel (copia local)
    bl   calcular_paridade_w5_w6
    cmp  w0, #1                        // paridade DEVE indicar erro agora
    b.ne falha3

    add  x28, x28, #1                  // telemetria: +1 leitura com erro detectado

    // ------------------------------------------------------------------
    // Teste 3: confere os contadores finais de telemetria
    // esperado: leituras_realizadas=1, leituras_com_erro=1
    // ------------------------------------------------------------------
    cmp  x27, #1
    b.ne falha4
    cmp  x28, #1
    b.ne falha4

    // ------------------------------------------------------------------
    // Encerramento: desfaz o mapeamento e fecha o descritor
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
falha1:
    mov  x0, #3
    mov  x8, #SYS_exit
    svc  #0
falha2:
    mov  x0, #4
    mov  x8, #SYS_exit
    svc  #0
falha3:
    mov  x0, #5
    mov  x8, #SYS_exit
    svc  #0
falha4:
    mov  x0, #6
    mov  x8, #SYS_exit
    svc  #0

// ============================================================================
// calcular_paridade_w5_w6: recebe 2 bytes em w5/w6 e retorna em w0 o bit de
// paridade (0 = numero par de bits em 1 no total, 1 = numero impar),
// dobrando os bits com EOR sucessivos (sem usar bl para outras rotinas,
// evitando o problema de link register ja identificado e corrigido em
// comunicacao_fpga_tp4.S).
// ============================================================================
calcular_paridade_w5_w6:
    eor  w10, w5, w6      // combina os dois bytes
    eor  w10, w10, w10, lsr #4
    eor  w10, w10, w10, lsr #2
    eor  w10, w10, w10, lsr #1
    and  w0, w10, #1
    ret

.section .rodata
caminho_devmem: .asciz "/dev/mem"
caminho_teste:  .asciz "gpio_mem_simulado.bin"
.align 3
endereco_base_gpio:  .quad 0x3F200000
.align 2
valor_teste_gplev0:  .word 0x0C800050
checksum_esperado:   .word 202

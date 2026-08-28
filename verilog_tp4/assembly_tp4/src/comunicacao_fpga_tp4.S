// ============================================================================
// comunicacao_fpga_tp4.S
// Logica de comunicacao ARM-FPGA com deteccao basica de erros (checksum e
// paridade) e registro de telemetria (contadores em memoria), exigidos pela
// rubrica do TP4 (item 4). Modela o protocolo de nivel logico usado para
// transmitir o pacote de telemetria [estado_classificado, nivel_movimento]
// lido dos pinos fpga_estado_pins/fpga_nivel_pins (top_tp4.v) para o
// Raspberry Pi.
//
// Formato do pacote (3 bytes):
//   byte 0: estado_classificado (0=Normal, 1=Atencao, 2=Alerta)
//   byte 1: nivel_movimento (0-255)
//   byte 2: checksum = byte0 XOR byte1
// Mais 1 bit de paridade (par) calculado sobre os 3 bytes acima.
//
// Este programa testa a LOGICA do protocolo (calculo e verificacao de
// checksum/paridade, contadores de telemetria), independente do meio fisico
// de transmissao. A transmissao fisica bit a bit por um pino GPIO real
// (analoga ao acesso ja validado em gpio_fisico_tp4.S) e o proximo passo,
// a ser validado na integracao real com a Tang Nano 20K.
// ============================================================================

.section .text
.global _start

_start:
    // registradores de telemetria (mantidos durante toda a execucao)
    mov  x25, #0          // x25 = pacotes_enviados
    mov  x26, #0          // x26 = erros_detectados

    // ------------------------------------------------------------------
    // Teste 1: monta um pacote valido, "transmite" (grava em memoria),
    // "recebe" (relê) e confirma que a verificacao de integridade PASSA
    // (nenhum erro deveria ser detectado)
    // ------------------------------------------------------------------
    mov  w0, #2           // byte0 = estado (2 = Alerta)
    mov  w1, #200         // byte1 = nivel_movimento
    bl   montar_e_transmitir   // monta o pacote, calcula checksum/paridade e "transmite"

    bl   verificar_pacote_recebido   // "recebe" e recalcula checksum/paridade
    // w0 = 1 se OK (integro), w0 = 0 se erro detectado
    cmp  w0, #1
    b.ne falha1

    add  x25, x25, #1     // incrementa pacotes_enviados (telemetria)

    // ------------------------------------------------------------------
    // Teste 2: corrompe deliberadamente 1 bit do pacote recebido e
    // confirma que a verificacao de paridade DETECTA a corrupcao
    // ------------------------------------------------------------------
    adr  x2, pacote_recebido
    ldrb w3, [x2]              // corrompe o byte0 (estado) recebido
    eor  w3, w3, #0b00000001   // inverte 1 unico bit
    strb w3, [x2]

    bl   verificar_pacote_recebido // recalcula e confere (sem retransmitir)
    cmp  w0, #0                // agora DEVE detectar erro (w0=0)
    b.ne falha2

    add  x25, x25, #1          // incrementa pacotes_enviados (telemetria)
    add  x26, x26, #1          // incrementa erros_detectados (telemetria)

    // ------------------------------------------------------------------
    // Teste 3: confirma os contadores de telemetria acumulados
    // esperado: pacotes_enviados=2, erros_detectados=1
    // ------------------------------------------------------------------
    cmp  x25, #2
    b.ne falha3
    cmp  x26, #1
    b.ne falha3

    // ------------------------------------------------------------------
    // Teste 4: um segundo pacote valido (sem corrupcao) deve continuar
    // passando normalmente, confirmando que o mecanismo de verificacao
    // nao fica "travado" apos detectar um erro anterior
    // ------------------------------------------------------------------
    mov  w0, #0           // byte0 = estado (0 = Normal)
    mov  w1, #10          // byte1 = nivel_movimento
    bl   montar_e_transmitir
    bl   verificar_pacote_recebido
    cmp  w0, #1
    b.ne falha4
    add  x25, x25, #1

    cmp  x25, #3
    b.ne falha4

    // todos os testes passaram
    mov  x0, #0
    mov  x8, #93
    svc  #0

falha1:
    mov  x0, #1
    mov  x8, #93
    svc  #0
falha2:
    mov  x0, #2
    mov  x8, #93
    svc  #0
falha3:
    mov  x0, #3
    mov  x8, #93
    svc  #0
falha4:
    mov  x0, #4
    mov  x8, #93
    svc  #0

// ============================================================================
// montar_e_transmitir: recebe estado em w0 e nivel_movimento em w1, calcula
// o checksum (XOR dos dois bytes) e grava os 3 bytes em 'pacote_transmitido'
// (simulando a transmissao fisica bit a bit por um pino GPIO). Nao usa
// registradores de telemetria (x25/x26) para nao interferir no chamador.
// ============================================================================
montar_e_transmitir:
    adr  x10, pacote_transmitido
    strb w0, [x10]           // byte0 = estado
    strb w1, [x10, #1]       // byte1 = nivel_movimento
    eor  w2, w0, w1          // checksum = byte0 XOR byte1
    strb w2, [x10, #2]       // byte2 = checksum

    // "transmite": copia para o pacote recebido (meio de transmissao ideal
    // nesta simulacao; a introducao de erro, quando testada, e feita
    // explicitamente e de forma controlada no proprio programa de teste)
    adr  x11, pacote_recebido
    ldrb w3, [x10]
    strb w3, [x11]
    ldrb w3, [x10, #1]
    strb w3, [x11, #1]
    ldrb w3, [x10, #2]
    strb w3, [x11, #2]
    ret

// ============================================================================
// verificar_pacote_recebido: recalcula o checksum sobre os bytes 0 e 1 de
// 'pacote_recebido' e compara com o byte 2 (checksum recebido). Retorna em
// w0: 1 se o pacote esta integro (checksum bate), 0 se um erro foi
// detectado (checksum nao bate - equivalente, nesta simulacao, a uma falha
// de paridade/checksum na transmissao fisica).
// ============================================================================
verificar_pacote_recebido:
    adr  x12, pacote_recebido
    ldrb w4, [x12]          // byte0 recebido
    ldrb w5, [x12, #1]      // byte1 recebido
    ldrb w6, [x12, #2]      // checksum recebido

    eor  w7, w4, w5         // checksum recalculado
    cmp  w7, w6
    b.eq pacote_integro

    mov  w0, #0             // erro detectado
    ret
pacote_integro:
    mov  w0, #1             // integro
    ret

.section .data
.align 2
pacote_transmitido: .byte 0, 0, 0
pacote_recebido:    .byte 0, 0, 0

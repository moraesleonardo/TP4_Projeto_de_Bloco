// bitwise_tp4.S
// TP4 - Mascaras, shifts, rotacoes e combinacoes bitwise em Assembly ARM64
//
// Contexto do projeto: o pacote de telemetria enviado pela FPGA ao
// Raspberry Pi (detalhado no Capitulo 5) empacota o estado classificado
// (2 bits: Normal/Atencao/Alerta) e o nivel de movimento (8 bits) em um
// unico campo. Esta rotina demonstra, do lado do Raspberry Pi, como
// empacotar esses dois campos em um unico registrador e como desempacota-los
// de volta, alem de uma rotacao de bits usada como etapa simples de
// espalhamento (analoga a uma etapa de checksum).
//
// Demonstra:
//   - Combinacao bitwise (ORR, AND) para empacotar/desempacotar campos
//   - Deslocamentos (LSL, LSR) para posicionar campos dentro do registrador
//   - Mascaras (AND) para extrair um campo especifico
//   - Rotacao de bits (ROR) como etapa de espalhamento

.section .data
    estado_original:  .byte 0b10        // 2 bits: 10 = Alerta
    nivel_original:   .byte 0xB4        // 8 bits: nivel de movimento = 180 (0xB4)

    pacote_empacotado:  .word 0         // resultado: estado e nivel empacotados
    estado_extraido:    .byte 0         // resultado: estado desempacotado
    nivel_extraido:     .byte 0         // resultado: nivel desempacotado
    pacote_rotacionado: .word 0         // resultado: pacote apos rotacao de espalhamento

.section .text
.global _start

_start:
    // ---------------- Empacotamento: estado (bits 9:8) | nivel (bits 7:0) ----------------
    adr x0, estado_original
    ldrb w1, [x0]              // w1 = estado_original (2 bits validos: 0b10)
    adr x0, nivel_original
    ldrb w2, [x0]              // w2 = nivel_original (8 bits: 0xB4)

    lsl w3, w1, #8              // w3 = estado deslocado para os bits 9:8
    orr w4, w3, w2               // w4 = pacote = estado(9:8) | nivel(7:0)

    adr x0, pacote_empacotado
    str w4, [x0]                // guarda o pacote empacotado (esperado: 0x02B4)

    // ---------------- Desempacotamento ----------------
    lsr w5, w4, #8               // w5 = pacote >> 8 (isola os bits do estado, com lixo acima)
    and w5, w5, #0b11            // mascara: mantem so os 2 bits validos do estado
    and w6, w4, #0xFF            // mascara: mantem so os 8 bits do nivel

    adr x0, estado_extraido
    strb w5, [x0]                 // esperado: 0b10 (igual ao estado original)
    adr x0, nivel_extraido
    strb w6, [x0]                 // esperado: 0xB4 (igual ao nivel original)

    // ---------------- Rotacao de bits (espalhamento simples) ----------------
    // Rotaciona o pacote de 32 bits em 4 posicoes para a direita, uma forma
    // simples de espalhar os bits do pacote antes de uma etapa de checksum
    // (o calculo de checksum real e feito no lado da FPGA/Raspberry Pi no
    // protocolo serial do Capitulo 5; aqui demonstra-se apenas a operacao
    // de rotacao em si, um bloco de construcao comum para esse tipo de calculo)
    ror w7, w4, #4

    adr x0, pacote_rotacionado
    str w7, [x0]

fim_calculos:
    // Encerra o programa devolvendo em x0 o nivel extraido, para
    // conferencia rapida via echo $? (deve bater com o nivel original, 0xB4 = 180)
    mov x0, x6
    mov x8, #93
    svc #0

// ============================================================================
// bitwise_tp4.S
// Manipulacao numerica com mascaras, shifts, rotacoes e combinacoes bitwise
// em Assembly ARM64. Usa como cenario a extracao/montagem de campos de bits,
// no mesmo espirito do mapeamento de registradores GPIO do TP3 (onde campos
// como FSEL17 eram extraidos/ajustados dentro de um registrador de 32 bits).
//
// Programa auto-verificavel (mesmo padrao dos arquivos anteriores).
// ============================================================================

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Teste 1: extracao de campo de bits com shift + mascara
    // valor = 0xABCD1234; extrai o byte na posicao 2 (bits 23:16) = 0xCD
    // ------------------------------------------------------------------
    ldr  w0, valor_base
    lsr  w1, w0, #16      // desloca o campo desejado para a posicao 0
    and  w1, w1, #0xFF    // isola apenas 1 byte
    cmp  w1, #0xCD
    b.ne falha1

    // ------------------------------------------------------------------
    // Teste 2: limpar um campo de bits (BIC) e depois definir um novo
    // valor nesse campo (ORR) - mesmo padrao usado no TP3 para FSEL17
    // valor = 0xABCD1234; zera os bits 15:8 e escreve 0x99 nessa posicao
    // resultado esperado: 0xABCD9934
    // ------------------------------------------------------------------
    ldr  w2, valor_base
    bic  w2, w2, #0xFF00        // limpa os bits 15:8
    mov  w9, #0x9900            // 0x99 ja posicionado no campo bits 15:8
    orr  w2, w2, w9             // escreve 0x99 nessa posicao
    ldr  w3, valor_esperado_t2
    cmp  w2, w3
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 3: rotacao de bits (ROR)
    // valor = 0x00000001, rotacionado 4 bits para a direita -> 0x10000000
    // ------------------------------------------------------------------
    mov  w4, #1
    ror  w4, w4, #4
    ldr  w5, valor_esperado_t3
    cmp  w4, w5
    b.ne falha3

    // ------------------------------------------------------------------
    // Teste 4: combinacao bitwise (EOR / XOR) usada como "toggle" de bits
    // valor = 0xF0F0F0F0 XOR 0xFFFFFFFF = 0x0F0F0F0F (inverte todos os bits)
    // ------------------------------------------------------------------
    ldr  w6, valor_t4
    mov  w7, #-1                // 0xFFFFFFFF (32 bits, truncado pelo proprio registrador w7)
    eor  w6, w6, w7
    ldr  w8, valor_esperado_t4
    cmp  w6, w8
    b.ne falha4

    // ------------------------------------------------------------------
    // Teste 5: teste de bit especifico com shift + and (verifica se o bit
    // 5 de um valor esta ativo) - padrao usado para status de GPIO/flags
    // valor = 0b00100000 (bit 5 ativo) -> deve confirmar bit ativo
    // ------------------------------------------------------------------
    mov  w9, #0b00100000
    lsr  w10, w9, #5
    and  w10, w10, #1
    cmp  w10, #1
    b.ne falha5

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
falha5:
    mov  x0, #5
    mov  x8, #93
    svc  #0

.section .rodata
.align 2
valor_base:            .word 0xABCD1234
valor_esperado_t2:     .word 0xABCD9934
valor_esperado_t3:     .word 0x10000000
valor_t4:              .word 0xF0F0F0F0
valor_esperado_t4:     .word 0x0F0F0F0F

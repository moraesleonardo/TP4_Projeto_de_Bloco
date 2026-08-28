// ============================================================================
// conversao_tp4.S
// Conversoes entre inteiros e ponto flutuante em Assembly ARM64: inteiro ->
// double (SCVTF), double -> inteiro com truncamento (FCVTZS), e um teste de
// ida-e-volta (round-trip) para confirmar que a conversao preserva o valor
// original em casos exatos.
//
// Programa auto-verificavel (mesmo padrao de multipalavra_tp4.S): codigo de
// saida 0 = todos os testes passaram; codigo != 0 identifica o teste que
// falhou.
// ============================================================================

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Teste 1: inteiro -> double -> inteiro (ida e volta), valor positivo
    // 1234 -> 1234.0 -> 1234 (deve ser exato, sem perda)
    // ------------------------------------------------------------------
    mov   x0, #1234
    scvtf d0, x0          // d0 = (double) x0
    fcvtzs x1, d0         // x1 = (int64) d0, truncando em direcao a zero

    cmp   x1, #1234
    b.ne  falha1

    // ------------------------------------------------------------------
    // Teste 2: inteiro negativo -> double -> inteiro (ida e volta)
    // -5000 -> -5000.0 -> -5000
    // ------------------------------------------------------------------
    mov   x2, #-5000
    scvtf d1, x2
    fcvtzs x3, d1

    cmp   x3, x2
    b.ne  falha2

    // ------------------------------------------------------------------
    // Teste 3: truncamento de ponto flutuante nao inteiro
    // Valor double 7.9 (bit pattern IEEE-754 binario64) truncado -> 7
    // 0x401F999999999999 = 7.9 em double
    // ------------------------------------------------------------------
    ldr   d2, valor_7_9
    fcvtzs x4, d2

    cmp   x4, #7
    b.ne  falha3

    // ------------------------------------------------------------------
    // Teste 4: truncamento de valor negativo nao inteiro (trunca em
    // direcao a zero, nao para baixo): -7.9 -> -7 (nao -8)
    // 0xC01F999999999999 = -7.9 em double
    // ------------------------------------------------------------------
    ldr   d3, valor_menos_7_9
    fcvtzs x5, d3

    cmp   x5, #-7
    b.ne  falha4

    // ------------------------------------------------------------------
    // Teste 5: conversao inteiro -> float de precisao simples (32 bits)
    // 42 -> 42.0f, e de volta -> 42
    // ------------------------------------------------------------------
    mov   x6, #42
    scvtf s0, x6
    fcvtzs x7, s0

    cmp   x7, #42
    b.ne  falha5

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
.align 3
valor_7_9:        .double 7.9
valor_menos_7_9:  .double -7.9

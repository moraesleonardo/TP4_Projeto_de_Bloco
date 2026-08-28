// ============================================================================
// neon_float_tp4.S
// Rotina vetorial NEON para ponto flutuante: multiplicacao e multiplicacao-
// acumulacao (FMLA) elemento-a-elemento de vetores de 4 floats de precisao
// simples (registradores v0.4s .. v2.4s), demonstrando paralelizacao de
// operacoes vetoriais em ponto flutuante.
//
// Os valores de teste foram escolhidos para que os produtos sejam EXATOS em
// IEEE-754 binario32 (potencias de 2 e valores redondos), evitando qualquer
// ambiguidade de arredondamento na autoverificacao.
//
// Programa auto-verificavel (mesmo padrao dos arquivos anteriores).
// ============================================================================

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Teste 1: multiplicacao vetorial de ponto flutuante (FMUL)
    // vetor A = [2.0, 1.5, 4.0, -1.0]
    // vetor B = [3.0, 2.0, 0.5, 8.0]
    // A * B   = [6.0, 3.0, 2.0, -8.0]  (todos exatos em binario32)
    // ------------------------------------------------------------------
    adr  x0, vetor_a
    adr  x1, vetor_b
    ld1  {v0.4s}, [x0]
    ld1  {v1.4s}, [x1]

    fmul v2.4s, v0.4s, v1.4s

    adr  x2, resultado_mul
    st1  {v2.4s}, [x2]

    ldr  w3, [x2]
    ldr  w4, esperado_mul_e0     // 6.0f
    cmp  w3, w4
    b.ne falha1
    ldr  w3, [x2, #4]
    ldr  w4, esperado_mul_e1     // 3.0f
    cmp  w3, w4
    b.ne falha1
    ldr  w3, [x2, #8]
    ldr  w4, esperado_mul_e2     // 2.0f
    cmp  w3, w4
    b.ne falha1
    ldr  w3, [x2, #12]
    ldr  w4, esperado_mul_e3     // -8.0f
    cmp  w3, w4
    b.ne falha1

    // ------------------------------------------------------------------
    // Teste 2: multiplicacao-acumulacao vetorial (FMLA)
    // acumulador inicial = [1.0, 1.0, 1.0, 1.0]
    // acumulador += A * B  ->  [7.0, 4.0, 3.0, -7.0]
    // ------------------------------------------------------------------
    adr  x5, acumulador_inicial
    ld1  {v3.4s}, [x5]           // v3 = acumulador (comeca em 1.0 em cada lane)

    fmla v3.4s, v0.4s, v1.4s     // v3 = v3 + (v0 * v1)

    adr  x6, resultado_fmla
    st1  {v3.4s}, [x6]

    ldr  w7, [x6]
    ldr  w8, esperado_fmla_e0    // 7.0f
    cmp  w7, w8
    b.ne falha2
    ldr  w7, [x6, #4]
    ldr  w8, esperado_fmla_e1    // 4.0f
    cmp  w7, w8
    b.ne falha2
    ldr  w7, [x6, #8]
    ldr  w8, esperado_fmla_e2    // 3.0f
    cmp  w7, w8
    b.ne falha2
    ldr  w7, [x6, #12]
    ldr  w8, esperado_fmla_e3    // -7.0f
    cmp  w7, w8
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 3: soma vetorial de ponto flutuante (FADD), verificando o
    // registrador escalar (elemento 0) isoladamente com FMOV para conferir
    // a interoperabilidade entre o banco vetorial e o escalar de FP
    // ------------------------------------------------------------------
    adr  x9, vetor_a
    adr  x10, vetor_b
    ld1  {v4.4s}, [x9]
    ld1  {v5.4s}, [x10]
    fadd v6.4s, v4.4s, v5.4s      // [5.0, 3.5, 4.5, 7.0]

    mov  v7.s[0], v6.s[0]         // isola a lane 0 em v7
    fmov w11, s7                  // w11 = bits IEEE-754 da lane 0 (5.0f)
    ldr  w12, esperado_fadd_e0
    cmp  w11, w12
    b.ne falha3

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

.section .data
.align 4
vetor_a:            .float 2.0, 1.5, 4.0, -1.0
vetor_b:            .float 3.0, 2.0, 0.5, 8.0
acumulador_inicial: .float 1.0, 1.0, 1.0, 1.0
resultado_mul:      .word  0, 0, 0, 0
resultado_fmla:     .word  0, 0, 0, 0

.align 2
esperado_mul_e0:   .float 6.0
esperado_mul_e1:   .float 3.0
esperado_mul_e2:   .float 2.0
esperado_mul_e3:   .float -8.0
esperado_fmla_e0:  .float 7.0
esperado_fmla_e1:  .float 4.0
esperado_fmla_e2:  .float 3.0
esperado_fmla_e3:  .float -7.0
esperado_fadd_e0:  .float 5.0

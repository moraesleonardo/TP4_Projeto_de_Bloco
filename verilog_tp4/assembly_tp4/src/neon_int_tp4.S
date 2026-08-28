// ============================================================================
// neon_int_tp4.S
// Rotina vetorial NEON para inteiros: soma elemento-a-elemento de dois
// vetores de 4 inteiros de 32 bits (registradores v0.4s e v1.4s), em uma
// unica instrucao ADD vetorial, demonstrando o ganho estrutural de
// paralelizacao em relacao a um laco escalar equivalente (4 ADDs
// sequenciais em registradores de proposito geral).
//
// Registradores NEON usados: v0, v1 (entradas), v2 (saida), todos no modo
// ".4S" (4 elementos de 32 bits cada, totalizando os 128 bits do registrador
// vetorial).
//
// Programa auto-verificavel (mesmo padrao dos arquivos anteriores).
// ============================================================================

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Teste 1: soma vetorial de 4 inteiros em paralelo
    // vetor A = [10, 20, 30, 40]
    // vetor B = [1, 2, 3, 4]
    // A + B   = [11, 22, 33, 44]  (calculado em UMA instrucao ADD vetorial,
    //                              nao em 4 ADDs escalares sequenciais)
    // ------------------------------------------------------------------
    adr  x0, vetor_a
    adr  x1, vetor_b
    ld1  {v0.4s}, [x0]     // carrega os 4 inteiros de A em v0
    ld1  {v1.4s}, [x1]     // carrega os 4 inteiros de B em v1

    add  v2.4s, v0.4s, v1.4s   // soma vetorial: as 4 lanes somadas em paralelo

    adr  x2, resultado_soma
    st1  {v2.4s}, [x2]     // guarda o resultado em memoria para conferencia

    ldr  w3, [x2]          // lane 0
    cmp  w3, #11
    b.ne falha1
    ldr  w3, [x2, #4]      // lane 1
    cmp  w3, #22
    b.ne falha1
    ldr  w3, [x2, #8]      // lane 2
    cmp  w3, #33
    b.ne falha1
    ldr  w3, [x2, #12]     // lane 3
    cmp  w3, #44
    b.ne falha1

    // ------------------------------------------------------------------
    // Teste 2: multiplicacao vetorial elemento-a-elemento (MUL), para
    // demonstrar outra operacao aritmetica tambem paralelizada pelo NEON
    // vetor C = [2, 3, 4, 5]
    // vetor D = [10, 10, 10, 10]
    // C * D   = [20, 30, 40, 50]
    // ------------------------------------------------------------------
    adr  x4, vetor_c
    adr  x5, vetor_d
    ld1  {v3.4s}, [x4]
    ld1  {v4.4s}, [x5]

    mul  v5.4s, v3.4s, v4.4s

    adr  x6, resultado_mul
    st1  {v5.4s}, [x6]

    ldr  w7, [x6]
    cmp  w7, #20
    b.ne falha2
    ldr  w7, [x6, #4]
    cmp  w7, #30
    b.ne falha2
    ldr  w7, [x6, #8]
    cmp  w7, #40
    b.ne falha2
    ldr  w7, [x6, #12]
    cmp  w7, #50
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 3: comparacao estrutural - o mesmo resultado do Teste 1
    // tambem e calculado de forma ESCALAR (4 ADDs sequenciais), e os dois
    // metodos devem coincidir. Isso evidencia, no proprio codigo, que a
    // versao vetorial substitui 4 instrucoes escalares por 1 instrucao
    // vetorial (o "ganho estrutural por paralelizacao" pedido no TP4).
    // ------------------------------------------------------------------
    ldr  w8,  vetor_a_e0
    ldr  w9,  vetor_b_e0
    add  w10, w8, w9        // escalar: lane 0

    ldr  w8,  vetor_a_e1
    ldr  w9,  vetor_b_e1
    add  w11, w8, w9        // escalar: lane 1

    ldr  w8,  vetor_a_e2
    ldr  w9,  vetor_b_e2
    add  w12, w8, w9        // escalar: lane 2

    ldr  w8,  vetor_a_e3
    ldr  w9,  vetor_b_e3
    add  w13, w8, w9        // escalar: lane 3

    ldr  w14, [x2]          // reaproveita o resultado vetorial ja salvo (lane 0)
    cmp  w14, w10
    b.ne falha3
    ldr  w14, [x2, #4]
    cmp  w14, w11
    b.ne falha3
    ldr  w14, [x2, #8]
    cmp  w14, w12
    b.ne falha3
    ldr  w14, [x2, #12]
    cmp  w14, w13
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
vetor_a:         .word 10, 20, 30, 40
vetor_b:         .word 1, 2, 3, 4
vetor_c:         .word 2, 3, 4, 5
vetor_d:         .word 10, 10, 10, 10
resultado_soma:  .word 0, 0, 0, 0
resultado_mul:   .word 0, 0, 0, 0

.align 2
vetor_a_e0: .word 10
vetor_a_e1: .word 20
vetor_a_e2: .word 30
vetor_a_e3: .word 40
vetor_b_e0: .word 1
vetor_b_e1: .word 2
vetor_b_e2: .word 3
vetor_b_e3: .word 4

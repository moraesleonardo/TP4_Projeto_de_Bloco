// medicao_desempenho_tp4.S
// TP4 - Medicao de desempenho das rotinas numericas do Capitulo 4, usando
// clock_gettime (CLOCK_MONOTONIC) para medir a latencia media de cada uma.
//
// Metodologia: para cada rotina, o nucleo computacional (as mesmas
// instrucoes ja validadas nos programas do Capitulo 4) e executado
// N_ITERACOES vezes em sequencia, cronometrado do inicio ao fim com uma
// unica chamada a clock_gettime antes e outra depois. O tempo total
// decorrido e dividido pelo numero de iteracoes, produzindo a latencia
// media por execucao em nanossegundos. Rodar em lote (em vez de cronometrar
// uma unica execucao) reduz o efeito da resolucao do relogio do sistema e
// de eventuais interrupcoes do sistema operacional sobre a medida.

.equ N_ITERACOES, 10000

.section .data
    t_inicio: .quad 0, 0   // struct timespec {tv_sec, tv_nsec}
    t_fim:    .quad 0, 0

    latencia_multipalavra_ns: .quad 0
    latencia_conversao_ns:    .quad 0
    latencia_lookup_ns:       .quad 0
    latencia_bitwise_ns:      .quad 0
    latencia_neon_ns:         .quad 0

    // dados de apoio, iguais aos usados nos programas originais do Capitulo 4
    lo_a: .quad 0xFFFFFFFFFFFFFFFF
    hi_a: .quad 0x0000000000000001
    lo_b: .quad 0x0000000000000002
    hi_b: .quad 0x0000000000000000
    resultado_mp: .quad 0, 0, 0, 0, 0, 0

    nivel_movimento_int: .word 180
    nivel_maximo_f:      .float 255.0

    tabela_prioridade: .byte 0, 1, 2, 3, 5, 7, 9, 10
    nivel_consulta:    .byte 200
    resultado_lookup:  .byte 0

    estado_original: .byte 0b10
    nivel_original:  .byte 0xB4
    resultado_bitwise: .word 0

    vetor_a: .word 10, 40, 100, 200
    vetor_b: .word 5, 20, 50, 30
    resultado_neon: .word 0, 0, 0, 0

.section .text
.global _start

_start:
    // ================= 1) MULTIPALAVRA (soma/subtracao/multiplicacao 128 bits) =================
    mov x0, #1
    adr x1, t_inicio
    mov x8, #113
    svc #0

    mov x20, #N_ITERACOES
loop_multipalavra:
    ldr x0, lo_a
    ldr x1, hi_a
    ldr x2, lo_b
    ldr x3, hi_b
    adds x4, x0, x2
    adc  x5, x1, x3
    adr x6, resultado_mp
    str x4, [x6]
    str x5, [x6, #8]
    subs x4, x0, x2
    sbc  x5, x1, x3
    str x4, [x6, #16]
    str x5, [x6, #24]
    mul   x4, x0, x2
    umulh x5, x0, x2
    str x4, [x6, #32]
    str x5, [x6, #40]
    subs x20, x20, #1
    b.ne loop_multipalavra

    mov x0, #1
    adr x1, t_fim
    mov x8, #113
    svc #0
    bl calcula_media_ns
    adr x2, latencia_multipalavra_ns
    str x8, [x2]

    // ================= 2) CONVERSAO (inteiro <-> ponto flutuante) =================
    mov x0, #1
    adr x1, t_inicio
    mov x8, #113
    svc #0

    mov x20, #N_ITERACOES
loop_conversao:
    ldr w0, nivel_movimento_int
    scvtf s0, w0
    adr x1, nivel_maximo_f
    ldr s1, [x1]
    fdiv s2, s0, s1
    fmul s3, s2, s1
    fcvtzs w2, s3
    subs x20, x20, #1
    b.ne loop_conversao

    mov x0, #1
    adr x1, t_fim
    mov x8, #113
    svc #0
    bl calcula_media_ns
    adr x2, latencia_conversao_ns
    str x8, [x2]

    // ================= 3) LOOKUP TABLE (consulta indexada) =================
    mov x0, #1
    adr x1, t_inicio
    mov x8, #113
    svc #0

    mov x20, #N_ITERACOES
loop_lookup:
    adr x0, tabela_prioridade
    ldrb w4, [x0]
    adr x1, nivel_consulta
    ldrb w5, [x1]
    lsr  w5, w5, #5
    ldrb w6, [x0, w5, uxtw]
    adr x1, resultado_lookup
    strb w6, [x1]
    subs x20, x20, #1
    b.ne loop_lookup

    mov x0, #1
    adr x1, t_fim
    mov x8, #113
    svc #0
    bl calcula_media_ns
    adr x2, latencia_lookup_ns
    str x8, [x2]

    // ================= 4) BITWISE (empacotamento, mascaras, rotacao) =================
    mov x0, #1
    adr x1, t_inicio
    mov x8, #113
    svc #0

    mov x20, #N_ITERACOES
loop_bitwise:
    adr x0, estado_original
    ldrb w1, [x0]
    adr x0, nivel_original
    ldrb w2, [x0]
    lsl w3, w1, #8
    orr w4, w3, w2
    lsr w5, w4, #8
    and w5, w5, #0b11
    and w6, w4, #0xFF
    ror w7, w4, #4
    adr x0, resultado_bitwise
    str w7, [x0]
    subs x20, x20, #1
    b.ne loop_bitwise

    mov x0, #1
    adr x1, t_fim
    mov x8, #113
    svc #0
    bl calcula_media_ns
    adr x2, latencia_bitwise_ns
    str x8, [x2]

    // ================= 5) NEON SIMD (soma vetorial de inteiros) =================
    mov x0, #1
    adr x1, t_inicio
    mov x8, #113
    svc #0

    mov x20, #N_ITERACOES
loop_neon:
    adr x0, vetor_a
    adr x1, vetor_b
    ld1 {v0.4s}, [x0]
    ld1 {v1.4s}, [x1]
    add v2.4s, v0.4s, v1.4s
    adr x2, resultado_neon
    st1 {v2.4s}, [x2]
    subs x20, x20, #1
    b.ne loop_neon

    mov x0, #1
    adr x1, t_fim
    mov x8, #113
    svc #0
    bl calcula_media_ns
    adr x2, latencia_neon_ns
    str x8, [x2]

fim_medicoes:
    mov x0, #0
    mov x8, #93
    svc #0

// ---------------- Sub-rotina: calcula (t_fim - t_inicio) / N_ITERACOES em ns ----------------
// Retorna o resultado em x8 (nanossegundos por iteracao, em media)
calcula_media_ns:
    adr x2, t_inicio
    adr x3, t_fim
    ldr x4, [x2]         // t_inicio.tv_sec
    ldr x5, [x2, #8]     // t_inicio.tv_nsec
    ldr x6, [x3]         // t_fim.tv_sec
    ldr x7, [x3, #8]     // t_fim.tv_nsec
    sub x8, x6, x4       // diferenca de segundos
    movz x9, #0xCA00
    movk x9, #0x3B9A, lsl #16   // x9 = 1_000_000_000 (nanossegundos por segundo)
    mul x8, x8, x9       // convertido para nanossegundos
    sub x10, x7, x5      // diferenca de nanossegundos
    add x8, x8, x10       // total de nanossegundos decorridos
    mov x9, #N_ITERACOES
    udiv x8, x8, x9        // media por iteracao
    ret

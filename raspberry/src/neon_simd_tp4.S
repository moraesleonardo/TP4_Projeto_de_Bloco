// neon_simd_tp4.S
// TP4 - Paralelizacao com NEON SIMD (inteiro e ponto flutuante) em Assembly ARM64
//
// Contexto do projeto: em vez de processar um nivel de movimento por vez,
// esta rotina demonstra como o Raspberry Pi poderia processar 4 amostras de
// nivel de movimento (por exemplo, de 4 ciclos de captura consecutivos, ou
// de 4 pontos amostrados de um frame) em paralelo, usando as unidades NEON
// SIMD de 128 bits do processador ARM64. Sao demonstrados dois blocos
// independentes: um com vetores de inteiros, outro com vetores de floats.
//
// Demonstra:
//   - Bloco inteiro: carga vetorial (LD1), soma vetorial (ADD.4S) e extracao
//     de elemento individual (UMOV) para 4 niveis de movimento inteiros
//   - Bloco float: carga vetorial (LD1), soma vetorial (FADD.4S) para 4
//     niveis de movimento normalizados (ja convertidos para float)

.section .data
    // ---------------- Bloco inteiro: 4 niveis de movimento de duas fontes ----------------
    niveis_fonte_a: .word 10, 40, 100, 200      // ex.: niveis medidos por 4 amostras do frame atual
    niveis_fonte_b: .word 5,  20,  50,  30       // ex.: niveis medidos por 4 amostras do frame de referencia
    niveis_soma:    .word 0,  0,   0,   0        // resultado: soma elemento a elemento

    // ---------------- Bloco float: 4 niveis ja normalizados (0.0-1.0) ----------------
    niveis_norm_a: .float 0.10, 0.40, 0.70, 0.90
    niveis_norm_b: .float 0.05, 0.10, 0.20, 0.05
    niveis_norm_soma: .float 0.0, 0.0, 0.0, 0.0

.section .text
.global _start

_start:
    // ---------------- Bloco inteiro: soma vetorial de 4 niveis de movimento ----------------
    adr x0, niveis_fonte_a
    adr x1, niveis_fonte_b
    ld1 {v0.4s}, [x0]           // v0 = {10, 40, 100, 200}
    ld1 {v1.4s}, [x1]           // v1 = {5, 20, 50, 30}
    add v2.4s, v0.4s, v1.4s     // v2 = {15, 60, 150, 230} (soma elemento a elemento, em paralelo)

    adr x2, niveis_soma
    st1 {v2.4s}, [x2]           // guarda o vetor resultado na memoria

    // extrai o terceiro elemento (indice 2) do resultado inteiro, para
    // conferencia isolada: esperado 150 (100 + 50)
    umov w3, v2.s[2]

fim_calculos_inteiro:
    // ---------------- Bloco float: soma vetorial de 4 niveis normalizados ----------------
    adr x0, niveis_norm_a
    adr x1, niveis_norm_b
    ld1 {v3.4s}, [x0]           // v3 = {0.10, 0.40, 0.70, 0.90}
    ld1 {v4.4s}, [x1]           // v4 = {0.05, 0.10, 0.20, 0.05}
    fadd v5.4s, v3.4s, v4.4s    // v5 = {0.15, 0.50, 0.90, 0.95} (soma vetorial em ponto flutuante)

    adr x2, niveis_norm_soma
    st1 {v5.4s}, [x2]           // guarda o vetor resultado na memoria

fim_calculos:
    // Encerra o programa devolvendo em x0 o terceiro elemento do resultado
    // inteiro (150), para conferencia rapida via echo $?
    mov x0, x3
    mov x8, #93
    svc #0

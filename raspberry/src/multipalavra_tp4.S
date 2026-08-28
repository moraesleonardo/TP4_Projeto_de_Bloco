// multipalavra_tp4.S
// TP4 - Operacoes multi-palavra (128 bits) em Assembly ARM64
//
// Contexto do projeto: o nivel de movimento (8 bits, 0-255) detectado pela
// Tang Nano a cada ciclo de captura e acumulado aqui como "energia total de
// movimento" - um contador de 128 bits que nao estoura mesmo apos um numero
// muito grande de ciclos de deteccao, ao contrario de um contador de 32 ou
// 64 bits que eventualmente estouraria em uma operacao de longa duracao.
//
// Um valor de 128 bits e representado como um par de registradores de 64
// bits: a metade menos significativa (lo) e a mais significativa (hi).
//
// Demonstra:
//   - Soma de 128 bits com propagacao de carry (ADDS + ADCS)
//   - Subtracao de 128 bits com propagacao de borrow (SUBS + SBCS)
//   - Multiplicacao de 64x64 bits produzindo um resultado de 128 bits
//     (MUL para os bits baixos, UMULH para os bits altos)

.section .data
    // operando A (128 bits): hi_a:lo_a
    lo_a: .quad 0xFFFFFFFFFFFFFFFF   // parte baixa = todos os bits em 1
    hi_a: .quad 0x0000000000000001   // parte alta = 1
    // operando B (128 bits): hi_b:lo_b
    lo_b: .quad 0x0000000000000002   // parte baixa = 2
    hi_b: .quad 0x0000000000000000   // parte alta = 0

    // resultados (128 bits cada)
    soma_lo:  .quad 0
    soma_hi:  .quad 0
    sub_lo:   .quad 0
    sub_hi:   .quad 0
    mul_lo:   .quad 0
    mul_hi:   .quad 0

.section .text
.global _start

_start:
    // ---------------- Soma de 128 bits: (hi_a:lo_a) + (hi_b:lo_b) ----------------
    // Carrega os operandos
    ldr x0, lo_a
    ldr x1, hi_a
    ldr x2, lo_b
    ldr x3, hi_b

    // Soma a parte baixa, gerando a flag de carry se houver estouro
    adds x4, x0, x2        // x4 = lo_a + lo_b, atualiza flag C
    // Soma a parte alta incorporando o carry da soma anterior
    adc  x5, x1, x3        // x5 = hi_a + hi_b + carry

    // Armazena o resultado da soma (esperado: lo=0x0000000000000001, hi=0x0000000000000002,
    // pois 0xFFFF...FFFF + 2 estoura para 1, propagando carry de +1 para a parte alta)
    adr x6, soma_lo
    str x4, [x6]
    adr x6, soma_hi
    str x5, [x6]

    // ---------------- Subtracao de 128 bits: (hi_a:lo_a) - (hi_b:lo_b) ----------------
    ldr x0, lo_a
    ldr x1, hi_a
    ldr x2, lo_b
    ldr x3, hi_b

    subs x4, x0, x2        // x4 = lo_a - lo_b, atualiza flag C (borrow invertido)
    sbc  x5, x1, x3        // x5 = hi_a - hi_b - borrow

    // Armazena o resultado da subtracao (esperado: lo=0xFFFFFFFFFFFFFFFD, hi=0x0000000000000001,
    // pois 0xFFFF...FFFF - 2 = 0xFFFF...FFFD, sem necessidade de borrow da parte alta)
    adr x6, sub_lo
    str x4, [x6]
    adr x6, sub_hi
    str x5, [x6]

    // ---------------- Multiplicacao 64x64 -> 128 bits ----------------
    // Usa valores diferentes para um teste de multiplicacao mais direto:
    // 0x0000000100000000 (2^32) * 3 = 0x0000000300000000 (cabe em 64 bits,
    // mas MUL/UMULH sempre produzem o par de 128 bits correto de qualquer forma)
    movz x0, #1, lsl #32   // x0 = 2^32
    mov x1, #3                 // x1 = 3

    mul   x4, x0, x1       // x4 = bits baixos do produto (64 bits menos significativos)
    umulh x5, x0, x1       // x5 = bits altos do produto (64 bits mais significativos)

    // Armazena o resultado da multiplicacao (esperado: lo=0x0000000300000000, hi=0x0000000000000000)
    adr x6, mul_lo
    str x4, [x6]
    adr x6, mul_hi
    str x5, [x6]

    // Encerra o programa com syscall exit, devolvendo em x0 os bits baixos
    // da soma de 128 bits (0x1), para conferencia rapida via echo $?
fim_calculos:
    ldr x0, soma_lo
    and x0, x0, #0xFF      // mantem so o byte menos significativo (codigo de saida e 8 bits)
    mov x8, #93            // syscall exit
    svc #0

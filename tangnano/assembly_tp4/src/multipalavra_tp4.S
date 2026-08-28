// ============================================================================
// multipalavra_tp4.S
// Operacoes numericas multi-palavra em Assembly ARM64: soma de 128 bits com
// propagacao de carry, subtracao de 128 bits com propagacao de borrow, e
// multiplicacao longa 64x64 -> 128 bits.
//
// Programa auto-verificavel: cada teste compara o resultado computado contra
// um valor esperado calculado a mao; se todos os testes passarem, o processo
// termina com codigo de saida 0. Caso um teste falhe, termina com um codigo
// de saida distinto (1, 2 ou 3) identificando qual teste falhou - permite
// validacao automatizada via "echo $?", sem depender de inspecao manual
// no GDB (a inspecao no GDB permanece disponivel para o relatorio).
//
// Numeros de 128 bits sao representados como um par de registradores
// (parte alta:parte baixa), convencao ja usada informalmente no projeto.
// ============================================================================

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Teste 1: soma de 128 bits com propagacao de carry
    // A = 0x0000000000000000_FFFFFFFFFFFFFFFF (hi:lo)
    // B = 0x0000000000000000_0000000000000001
    // A + B = 0x0000000000000001_0000000000000000 (estoura para o hi)
    // ------------------------------------------------------------------
    mov  x0, #-1          // x0 = A_lo = 0xFFFFFFFFFFFFFFFF
    mov  x1, #0           // x1 = A_hi = 0
    mov  x2, #1           // x2 = B_lo = 1
    mov  x3, #0           // x3 = B_hi = 0

    adds x4, x0, x2       // x4 = soma_lo, atualiza a flag de carry
    adc  x5, x1, x3       // x5 = soma_hi = A_hi + B_hi + carry

    cmp  x4, #0
    b.ne falha1
    cmp  x5, #1
    b.ne falha1

    // ------------------------------------------------------------------
    // Teste 2: subtracao de 128 bits com propagacao de borrow
    // C = 0x0000000000000001_0000000000000000 (hi:lo)
    // D = 0x0000000000000000_0000000000000001
    // C - D = 0x0000000000000000_FFFFFFFFFFFFFFFF (empresta do hi)
    // ------------------------------------------------------------------
    mov  x6, #0           // x6 = C_lo = 0
    mov  x7, #1           // x7 = C_hi = 1
    mov  x8, #1           // x8 = D_lo = 1
    mov  x9, #0           // x9 = D_hi = 0

    subs x10, x6, x8      // x10 = dif_lo, atualiza a flag de carry (carry=0 => houve borrow)
    sbc  x11, x7, x9      // x11 = dif_hi = C_hi - D_hi - borrow

    mov  x12, #-1         // x12 = valor esperado para dif_lo (0xFFFFFFFFFFFFFFFF)
    cmp  x10, x12
    b.ne falha2
    cmp  x11, #0
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 3: multiplicacao longa 64x64 -> 128 bits
    // E = 0xFFFFFFFFFFFFFFFF (2^64 - 1), F = 2
    // E * F = 2^65 - 2 = 0x0000000000000001_FFFFFFFFFFFFFFFE (hi:lo)
    // ------------------------------------------------------------------
    mov   x13, #-1        // x13 = E = 0xFFFFFFFFFFFFFFFF
    mov   x14, #2          // x14 = F = 2

    mul   x15, x13, x14    // x15 = produto_lo (64 bits menos significativos)
    umulh x16, x13, x14    // x16 = produto_hi (64 bits mais significativos, multiplicacao sem sinal)

    mov   x17, #-1
    sub   x17, x17, #1     // x17 = 0xFFFFFFFFFFFFFFFE (esperado para produto_lo)
    cmp   x15, x17
    b.ne  falha3
    cmp   x16, #1
    b.ne  falha3

    // todos os testes passaram
    mov  x0, #0
    mov  x8, #93           // syscall exit
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

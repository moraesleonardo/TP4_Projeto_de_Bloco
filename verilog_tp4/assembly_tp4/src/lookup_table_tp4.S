// ============================================================================
// lookup_table_tp4.S
// Tabela de consulta (lookup table) em Assembly ARM64: evita recalcular uma
// funcao repetidamente, substituindo o calculo por um acesso indexado a
// memoria. Usa como exemplo uma tabela de quadrados (0^2 .. 15^2),
// referenciada pelo mesmo padrao de "adr + indice*tamanho + ldr" ja usado
// na tabela de salto do TP3 (tabela_salto, secao 4.2), mas aqui indexando
// dados em vez de enderecos de rotina.
//
// Programa auto-verificavel (mesmo padrao dos arquivos anteriores).
// ============================================================================

.section .text
.global _start

_start:
    adr  x0, tabela_quadrados   // x0 = endereco base da tabela

    // ------------------------------------------------------------------
    // Teste 1: consulta do indice 5 -> deve retornar 25 (5^2)
    // ------------------------------------------------------------------
    mov  x1, #5
    ldr  w2, [x0, x1, lsl #2]   // w2 = tabela[5] (cada entrada tem 4 bytes)
    cmp  w2, #25
    b.ne falha1

    // ------------------------------------------------------------------
    // Teste 2: consulta do indice 0 -> deve retornar 0
    // ------------------------------------------------------------------
    mov  x1, #0
    ldr  w2, [x0, x1, lsl #2]
    cmp  w2, #0
    b.ne falha2

    // ------------------------------------------------------------------
    // Teste 3: consulta do ultimo indice valido (15) -> deve retornar 225
    // ------------------------------------------------------------------
    mov  x1, #15
    ldr  w2, [x0, x1, lsl #2]
    cmp  w2, #225
    b.ne falha3

    // ------------------------------------------------------------------
    // Teste 4: percorre a tabela inteira em um laco e confirma que cada
    // entrada bate com o quadrado do indice, computado por multiplicacao
    // direta (MUL), comparando os dois metodos entre si
    // ------------------------------------------------------------------
    mov  x3, #0                 // x3 = indice do laco
loop_verifica:
    cmp  x3, #16
    b.ge fim_loop_verifica
    ldr  w4, [x0, x3, lsl #2]   // w4 = tabela[indice] (metodo 1: lookup table)
    mul  w5, w3, w3             // w5 = indice*indice (metodo 2: calculo direto)
    cmp  w4, w5
    b.ne falha4
    add  x3, x3, #1
    b    loop_verifica
fim_loop_verifica:

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

.section .rodata
.align 2
tabela_quadrados:
    .word 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225

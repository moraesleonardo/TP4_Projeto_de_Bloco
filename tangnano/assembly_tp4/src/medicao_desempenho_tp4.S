// ============================================================================
// medicao_desempenho_tp4.S
// Mede o tempo de execucao (latencia) de uma rotina numerica repetida N
// vezes, usando a syscall clock_gettime(CLOCK_MONOTONIC) como cronometro,
// e imprime o resultado em nanossegundos no terminal - atendendo ao pedido
// da rubrica do TP4 de medir e documentar o desempenho (ciclos/tempo de
// execucao) das operacoes aritmeticas.
//
// A rotina medida e a soma multi-palavra de 128 bits (mesma logica de
// multipalavra_tp4.S), repetida REPETICOES vezes em um laco fechado.
//
// Este programa e autoverificavel de forma dupla:
//   1) confirma que a soma de 128 bits continua correta ao longo de todas
//      as repeticoes (nao apenas na primeira iteracao);
//   2) confirma que o tempo medido e plausivel (maior que zero e menor que
//      um limite superior generoso), descartando erros grosseiros de
//      leitura do relogio.
//
// IMPORTANTE: o valor de nanossegundos medido aqui reflete o desempenho do
// PROCESSADOR HOSPEDEIRO deste ambiente de desenvolvimento (ou, quando
// executado via qemu-aarch64, do processador que roda a emulacao) - NAO o
// desempenho real do Raspberry Pi Zero 2W. A mecanica de medicao (a
// syscall e o calculo de diferenca de tempo) e identica e sera reexecutada
// no hardware fisico para obter o numero real a documentar no relatorio.
// ============================================================================

.equ SYS_clock_gettime, 113
.equ SYS_write,         64
.equ SYS_exit,          93
.equ CLOCK_MONOTONIC,   1

.equ REPETICOES, 100000

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Marca o tempo inicial
    // ------------------------------------------------------------------
    mov  x0, #CLOCK_MONOTONIC
    adr  x1, ts_inicio
    mov  x8, #SYS_clock_gettime
    svc  #0

    // ------------------------------------------------------------------
    // Laco fechado: repete a soma de 128 bits REPETICOES vezes, verificando
    // a corretude do resultado em CADA iteracao (nao apenas na ultima)
    // ------------------------------------------------------------------
    mov  x21, #0                 // x21 = contador do laco
    mov  x22, #0x86a0            // x22 = REPETICOES = 100000 (0x000186A0)
    movk x22, #0x0001, lsl #16
loop_medicao:
    cmp  x21, x22
    b.ge fim_loop_medicao

    mov  x0, #-1                 // A_lo = 0xFFFFFFFFFFFFFFFF
    mov  x1, #0                  // A_hi = 0
    mov  x2, #1                  // B_lo = 1
    mov  x3, #0                  // B_hi = 0
    adds x4, x0, x2              // soma_lo
    adc  x5, x1, x3              // soma_hi

    cmp  x4, #0                  // verifica a cada iteracao (nao so no fim)
    b.ne falha_calculo
    cmp  x5, #1
    b.ne falha_calculo

    add  x21, x21, #1
    b    loop_medicao
fim_loop_medicao:

    // ------------------------------------------------------------------
    // Marca o tempo final
    // ------------------------------------------------------------------
    mov  x0, #CLOCK_MONOTONIC
    adr  x1, ts_fim
    mov  x8, #SYS_clock_gettime
    svc  #0

    // ------------------------------------------------------------------
    // Calcula a diferenca em nanossegundos:
    // struct timespec { long tv_sec; long tv_nsec; } (16 bytes, 2 x int64)
    // diferenca_ns = (fim.tv_sec - inicio.tv_sec)*1_000_000_000
    //              + (fim.tv_nsec - inicio.tv_nsec)
    // ------------------------------------------------------------------
    ldr  x10, ts_inicio           // tv_sec inicial
    ldr  x11, ts_inicio+8         // tv_nsec inicial
    ldr  x12, ts_fim              // tv_sec final
    ldr  x13, ts_fim+8            // tv_nsec final

    sub  x14, x12, x10             // diferenca de segundos
    mov  x15, #0xca00              // 1_000_000_000 = 0x3B9ACA00 (imediato grande demais p/ 1 instrucao)
    movk x15, #0x3b9a, lsl #16
    mul  x14, x14, x15             // diferenca de segundos, em nanossegundos

    sub  x16, x13, x11              // diferenca de nanossegundos (pode ser negativa)
    add  x17, x14, x16              // x17 = diferenca total em nanossegundos

    // ------------------------------------------------------------------
    // Verificacao de sanidade: 0 < diferenca < 10 segundos (10_000_000_000 ns)
    // ------------------------------------------------------------------
    cmp  x17, #0
    b.le falha_tempo_invalido
    mov  x18, #0xe400               // 10_000_000_000 = 0x2540BE400 (imediato grande, 3 halfwords)
    movk x18, #0x540b, lsl #16
    movk x18, #0x0002, lsl #32
    cmp  x17, x18
    b.gt falha_tempo_invalido

    // ------------------------------------------------------------------
    // Converte x17 (nanossegundos) para uma string decimal ASCII e
    // imprime no terminal - registra a evidencia numerica da medicao
    // ------------------------------------------------------------------
    mov  x0, x17
    adr  x1, buffer_texto_fim      // ponteiro para o FIM do buffer (preenchimento reverso)
    bl   converter_e_imprimir_decimal

    mov  x0, #0
    mov  x8, #SYS_exit
    svc  #0

falha_calculo:
    mov  x0, #1
    mov  x8, #SYS_exit
    svc  #0
falha_tempo_invalido:
    mov  x0, #2
    mov  x8, #SYS_exit
    svc  #0

// ============================================================================
// converter_e_imprimir_decimal: recebe um inteiro sem sinal em x0 e um
// ponteiro para o FIM de um buffer em x1; monta a representacao decimal em
// ASCII de tras para frente, adiciona a mensagem fixa antes do numero, e
// imprime tudo via syscall write. Rotina "folha" (nao chama outras
// subrotinas), evitando qualquer risco de conflito de link register.
// ============================================================================
converter_e_imprimir_decimal:
    mov  x2, #10
    mov  x3, x1                    // x3 = cursor de escrita (comeca no fim do buffer)
    mov  x4, #0                    // x4 = quantidade de digitos escritos

converter_loop:
    udiv x5, x0, x2                 // x5 = x0 / 10
    msub x6, x5, x2, x0             // x6 = x0 - (x5*10) = x0 % 10
    add  x6, x6, #'0'                // converte para caractere ASCII
    sub  x3, x3, #1
    strb w6, [x3]
    add  x4, x4, #1
    mov  x0, x5
    cbnz x0, converter_loop          // repete enquanto ainda houver digitos

    // adiciona a quebra de linha final
    mov  w6, #'\n'
    strb w6, [x1]

    // prefixo fixo da mensagem, escrito logo antes do numero
    adr  x7, prefixo_mensagem
    mov  x8, #tamanho_prefixo
copiar_prefixo:
    cbz  x8, prefixo_copiado
    sub  x3, x3, #1
    sub  x8, x8, #1
    ldrb w9, [x7, x8]
    strb w9, [x3]
    b    copiar_prefixo
prefixo_copiado:

    // calcula o tamanho total a imprimir: (fim_buffer + 1 [\n]) - inicio_real
    add  x1, x1, #1                  // inclui o '\n' no tamanho
    sub  x2, x1, x3                  // x2 = tamanho total da mensagem

    mov  x0, #1                       // fd = stdout
    mov  x1, x3                       // buffer = inicio real da mensagem
    mov  x8, #SYS_write
    svc  #0
    ret

.section .data
.align 3
ts_inicio: .quad 0, 0
ts_fim:    .quad 0, 0

.section .bss
.align 3
.lcomm buffer_texto, 128
buffer_texto_fim = buffer_texto + 128

.section .rodata
prefixo_mensagem: .ascii "tempo medido (ns): "
.equ tamanho_prefixo, . - prefixo_mensagem

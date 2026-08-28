// lookup_tabela_tp4.S
// TP4 - Tabela de consulta (lookup table) em Assembly ARM64
//
// Contexto do projeto: em vez de comparar o nivel de movimento contra
// limiares fixos em uma cadeia de decisoes (if/else if/else), esta rotina
// usa uma tabela de consulta indexada para mapear uma faixa (bucket) do
// nivel de movimento a um peso de prioridade, permitindo no futuro uma
// priorizacao mais refinada do sinal (mencionada como possivel evolucao
// do projeto desde o planejamento do TP1).
//
// O nivel de movimento (0-255) e dividido em 8 faixas iguais de 32 valores
// (nivel >> 5), e cada faixa tem um peso de prioridade associado em uma
// tabela de 8 bytes.
//
// Demonstra:
//   - Declaracao de uma tabela de consulta em memoria (.byte)
//   - Calculo de indice por deslocamento de bits (LSR)
//   - Acesso indexado a memoria (base + indice, LDRB)

.section .data
    // tabela de pesos de prioridade, uma entrada por faixa de 32 niveis:
    // faixa 0 (0-31)=peso 0, faixa 1 (32-63)=peso 1, ... faixa 7 (224-255)=peso 10
    // pesos crescem de forma nao linear, dando mais peso as faixas altas
    tabela_prioridade:
        .byte 0, 1, 2, 3, 5, 7, 9, 10

    // valores de teste: alguns niveis de movimento representativos
    niveis_teste: .byte 0, 40, 100, 130, 200, 255
    NUM_TESTES = 6

    resultados: .skip NUM_TESTES     // um byte de peso de prioridade por teste

.section .text
.global _start

_start:
    adr x0, niveis_teste       // x0 = ponteiro para o vetor de niveis de teste
    adr x1, tabela_prioridade  // x1 = ponteiro para a tabela de consulta
    adr x2, resultados         // x2 = ponteiro para onde gravar os resultados
    mov x3, #0                 // x3 = indice do teste atual

loop_consulta:
    cmp x3, #NUM_TESTES
    b.ge fim_calculos

    ldrb w4, [x0, x3]          // w4 = niveis_teste[indice]
    lsr  w5, w4, #5            // w5 = indice na tabela = nivel / 32 (desloca 5 bits)
    ldrb w6, [x1, w5, uxtw]    // w6 = tabela_prioridade[indice_tabela]
    strb w6, [x2, x3]          // resultados[indice] = peso encontrado

    add x3, x3, #1
    b loop_consulta

fim_calculos:
    // Encerra o programa devolvendo em x0 o ultimo peso calculado (nivel 255
    // deve mapear para peso 10, a faixa mais alta), para conferencia via echo $?
    ldrb w0, [x2, #(NUM_TESTES - 1)]
    mov x8, #93
    svc #0

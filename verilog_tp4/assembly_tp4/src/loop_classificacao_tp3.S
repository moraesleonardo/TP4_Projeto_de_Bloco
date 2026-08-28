.global _start
.section .text

_start:
        adr     x0, vetor_niveis      // x0 = endereco base do vetor
        mov     x1, #8                 // x1 = numero de elementos

        mov     x2, x0                 // ponteiro = base do vetor
        mov     x3, x1                 // contador = numero de elementos

        mov     x9,  #0                // contagem_normal
        mov     x10, #0                // contagem_atencao
        mov     x11, #0                // contagem_alerta

loop_for:
        cbz     x3, fim_loop_for       // if (contador == 0) sai do laco

        ldr     w4, [x2]               // w4 = *ponteiro
        bl      classifica_nivel       // chama a rotina if-elseif-else -> w5 = codigo (0,1,2)

        adr     x6, tabela_salto       // x6 = endereco base da tabela de salto
        ldr     x7, [x6, x5, lsl #3]   // x7 = tabela_salto[w5] (cada ponteiro tem 8 bytes)
        blr     x7                     // chama a rotina apontada por x7

        add     x2, x2, #4             // ponteiro++ (vetor de words de 32 bits)
        sub     x3, x3, #1             // contador--
        b       loop_for

fim_loop_for:
        mov     x0, #0                 // codigo de saida = 0
        mov     x8, #93                // syscall exit
        svc     #0

classifica_nivel:
        cmp     w4, #50
        b.lt    is_normal              // if (nivel < 50) goto is_normal

        cmp     w4, #120
        b.le    is_atencao             // else if (nivel <= 120) goto is_atencao

        mov     w5, #2                 // else: Alerta (codigo 2)
        b       fim_classifica

is_atencao:
        mov     w5, #1                 // Atencao (codigo 1)
        b       fim_classifica

is_normal:
        mov     w5, #0                 // Normal (codigo 0)

fim_classifica:
        ret                            // w5 = codigo do estado classificado

rotina_normal:
        add     x9, x9, #1             // contagem_normal++
        ret

rotina_atencao:
        add     x10, x10, #1           // contagem_atencao++
        ret

rotina_alerta:
        add     x11, x11, #1           // contagem_alerta++
        ret

.section .data
vetor_niveis:
        .word   10, 45, 60, 90, 120, 130, 200, 250

.align 3
tabela_salto:
        .xword  rotina_normal, rotina_atencao, rotina_alerta

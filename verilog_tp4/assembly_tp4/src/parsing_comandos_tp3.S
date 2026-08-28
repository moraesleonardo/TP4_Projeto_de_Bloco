.global _start
.section .text

_start:
        adr     x0, vetor_comandos     // x0 = endereco base do vetor de comandos
        mov     x1, #6                  // x1 = numero de comandos no vetor

        mov     x2, x0                  // ponteiro = base do vetor
        mov     x3, x1                  // contador = numero de comandos

        mov     x9,  #0                 // contagem_iniciar
        mov     x10, #0                 // contagem_pausar
        mov     x11, #0                 // contagem_status
        mov     x12, #0                 // contagem_resetar
        mov     x13, #0                 // contagem_invalido

loop_parsing:
        cbz     x3, fim_loop_parsing    // if (contador == 0) sai do laco

        ldrb    w4, [x2]                // w4 = *ponteiro (um byte, o caractere)
        bl      parse_comando           // interpreta o caractere -> w5 = codigo da acao

        add     x2, x2, #1              // ponteiro++ (vetor de bytes)
        sub     x3, x3, #1              // contador--
        b       loop_parsing

fim_loop_parsing:
        mov     x0, #0                  // codigo de saida = 0
        mov     x8, #93                 // syscall exit
        svc     #0

// parse_comando: recebe o caractere em w4, interpreta e conta a acao em w5
// w5: 0=iniciar, 1=pausar, 2=status, 3=resetar, 4=invalido
parse_comando:
        cmp     w4, #'i'
        b.eq    cmd_iniciar

        cmp     w4, #'p'
        b.eq    cmd_pausar

        cmp     w4, #'s'
        b.eq    cmd_status

        cmp     w4, #'r'
        b.eq    cmd_resetar

        // nenhum dos comandos validos: comando invalido
        mov     w5, #4
        add     x13, x13, #1             // contagem_invalido++
        ret

cmd_iniciar:
        mov     w5, #0
        add     x9, x9, #1               // contagem_iniciar++
        ret

cmd_pausar:
        mov     w5, #1
        add     x10, x10, #1             // contagem_pausar++
        ret

cmd_status:
        mov     w5, #2
        add     x11, x11, #1             // contagem_status++
        ret

cmd_resetar:
        mov     w5, #3
        add     x12, x12, #1             // contagem_resetar++
        ret

.section .data
vetor_comandos:
        .ascii  "ipsrxi"

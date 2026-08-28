// ============================================================================
// gpio_fisico_tp4.S
// Evolucao do gpio_acesso_tp3.S: em vez de operar sobre uma area de memoria
// alocada localmente (simulacao em memoria, TP3), este programa mapeia o
// endereco fisico real dos registradores GPIO do Raspberry Pi Zero 2W via
// /dev/mem e mmap, seguindo o mapeamento ja validado no TP3 (BCM2710A1,
// base 0x3F200000, GPIO 17: campo FSEL17 em GPFSEL1, bit 17 em GPSET0/
// GPCLR0/GPLEV0).
//
// MODO_TESTE (montagem: "as --defsym MODO_TESTE=1 ..."):
//   Como este ambiente de desenvolvimento nao possui acesso a um Raspberry
//   Pi fisico, MODO_TESTE=1 substitui /dev/mem por um arquivo comum
//   ("gpio_mem_simulado.bin"), preservando EXATAMENTE a mesma sequencia de
//   syscalls (openat, ftruncate, mmap, munmap, close) e a mesma logica de
//   manipulacao de bits. Isso permite validar aqui a MECANICA do acesso
//   mapeado em memoria (mmap funciona, os deslocamentos de bits estao
//   corretos, os valores sao persistidos e relidos corretamente).
//
//   O que o modo de teste NAO pode validar (por nao existir hardware real
//   neste ambiente): o acoplamento eletrico verdadeiro entre GPSET0/GPCLR0
//   e o nivel fisico lido em GPLEV0 - isso exige o Raspberry Pi real, e
//   permanece como validacao fisica a ser feita e fotografada/registrada
//   durante a integracao com a Tang Nano 20K.
//
// MODO_TESTE=0 (padrao, sem --defsym): usa /dev/mem real, exige privilegio
// de superusuario e so funciona no Raspberry Pi fisico.
// ============================================================================

.ifndef MODO_TESTE
.equ MODO_TESTE, 0
.endif

.equ OFFSET_GPFSEL1, 0x04
.equ OFFSET_GPSET0,  0x1C
.equ OFFSET_GPCLR0,  0x28
.equ OFFSET_GPLEV0,  0x34
.equ TAMANHO_MAPA,   4096      // 1 pagina, suficiente para os registradores usados

.equ SYS_openat,    56
.equ SYS_close,     57
.equ SYS_ftruncate, 46
.equ SYS_mmap,      222
.equ SYS_munmap,    215
.equ SYS_exit,      93

.equ AT_FDCWD, -100
.equ O_RDWR,   0x2
.equ O_CREAT,  0x40
.equ O_SYNC,   0x101000
.equ PROT_READ,  0x1
.equ PROT_WRITE, 0x2
.equ MAP_SHARED, 0x01

.section .text
.global _start

_start:
    // ------------------------------------------------------------------
    // Abertura do arquivo/dispositivo (openat)
    // ------------------------------------------------------------------
    mov  x0, #AT_FDCWD
.if MODO_TESTE
    adr  x1, caminho_teste
    mov  x2, #(O_RDWR | O_CREAT)
    mov  x3, #0x1A4          // modo 0644
.else
    adr  x1, caminho_devmem
    // O_RDWR|O_SYNC = 0x101002 (imediato grande demais para 1 instrucao):
    // halfword baixo = 0x1002 (O_RDWR=0x2 | parte baixa de O_SYNC=0x1000)
    // halfword alto  = 0x0010 (parte alta de O_SYNC)
    mov  x2, #0x1002
    movk x2, #0x0010, lsl #16
    mov  x3, #0
.endif
    mov  x8, #SYS_openat
    svc  #0
    cmp  x0, #0
    b.lt falha_abertura      // codigo de retorno negativo = erro
    mov  x19, x0             // x19 = descritor de arquivo (preservado)

.if MODO_TESTE
    // no modo de teste, garante que o arquivo comum tenha o tamanho da pagina
    mov  x0, x19
    mov  x1, #TAMANHO_MAPA
    mov  x8, #SYS_ftruncate
    svc  #0
.endif

    // ------------------------------------------------------------------
    // mmap do bloco de registradores GPIO (ou do arquivo de teste)
    // ------------------------------------------------------------------
    mov  x0, #0                       // addr = NULL (deixa o kernel escolher)
    mov  x1, #TAMANHO_MAPA             // length
    mov  x2, #(PROT_READ | PROT_WRITE) // prot
    mov  x3, #MAP_SHARED                // flags
    mov  x4, x19                        // fd
.if MODO_TESTE
    mov  x5, #0                         // offset = 0 (arquivo comum)
.else
    ldr  x5, endereco_base_gpio         // offset = 0x3F200000 (base fisica do GPIO)
.endif
    mov  x8, #SYS_mmap
    svc  #0
    cmp  x0, #0
    b.lt falha_mmap
    mov  x20, x0              // x20 = endereco base mapeado (preservado)

    // ------------------------------------------------------------------
    // Configura o GPIO 17 como saida (campo FSEL17 = bits 21:23 de GPFSEL1)
    // mesma logica de bits ja validada no TP3
    // ------------------------------------------------------------------
    ldr  w0, [x20, #OFFSET_GPFSEL1]
    bic  w0, w0, #(0b111 << 21)   // limpa o campo FSEL17
    orr  w0, w0, #(0b001 << 21)   // define FSEL17 = 001 (saida)
    str  w0, [x20, #OFFSET_GPFSEL1]

    // confere (mecanica de escrita/leitura mapeada em memoria): relendo o
    // mesmo endereco, o campo FSEL17 deve refletir o valor recem-escrito
    ldr  w1, [x20, #OFFSET_GPFSEL1]
    lsr  w2, w1, #21
    and  w2, w2, #0b111
    cmp  w2, #0b001
    b.ne falha_gpfsel1

    // ------------------------------------------------------------------
    // Ativa o GPIO 17 em nivel alto (GPSET0, bit 17)
    // ------------------------------------------------------------------
    mov  w3, #(1 << 17)
    str  w3, [x20, #OFFSET_GPSET0]
    // confere que o valor persistiu corretamente no endereco mapeado
    ldr  w4, [x20, #OFFSET_GPSET0]
    cmp  w4, w3
    b.ne falha_gpset0

    // ------------------------------------------------------------------
    // Desativa o GPIO 17 (GPCLR0, bit 17)
    // ------------------------------------------------------------------
    mov  w5, #(1 << 17)
    str  w5, [x20, #OFFSET_GPCLR0]
    ldr  w6, [x20, #OFFSET_GPCLR0]
    cmp  w6, w5
    b.ne falha_gpclr0

.if MODO_TESTE
    // ------------------------------------------------------------------
    // Apenas no modo de teste: simula um valor que o "hardware" teria
    // deixado em GPLEV0 (no Raspberry Pi real, isso reflete o nivel
    // eletrico do pino; aqui, escrevemos manualmente um valor conhecido
    // para validar a LOGICA de extracao de bit, nao o acoplamento
    // eletrico real, que exige o hardware fisico)
    // ------------------------------------------------------------------
    mov  w7, #(1 << 17)
    str  w7, [x20, #OFFSET_GPLEV0]
.endif

    // ------------------------------------------------------------------
    // Le o nivel logico atual do GPIO 17 (GPLEV0, bit 17)
    // ------------------------------------------------------------------
    ldr  w8, [x20, #OFFSET_GPLEV0]
    lsr  w9, w8, #17
    and  w9, w9, #1

.if MODO_TESTE
    cmp  w9, #1               // valor que forcamos manualmente acima
    b.ne falha_gplev0
.endif
    // fora do modo de teste, w9 contem o nivel real do pino (validado
    // fisicamente no Raspberry Pi, nao pela autoverificacao deste programa)

    // ------------------------------------------------------------------
    // Encerramento: desfaz o mapeamento e fecha o descritor
    // ------------------------------------------------------------------
    mov  x0, x20
    mov  x1, #TAMANHO_MAPA
    mov  x8, #SYS_munmap
    svc  #0

    mov  x0, x19
    mov  x8, #SYS_close
    svc  #0

    mov  x0, #0
    mov  x8, #SYS_exit
    svc  #0

falha_abertura:
    mov  x0, #1
    mov  x8, #SYS_exit
    svc  #0
falha_mmap:
    mov  x0, #2
    mov  x8, #SYS_exit
    svc  #0
falha_gpfsel1:
    mov  x0, #3
    mov  x8, #SYS_exit
    svc  #0
falha_gpset0:
    mov  x0, #4
    mov  x8, #SYS_exit
    svc  #0
falha_gpclr0:
    mov  x0, #5
    mov  x8, #SYS_exit
    svc  #0
falha_gplev0:
    mov  x0, #6
    mov  x8, #SYS_exit
    svc  #0

.section .rodata
caminho_devmem: .asciz "/dev/mem"
caminho_teste:  .asciz "gpio_mem_simulado.bin"
.align 3
endereco_base_gpio: .quad 0x3F200000

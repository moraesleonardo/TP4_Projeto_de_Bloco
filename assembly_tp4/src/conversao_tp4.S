// conversao_tp4.S
// TP4 - Conversoes entre inteiros e ponto flutuante em Assembly ARM64
//
// Contexto do projeto: o nivel de movimento produzido pela Tang Nano e um
// inteiro de 8 bits (0-255). Para fins de registro/telemetria mais
// descritivo no Raspberry Pi, esta rotina converte esse inteiro em uma
// fracao de ponto flutuante (0.0 a 1.0) representando a porcentagem do
// nivel maximo de movimento, e demonstra a conversao inversa.
//
// Demonstra:
//   - SCVTF (signed integer -> float): conversao de inteiro para float
//   - Divisao em ponto flutuante (FDIV) para normalizar em uma faixa 0.0-1.0
//   - FCVTZS (float -> signed integer, truncando): conversao inversa

.section .data
    nivel_movimento_int: .word 180        // exemplo: nivel de movimento capturado (0-255)
    nivel_maximo_f:      .float 255.0     // divisor para normalizar

    nivel_normalizado_f: .float 0.0       // resultado: fracao 0.0-1.0
    nivel_reconvertido:  .word 0          // resultado: de volta para inteiro (deve bater com o original)

.section .text
.global _start

_start:
    // ---------------- Inteiro -> float ----------------
    ldr w0, nivel_movimento_int     // w0 = 180 (inteiro de 32 bits)
    scvtf s0, w0                    // s0 = 180.0 (converte inteiro com sinal para float de precisao simples)

    // ---------------- Normalizacao: divide pelo nivel maximo ----------------
    adr x1, nivel_maximo_f
    ldr s1, [x1]                    // s1 = 255.0
    fdiv s2, s0, s1                 // s2 = 180.0 / 255.0 = 0.705882... (fracao do nivel maximo)

    adr x1, nivel_normalizado_f
    str s2, [x1]                    // guarda o resultado normalizado

    // ---------------- Conversao inversa: float -> inteiro ----------------
    // Multiplica de volta pelo nivel maximo e converte para inteiro, truncando
    fmul s3, s2, s1                 // s3 = 0.705882... * 255.0 = 180.0 (aproximadamente)
    fcvtzs w2, s3                   // w2 = 180 (trunca a parte fracionaria)

    adr x1, nivel_reconvertido
    str w2, [x1]

    // Encerra o programa devolvendo em x0 o valor reconvertido, para
    // conferencia rapida via echo $? (deve bater com o valor original, 180)
fim_calculos:
    mov x0, x2
    and x0, x0, #0xFF
    mov x8, #93
    svc #0

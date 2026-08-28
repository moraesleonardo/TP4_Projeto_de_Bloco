// ============================================================================
// frame_diff_tp4.v
// Compara, endereco a endereco, o buffer do frame atual com o buffer do
// frame de referencia (background), acumulando a soma das diferencas
// absolutas. Essa soma e o "nivel de movimento" usado pelo classificador
// ja existente (classificador_movimento_cfg.v, herdado do TP2).
//
// Implementa a tecnica de "frame differencing" (comparacao entre frames)
// prevista no MVP do TP1, na variante de "background subtraction": o frame
// de referencia e capturado uma unica vez (primeiro frame apos a
// configuracao da camera) e mantido fixo, sendo usado como base de
// comparacao para todos os frames seguintes. Essa e uma tecnica valida e
// amplamente usada de frame differencing, e simplifica o projeto ao evitar
// um mecanismo adicional de atualizacao continua do frame de referencia.
// ============================================================================
module frame_diff_tp4 #(
    parameter ADDR_W     = 6,
    parameter N_AMOSTRAS = 64
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        iniciar,               // pulso: inicia a comparacao de um frame completo
    output reg  [ADDR_W-1:0] endereco_leitura, // endereco comum aplicado aos dois buffers (atual e referencia)
    input  wire [7:0]  dado_atual,             // saida sincrona do buffer atual no endereco lido
    input  wire [7:0]  dado_referencia,        // saida sincrona do buffer de referencia no endereco lido
    output reg  [15:0] soma_diferencas,        // soma acumulada das diferencas absolutas
    output reg  [7:0]  nivel_movimento,        // soma saturada em 8 bits (nivel para o classificador)
    output reg          pronto                  // pulso de 1 ciclo ao concluir a comparacao do frame
);
    localparam OCIOSO = 3'd0, ESPERA_DADO = 3'd1, ACUMULA = 3'd2, FIM = 3'd3;
    reg [2:0]        estado;
    reg [ADDR_W:0]   contador; // precisa contar ate N_AMOSTRAS (1 bit a mais que ADDR_W)

    wire signed [8:0] diferenca     = {1'b0, dado_atual} - {1'b0, dado_referencia};
    wire       [7:0]  diferenca_abs_raw = diferenca[8] ? (~diferenca[7:0] + 1'b1) : diferenca[7:0];
    // ZONA MORTA por pixel: diferencas pequenas (<= LIMIAR_RUIDO) sao ruido do
    // sensor e contam como 0; so diferencas maiores contam como movimento real.
    // Elimina na origem o "movimento de fundo" constante entre frames, em vez de
    // tentar compensar depois via limiares do classificador.
    localparam [7:0] LIMIAR_RUIDO = 8'd3;
    wire [7:0] diferenca_abs = (diferenca_abs_raw > LIMIAR_RUIDO) ? diferenca_abs_raw : 8'd0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado <= OCIOSO;
            endereco_leitura <= {ADDR_W{1'b0}};
            soma_diferencas  <= 16'd0;
            nivel_movimento  <= 8'd0;
            pronto <= 1'b0;
            contador <= {(ADDR_W+1){1'b0}};
        end else begin
            pronto <= 1'b0;

            case (estado)
                OCIOSO: begin
                    // 'iniciar' agora chega como pulso de 1 ciclo ja pronto da FSM
                    // (gerado exatamente na transicao CAPTURA->COMPARA), entao um
                    // simples nivel basta -- sem deteccao de borda/retrigger aqui.
                    if (iniciar) begin
                        soma_diferencas  <= 16'd0;
                        contador <= {(ADDR_W+1){1'b0}};
                        endereco_leitura <= {ADDR_W{1'b0}};
                        estado <= ESPERA_DADO; // 1 ciclo de latencia da leitura sincrona da BRAM
                    end
                end
                ESPERA_DADO: begin
                    estado <= ACUMULA;
                end
                ACUMULA: begin
                    soma_diferencas <= soma_diferencas + diferenca_abs;
                    if (contador == N_AMOSTRAS-1) begin
                        estado <= FIM;
                    end else begin
                        contador <= contador + 1'b1;
                        endereco_leitura <= endereco_leitura + 1'b1;
                        estado <= ESPERA_DADO;
                    end
                end
                FIM: begin
                    // normaliza pela MEDIA da diferenca por amostra (soma / N_AMOSTRAS).
                    // Antes usava saturacao binaria (>255 -> 255), que grudava o nivel
                    // em 255 com qualquer ruido em 64 amostras. A media da diferenca
                    // absoluta por amostra da uma escala proporcional 0-255 que reflete
                    // a intensidade real do movimento. N_AMOSTRAS=64 -> divisao por 64
                    // e um shift de 6 bits a direita.
                    nivel_movimento <= soma_diferencas[13:6]; // soma / 64, limitado a 8 bits
                    pronto <= 1'b1;
                    estado <= OCIOSO;
                end
                default: estado <= OCIOSO;
            endcase
        end
    end
endmodule

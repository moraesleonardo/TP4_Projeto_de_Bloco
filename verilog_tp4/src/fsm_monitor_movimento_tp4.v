// ============================================================================
// fsm_monitor_movimento_tp4.v
// FSM do TP4: evolui a FSM do TP3 (Espera -> Captura -> Classifica -> Exibe)
// incorporando a configuracao inicial da camera (SCCB) e a etapa de
// comparacao entre frames (frame differencing), que substitui a sequencia
// de valores simulados usada no TP3 pela leitura real do buffer de imagem.
//
// Estados:
//  CONFIG   - dispara a configuracao SCCB da camera uma unica vez apos reset
//  ESPERA   - aguarda o comando de inicio (equivalente ao arm_start do TP3)
//  CAPTURA  - aguarda o pulso frame_pronto do capturador de camera
//  COMPARA  - dispara o frame_diff e aguarda o pulso 'pronto'
//  EXIBE    - mantem o resultado visivel por HOLD_CYCLES ciclos (igual TP3)
//
// A classificacao (Normal/Atencao/Alerta) permanece combinacional, feita
// pelo classificador_movimento_cfg.v (herdado do TP2) fora desta FSM, a
// partir do nivel_movimento produzido pelo frame_diff.
// ============================================================================
module fsm_monitor_movimento_tp4 #(
    parameter HOLD_CYCLES = 5
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        sccb_pronto,   // pulso: configuracao SCCB da camera concluida
    input  wire        frame_pronto,  // pulso: novo frame reduzido disponivel no buffer atual
    input  wire        diff_pronto,   // pulso: comparacao entre frames concluida
    output reg         sccb_iniciar,  // dispara a configuracao da camera (uma vez, apos reset)
    output reg         diff_iniciar,  // dispara a comparacao entre buffers
    output reg  [2:0]  estado_fsm_dbg
);
    localparam CONFIG=3'd0, ESPERA=3'd1, CAPTURA=3'd2, COMPARA=3'd3, EXIBE=3'd4;

    reg [2:0]  estado, prox_estado;
    reg [31:0] contador_exibicao;
    reg        sccb_disparado;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado <= CONFIG;
            contador_exibicao <= 32'd0;
            sccb_disparado <= 1'b0;
        end else begin
            estado <= prox_estado;

            if (estado == CONFIG && !sccb_disparado)
                sccb_disparado <= 1'b1;

            if (estado == EXIBE)
                contador_exibicao <= contador_exibicao + 1'b1;
            else
                contador_exibicao <= 32'd0;
        end
    end

    always @(*) begin
        sccb_iniciar = 1'b0;
        diff_iniciar = 1'b0;
        prox_estado  = estado;
        case (estado)
            CONFIG: begin
                sccb_iniciar = !sccb_disparado; // pulso de 1 ciclo: dispara so na 1a vez
                if (sccb_pronto)
                    prox_estado = ESPERA;
            end
            ESPERA: begin
                if (start)
                    prox_estado = CAPTURA;
            end
            CAPTURA: begin
                if (frame_pronto) begin
                    prox_estado  = COMPARA;
                    diff_iniciar = 1'b1; // pulso de 1 ciclo, exatamente na transicao
                end
            end
            COMPARA: begin
                if (diff_pronto)
                    prox_estado = EXIBE;
            end
            EXIBE: begin
                if (contador_exibicao >= HOLD_CYCLES)
                    prox_estado = start ? CAPTURA : ESPERA;
            end
            default: prox_estado = CONFIG;
        endcase
    end

    always @(*) estado_fsm_dbg = estado;
endmodule

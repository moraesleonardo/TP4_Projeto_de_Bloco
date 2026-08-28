// FSM principal do TP3 - controla o fluxo Espera -> Captura -> Classifica -> Exibe
// Reaproveita os modulos combinacionais ja validados no TP2.
module fsm_monitor_movimento #(
    parameter HOLD_CYCLES = 27_000_000  // tempo de exibicao (~1s a 27MHz); usar valor pequeno no testbench
) (
    input  wire       clk,
    input  wire       rst,          // reset sincrono, ativo alto
    input  wire       start,        // comando de controle (equivalente ao arm_start do TP2)
    output wire        led_normal,
    output wire        led_atencao,
    output wire        led_alerta,
    output wire [1:0]  estado_atual,     // saida de depuracao: resultado da classificacao (Normal/Atencao/Alerta)
    output wire [7:0]  nivel_atual,      // saida de depuracao: valor de movimento capturado
    output wire [1:0]  estado_fsm_dbg    // saida de depuracao: estado interno da FSM (Espera/Captura/Classifica/Exibe)
);

    localparam S_ESPERA    = 2'b00;
    localparam S_CAPTURA   = 2'b01;
    localparam S_CLASSIFICA= 2'b10;
    localparam S_EXIBE     = 2'b11;

    reg [1:0] estado_fsm;
    reg [1:0] prox_estado_fsm;

    reg [2:0] indice_rom;
    reg [7:0] nivel_movimento_reg;
    reg [31:0] contador_exibicao;

    reg [7:0] valor_rom;
    always @(*) begin
        case (indice_rom)
            3'd0: valor_rom = 8'd10;
            3'd1: valor_rom = 8'd45;
            3'd2: valor_rom = 8'd60;
            3'd3: valor_rom = 8'd90;
            3'd4: valor_rom = 8'd120;
            3'd5: valor_rom = 8'd130;
            3'd6: valor_rom = 8'd200;
            3'd7: valor_rom = 8'd250;
            default: valor_rom = 8'd0;
        endcase
    end

    wire [7:0] limiar_atencao = 8'd50;
    wire [7:0] limiar_alerta  = 8'd120;
    wire [1:0] estado_class;

    classificador_movimento_cfg classificador (
        .nivel_movimento(nivel_movimento_reg),
        .limiar_atencao(limiar_atencao),
        .limiar_alerta(limiar_alerta),
        .estado(estado_class)
    );

    wire led_normal_raw, led_atencao_raw, led_alerta_raw;
    estado_para_leds saida_leds (
        .estado(estado_class),
        .led_normal(led_normal_raw),
        .led_atencao(led_atencao_raw),
        .led_alerta(led_alerta_raw)
    );

    // LEDs so acendem durante o estado EXIBE (permite ver a FSM "andando").
    // Saida invertida (~) porque os LEDs embarcados da Tang Nano 20K sao
    // ativo-baixos: pino em 0 acende o LED, pino em 1 apaga.
    assign led_normal  = (estado_fsm == S_EXIBE) ? ~led_normal_raw  : 1'b1;
    assign led_atencao = (estado_fsm == S_EXIBE) ? ~led_atencao_raw : 1'b1;
    assign led_alerta  = (estado_fsm == S_EXIBE) ? ~led_alerta_raw  : 1'b1;

    assign estado_atual   = estado_class;
    assign nivel_atual    = nivel_movimento_reg;
    assign estado_fsm_dbg = estado_fsm;

    always @(*) begin
        case (estado_fsm)
            S_ESPERA:
                prox_estado_fsm = start ? S_CAPTURA : S_ESPERA;
            S_CAPTURA:
                prox_estado_fsm = S_CLASSIFICA;
            S_CLASSIFICA:
                prox_estado_fsm = S_EXIBE;
            S_EXIBE:
                if (contador_exibicao == HOLD_CYCLES - 1)
                    prox_estado_fsm = start ? S_CAPTURA : S_ESPERA;
                else
                    prox_estado_fsm = S_EXIBE;
            default:
                prox_estado_fsm = S_ESPERA;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            estado_fsm          <= S_ESPERA;
            indice_rom          <= 3'd0;
            nivel_movimento_reg <= 8'd0;
            contador_exibicao   <= 32'd0;
        end else begin
            estado_fsm <= prox_estado_fsm;
            if (estado_fsm == S_CAPTURA) begin
                nivel_movimento_reg <= valor_rom;
                indice_rom          <= indice_rom + 3'd1;
            end
            if (estado_fsm == S_EXIBE) begin
                if (contador_exibicao == HOLD_CYCLES - 1)
                    contador_exibicao <= 32'd0;
                else
                    contador_exibicao <= contador_exibicao + 32'd1;
            end else begin
                contador_exibicao <= 32'd0;
            end
        end
    end

endmodule

// ============================================================================
// sccb_master_tp4.v
// Mestre SCCB simplificado (protocolo semelhante ao I2C usado pela OV7670
// para configuracao de registradores internos via SIO_C/SIO_D).
// Escreve uma transacao de 3 bytes (endereco do escravo, endereco do
// registrador, dado) sempre que "iniciar" e pulsado.
//
// SIMPLIFICACAO DOCUMENTADA: por ser um mestre apenas de ESCRITA, o bit de
// "nao-importa" (posicao onde o escravo normalmente dirige o ACK) e mantido
// em 0 pelo proprio mestre, sem verificacao de reconhecimento do escravo -
// simplificacao comum em implementacoes abertas de mestres SCCB de escrita.
// O divisor DIV controla quantos ciclos de "clk" formam cada semiperiodo de
// SIO_C (reduzido nesta simulacao para manter o teste curto; na sintese
// fisica sera ajustado para a faixa de ~100kHz exigida pela OV7670).
// ============================================================================
module sccb_master_tp4 #(
    parameter DIV = 4
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       iniciar,
    input  wire [7:0] endereco_escravo,
    input  wire [7:0] endereco_registro,
    input  wire [7:0] dado_registro,
    output reg        sio_c,
    output reg        sio_d,
    output reg        ocupado,
    output reg        transacao_concluida
);
    localparam IDLE      = 3'd0,
               START     = 3'd1,
               BIT_LOW   = 3'd2,
               BIT_HIGH  = 3'd3,
               STOP_LOW  = 3'd4,
               STOP_HIGH = 3'd5,
               FIM       = 3'd6;

    reg [2:0]  estado;
    reg [26:0] trama;          // 8(id) + 1(nao-importa) + 8(reg) + 1(nao-importa) + 8(dado) + 1(nao-importa)
    reg [4:0]  bits_restantes; // conta de 26 ate 0 (27 bits ao todo)
    reg [15:0] div_cont;
    reg        iniciar_anterior; // deteccao de borda de subida (evita retrigger)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            estado <= IDLE;
            sio_c <= 1'b1; sio_d <= 1'b1;
            ocupado <= 1'b0; transacao_concluida <= 1'b0;
            div_cont <= 0; trama <= 0; bits_restantes <= 0;
            iniciar_anterior <= 1'b0;
        end else begin
            transacao_concluida <= 1'b0;
            iniciar_anterior <= iniciar;

            case (estado)
                IDLE: begin
                    sio_c <= 1'b1; sio_d <= 1'b1;
                    if (iniciar && !iniciar_anterior) begin
                        trama <= {endereco_escravo, 1'b0, endereco_registro, 1'b0, dado_registro, 1'b0};
                        bits_restantes <= 5'd26;
                        ocupado <= 1'b1;
                        div_cont <= 0;
                        estado <= START;
                    end
                end
                START: begin
                    sio_c <= 1'b1;
                    if (div_cont < DIV-1) div_cont <= div_cont + 1;
                    else begin
                        sio_d <= 1'b0; // condicao de start: SIO_D cai com SIO_C em alto
                        div_cont <= 0;
                        estado <= BIT_LOW;
                    end
                end
                BIT_LOW: begin
                    sio_c <= 1'b0;
                    sio_d <= trama[26]; // bit mais significativo da trama restante
                    if (div_cont < DIV-1) div_cont <= div_cont + 1;
                    else begin div_cont <= 0; estado <= BIT_HIGH; end
                end
                BIT_HIGH: begin
                    sio_c <= 1'b1; // escravo amostra o dado nesta borda de subida
                    if (div_cont < DIV-1) div_cont <= div_cont + 1;
                    else begin
                        div_cont <= 0;
                        if (bits_restantes == 0) begin
                            estado <= STOP_LOW;
                        end else begin
                            trama <= trama << 1;
                            bits_restantes <= bits_restantes - 1'b1;
                            estado <= BIT_LOW;
                        end
                    end
                end
                STOP_LOW: begin
                    sio_c <= 1'b0; sio_d <= 1'b0;
                    if (div_cont < DIV-1) div_cont <= div_cont + 1;
                    else begin div_cont <= 0; estado <= STOP_HIGH; end
                end
                STOP_HIGH: begin
                    sio_c <= 1'b1;
                    if (div_cont < DIV-1) div_cont <= div_cont + 1;
                    else begin
                        sio_d <= 1'b1; // condicao de stop: SIO_D sobe com SIO_C em alto
                        div_cont <= 0;
                        estado <= FIM;
                    end
                end
                FIM: begin
                    ocupado <= 1'b0;
                    transacao_concluida <= 1'b1;
                    estado <= IDLE;
                end
                default: estado <= IDLE;
            endcase
        end
    end
endmodule

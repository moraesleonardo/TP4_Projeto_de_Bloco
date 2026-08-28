module classificador_movimento_cfg (
    input wire [7:0] nivel_movimento,
    input wire [7:0] limiar_atencao,
    input wire [7:0] limiar_alerta,
    output reg [1:0] estado
);

    // Estados:
    // 2'b00 = Normal
    // 2'b01 = Atencao
    // 2'b10 = Alerta

    always @(*) begin
        if (nivel_movimento <= limiar_atencao) begin
            estado = 2'b00; // Normal
        end else if (nivel_movimento <= limiar_alerta) begin
            estado = 2'b01; // Atencao
        end else begin
            estado = 2'b10; // Alerta
        end
    end

endmodule

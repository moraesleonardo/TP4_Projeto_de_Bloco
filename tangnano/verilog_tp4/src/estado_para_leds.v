module estado_para_leds (
    input wire [1:0] estado,
    output reg led_normal,
    output reg led_atencao,
    output reg led_alerta
);

    always @(*) begin
        // Saída segura padrão
        led_normal  = 1'b0;
        led_atencao = 1'b0;
        led_alerta  = 1'b0;

        case (estado)
            2'b00: led_normal  = 1'b1; // Normal
            2'b01: led_atencao = 1'b1; // Atencao
            2'b10: led_alerta  = 1'b1; // Alerta
            default: begin
                led_normal  = 1'b0;
                led_atencao = 1'b0;
                led_alerta  = 1'b0;
            end
        endcase
    end

endmodule

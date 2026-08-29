// Envia velocidade atual Tang -> Pi via MISO em todo quadro SPI:
//   STX | 0x20 | speed | ETX
//
// Independente do MOSI: config_rx so olha MOSI, isto so dirige MISO.

module speed_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] speed,

    input  wire       cs_desce,
    input  wire [7:0] rx_byte,
    input  wire       byte_valido,
    input  wire       quadro_fim,

    output reg  [7:0] tx_byte
);

    localparam [7:0] STX        = 8'h02;
    localparam [7:0] ETX        = 8'h03;
    localparam [7:0] TYPE_SPEED = 8'h20;

    reg [2:0] tx_idx = 3'd0;

    wire [2:0] tx_idx_eff = cs_desce ? 3'd0 : tx_idx;

    always @(posedge clk) begin
        if (rst)
            tx_idx <= 3'd0;
        else if (cs_desce)
            tx_idx <= 3'd0;
        else if (byte_valido)
            tx_idx <= tx_idx + 3'd1;
    end

    always @(*) begin
        case (tx_idx_eff)
            3'd0:    tx_byte = STX;
            3'd1:    tx_byte = TYPE_SPEED;
            3'd2:    tx_byte = speed;
            3'd3:    tx_byte = ETX;
            default: tx_byte = 8'h00;
        endcase
    end

endmodule

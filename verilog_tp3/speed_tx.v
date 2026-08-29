// Envia velocidade atual Tang -> Pi via MISO durante leitura SPI.
//
//   STX | 0x20 | speed | ETX
//
// Responde apenas quando o Pi faz read (MOSI = 0). Durante envio de
// config (MOSI != 0), MISO fica em zero para nao interferir.

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

    reg       read_tx = 1'b0;
    reg [2:0] tx_idx  = 3'd0;

    wire [2:0] tx_idx_eff = cs_desce ? 3'd0 : tx_idx;

    always @(posedge clk) begin
        if (rst) begin
            read_tx <= 1'b0;
            tx_idx  <= 3'd0;
        end else begin
            if (cs_desce) begin
                read_tx <= 1'b1;
                tx_idx  <= 3'd0;
            end else if (byte_valido) begin
                if (rx_byte != 8'h00)
                    read_tx <= 1'b0;
                tx_idx <= tx_idx + 3'd1;
            end

            if (quadro_fim)
                read_tx <= 1'b0;
        end
    end

    always @(*) begin
        if (!read_tx && !cs_desce)
            tx_byte = 8'h00;
        else
            case (tx_idx_eff)
                3'd0: tx_byte = STX;
                3'd1: tx_byte = TYPE_SPEED;
                3'd2: tx_byte = speed;
                3'd3: tx_byte = ETX;
                default: tx_byte = 8'h00;
            endcase
    end

endmodule

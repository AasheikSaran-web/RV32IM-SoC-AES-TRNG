module spi (
    input        pclk,
    input        presetn,

    input  [7:0] paddr,
    input        psel,
    input        penable,
    input        pwrite,
    input  [31:0] pwdata,
    output reg [31:0] prdata,
    output       pready,
    output       pslverr,

    output       sck,
    output       mosi,
    input        miso,
    output reg   cs_n,

    output       irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [15:0] div_reg;
    reg        cpol, cpha;
    reg        cs_auto;
    reg        irq_en;

    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg        busy;
    reg        done;

    reg [7:0]  shift_reg;
    reg [3:0]  bit_cnt;
    reg [15:0] div_cnt;
    reg        sck_r;
    reg        mosi_r;

    assign sck  = sck_r;
    assign mosi = mosi_r;
    assign irq  = done && irq_en;

    initial begin div_reg = 16'd4; cpol = 0; cpha = 0; cs_n = 1; end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            div_reg <= 4; cpol <= 0; cpha <= 0; cs_auto <= 0; irq_en <= 0;
            busy <= 0; done <= 0; cs_n <= 1; sck_r <= 0;
        end else begin
            done <= 0;
            if (psel && penable && pwrite) begin
                case (paddr[3:0])
                    4'h0: begin
                        tx_data   <= pwdata[7:0];
                        shift_reg <= pwdata[7:0];
                        bit_cnt   <= 4'd8;
                        div_cnt   <= div_reg;
                        busy      <= 1'b1;
                        if (cs_auto) cs_n <= 1'b0;
                    end
                    4'h8: begin
                        cpol    <= pwdata[1];
                        cpha    <= pwdata[2];
                        cs_auto <= pwdata[3];
                        irq_en  <= pwdata[4];
                        cs_n    <= !pwdata[5];
                    end
                    4'hC: div_reg <= pwdata[15:0];
                endcase
            end

            if (busy) begin
                if (div_cnt == 0) begin
                    div_cnt <= div_reg;
                    if (!sck_r) begin

                        rx_data   <= {rx_data[6:0], miso};
                        sck_r     <= 1'b1;
                    end else begin

                        sck_r   <= 1'b0;
                        if (bit_cnt > 0) begin
                            mosi_r    <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            bit_cnt   <= bit_cnt - 1;
                        end else begin
                            busy  <= 1'b0;
                            done  <= 1'b1;
                            if (cs_auto) cs_n <= 1'b1;
                        end
                    end
                end else
                    div_cnt <= div_cnt - 1;
            end
        end
    end

    always @(*) begin
        case (paddr[3:0])
            4'h0: prdata = {24'd0, rx_data};
            4'h4: prdata = {30'd0, done, busy};
            4'h8: prdata = {26'd0, !cs_n, irq_en, cs_auto, cpha, cpol, 1'b0};
            4'hC: prdata = {16'd0, div_reg};
            default: prdata = 32'd0;
        endcase
    end

endmodule

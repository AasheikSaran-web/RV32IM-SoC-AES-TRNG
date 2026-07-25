module uart #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115200
) (
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

    output       uart_tx,
    input        uart_rx,

    output       irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [31:0] baud_div;
    reg        tx_en, rx_en, tx_irq_en, rx_irq_en;
    reg [7:0]  tx_data;
    reg        tx_start;

    reg [7:0]  tx_shift;
    reg [3:0]  tx_bit_cnt;
    reg [15:0] tx_baud_cnt;
    reg        tx_busy;
    reg        tx_out;

    reg [7:0]  rx_shift;
    reg [3:0]  rx_bit_cnt;
    reg [15:0] rx_baud_cnt;
    reg        rx_busy;
    reg [7:0]  rx_data;
    reg        rx_valid;

    initial baud_div = CLK_FREQ / BAUD_RATE;

    assign uart_tx = tx_out;
    assign irq     = (rx_valid && rx_irq_en) || (!tx_busy && tx_irq_en);

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_en <= 1; rx_en <= 1; tx_irq_en <= 0; rx_irq_en <= 0;
            baud_div <= CLK_FREQ / BAUD_RATE;
            tx_start <= 0;
        end else begin
            tx_start <= 0;
            if (psel && penable && pwrite) begin
                case (paddr[3:0])
                    4'h0: begin tx_data <= pwdata[7:0]; tx_start <= 1; end
                    4'h8: begin tx_en <= pwdata[0]; rx_en <= pwdata[1];
                                tx_irq_en <= pwdata[4]; rx_irq_en <= pwdata[5]; end
                    4'hC: baud_div <= pwdata;
                endcase
            end
        end
    end

    always @(*) begin
        case (paddr[3:0])
            4'h0: prdata = {24'd0, rx_data};
            4'h4: prdata = {29'd0, rx_valid, 1'b0, tx_busy};
            4'h8: prdata = {26'd0, rx_irq_en, tx_irq_en, 2'b0, rx_en, tx_en};
            4'hC: prdata = baud_div;
            default: prdata = 32'd0;
        endcase
    end

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_busy <= 0; tx_out <= 1; tx_baud_cnt <= 0; tx_bit_cnt <= 0;
        end else if (tx_start && !tx_busy && tx_en) begin
            tx_shift    <= tx_data;
            tx_busy     <= 1;
            tx_baud_cnt <= baud_div[15:0];
            tx_bit_cnt  <= 4'd0;
            tx_out      <= 1'b0;
        end else if (tx_busy) begin
            if (tx_baud_cnt == 0) begin
                tx_baud_cnt <= baud_div[15:0];
                if (tx_bit_cnt < 4'd8) begin
                    tx_out     <= tx_shift[0];
                    tx_shift   <= {1'b0, tx_shift[7:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1;
                end else begin
                    tx_out   <= 1'b1;
                    tx_busy  <= 1'b0;
                end
            end else
                tx_baud_cnt <= tx_baud_cnt - 1;
        end
    end

    reg uart_rx_d;
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            rx_busy <= 0; rx_bit_cnt <= 0; rx_baud_cnt <= 0; rx_valid <= 0;
        end else begin
            uart_rx_d <= uart_rx;
            if (!rx_busy && !uart_rx && uart_rx_d && rx_en) begin

                rx_busy     <= 1;
                rx_baud_cnt <= (baud_div[15:0] >> 1);
                rx_bit_cnt  <= 0;
            end else if (rx_busy) begin
                if (rx_baud_cnt == 0) begin
                    rx_baud_cnt <= baud_div[15:0];
                    if (rx_bit_cnt < 4'd8) begin
                        rx_shift   <= {uart_rx, rx_shift[7:1]};
                        rx_bit_cnt <= rx_bit_cnt + 1;
                    end else begin
                        if (uart_rx) begin
                            rx_data  <= rx_shift;
                            rx_valid <= 1'b1;
                        end
                        rx_busy <= 1'b0;
                    end
                end else
                    rx_baud_cnt <= rx_baud_cnt - 1;
            end

            if (psel && penable && !pwrite && paddr[3:0] == 4'h0)
                rx_valid <= 1'b0;
        end
    end

endmodule

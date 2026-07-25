module i2c_master (
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

    inout        sda,
    inout        scl,

    output       irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [6:0]  slave_addr;
    reg        rw_bit;
    reg        start_cmd;
    reg        stop_cmd;
    reg [7:0]  tx_data;
    reg [7:0]  rx_data;
    reg        busy;
    reg        ack_err;
    reg        done;
    reg        irq_en;
    reg [15:0] div;

    assign irq = done && irq_en;

    reg sda_oe, scl_oe;
    assign sda = sda_oe ? 1'b0 : 1'bz;
    assign scl = scl_oe ? 1'b0 : 1'bz;
    wire sda_in = sda;
    wire scl_in = scl;

    localparam ST_IDLE   = 4'd0,
               ST_START  = 4'd1,
               ST_ADDR   = 4'd2,
               ST_ACK1   = 4'd3,
               ST_DATA   = 4'd4,
               ST_ACK2   = 4'd5,
               ST_STOP   = 4'd6,
               ST_DONE   = 4'd7;

    reg [3:0]  state;
    reg [3:0]  bit_cnt;
    reg [15:0] div_cnt;
    reg        clk_phase;
    reg [7:0]  shift;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            state <= ST_IDLE; busy <= 0; done <= 0; ack_err <= 0;
            sda_oe <= 0; scl_oe <= 0; div <= 16'd250;
            slave_addr <= 0; rw_bit <= 0; irq_en <= 0;
        end else begin
            done <= 0;

            if (psel && penable && pwrite) begin
                case (paddr[4:0])
                    5'h00: begin
                        slave_addr <= pwdata[6:0];
                        rw_bit     <= pwdata[7];
                        start_cmd  <= pwdata[8];
                        stop_cmd   <= pwdata[9];
                        irq_en     <= pwdata[10];
                        if (pwdata[8] && !busy) begin
                            state   <= ST_START;
                            busy    <= 1;
                            div_cnt <= div;
                            shift   <= {slave_addr, rw_bit};
                        end
                    end
                    5'h0C: tx_data <= pwdata[7:0];
                    5'h10: div     <= pwdata[15:0];
                endcase
            end

            if (busy) begin
                if (div_cnt == 0) begin
                    div_cnt   <= div;
                    clk_phase <= ~clk_phase;
                    case (state)
                        ST_START: begin
                            if (!clk_phase) begin
                                sda_oe <= 1;
                            end else begin
                                scl_oe <= 1;
                                bit_cnt <= 4'd7;
                                shift   <= {slave_addr, rw_bit};
                                state   <= ST_ADDR;
                            end
                        end
                        ST_ADDR: begin
                            if (!clk_phase) begin
                                sda_oe  <= ~shift[7];
                                shift   <= {shift[6:0], 1'b0};
                                scl_oe  <= 1;
                            end else begin
                                scl_oe  <= 0;
                                if (bit_cnt == 0) begin
                                    sda_oe <= 0;
                                    state  <= ST_ACK1;
                                end else
                                    bit_cnt <= bit_cnt - 1;
                            end
                        end
                        ST_ACK1: begin
                            if (clk_phase) begin
                                ack_err <= sda_in;
                                scl_oe  <= 1;
                                bit_cnt <= 4'd7;
                                shift   <= rw_bit ? 8'd0 : tx_data;
                                state   <= ST_DATA;
                            end else
                                scl_oe <= 0;
                        end
                        ST_DATA: begin
                            if (!clk_phase) begin
                                if (rw_bit) begin
                                    rx_data <= {rx_data[6:0], sda_in};
                                    sda_oe  <= 0;
                                end else begin
                                    sda_oe <= ~shift[7];
                                    shift  <= {shift[6:0], 1'b0};
                                end
                                scl_oe <= 1;
                            end else begin
                                scl_oe <= 0;
                                if (bit_cnt == 0) begin
                                    state <= ST_ACK2;
                                    sda_oe <= rw_bit ? 1 : 0;
                                end else
                                    bit_cnt <= bit_cnt - 1;
                            end
                        end
                        ST_ACK2: begin
                            if (clk_phase) begin
                                if (!rw_bit) ack_err <= sda_in;
                                scl_oe <= 1;
                                state  <= stop_cmd ? ST_STOP : ST_DONE;
                            end else
                                scl_oe <= 0;
                        end
                        ST_STOP: begin
                            if (!clk_phase) begin
                                sda_oe <= 1; scl_oe <= 1;
                            end else begin
                                sda_oe <= 0;
                                scl_oe <= 0;
                                state  <= ST_DONE;
                            end
                        end
                        ST_DONE: begin
                            busy <= 0; done <= 1; state <= ST_IDLE;
                        end
                    endcase
                end else
                    div_cnt <= div_cnt - 1;
            end
        end
    end

    always @(*) begin
        case (paddr[4:0])
            5'h00: prdata = {21'd0, irq_en, stop_cmd, start_cmd, rw_bit, slave_addr};
            5'h04: prdata = {29'd0, ack_err, done, busy};
            5'h0C: prdata = {24'd0, rx_data};
            5'h10: prdata = {16'd0, div};
            default: prdata = 32'd0;
        endcase
    end

endmodule

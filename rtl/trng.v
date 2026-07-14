module trng #(
    parameter AW = 32,
    parameter DW = 32
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0]  s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0]  s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0]  s_araddr, input s_arvalid,  output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg        s_rvalid, input s_rready
);

    reg [31:0] lfsr_a;
    reg [31:0] lfsr_b;
    reg [31:0] lfsr_c;

    reg        enable;
    reg        data_valid;
    reg [31:0] rand_data;
    reg [5:0]  bit_cnt;

    wire lfsr_a_bit = lfsr_a[31] ^ lfsr_a[21] ^ lfsr_a[1] ^ lfsr_a[0];
    wire lfsr_b_bit = lfsr_b[31] ^ lfsr_b[30] ^ lfsr_b[28] ^ lfsr_b[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_a <= 32'hACE1_3241;
            lfsr_b <= 32'hDEAD_BEEF;
            lfsr_c <= 32'h1234_5678;
            data_valid <= 0; rand_data <= 0; bit_cnt <= 0; enable <= 0;
        end else begin

            lfsr_a <= {lfsr_a[30:0], lfsr_a_bit};
            lfsr_b <= {lfsr_b[30:0], lfsr_b_bit};
            lfsr_c <= lfsr_c ^ {lfsr_c[14:0], lfsr_c[31:16]} ^ {lfsr_c[7:0], lfsr_c[31:8]};

            if (enable) begin

                rand_data  <= {rand_data[30:0], lfsr_a[0] ^ lfsr_b[0] ^ lfsr_c[0]};
                bit_cnt    <= bit_cnt + 1;
                if (bit_cnt == 6'd31) begin
                    data_valid <= 1'b1;
                end
            end

            s_awready <= 0; s_wready <= 0;
            if (s_awvalid && s_wvalid && !s_bvalid) begin
                s_awready <= 1; s_wready <= 1;
                case (s_awaddr[3:0])
                    4'h0: enable <= s_wdata[0];
                    4'hC: begin lfsr_a <= s_wdata; lfsr_b <= ~s_wdata; end
                endcase
                s_bvalid <= 1; s_bresp <= 2'b00;
            end
            if (s_bvalid && s_bready) s_bvalid <= 0;

            s_arready <= 0;
            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1; s_rresp <= 2'b00; s_rvalid <= 1;
                case (s_araddr[3:0])
                    4'h0: s_rdata <= {31'd0, enable};
                    4'h4: s_rdata <= {30'd0, data_valid, !enable};
                    4'h8: begin
                        s_rdata    <= rand_data;
                        data_valid <= 1'b0;
                        bit_cnt    <= 6'd0;
                    end
                    default: s_rdata <= 32'd0;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid <= 0;
        end
    end

endmodule

module plic #(
    parameter AW      = 32,
    parameter DW      = 32,
    parameter N_SRC   = 16
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0]  s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0]  s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0]  s_araddr, input s_arvalid,  output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg        s_rvalid, input s_rready,

    input  [N_SRC-1:0] irq_src,

    output             ext_irq
);

    reg [2:0]  priority   [1:N_SRC];

    reg [N_SRC:1] ie;
    reg [N_SRC:1] ip;
    reg [2:0]  threshold;
    reg [4:0]  claimed;

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ip <= 0;
        else begin
            for (j = 1; j <= N_SRC; j = j + 1)
                if (irq_src[j-1]) ip[j] <= 1'b1;
        end
    end

    integer k;
    reg [4:0]  winner;
    reg [2:0]  winner_pri;
    always @(*) begin
        winner     = 5'd0;
        winner_pri = 3'd0;
        for (k = 1; k <= N_SRC; k = k + 1) begin
            if (ip[k] && ie[k] && (priority[k] > threshold) && (priority[k] > winner_pri)) begin
                winner     = k[4:0];
                winner_pri = priority[k];
            end
        end
    end

    assign ext_irq = (winner != 5'd0);

    integer m;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 0; s_wready <= 0; s_bvalid <= 0; s_bresp <= 0;
            ie        <= 0;
            threshold <= 3'd0;
            claimed   <= 5'd0;
            for (m = 1; m <= N_SRC; m = m + 1) priority[m] <= 3'd1;
        end else begin
            s_awready <= 0; s_wready <= 0;
            if (s_awvalid && s_wvalid && !s_bvalid) begin
                s_awready <= 1'b1; s_wready <= 1'b1;
                casez (s_awaddr[23:0])

                    24'h00_0004: priority[1]  <= s_wdata[2:0];
                    24'h00_0008: priority[2]  <= s_wdata[2:0];
                    24'h00_000C: priority[3]  <= s_wdata[2:0];
                    24'h00_0010: priority[4]  <= s_wdata[2:0];
                    24'h00_0014: priority[5]  <= s_wdata[2:0];
                    24'h00_0018: priority[6]  <= s_wdata[2:0];
                    24'h00_001C: priority[7]  <= s_wdata[2:0];
                    24'h00_0020: priority[8]  <= s_wdata[2:0];
                    24'h00_0024: priority[9]  <= s_wdata[2:0];
                    24'h00_0028: priority[10] <= s_wdata[2:0];
                    24'h00_002C: priority[11] <= s_wdata[2:0];
                    24'h00_0030: priority[12] <= s_wdata[2:0];
                    24'h00_0034: priority[13] <= s_wdata[2:0];
                    24'h00_0038: priority[14] <= s_wdata[2:0];
                    24'h00_003C: priority[15] <= s_wdata[2:0];
                    24'h00_0040: priority[16] <= s_wdata[2:0];

                    24'h00_2000: ie <= s_wdata[N_SRC:1];

                    24'h20_0000: threshold <= s_wdata[2:0];

                    24'h20_0004: begin
                        if (s_wdata[4:0] >= 5'd1 && s_wdata[4:0] <= N_SRC[4:0])
                            ip[s_wdata[4:0]] <= 1'b0;
                        claimed <= 5'd0;
                    end
                    default: ;
                endcase
                s_bvalid <= 1'b1; s_bresp <= 2'b00;
            end
            if (s_bvalid && s_bready) s_bvalid <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 0; s_rvalid <= 0; s_rdata <= 0; s_rresp <= 0;
        end else begin
            s_arready <= 0;
            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1'b1; s_rresp <= 2'b00; s_rvalid <= 1'b1;
                casez (s_araddr[23:0])
                    24'h00_0004: s_rdata <= {29'd0, priority[1]};
                    24'h00_0008: s_rdata <= {29'd0, priority[2]};
                    24'h00_000C: s_rdata <= {29'd0, priority[3]};
                    24'h00_0010: s_rdata <= {29'd0, priority[4]};
                    24'h00_0014: s_rdata <= {29'd0, priority[5]};
                    24'h00_0018: s_rdata <= {29'd0, priority[6]};
                    24'h00_001C: s_rdata <= {29'd0, priority[7]};
                    24'h00_0020: s_rdata <= {29'd0, priority[8]};
                    24'h00_0024: s_rdata <= {29'd0, priority[9]};
                    24'h00_0028: s_rdata <= {29'd0, priority[10]};
                    24'h00_002C: s_rdata <= {29'd0, priority[11]};
                    24'h00_0030: s_rdata <= {29'd0, priority[12]};
                    24'h00_0034: s_rdata <= {29'd0, priority[13]};
                    24'h00_0038: s_rdata <= {29'd0, priority[14]};
                    24'h00_003C: s_rdata <= {29'd0, priority[15]};
                    24'h00_0040: s_rdata <= {29'd0, priority[16]};
                    24'h00_1000: s_rdata <= {15'd0, ip};
                    24'h00_2000: s_rdata <= {15'd0, ie};
                    24'h20_0000: s_rdata <= {29'd0, threshold};
                    24'h20_0004: s_rdata <= {27'd0, winner};
                    default:     s_rdata <= 32'd0;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid <= 1'b0;
        end
    end

endmodule

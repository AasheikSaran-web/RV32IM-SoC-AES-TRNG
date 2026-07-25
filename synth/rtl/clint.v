module clint #(
    parameter AW = 32,
    parameter DW = 32
) (
    input            clk,
    input            rst_n,

    input  [AW-1:0] s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0] s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0] s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0] s_araddr, input s_arvalid, output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg s_rvalid, input s_rready,

    output timer_irq,
    output soft_irq
);

    reg [63:0] mtime;
    reg [63:0] mtimecmp;
    reg        msip;

    assign timer_irq = (mtime >= mtimecmp);
    assign soft_irq  = msip;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mtime <= 64'd0;
        else        mtime <= mtime + 64'd1;
    end

    reg [AW-1:0] wr_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 0; s_wready <= 0; s_bvalid <= 0; s_bresp <= 0;
            mtimecmp  <= 64'hFFFF_FFFF_FFFF_FFFF;
            msip      <= 1'b0;
        end else begin
            s_awready <= 0; s_wready <= 0;
            if (s_awvalid && s_wvalid && !s_bvalid) begin
                s_awready <= 1'b1;
                s_wready  <= 1'b1;
                wr_addr   <= s_awaddr;
                case (s_awaddr[15:0])
                    16'h0000: msip              <= s_wdata[0];
                    16'h4000: mtimecmp[31:0]    <= s_wdata;
                    16'h4004: mtimecmp[63:32]   <= s_wdata;
                    16'hBFF8: mtime[31:0]        <= s_wdata;
                    16'hBFFC: mtime[63:32]       <= s_wdata;
                    default: ;
                endcase
                s_bvalid <= 1'b1;
                s_bresp  <= 2'b00;
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
                s_arready <= 1'b1;
                s_rresp   <= 2'b00;
                s_rvalid  <= 1'b1;
                case (s_araddr[15:0])
                    16'h0000: s_rdata <= {31'd0, msip};
                    16'h4000: s_rdata <= mtimecmp[31:0];
                    16'h4004: s_rdata <= mtimecmp[63:32];
                    16'hBFF8: s_rdata <= mtime[31:0];
                    16'hBFFC: s_rdata <= mtime[63:32];
                    default:  s_rdata <= 32'd0;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid <= 1'b0;
        end
    end

endmodule

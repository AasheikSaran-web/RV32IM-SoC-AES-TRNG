module boot_rom #(
    parameter AW = 32,
    parameter DW = 32
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_araddr,
    input             s_arvalid,
    output reg        s_arready,
    output reg [DW-1:0] s_rdata,
    output reg [1:0]  s_rresp,
    output reg        s_rvalid,
    input             s_rready,

    input  [AW-1:0]  s_awaddr,
    input             s_awvalid,
    output            s_awready,
    input  [DW-1:0]  s_wdata,
    input  [3:0]      s_wstrb,
    input             s_wvalid,
    output            s_wready,
    output [1:0]      s_bresp,
    output            s_bvalid,
    input             s_bready
);

    reg [DW-1:0] rom [0:1023];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) rom[i] = 32'h0000_0013;

        rom[0]  = 32'h02000137;
        rom[1]  = 32'h02010113;

        rom[0]  = 32'h20020137;
        rom[1]  = 32'h00010113;

        rom[2]  = 32'h00000297;
        rom[3]  = 32'h10028293;
        rom[4]  = 32'h30529073;

        rom[5]  = 32'h30047073;

        rom[6]  = 32'h080000EF;

        rom[7]  = 32'h20000067;

        rom[7]  = 32'h20000337;
        rom[8]  = 32'h00030067;

        rom[9]  = 32'hFE9FF06F;

        rom[32] = 32'h10002337;
        rom[33] = 32'h20000eb7;
        rom[34] = 32'h00100f13;

        rom[35] = 32'h00032e03;
        rom[36] = 32'h01cead23;
        rom[37] = 32'h00001013;
        rom[38] = 32'hFFC00F13;
        rom[39] = 32'h004E8E13;
        rom[40] = 32'hFE0F14E3;
        rom[41] = 32'h00008067;

        rom[64] = 32'h34202373;
        rom[65] = 32'h34102273;
        rom[66] = 32'h00420213;
        rom[67] = 32'h34121073;
        rom[68] = 32'h30200073;
    end

    reg [9:0] rd_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'd0;
            s_rresp   <= 2'b00;
        end else begin
            s_arready <= 1'b0;
            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1'b1;
                rd_addr   <= s_araddr[11:2];
                s_rdata   <= rom[s_araddr[11:2]];
                s_rresp   <= 2'b00;
                s_rvalid  <= 1'b1;
            end
            if (s_rvalid && s_rready)
                s_rvalid <= 1'b0;
        end
    end

    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_bresp   = 2'b00;
    assign s_bvalid  = 1'b0;

endmodule

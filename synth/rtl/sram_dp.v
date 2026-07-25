module sram_dp #(
    parameter AW   = 32,
    parameter DW   = 32,
    parameter DEPTH = 32768
) (
    input           clk,
    input           rst_n,

    input  [AW-1:0] pa_araddr,
    input           pa_arvalid,
    output reg      pa_arready,
    output reg [DW-1:0] pa_rdata,
    output reg [1:0]    pa_rresp,
    output reg      pa_rvalid,
    input           pa_rready,

    input  [AW-1:0] pa_awaddr, input pa_awvalid, output pa_awready,
    input  [DW-1:0] pa_wdata,  input [3:0] pa_wstrb, input pa_wvalid, output pa_wready,
    output [1:0]    pa_bresp,  output pa_bvalid, input pa_bready,

    input  [AW-1:0] pb_araddr,
    input           pb_arvalid,
    output reg      pb_arready,
    output reg [DW-1:0] pb_rdata,
    output reg [1:0]    pb_rresp,
    output reg      pb_rvalid,
    input           pb_rready,

    input  [AW-1:0] pb_awaddr,
    input           pb_awvalid,
    output reg      pb_awready,
    input  [DW-1:0] pb_wdata,
    input  [3:0]    pb_wstrb,
    input           pb_wvalid,
    output reg      pb_wready,
    output reg [1:0] pb_bresp,
    output reg       pb_bvalid,
    input            pb_bready
);

    reg [DW-1:0] mem [0:DEPTH-1];

    wire [$clog2(DEPTH)-1:0] pa_waddr = pa_araddr[$clog2(DEPTH)+1:2];
    wire [$clog2(DEPTH)-1:0] pb_raddr = pb_araddr[$clog2(DEPTH)+1:2];
    wire [$clog2(DEPTH)-1:0] pb_waddr = pb_awaddr[$clog2(DEPTH)+1:2];

    wire pb_do_write = pb_awvalid && pb_wvalid && !pb_bvalid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pa_arready <= 0; pa_rvalid <= 0; pa_rdata <= 0; pa_rresp <= 0;
        end else begin
            pa_arready <= 0;
            if (pa_arvalid && !pa_rvalid && !pb_do_write) begin
                pa_arready <= 1'b1;
                pa_rdata   <= mem[pa_waddr];
                pa_rresp   <= 2'b00;
                pa_rvalid  <= 1'b1;
            end
            if (pa_rvalid && pa_rready) pa_rvalid <= 1'b0;
        end
    end

    reg  [$clog2(DEPTH)-1:0] pb_saved_raddr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pb_arready <= 0; pb_rvalid <= 0; pb_rdata <= 0; pb_rresp <= 0;
        end else begin
            pb_arready <= 0;
            if (pb_arvalid && !pb_rvalid) begin
                pb_arready    <= 1'b1;
                pb_saved_raddr <= pb_raddr;
                pb_rdata      <= mem[pb_raddr];
                pb_rresp      <= 2'b00;
                pb_rvalid     <= 1'b1;
            end
            if (pb_rvalid && pb_rready) pb_rvalid <= 1'b0;
        end
    end

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pb_awready <= 0; pb_wready <= 0; pb_bvalid <= 0; pb_bresp <= 0;
        end else begin
            pb_awready <= 0; pb_wready <= 0;
            if (pb_do_write) begin
                pb_awready <= 1'b1;
                pb_wready  <= 1'b1;
                if (pb_wstrb[0]) mem[pb_waddr][7:0]   <= pb_wdata[7:0];
                if (pb_wstrb[1]) mem[pb_waddr][15:8]  <= pb_wdata[15:8];
                if (pb_wstrb[2]) mem[pb_waddr][23:16] <= pb_wdata[23:16];
                if (pb_wstrb[3]) mem[pb_waddr][31:24] <= pb_wdata[31:24];
                pb_bvalid <= 1'b1;
                pb_bresp  <= 2'b00;
            end
            if (pb_bvalid && pb_bready) pb_bvalid <= 1'b0;
        end
    end

    assign pa_awready = 1'b1; assign pa_wready = 1'b1;
    assign pa_bresp   = 2'b00; assign pa_bvalid = 1'b0;

endmodule

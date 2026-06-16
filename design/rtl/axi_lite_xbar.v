module axi_lite_xbar #(
    parameter AW     = 32,
    parameter DW     = 32,
    parameter N_SLV  = 8,

    parameter [255:0] BASE0 = 32'h0000_0000,
    parameter [255:0] BASE1 = 32'h0200_0000,
    parameter [255:0] BASE2 = 32'h0C00_0000,
    parameter [255:0] BASE3 = 32'h1000_0000,
    parameter [255:0] BASE4 = 32'h2000_0000,
    parameter [255:0] BASE5 = 32'h3000_0000,
    parameter [255:0] BASE6 = 32'h3000_1000,
    parameter [255:0] BASE7 = 32'h4000_0000,
    parameter [255:0] MASK0 = 32'hFFFF_F000,
    parameter [255:0] MASK1 = 32'hFFFF_0000,
    parameter [255:0] MASK2 = 32'hFC00_0000,
    parameter [255:0] MASK3 = 32'hFFFF_0000,
    parameter [255:0] MASK4 = 32'hFFFE_0000,
    parameter [255:0] MASK5 = 32'hFFFF_F000,
    parameter [255:0] MASK6 = 32'hFFFF_F000,
    parameter [255:0] MASK7 = 32'hFFFF_0000
) (
    input              clk, rst_n,

    input  [AW-1:0]   m_awaddr, input m_awvalid, output reg m_awready,
    input  [DW-1:0]   m_wdata,  input [3:0] m_wstrb, input m_wvalid, output reg m_wready,
    output reg [1:0]   m_bresp,  output reg m_bvalid, input m_bready,
    input  [AW-1:0]   m_araddr, input m_arvalid, output reg m_arready,
    output reg [DW-1:0] m_rdata, output reg [1:0] m_rresp,
    output reg         m_rvalid, input m_rready,

    output reg [AW-1:0] s0_awaddr, output reg s0_awvalid, input s0_awready,
    output reg [DW-1:0] s0_wdata,  output reg [3:0] s0_wstrb, output reg s0_wvalid, input s0_wready,
    input [1:0] s0_bresp, input s0_bvalid, output reg s0_bready,
    output reg [AW-1:0] s0_araddr, output reg s0_arvalid, input s0_arready,
    input [DW-1:0] s0_rdata, input [1:0] s0_rresp, input s0_rvalid, output reg s0_rready,

    output reg [AW-1:0] s1_awaddr, output reg s1_awvalid, input s1_awready,
    output reg [DW-1:0] s1_wdata,  output reg [3:0] s1_wstrb, output reg s1_wvalid, input s1_wready,
    input [1:0] s1_bresp, input s1_bvalid, output reg s1_bready,
    output reg [AW-1:0] s1_araddr, output reg s1_arvalid, input s1_arready,
    input [DW-1:0] s1_rdata, input [1:0] s1_rresp, input s1_rvalid, output reg s1_rready,

    output reg [AW-1:0] s2_awaddr, output reg s2_awvalid, input s2_awready,
    output reg [DW-1:0] s2_wdata,  output reg [3:0] s2_wstrb, output reg s2_wvalid, input s2_wready,
    input [1:0] s2_bresp, input s2_bvalid, output reg s2_bready,
    output reg [AW-1:0] s2_araddr, output reg s2_arvalid, input s2_arready,
    input [DW-1:0] s2_rdata, input [1:0] s2_rresp, input s2_rvalid, output reg s2_rready,

    output reg [AW-1:0] s3_awaddr, output reg s3_awvalid, input s3_awready,
    output reg [DW-1:0] s3_wdata,  output reg [3:0] s3_wstrb, output reg s3_wvalid, input s3_wready,
    input [1:0] s3_bresp, input s3_bvalid, output reg s3_bready,
    output reg [AW-1:0] s3_araddr, output reg s3_arvalid, input s3_arready,
    input [DW-1:0] s3_rdata, input [1:0] s3_rresp, input s3_rvalid, output reg s3_rready,

    output reg [AW-1:0] s4_awaddr, output reg s4_awvalid, input s4_awready,
    output reg [DW-1:0] s4_wdata,  output reg [3:0] s4_wstrb, output reg s4_wvalid, input s4_wready,
    input [1:0] s4_bresp, input s4_bvalid, output reg s4_bready,
    output reg [AW-1:0] s4_araddr, output reg s4_arvalid, input s4_arready,
    input [DW-1:0] s4_rdata, input [1:0] s4_rresp, input s4_rvalid, output reg s4_rready,

    output reg [AW-1:0] s5_awaddr, output reg s5_awvalid, input s5_awready,
    output reg [DW-1:0] s5_wdata,  output reg [3:0] s5_wstrb, output reg s5_wvalid, input s5_wready,
    input [1:0] s5_bresp, input s5_bvalid, output reg s5_bready,
    output reg [AW-1:0] s5_araddr, output reg s5_arvalid, input s5_arready,
    input [DW-1:0] s5_rdata, input [1:0] s5_rresp, input s5_rvalid, output reg s5_rready,

    output reg [AW-1:0] s6_awaddr, output reg s6_awvalid, input s6_awready,
    output reg [DW-1:0] s6_wdata,  output reg [3:0] s6_wstrb, output reg s6_wvalid, input s6_wready,
    input [1:0] s6_bresp, input s6_bvalid, output reg s6_bready,
    output reg [AW-1:0] s6_araddr, output reg s6_arvalid, input s6_arready,
    input [DW-1:0] s6_rdata, input [1:0] s6_rresp, input s6_rvalid, output reg s6_rready,

    output reg [AW-1:0] s7_awaddr, output reg s7_awvalid, input s7_awready,
    output reg [DW-1:0] s7_wdata,  output reg [3:0] s7_wstrb, output reg s7_wvalid, input s7_wready,
    input [1:0] s7_bresp, input s7_bvalid, output reg s7_bready,
    output reg [AW-1:0] s7_araddr, output reg s7_arvalid, input s7_arready,
    input [DW-1:0] s7_rdata, input [1:0] s7_rresp, input s7_rvalid, output reg s7_rready
);

    function [2:0] decode;
        input [AW-1:0] addr;
        begin
            if ((addr & MASK0[31:0]) == BASE0[31:0])      decode = 3'd0;
            else if ((addr & MASK1[31:0]) == BASE1[31:0]) decode = 3'd1;
            else if ((addr & MASK2[31:0]) == BASE2[31:0]) decode = 3'd2;
            else if ((addr & MASK3[31:0]) == BASE3[31:0]) decode = 3'd3;
            else if ((addr & MASK4[31:0]) == BASE4[31:0]) decode = 3'd4;
            else if ((addr & MASK5[31:0]) == BASE5[31:0]) decode = 3'd5;
            else if ((addr & MASK6[31:0]) == BASE6[31:0]) decode = 3'd6;
            else                                            decode = 3'd7;
        end
    endfunction

    localparam ST_IDLE = 2'd0, ST_WADDR = 2'd1, ST_RADDR = 2'd2, ST_WAIT = 2'd3;
    reg [1:0] state;
    reg [2:0] cur_slv;
    reg       is_write;

    task clr_slv_valids;
        begin
            s0_awvalid<=0; s0_wvalid<=0; s0_arvalid<=0; s0_bready<=0; s0_rready<=0;
            s1_awvalid<=0; s1_wvalid<=0; s1_arvalid<=0; s1_bready<=0; s1_rready<=0;
            s2_awvalid<=0; s2_wvalid<=0; s2_arvalid<=0; s2_bready<=0; s2_rready<=0;
            s3_awvalid<=0; s3_wvalid<=0; s3_arvalid<=0; s3_bready<=0; s3_rready<=0;
            s4_awvalid<=0; s4_wvalid<=0; s4_arvalid<=0; s4_bready<=0; s4_rready<=0;
            s5_awvalid<=0; s5_wvalid<=0; s5_arvalid<=0; s5_bready<=0; s5_rready<=0;
            s6_awvalid<=0; s6_wvalid<=0; s6_arvalid<=0; s6_bready<=0; s6_rready<=0;
            s7_awvalid<=0; s7_wvalid<=0; s7_arvalid<=0; s7_bready<=0; s7_rready<=0;
        end
    endtask

    task fwd_write;
        input [2:0] slv;
        input [AW-1:0] addr;
        input [DW-1:0] wdata;
        input [3:0]    wstrb;
        begin
            case (slv)
                3'd0: begin s0_awaddr<=addr; s0_wdata<=wdata; s0_wstrb<=wstrb; s0_awvalid<=1; s0_wvalid<=1; end
                3'd1: begin s1_awaddr<=addr; s1_wdata<=wdata; s1_wstrb<=wstrb; s1_awvalid<=1; s1_wvalid<=1; end
                3'd2: begin s2_awaddr<=addr; s2_wdata<=wdata; s2_wstrb<=wstrb; s2_awvalid<=1; s2_wvalid<=1; end
                3'd3: begin s3_awaddr<=addr; s3_wdata<=wdata; s3_wstrb<=wstrb; s3_awvalid<=1; s3_wvalid<=1; end
                3'd4: begin s4_awaddr<=addr; s4_wdata<=wdata; s4_wstrb<=wstrb; s4_awvalid<=1; s4_wvalid<=1; end
                3'd5: begin s5_awaddr<=addr; s5_wdata<=wdata; s5_wstrb<=wstrb; s5_awvalid<=1; s5_wvalid<=1; end
                3'd6: begin s6_awaddr<=addr; s6_wdata<=wdata; s6_wstrb<=wstrb; s6_awvalid<=1; s6_wvalid<=1; end
                3'd7: begin s7_awaddr<=addr; s7_wdata<=wdata; s7_wstrb<=wstrb; s7_awvalid<=1; s7_wvalid<=1; end
            endcase
        end
    endtask

    task fwd_read;
        input [2:0] slv;
        input [AW-1:0] addr;
        begin
            case (slv)
                3'd0: begin s0_araddr<=addr; s0_arvalid<=1; end
                3'd1: begin s1_araddr<=addr; s1_arvalid<=1; end
                3'd2: begin s2_araddr<=addr; s2_arvalid<=1; end
                3'd3: begin s3_araddr<=addr; s3_arvalid<=1; end
                3'd4: begin s4_araddr<=addr; s4_arvalid<=1; end
                3'd5: begin s5_araddr<=addr; s5_arvalid<=1; end
                3'd6: begin s6_araddr<=addr; s6_arvalid<=1; end
                3'd7: begin s7_araddr<=addr; s7_arvalid<=1; end
            endcase
        end
    endtask

    wire aw_ready = (cur_slv==0)?s0_awready:(cur_slv==1)?s1_awready:(cur_slv==2)?s2_awready:
                   (cur_slv==3)?s3_awready:(cur_slv==4)?s4_awready:(cur_slv==5)?s5_awready:
                   (cur_slv==6)?s6_awready:s7_awready;
    wire w_ready  = (cur_slv==0)?s0_wready :(cur_slv==1)?s1_wready :(cur_slv==2)?s2_wready:
                   (cur_slv==3)?s3_wready :(cur_slv==4)?s4_wready :(cur_slv==5)?s5_wready:
                   (cur_slv==6)?s6_wready :s7_wready;
    wire b_valid  = (cur_slv==0)?s0_bvalid:(cur_slv==1)?s1_bvalid:(cur_slv==2)?s2_bvalid:
                   (cur_slv==3)?s3_bvalid:(cur_slv==4)?s4_bvalid:(cur_slv==5)?s5_bvalid:
                   (cur_slv==6)?s6_bvalid:s7_bvalid;
    wire ar_ready = (cur_slv==0)?s0_arready:(cur_slv==1)?s1_arready:(cur_slv==2)?s2_arready:
                   (cur_slv==3)?s3_arready:(cur_slv==4)?s4_arready:(cur_slv==5)?s5_arready:
                   (cur_slv==6)?s6_arready:s7_arready;
    wire r_valid  = (cur_slv==0)?s0_rvalid:(cur_slv==1)?s1_rvalid:(cur_slv==2)?s2_rvalid:
                   (cur_slv==3)?s3_rvalid:(cur_slv==4)?s4_rvalid:(cur_slv==5)?s5_rvalid:
                   (cur_slv==6)?s6_rvalid:s7_rvalid;
    wire [DW-1:0] r_data = (cur_slv==0)?s0_rdata:(cur_slv==1)?s1_rdata:(cur_slv==2)?s2_rdata:
                           (cur_slv==3)?s3_rdata:(cur_slv==4)?s4_rdata:(cur_slv==5)?s5_rdata:
                           (cur_slv==6)?s6_rdata:s7_rdata;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            m_awready<=0; m_wready<=0; m_bvalid<=0; m_bresp<=0;
            m_arready<=0; m_rvalid<=0; m_rdata<=0; m_rresp<=0;
            clr_slv_valids();
        end else begin
            m_awready<=0; m_wready<=0; m_arready<=0;

            case (state)
                ST_IDLE: begin
                    clr_slv_valids();
                    if (m_awvalid && m_wvalid) begin
                        cur_slv  <= decode(m_awaddr);
                        is_write <= 1;
                        fwd_write(decode(m_awaddr), m_awaddr, m_wdata, m_wstrb);
                        m_awready <= 1; m_wready <= 1;
                        state <= ST_WAIT;
                    end else if (m_arvalid) begin
                        cur_slv  <= decode(m_araddr);
                        is_write <= 0;
                        fwd_read(decode(m_araddr), m_araddr);
                        m_arready <= 1;
                        state <= ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (is_write) begin

                        case (cur_slv)
                            3'd0: s0_bready <= 1; 3'd1: s1_bready <= 1;
                            3'd2: s2_bready <= 1; 3'd3: s3_bready <= 1;
                            3'd4: s4_bready <= 1; 3'd5: s5_bready <= 1;
                            3'd6: s6_bready <= 1; 3'd7: s7_bready <= 1;
                        endcase
                        if (b_valid) begin
                            m_bvalid <= 1; m_bresp <= 2'b00;
                            clr_slv_valids();
                            state <= ST_IDLE;
                        end
                    end else begin

                        case (cur_slv)
                            3'd0: s0_rready <= 1; 3'd1: s1_rready <= 1;
                            3'd2: s2_rready <= 1; 3'd3: s3_rready <= 1;
                            3'd4: s4_rready <= 1; 3'd5: s5_rready <= 1;
                            3'd6: s6_rready <= 1; 3'd7: s7_rready <= 1;
                        endcase
                        if (r_valid) begin
                            m_rvalid <= 1; m_rdata <= r_data; m_rresp <= 2'b00;
                            clr_slv_valids();
                            state <= ST_IDLE;
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase

            if (m_bvalid && m_bready) m_bvalid <= 0;
            if (m_rvalid && m_rready) m_rvalid <= 0;
        end
    end

endmodule

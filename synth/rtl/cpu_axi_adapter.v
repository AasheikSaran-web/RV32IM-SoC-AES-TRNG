module cpu_axi_adapter #(
    parameter READ_ONLY = 0
) (
    input             clk,
    input             rst_n,

    input  [31:0]     cpu_addr,
    input  [31:0]     cpu_wdata,
    input  [3:0]      cpu_wstrb,
    input             cpu_req,
    output reg [31:0] cpu_rdata,
    output reg        cpu_ready,

    output reg [31:0] m_araddr,
    output reg        m_arvalid,
    input             m_arready,
    input  [31:0]     m_rdata,
    input  [1:0]      m_rresp,
    input             m_rvalid,
    output            m_rready,

    output reg [31:0] m_awaddr,
    output reg        m_awvalid,
    input             m_awready,
    output reg [31:0] m_wdata,
    output reg [3:0]  m_wstrb,
    output reg        m_wvalid,
    input             m_wready,
    input  [1:0]      m_bresp,
    input             m_bvalid,
    output            m_bready
);

    assign m_rready = 1'b1;
    assign m_bready = 1'b1;

    localparam ST_IDLE  = 2'd0,
               ST_RADDR = 2'd1,
               ST_RDATA = 2'd2,
               ST_WRITE = 2'd3;

    reg [1:0] state;
    wire is_write = cpu_req && (|cpu_wstrb) && !READ_ONLY;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= ST_IDLE;
            cpu_ready  <= 1'b0;
            m_arvalid  <= 1'b0;
            m_awvalid  <= 1'b0;
            m_wvalid   <= 1'b0;
            cpu_rdata  <= 32'd0;
        end else begin
            cpu_ready <= 1'b0;

            case (state)
                ST_IDLE: begin
                    if (cpu_req) begin
                        if (is_write) begin
                            m_awaddr  <= cpu_addr;
                            m_awvalid <= 1'b1;
                            m_wdata   <= cpu_wdata;
                            m_wstrb   <= cpu_wstrb;
                            m_wvalid  <= 1'b1;
                            state     <= ST_WRITE;
                        end else begin
                            m_araddr  <= cpu_addr;
                            m_arvalid <= 1'b1;
                            state     <= ST_RADDR;
                        end
                    end
                end

                ST_RADDR: begin
                    if (m_arready) begin
                        m_arvalid <= 1'b0;
                        state     <= ST_RDATA;
                    end
                end

                ST_RDATA: begin
                    if (m_rvalid) begin
                        cpu_rdata <= m_rdata;
                        cpu_ready <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end

                ST_WRITE: begin
                    if (m_awready) m_awvalid <= 1'b0;
                    if (m_wready)  m_wvalid  <= 1'b0;
                    if (m_bvalid) begin
                        cpu_ready <= 1'b1;
                        state     <= ST_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

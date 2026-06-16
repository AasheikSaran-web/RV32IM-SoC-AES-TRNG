module axi_lite_apb_bridge #(
    parameter AW      = 32,
    parameter DW      = 32,
    parameter N_SLAVE = 8
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0]  s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0]  s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0]  s_araddr, input s_arvalid,  output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg        s_rvalid, input s_rready,

    output reg [AW-1:0] paddr,
    output reg           psel0, psel1, psel2, psel3,
    output reg           psel4, psel5, psel6, psel7,
    output reg           penable,
    output reg           pwrite,
    output reg [DW-1:0]  pwdata,
    output reg [3:0]     pstrb,
    input  [DW-1:0]      prdata0, prdata1, prdata2, prdata3,
    input  [DW-1:0]      prdata4, prdata5, prdata6, prdata7,
    input                pready0, pready1, pready2, pready3,
    input                pready4, pready5, pready6, pready7
);

    wire [2:0] apb_sel = paddr[14:12];

    wire [DW-1:0] prdata_mux = (apb_sel==3'd0) ? prdata0 : (apb_sel==3'd1) ? prdata1 :
                               (apb_sel==3'd2) ? prdata2 : (apb_sel==3'd3) ? prdata3 :
                               (apb_sel==3'd4) ? prdata4 : (apb_sel==3'd5) ? prdata5 :
                               (apb_sel==3'd6) ? prdata6 : prdata7;

    wire pready_mux = (apb_sel==3'd0) ? pready0 : (apb_sel==3'd1) ? pready1 :
                      (apb_sel==3'd2) ? pready2 : (apb_sel==3'd3) ? pready3 :
                      (apb_sel==3'd4) ? pready4 : (apb_sel==3'd5) ? pready5 :
                      (apb_sel==3'd6) ? pready6 : pready7;

    localparam APB_IDLE   = 2'd0,
               APB_SETUP  = 2'd1,
               APB_ENABLE = 2'd2,
               APB_RESP   = 2'd3;

    reg [1:0] apb_state;
    reg       is_write_trans;

    task set_psel;
        input [2:0] sel;
        begin
            psel0 = (sel==0); psel1 = (sel==1); psel2 = (sel==2); psel3 = (sel==3);
            psel4 = (sel==4); psel5 = (sel==5); psel6 = (sel==6); psel7 = (sel==7);
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            apb_state <= APB_IDLE;
            s_awready <= 0; s_wready <= 0; s_bvalid <= 0; s_bresp <= 0;
            s_arready <= 0; s_rvalid <= 0; s_rdata  <= 0; s_rresp <= 0;
            psel0<=0; psel1<=0; psel2<=0; psel3<=0;
            psel4<=0; psel5<=0; psel6<=0; psel7<=0;
            penable <= 0; pwrite <= 0; paddr <= 0; pwdata <= 0; pstrb <= 0;
        end else begin
            s_awready <= 0; s_wready <= 0; s_arready <= 0;

            case (apb_state)
                APB_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        is_write_trans <= 1;
                        paddr          <= s_awaddr;
                        pwdata         <= s_wdata;
                        pstrb          <= s_wstrb;
                        pwrite         <= 1;
                        set_psel(s_awaddr[14:12]);
                        penable        <= 0;
                        s_awready      <= 1;
                        s_wready       <= 1;
                        apb_state      <= APB_SETUP;
                    end else if (s_arvalid) begin
                        is_write_trans <= 0;
                        paddr          <= s_araddr;
                        pwrite         <= 0;
                        set_psel(s_araddr[14:12]);
                        penable        <= 0;
                        s_arready      <= 1;
                        apb_state      <= APB_SETUP;
                    end
                end

                APB_SETUP: begin
                    penable   <= 1;
                    apb_state <= APB_ENABLE;
                end

                APB_ENABLE: begin
                    if (pready_mux) begin
                        penable <= 0;
                        psel0<=0; psel1<=0; psel2<=0; psel3<=0;
                        psel4<=0; psel5<=0; psel6<=0; psel7<=0;
                        if (is_write_trans) begin
                            s_bvalid  <= 1;
                            s_bresp   <= 2'b00;
                        end else begin
                            s_rdata   <= prdata_mux;
                            s_rresp   <= 2'b00;
                            s_rvalid  <= 1;
                        end
                        apb_state <= APB_RESP;
                    end
                end

                APB_RESP: begin
                    if ((s_bvalid && s_bready) || (s_rvalid && s_rready)) begin
                        s_bvalid  <= 0;
                        s_rvalid  <= 0;
                        apb_state <= APB_IDLE;
                    end
                end
            endcase
        end
    end

endmodule

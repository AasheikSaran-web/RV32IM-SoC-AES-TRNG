`timescale 1ns/1ps
module apb_gpio #(
    parameter N_GPIO = 32,
    parameter APB_ADDR_WIDTH = 8
) (
    input  wire                     pclk,
    input  wire                     presetn,
    input  wire [APB_ADDR_WIDTH-1:0] paddr,
    input  wire                     psel,
    input  wire                     penable,
    input  wire                     pwrite,
    input  wire [31:0]              pwdata,
    output reg  [31:0]              prdata,
    output wire                     pready,
    output wire                     pslverr,
    inout  wire [N_GPIO-1:0]        gpio_pins,
    output wire                     irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [N_GPIO-1:0] paddir;
    reg [N_GPIO-1:0] padout;
    reg [N_GPIO-1:0] inten;
    reg [N_GPIO-1:0] inttype0;
    reg [N_GPIO-1:0] inttype1;
    reg [N_GPIO-1:0] intstatus;

    reg [N_GPIO-1:0] padin_sync1, padin_sync2, padin_prev;
    wire [N_GPIO-1:0] padin = padin_sync2;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            padin_sync1 <= 0;
            padin_sync2 <= 0;
            padin_prev  <= 0;
        end else begin
            padin_sync1 <= gpio_pins;
            padin_sync2 <= padin_sync1;
            padin_prev  <= padin_sync2;
        end
    end

    wire [N_GPIO-1:0] rise_edge = padin & ~padin_prev;
    wire [N_GPIO-1:0] fall_edge = ~padin & padin_prev;

    genvar gi;
    generate
        for (gi = 0; gi < N_GPIO; gi = gi + 1) begin : irq_gen
            wire level_lo  = (!inttype0[gi]) && (!inttype1[gi]) && (!padin[gi]);
            wire level_hi  = (!inttype0[gi]) &&   inttype1[gi]  &&   padin[gi];
            wire fall      =   inttype0[gi]  && (!inttype1[gi]) && fall_edge[gi];
            wire rise_e    =   inttype0[gi]  &&   inttype1[gi]  && rise_edge[gi];
            wire pin_int   = inten[gi] && (level_lo | level_hi | fall | rise_e);
            always @(posedge pclk or negedge presetn) begin
                if (!presetn)         intstatus[gi] <= 1'b0;
                else if (pin_int)     intstatus[gi] <= 1'b1;
                else if (intstatus_rd) intstatus[gi] <= 1'b0;
            end
        end
    endgenerate

    wire intstatus_rd = psel && penable && !pwrite && (paddr[5:0] == 6'h18);

    assign irq = |intstatus;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            paddir   <= 0;
            padout   <= 0;
            inten    <= 0;
            inttype0 <= 0;
            inttype1 <= 0;
        end else if (psel && penable && pwrite) begin
            case (paddr[5:0])
                6'h00: paddir   <= pwdata[N_GPIO-1:0];
                6'h08: padout   <= pwdata[N_GPIO-1:0];
                6'h0C: inten    <= pwdata[N_GPIO-1:0];
                6'h10: inttype0 <= pwdata[N_GPIO-1:0];
                6'h14: inttype1 <= pwdata[N_GPIO-1:0];
                default: ;
            endcase
        end
    end

    always @(*) begin
        prdata = 32'd0;
        case (paddr[5:0])
            6'h00: prdata = {{(32-N_GPIO){1'b0}}, paddir};
            6'h04: prdata = {{(32-N_GPIO){1'b0}}, padin};
            6'h08: prdata = {{(32-N_GPIO){1'b0}}, padout};
            6'h0C: prdata = {{(32-N_GPIO){1'b0}}, inten};
            6'h10: prdata = {{(32-N_GPIO){1'b0}}, inttype0};
            6'h14: prdata = {{(32-N_GPIO){1'b0}}, inttype1};
            6'h18: prdata = {{(32-N_GPIO){1'b0}}, intstatus};
            default: prdata = 32'd0;
        endcase
    end

    generate
        for (gi = 0; gi < N_GPIO; gi = gi + 1) begin : pad_drv
            assign gpio_pins[gi] = paddir[gi] ? padout[gi] : 1'bz;
        end
    endgenerate

endmodule

module timer (
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

    output       irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg        timer_en;
    reg        irq_en;
    reg        auto_reload;
    reg [31:0] load_val;
    reg [31:0] cmp_val;
    reg [31:0] counter;
    reg        irq_stat;
    reg [7:0]  prescaler_load;
    reg [7:0]  prescaler_cnt;

    assign irq = irq_stat && irq_en;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            timer_en <= 0; irq_en <= 0; auto_reload <= 1; irq_stat <= 0;
            load_val <= 32'hFFFF_FFFF; cmp_val <= 32'd0; counter <= 32'hFFFF_FFFF;
            prescaler_load <= 8'd0; prescaler_cnt <= 8'd0;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr[4:0])
                    5'h00: begin timer_en <= pwdata[0]; irq_en <= pwdata[1];
                                 auto_reload <= pwdata[2]; prescaler_load <= pwdata[15:8]; end
                    5'h04: begin load_val <= pwdata; counter <= pwdata; end
                    5'h08: counter   <= pwdata;
                    5'h0C: cmp_val   <= pwdata;
                    5'h10: irq_stat  <= irq_stat & ~pwdata[0];
                endcase
            end

            if (timer_en) begin
                if (prescaler_cnt == 0) begin
                    prescaler_cnt <= prescaler_load;
                    if (counter == cmp_val) begin
                        irq_stat <= 1'b1;
                        counter  <= auto_reload ? load_val : counter;
                    end else
                        counter <= counter - 1;
                end else
                    prescaler_cnt <= prescaler_cnt - 1;
            end
        end
    end

    always @(*) begin
        case (paddr[4:0])
            5'h00: prdata = {16'd0, prescaler_load, 5'd0, auto_reload, irq_en, timer_en};
            5'h04: prdata = load_val;
            5'h08: prdata = counter;
            5'h0C: prdata = cmp_val;
            5'h10: prdata = {31'd0, irq_stat};
            default: prdata = 32'd0;
        endcase
    end

endmodule

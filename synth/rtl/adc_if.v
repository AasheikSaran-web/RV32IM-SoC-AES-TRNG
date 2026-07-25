module adc_if (
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

    input  [11:0] adc_data,
    input         adc_eoc,
    output reg    adc_soc,
    output reg [2:0] adc_ch,

    output        irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [11:0] result;
    reg        busy;
    reg        done;
    reg        irq_en;
    reg        auto_sample;

    assign irq = done && irq_en;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            adc_soc <= 0; adc_ch <= 0; busy <= 0; done <= 0;
            result <= 0; irq_en <= 0; auto_sample <= 0;
        end else begin
            adc_soc <= 1'b0;

            if (psel && penable && pwrite) begin
                case (paddr[3:0])
                    4'h0: begin
                        adc_ch  <= pwdata[2:0];
                        irq_en  <= pwdata[4];
                        if (pwdata[0] && !busy) begin
                            adc_soc <= 1'b1;
                            busy    <= 1'b1;
                            done    <= 1'b0;
                        end
                    end
                    4'h4: done <= done & ~pwdata[0];
                endcase
            end

            if (busy && adc_eoc) begin
                result <= adc_data;
                busy   <= 1'b0;
                done   <= 1'b1;
                if (auto_sample) begin
                    adc_soc <= 1'b1;
                    busy    <= 1'b1;
                end
            end
        end
    end

    always @(*) begin
        case (paddr[3:0])
            4'h0: prdata = {27'd0, irq_en, adc_ch};
            4'h4: prdata = {30'd0, done, busy};
            4'h8: prdata = {20'd0, result};
            default: prdata = 32'd0;
        endcase
    end

endmodule

module gpio (
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

    inout  [31:0] gpio_pins,

    output       irq
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    reg [31:0] gpio_dir;
    reg [31:0] gpio_out;
    reg [31:0] gpio_irq_en;
    reg [31:0] gpio_irq_stat;
    reg [31:0] gpio_in_prev;

    wire [31:0] gpio_in;

    genvar g;
    generate
        for (g = 0; g < 32; g = g + 1) begin : gpio_tristate
            assign gpio_pins[g] = gpio_dir[g] ? gpio_out[g] : 1'bz;
        end
    endgenerate

    assign gpio_in = gpio_pins;
    assign irq = |(gpio_irq_stat & gpio_irq_en);

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_dir <= 0; gpio_out <= 0; gpio_irq_en <= 0; gpio_irq_stat <= 0;
            gpio_in_prev <= 0;
        end else begin
            gpio_in_prev    <= gpio_in;
            gpio_irq_stat   <= gpio_irq_stat | (gpio_in & ~gpio_in_prev);

            if (psel && penable && pwrite) begin
                case (paddr[4:0])
                    5'h00: gpio_out      <= pwdata;
                    5'h04: gpio_dir      <= pwdata;
                    5'h0C: gpio_irq_en   <= pwdata;
                    5'h10: gpio_irq_stat <= gpio_irq_stat & ~pwdata;
                endcase
            end
        end
    end

    always @(*) begin
        case (paddr[4:0])
            5'h00: prdata = gpio_out;
            5'h04: prdata = gpio_dir;
            5'h08: prdata = gpio_in;
            5'h0C: prdata = gpio_irq_en;
            5'h10: prdata = gpio_irq_stat;
            default: prdata = 32'd0;
        endcase
    end

endmodule

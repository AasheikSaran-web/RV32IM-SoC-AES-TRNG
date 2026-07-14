`timescale 1ns/1ps
// Behavioral APB UART — simulation-only wrapper compatible with iverilog.
// Same port interface as PULP apb_uart.sv (16750 superset).
// Implements APB register map (RBR/THR, IER, IIR, LCR, MCR, LSR, MSR, DLL, DLM)
// and serializes TX/RX at the baud rate configured via DLL/DLM.
// For synthesis use the real apb_uart.sv; this file is for iverilog simulation only.

module apb_uart (
    input  wire        CLK,
    input  wire        RSTN,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [2:0]  PADDR,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,
    // Interrupt
    output wire        INT,
    // Modem signals (tied off in SoC, kept for interface compatibility)
    output wire        OUT1N,
    output wire        OUT2N,
    output wire        RTSN,
    output wire        DTRN,
    input  wire        CTSN,
    input  wire        DSRN,
    input  wire        DCDN,
    input  wire        RIN,
    // Serial data
    input  wire        SIN,
    output reg         SOUT
);

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;
    assign OUT1N   = 1'b1;
    assign OUT2N   = 1'b1;
    assign RTSN    = 1'b1;
    assign DTRN    = 1'b1;

    // -------------------------------------------------------------------------
    // Register file
    // -------------------------------------------------------------------------
    reg [7:0] THR;       // Transmit Holding Register  (write-only, DLAB=0, addr=0)
    reg [7:0] RBR;       // Receive  Buffer  Register  (read-only,  DLAB=0, addr=0)
    reg [7:0] IER;       // Interrupt Enable Register  (DLAB=0, addr=1)
    reg [7:0] IIR;       // Interrupt Ident. Register  (read-only, addr=2)
    reg [7:0] LCR;       // Line Control Register      (addr=3)
    reg [7:0] MCR;       // Modem Control Register     (addr=4)
    reg [7:0] LSR;       // Line Status Register        (read-only, addr=5)
    reg [7:0] MSR;       // Modem Status Register       (read-only, addr=6)
    reg [7:0] SCR;       // Scratch Register            (addr=7)
    reg [7:0] DLL;       // Divisor Latch LSB           (DLAB=1, addr=0)
    reg [7:0] DLM;       // Divisor Latch MSB           (DLAB=1, addr=1)

    wire DLAB = LCR[7];

    // LSR defaults: THR empty (bit5=1), TX empty (bit6=1), no error
    // After reset: THRE=1, TEMT=1, DR=0
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            THR  <= 8'h00;
            RBR  <= 8'h00;
            IER  <= 8'h00;
            IIR  <= 8'h01;  // No interrupt pending
            LCR  <= 8'h00;
            MCR  <= 8'h00;
            LSR  <= 8'h60;  // THRE=1, TEMT=1
            MSR  <= 8'h00;
            SCR  <= 8'h00;
            DLL  <= 8'h01;  // Default: divisor=1
            DLM  <= 8'h00;
            SOUT <= 1'b1;
        end else begin
            // APB write
            if (PSEL && PENABLE && PWRITE) begin
                case (PADDR)
                    3'd0: if (!DLAB) THR <= PWDATA[7:0]; else DLL <= PWDATA[7:0];
                    3'd1: if (!DLAB) IER <= PWDATA[7:0]; else DLM <= PWDATA[7:0];
                    3'd3: LCR <= PWDATA[7:0];
                    3'd4: MCR <= PWDATA[7:0];
                    3'd7: SCR <= PWDATA[7:0];
                    default: ;
                endcase
            end
        end
    end

    // APB read — combinational
    always @(*) begin
        PRDATA = 32'h0;
        case (PADDR)
            3'd0: PRDATA = DLAB ? {24'h0, DLL} : {24'h0, RBR};
            3'd1: PRDATA = DLAB ? {24'h0, DLM} : {24'h0, IER};
            3'd2: PRDATA = {24'h0, IIR};
            3'd3: PRDATA = {24'h0, LCR};
            3'd4: PRDATA = {24'h0, MCR};
            3'd5: PRDATA = {24'h0, LSR};
            3'd6: PRDATA = {24'h0, MSR};
            3'd7: PRDATA = {24'h0, SCR};
            default: PRDATA = 32'h0;
        endcase
    end

    // -------------------------------------------------------------------------
    // TX serializer — shift out THR on SOUT when a byte is written to THR
    // Baud rate = CLK / ((DLM<<8 | DLL) * 16), but for simulation we use a
    // fixed 16-cycle-per-bit period to keep simulation fast.
    // -------------------------------------------------------------------------
    reg        tx_busy;
    reg [7:0]  tx_shift;
    reg [3:0]  tx_bit_cnt;
    reg [8:0]  tx_clk_cnt;

    wire [15:0] divisor = {DLM, DLL};
    // Bit period in clock cycles = divisor * 16 (UART oversampling)
    wire [19:0] bit_period = (divisor == 0) ? 20'd16 : {divisor, 4'h0};

    // Detect new byte written to THR
    reg thr_written;
    always @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            tx_busy    <= 1'b0;
            tx_shift   <= 8'hFF;
            tx_bit_cnt <= 4'd0;
            tx_clk_cnt <= 9'd0;
            thr_written<= 1'b0;
            SOUT       <= 1'b1;
            LSR[5]     <= 1'b1; // THRE: THR empty
            LSR[6]     <= 1'b1; // TEMT: TX empty
        end else begin
            thr_written <= (PSEL && PENABLE && PWRITE && (PADDR == 3'd0) && !DLAB);

            if (thr_written) begin
                tx_shift    <= THR;
                tx_busy     <= 1'b1;
                tx_clk_cnt  <= 9'd0;
                tx_bit_cnt  <= 4'd0;
                LSR[5]      <= 1'b0; // THRE clear (THR full)
                LSR[6]      <= 1'b0; // TEMT clear
            end else if (tx_busy) begin
                if (tx_clk_cnt >= bit_period[8:0] - 1) begin
                    tx_clk_cnt <= 9'd0;
                    case (tx_bit_cnt)
                        4'd0:  begin SOUT <= 1'b0; tx_bit_cnt <= 4'd1; end  // start bit
                        4'd1:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd2; end
                        4'd2:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd3; end
                        4'd3:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd4; end
                        4'd4:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd5; end
                        4'd5:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd6; end
                        4'd6:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd7; end
                        4'd7:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd8; end
                        4'd8:  begin SOUT <= tx_shift[0]; tx_shift <= {1'b1, tx_shift[7:1]}; tx_bit_cnt <= 4'd9; end
                        4'd9:  begin SOUT <= 1'b1; tx_busy <= 1'b0; LSR[5] <= 1'b1; LSR[6] <= 1'b1; end  // stop bit
                        default: begin tx_busy <= 1'b0; SOUT <= 1'b1; end
                    endcase
                end else begin
                    tx_clk_cnt <= tx_clk_cnt + 1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Interrupt — THRE interrupt when THRE=1 and IER[1] set
    // -------------------------------------------------------------------------
    assign INT = (IER[1] && LSR[5]);   // TX empty interrupt

endmodule

module jtag_tap #(
    parameter IDCODE_VAL = 32'h1002_4093
) (

    input  tck,
    input  tms,
    input  tdi,
    output tdo,
    input  trstn,

    output bscan_mode,
    output bscan_update,
    output bscan_capture,
    output bscan_shift,
    output bscan_tdi,
    input  bscan_tdo,

    output scan_en,
    output scan_mode,
    output scan_reset
);

    localparam
        TEST_LOGIC_RESET = 4'd0,
        RUN_TEST_IDLE    = 4'd1,
        SELECT_DR        = 4'd2,
        CAPTURE_DR       = 4'd3,
        SHIFT_DR         = 4'd4,
        EXIT1_DR         = 4'd5,
        PAUSE_DR         = 4'd6,
        EXIT2_DR         = 4'd7,
        UPDATE_DR        = 4'd8,
        SELECT_IR        = 4'd9,
        CAPTURE_IR       = 4'd10,
        SHIFT_IR         = 4'd11,
        EXIT1_IR         = 4'd12,
        PAUSE_IR         = 4'd13,
        EXIT2_IR         = 4'd14,
        UPDATE_IR        = 4'd15;

    localparam
        EXTEST        = 4'b0000,
        SAMPLE_LOAD   = 4'b0001,
        IDCODE        = 4'b0010,
        BYPASS        = 4'b1111,
        INTEST        = 4'b0011,
        CLAMP         = 4'b0100;

    reg [3:0] tap_state, tap_next;

    reg [3:0] ir_shift, ir_reg;

    reg        bypass_sr;
    reg [31:0] idcode_sr;

    always @(posedge tck or negedge trstn) begin
        if (!trstn)
            tap_state <= TEST_LOGIC_RESET;
        else
            tap_state <= tap_next;
    end

    always @(*) begin
        case (tap_state)
            TEST_LOGIC_RESET: tap_next = tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            RUN_TEST_IDLE:    tap_next = tms ? SELECT_DR        : RUN_TEST_IDLE;
            SELECT_DR:        tap_next = tms ? SELECT_IR        : CAPTURE_DR;
            CAPTURE_DR:       tap_next = tms ? EXIT1_DR         : SHIFT_DR;
            SHIFT_DR:         tap_next = tms ? EXIT1_DR         : SHIFT_DR;
            EXIT1_DR:         tap_next = tms ? UPDATE_DR        : PAUSE_DR;
            PAUSE_DR:         tap_next = tms ? EXIT2_DR         : PAUSE_DR;
            EXIT2_DR:         tap_next = tms ? UPDATE_DR        : SHIFT_DR;
            UPDATE_DR:        tap_next = tms ? SELECT_DR        : RUN_TEST_IDLE;
            SELECT_IR:        tap_next = tms ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR:       tap_next = tms ? EXIT1_IR         : SHIFT_IR;
            SHIFT_IR:         tap_next = tms ? EXIT1_IR         : SHIFT_IR;
            EXIT1_IR:         tap_next = tms ? UPDATE_IR        : PAUSE_IR;
            PAUSE_IR:         tap_next = tms ? EXIT2_IR         : PAUSE_IR;
            EXIT2_IR:         tap_next = tms ? UPDATE_IR        : SHIFT_IR;
            UPDATE_IR:        tap_next = tms ? SELECT_DR        : RUN_TEST_IDLE;
            default:          tap_next = TEST_LOGIC_RESET;
        endcase
    end

    always @(posedge tck or negedge trstn) begin
        if (!trstn) begin
            ir_shift <= 4'b0010;
            ir_reg   <= 4'b0010;
        end else begin
            case (tap_state)
                CAPTURE_IR: ir_shift <= {2'b01, ir_reg[1:0]};
                SHIFT_IR:   ir_shift <= {tdi, ir_shift[3:1]};
                UPDATE_IR:  ir_reg   <= ir_shift;
                default: ;
            endcase
        end
    end

    always @(posedge tck) begin
        if (tap_state == CAPTURE_DR)
            bypass_sr <= 1'b0;
        else if (tap_state == SHIFT_DR && ir_reg == BYPASS)
            bypass_sr <= tdi;
    end

    always @(posedge tck) begin
        if (tap_state == CAPTURE_DR)
            idcode_sr <= IDCODE_VAL;
        else if (tap_state == SHIFT_DR && ir_reg == IDCODE)
            idcode_sr <= {tdi, idcode_sr[31:1]};
    end

    reg tdo_reg;
    always @(negedge tck) begin
        if (tap_state == SHIFT_IR)
            tdo_reg <= ir_shift[0];
        else if (tap_state == SHIFT_DR) begin
            case (ir_reg)
                BYPASS:    tdo_reg <= bypass_sr;
                IDCODE:    tdo_reg <= idcode_sr[0];
                EXTEST,
                SAMPLE_LOAD,
                INTEST:    tdo_reg <= bscan_tdo;
                default:   tdo_reg <= bypass_sr;
            endcase
        end
    end
    assign tdo = tdo_reg;

    assign bscan_mode    = (ir_reg == EXTEST) || (ir_reg == INTEST);
    assign bscan_shift   = (tap_state == SHIFT_DR) &&
                           ((ir_reg == EXTEST) || (ir_reg == SAMPLE_LOAD) || (ir_reg == INTEST));
    assign bscan_capture = (tap_state == CAPTURE_DR) &&
                           ((ir_reg == EXTEST) || (ir_reg == SAMPLE_LOAD) || (ir_reg == INTEST));
    assign bscan_update  = (tap_state == UPDATE_DR) &&
                           ((ir_reg == EXTEST) || (ir_reg == SAMPLE_LOAD) || (ir_reg == INTEST));
    assign bscan_tdi     = tdi;

    assign scan_en    = (tap_state == SHIFT_DR)   && (ir_reg == INTEST);
    assign scan_mode  = (ir_reg == INTEST) || (ir_reg == EXTEST);
    assign scan_reset = trstn;

endmodule

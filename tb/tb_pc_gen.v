`timescale 1ns/1ps
module tb_pc_gen;

    reg         clk, rst_n;
    reg         stall;
    reg         flush;
    reg [31:0]  redirect_pc;
    wire [31:0] pc_out;
    wire [31:0] pc_plus4;

    reg [31:0] pc_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_reg <= 32'h0000_0000;
        else if (flush)
            pc_reg <= redirect_pc;
        else if (!stall)
            pc_reg <= pc_reg + 32'd4;
    end

    assign pc_out   = pc_reg;
    assign pc_plus4 = pc_reg + 32'd4;

    always #5 clk = ~clk;

    integer pass = 0, fail = 0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin
                $display("  PASS [%0s] got=%08h", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_pc_gen.vcd");
        $dumpvars(0, tb_pc_gen);

        clk = 0; rst_n = 0; stall = 0; flush = 0; redirect_pc = 0;

        @(posedge clk); #1;
        check(pc_out, 32'h0, "RESET_PC");

        rst_n = 1;
        @(posedge clk); #1; check(pc_out, 32'h4,  "SEQ+4_1");
        @(posedge clk); #1; check(pc_out, 32'h8,  "SEQ+4_2");
        @(posedge clk); #1; check(pc_out, 32'hC,  "SEQ+4_3");

        stall = 1;
        @(posedge clk); #1; check(pc_out, 32'hC,  "STALL_HOLD");
        @(posedge clk); #1; check(pc_out, 32'hC,  "STALL_HOLD2");
        stall = 0;
        @(posedge clk); #1; check(pc_out, 32'h10, "POST_STALL");

        redirect_pc = 32'h0000_0100;
        flush = 1;
        @(posedge clk); #1;
        flush = 0;
        check(pc_out, 32'h100, "REDIRECT_BRANCH");
        @(posedge clk); #1; check(pc_out, 32'h104, "POST_REDIRECT_SEQ");

        redirect_pc = 32'hFFFF_0000;
        flush = 1;
        @(posedge clk); #1;
        flush = 0;
        check(pc_out, 32'hFFFF_0000, "REDIRECT_TRAP");

        @(posedge clk); #1;
        redirect_pc = 32'h5555_5554;
        flush = 1; stall = 1;
        @(posedge clk); #1;
        flush = 0; stall = 0;
        check(pc_out, 32'h5555_5554, "FLUSH_BEATS_STALL");

        @(posedge clk); #1;
        check(pc_plus4, pc_out + 32'd4, "PC_PLUS4");

        rst_n = 0; @(posedge clk); #1; rst_n = 1;
        redirect_pc = 32'hFFFF_FFFC;
        flush = 1; @(posedge clk); #1; flush = 0;
        @(posedge clk); #1;
        check(pc_out, 32'h0000_0000, "WRAP_AROUND");

        $display("\n=== PC_GEN Results: %0d PASS, %0d FAIL ===", pass, fail);
        if (fail == 0) $display("ALL TESTS PASSED");
        else           $display("FAILURES DETECTED");
        $finish;
    end

endmodule

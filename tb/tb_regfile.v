`timescale 1ns/1ps
module tb_regfile;

    reg         clk, rst_n;
    reg         we;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] wdata;
    wire [31:0] rdata1, rdata2;

    reg [31:0] regs [1:31];

    always @(posedge clk) begin
        if (we && rd != 5'd0) regs[rd] <= wdata;
    end

    assign rdata1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rdata2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1) regs[i] = 32'd0;
    end

    always #5 clk = ~clk;

    integer pass=0, fail=0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_regfile.vcd");
        $dumpvars(0, tb_regfile);

        clk=0; rst_n=0; we=0; rs1=0; rs2=0; rd=0; wdata=0;
        #3; rst_n=1;

        rs1=0; rs2=0; #1;
        check(rdata1, 32'd0, "X0_READ1_ZERO");
        check(rdata2, 32'd0, "X0_READ2_ZERO");

        we=1; rd=0; wdata=32'hDEAD_BEEF; @(posedge clk); #1;
        rs1=0; #1;
        check(rdata1, 32'd0, "X0_WRITE_BLOCKED");
        we=0;

        for (i=1; i<32; i=i+1) begin
            we=1; rd=i; wdata=32'hA0000000 | i; @(posedge clk); #1;
            we=0; rs1=i; #1;
            check(rdata1, 32'hA0000000 | i, "REGFILE_WR_RD");
        end

        we=1; rd=5; wdata=32'h1111_1111; @(posedge clk); #1;
        we=1; rd=6; wdata=32'h2222_2222; @(posedge clk); #1;
        we=0; rs1=5; rs2=6; #1;
        check(rdata1, 32'h1111_1111, "RS1_RS2_INDEP_1");
        check(rdata2, 32'h2222_2222, "RS1_RS2_INDEP_2");

        rs1=7; rs2=7;
        we=0; rd=7; wdata=32'hFFFF_FFFF; @(posedge clk); #1;
        check(rdata1, 32'hA000_0007, "WE_GATE");

        we=1; rd=10; wdata=32'hCAFE_BABE; @(posedge clk); #1;
        we=0; rs1=10; #1;
        check(rdata1, 32'hCAFE_BABE, "WRITE_THEN_READ");

        we=1; rd=15; wdata=32'h0BAD_F00D;
        rs1=15; rs2=15; #1;
        check(rdata1, 32'hA000_000F, "READ_BEFORE_WRITE_OLD");
        @(posedge clk); #1;
        check(rdata1, 32'h0BAD_F00D, "READ_AFTER_WRITE_NEW");
        we=0;

        $display("\n=== REGFILE Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule

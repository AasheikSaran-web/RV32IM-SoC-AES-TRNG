`timescale 1ns/1ps
module tb_hazard;

    reg         clk, rst_n;

    reg [4:0]   idex_rs1, idex_rs2, idex_rd;
    reg         idex_reg_write, idex_mem_read, idex_is_mul_div;

    reg [4:0]   exmem_rd;
    reg         exmem_reg_write, exmem_mem_read;

    reg [4:0]   memwb_rd;
    reg         memwb_reg_write;

    wire        stall;
    wire        flush;
    wire [1:0]  fwd_a, fwd_b;

    wire load_use_stall = idex_mem_read &&
                          ((idex_rd == idex_rs1) || (idex_rd == idex_rs2)) &&
                          (idex_rd != 5'd0);

    assign stall = load_use_stall || idex_is_mul_div;

    reg branch_taken;
    assign flush = branch_taken;

    assign fwd_a =
        (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs1)) ? 2'b10 :
        (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs1)) ? 2'b01 :
        2'b00;

    assign fwd_b =
        (exmem_reg_write && (exmem_rd != 5'd0) && (exmem_rd == idex_rs2)) ? 2'b10 :
        (memwb_reg_write && (memwb_rd != 5'd0) && (memwb_rd == idex_rs2)) ? 2'b01 :
        2'b00;

    always #5 clk = ~clk;

    integer pass=0, fail=0;
    task check2;
        input [1:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s] %b", label, got); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask
    task check1;
        input got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_hazard.vcd");
        $dumpvars(0, tb_hazard);
        clk=0; rst_n=0;
        idex_rs1=0; idex_rs2=0; idex_rd=0;
        idex_reg_write=0; idex_mem_read=0; idex_is_mul_div=0;
        exmem_rd=0; exmem_reg_write=0; exmem_mem_read=0;
        memwb_rd=0; memwb_reg_write=0;
        branch_taken=0;
        @(posedge clk); rst_n=1;

        idex_rs1=5'd1; idex_rs2=5'd2; idex_rd=5'd3;
        exmem_rd=5'd5; exmem_reg_write=1;
        memwb_rd=5'd6; memwb_reg_write=1; #1;
        check1(stall, 0, "NO_HAZARD_NO_STALL");
        check2(fwd_a, 2'b00, "NO_HAZARD_FWDA");
        check2(fwd_b, 2'b00, "NO_HAZARD_FWDB");

        idex_rs1=5'd5; exmem_rd=5'd5; exmem_reg_write=1; #1;
        check2(fwd_a, 2'b10, "EX_FWD_A_FROM_EXMEM");

        idex_rs2=5'd6; memwb_rd=5'd6; memwb_reg_write=1;
        exmem_rd=5'd9; #1;
        check2(fwd_b, 2'b01, "MEM_FWD_B_FROM_MEMWB");

        idex_rs1=5'd5;
        exmem_rd=5'd5; exmem_reg_write=1;
        memwb_rd=5'd5; memwb_reg_write=1; #1;
        check2(fwd_a, 2'b10, "EX_FWD_PRIORITY_OVER_MEM");

        idex_rs1=5'd0; exmem_rd=5'd0; exmem_reg_write=1; #1;
        check2(fwd_a, 2'b00, "X0_NO_FORWARD");

        idex_rs1=5'd7; idex_rs2=5'd8; idex_rd=5'd7; idex_mem_read=1; #1;
        check1(stall, 1, "LOAD_USE_STALL");
        idex_mem_read=0; idex_rd=5'd3; #1;
        check1(stall, 0, "LOAD_USE_RESOLVED");

        idex_rd=5'd0; idex_mem_read=1; idex_rs1=5'd0; #1;
        check1(stall, 0, "LOAD_USE_X0_NO_STALL");
        idex_mem_read=0; idex_rd=5'd3;

        branch_taken=1; #1;
        check1(flush, 1, "CTRL_FLUSH");
        branch_taken=0; #1;
        check1(flush, 0, "CTRL_FLUSH_CLEAR");

        idex_mem_read=0; idex_rd=5'd1; idex_rs1=5'd2;
        idex_is_mul_div=1; #1;
        check1(stall, 1, "MULDIV_STALL");
        idex_is_mul_div=0; #1;
        check1(stall, 0, "MULDIV_DONE");

        idex_rs1=5'd5; idex_rd=5'd5; idex_mem_read=1; idex_is_mul_div=1; #1;
        check1(stall, 1, "SIMULTANEOUS_STALLS");

        $display("\n=== HAZARD Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule

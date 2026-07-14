`timescale 1ns/1ps

`define MEM_WORDS 4096

module core_sanity_tb;

    reg clk, rst_n;
    always #5 clk = ~clk;

    wire [31:0] imem_addr;
    wire        imem_req;
    reg  [31:0] imem_rdata;
    reg         imem_ready;

    wire [31:0] dmem_addr;
    wire        dmem_req;
    wire        dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    reg         dmem_ready;

    reg         timer_irq, soft_irq, ext_irq;

    reg [31:0] imem [0:`MEM_WORDS-1];
    reg [7:0]  dmem [0:(`MEM_WORDS*4)-1];

    always @(posedge clk) begin
        if (imem_req) begin
            imem_rdata <= imem[imem_addr[13:2]];
            imem_ready <= 1;
        end else
            imem_ready <= 0;
    end

    always @(posedge clk) begin
        dmem_ready <= 0;
        if (dmem_req) begin
            if (dmem_we) begin
                if (dmem_be[0]) dmem[dmem_addr+0] <= dmem_wdata[7:0];
                if (dmem_be[1]) dmem[dmem_addr+1] <= dmem_wdata[15:8];
                if (dmem_be[2]) dmem[dmem_addr+2] <= dmem_wdata[23:16];
                if (dmem_be[3]) dmem[dmem_addr+3] <= dmem_wdata[31:24];
            end else begin
                dmem_rdata <= {dmem[dmem_addr+3], dmem[dmem_addr+2],
                               dmem[dmem_addr+1], dmem[dmem_addr+0]};
            end
            dmem_ready <= 1;
        end
    end

    rv32i_cpu #(.RESET_ADDR(32'h0)) u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),

        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready),

        .dmem_addr  (dmem_addr),
        .dmem_req   (dmem_req),
        .dmem_we    (dmem_we),
        .dmem_be    (dmem_be),
        .dmem_wdata (dmem_wdata),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),

        .timer_irq  (timer_irq),
        .soft_irq   (soft_irq),
        .ext_irq    (ext_irq)
    );

    task load_program;
        integer i;
        begin
            for (i=0; i<`MEM_WORDS; i=i+1) imem[i] = 32'h0000_0013;
            for (i=0; i<`MEM_WORDS*4; i=i+1) dmem[i] = 8'h00;

            imem[0]  = 32'h00000297;
            imem[1]  = 32'h60028293;
            imem[2]  = 32'h30529073;
            imem[3]  = 32'h00001137;

            imem[4]  = 32'h00500093;
            imem[5]  = 32'h00300113;
            imem[6]  = 32'h002081B3;
            imem[7]  = 32'h40208233;
            imem[8]  = 32'h002092B3;
            imem[9]  = 32'h0020E333;
            imem[10] = 32'h0020C3B3;
            imem[11] = 32'h0020A433;
            imem[12] = 32'h001124B3;

            imem[13] = 32'h00309513;
            imem[14] = 32'h00305593;
            imem[15] = 32'hFFF00613;

            imem[16] = 32'hABCDE6B7;
            imem[17] = 32'h00000717;
            imem[18] = 32'h00070713;

            imem[19] = 32'hFEA12023;
            imem[20] = 32'hFE012783;
            imem[21] = 32'h00109823;
            imem[22] = 32'h01011803;
            imem[23] = 32'h00108023;
            imem[24] = 32'h00010883;

            imem[25] = 32'hFFF00913;
            imem[26] = 32'h01208023;
            imem[27] = 32'h00014983;

            imem[28] = 32'h00208463;
            imem[29] = 32'h00000013;
            imem[30] = 32'h00209463;
            imem[31] = 32'hxxxxxxxx;
            imem[32] = 32'h0020C463;
            imem[33] = 32'h00000013;
            imem[34] = 32'h0010D463;
            imem[35] = 32'hxxxxxxxx;

            imem[36] = 32'h010000EF;
            imem[37] = 32'hxxxxxxxx;
            imem[38] = 32'hxxxxxxxx;
            imem[39] = 32'hxxxxxxxx;
            imem[40] = 32'h00008067;
            imem[41] = 32'h00000013;

            imem[42] = 32'hB0002B03;
            imem[43] = 32'h12300B73;

            imem[44] = 32'h30405073;
            imem[45] = 32'h30046073;

            imem[46] = 32'h00000013;
            imem[47] = 32'h00000013;
            imem[48] = 32'h00000013;
            imem[49] = 32'h00000013;
            imem[50] = 32'h00000013;

            imem[51] = 32'h00000013;
            imem[52] = 32'h00000013;

            imem[53] = 32'h02208C33;
            imem[54] = 32'h0220C CB3;

            imem[54] = 32'h0220_4CB3;
            imem[55] = 32'h0220_6D33;

            imem[56] = 32'h00700093;
            imem[57] = 32'h00108133;
            imem[58] = 32'h00210133;

            imem[59] = 32'h00012183;
            imem[60] = 32'h00318233;

            imem[61] = 32'h0000006F;

            imem[32'h600/4]     = 32'hBEEF0F37;
            imem[32'h604/4]     = 32'hFEFF0F13;
            imem[32'h608/4]     = 32'h30200073;

        end
    endtask

    integer pass_cnt=0, fail_cnt=0, cycle=0;

    task expect_reg;
        input [4:0]  reg_id;
        input [31:0] exp_val;
        input [127:0] label;

        reg [31:0] got;
        begin

            case (reg_id)
                5'd1:  got = u_cpu.regfile[1];
                5'd2:  got = u_cpu.regfile[2];
                5'd3:  got = u_cpu.regfile[3];
                5'd4:  got = u_cpu.regfile[4];
                5'd5:  got = u_cpu.regfile[5];
                5'd6:  got = u_cpu.regfile[6];
                5'd7:  got = u_cpu.regfile[7];
                5'd8:  got = u_cpu.regfile[8];
                5'd9:  got = u_cpu.regfile[9];
                5'd10: got = u_cpu.regfile[10];
                5'd22: got = u_cpu.regfile[22];
                5'd24: got = u_cpu.regfile[24];
                5'd30: got = u_cpu.regfile[30];
                default: got = 32'hXXXX_XXXX;
            endcase
            if (got === exp_val) begin
                $display("  PASS [%0s] x%0d=%08h", label, reg_id, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL [%0s] x%0d got=%08h exp=%08h", label, reg_id, got, exp_val);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("core_sanity_tb.vcd");
        $dumpvars(0, core_sanity_tb);

        clk=0; rst_n=0;
        timer_irq=0; soft_irq=0; ext_irq=0;

        load_program();

        repeat(3) @(posedge clk);
        rst_n = 1;

        repeat(200) @(posedge clk);

        soft_irq = 1;
        repeat(10) @(posedge clk);
        soft_irq = 0;

        repeat(50) @(posedge clk);

        $display("\n--- Core Sanity Register Checks ---");

        expect_reg(3,  32'd8,        "ADD_x3=8");
        expect_reg(4,  32'd2,        "SUB_x4=2");
        expect_reg(5,  32'd1,        "AND_x5=1");
        expect_reg(6,  32'd7,        "OR_x6=7");
        expect_reg(7,  32'd6,        "XOR_x7=6");
        expect_reg(8,  32'd0,        "SLT_x8=0");
        expect_reg(9,  32'd1,        "SLT_x9=1");
        expect_reg(10, 32'd40,       "SLLI_x10=40");

        expect_reg(15, 32'd40,       "LW_x15=40");
        expect_reg(16, 32'd5,        "LH_x16=5");
        expect_reg(17, 32'd5,        "LB_x17=5");

        expect_reg(30, 32'hBEEF0000, "IRQ_HANDLER_x30");

        expect_reg(24, 32'd15,       "MUL_x24=15");

        expect_reg(2, 32'd28, "RAW_FWD_x2=28");

        $display("\n=== CORE SANITY: %0d PASS, %0d FAIL ===", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

    initial begin
        #100000;
        $display("WATCHDOG: simulation exceeded 100us (10000 cycles @ 10ns)");
        $finish;
    end

endmodule

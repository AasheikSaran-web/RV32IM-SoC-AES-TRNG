`timescale 1ns/1ps
module tb_aes_instr;

    reg  [31:0] rs1, rs2;
    reg  [2:0]  funct3;
    reg  [6:0]  funct7;
    wire [31:0] result;

    aes_instr dut (.rs1(rs1), .rs2(rs2), .funct3(funct3), .funct7(funct7), .result(result));

    integer pass=0, fail=0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s] %08h", label, got); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask

    task set_esb; input [1:0] bs; begin funct3=3'b000; funct7={bs,5'b00001}; end endtask

    task set_emx; input [1:0] bs; begin funct3=3'b000; funct7={bs,5'b00010}; end endtask

    initial begin
        $dumpfile("tb_aes_instr.vcd");
        $dumpvars(0, tb_aes_instr);

        rs1=32'd0;

        set_esb(2'd0); rs2=32'h0000_0000; #1;
        check(result, 32'h0000_0063, "SBOX_0x00_bs0");

        set_esb(2'd0); rs2=32'h0000_0053; #1;
        check(result, 32'h0000_00ED, "SBOX_0x53_bs0");

        set_esb(2'd0); rs2=32'h0000_00FF; #1;
        check(result, 32'h0000_0016, "SBOX_0xFF_bs0");

        set_esb(2'd1); rs2=32'h0000_5300; #1;
        check(result, 32'h0000_ED00, "SBOX_0x53_bs1");
        set_esb(2'd2); rs2=32'h0053_0000; #1;
        check(result, 32'h00ED_0000, "SBOX_0x53_bs2");
        set_esb(2'd3); rs2=32'h5300_0000; #1;
        check(result, 32'hED00_0000, "SBOX_0x53_bs3");

        set_esb(2'd0); rs1=32'hABCD_EF01; rs2=32'h0000_0000; #1;
        check(result, 32'hABCD_EF62, "ESB_ACCUM");

        set_emx(2'd0); rs1=32'd0; rs2=32'h0000_0001; #1;
        check(result, 32'h7C7C_84F8, "EMX_SBOX01_bs0");

        set_emx(2'd1); rs1=32'd0; rs2=32'h0000_0100; #1;
        check(result, 32'h7C84_F87C, "EMX_SBOX01_bs1");

        set_emx(2'd2); rs1=32'd0; rs2=32'h0001_0000; #1;
        check(result, 32'h84F8_7C7C, "EMX_SBOX01_bs2");

        set_emx(2'd3); rs1=32'd0; rs2=32'h0100_0000; #1;
        check(result, 32'hF87C_7C84, "EMX_SBOX01_bs3");

        set_emx(2'd0); rs1=32'd0; rs2=32'h0000_0000; #1;
        begin : emx_acc
            reg [31:0] t0;
            t0 = result;

            check(t0, 32'h6363_A5C6, "EMX_ZERO_bs0");
            set_emx(2'd1); rs1=t0; rs2=32'h0000_0000; #1;
            t0 = result;

            check(t0, 32'h00C6_63A5, "EMX_ZERO_acc1");
        end

        funct3 = 3'b001; funct7 = 7'd0;
        rs1 = 32'd0; rs2 = 32'h09CF_4F3C; #1;

        rs2 = 32'h0000_0000; #1;
        check(result, 32'h6263_6363, "KS1_ZERO_RNUM0");

        rs2 = 32'h0000_0001; #1;
        check(result, 32'h6163_7C63, "KS1_RS2_1_RNUM1");

        funct3 = 3'b010; funct7 = 7'd0;
        rs1 = 32'hDEAD_BEEF; rs2 = 32'h1234_5678; #1;
        check(result, 32'hCC99_E897, "KS2_XOR");
        rs1 = 32'd0; rs2 = 32'hFFFF_FFFF; #1;
        check(result, 32'hFFFF_FFFF, "KS2_ZERO_XOR_MAX");
        rs1 = 32'hAAAA_AAAA; rs2 = 32'hAAAA_AAAA; #1;
        check(result, 32'd0,         "KS2_SELF_ZERO");

        set_esb(2'd0); rs1=32'd0; rs2=32'h0000_00B9; #1;
        check(result[7:0], 8'h56, "FIPS197_SBOX_B9");
        set_esb(2'd0); rs1=32'd0; rs2=32'h0000_00B5; #1;
        check(result[7:0], 8'hD5, "FIPS197_SBOX_B5");
        set_esb(2'd0); rs1=32'd0; rs2=32'h0000_00C0; #1;
        check(result[7:0], 8'hBA, "FIPS197_SBOX_C0");
        set_esb(2'd0); rs1=32'd0; rs2=32'h0000_0094; #1;
        check(result[7:0], 8'h22, "FIPS197_SBOX_94");

        $display("\n=== AES_INSTR Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end
endmodule

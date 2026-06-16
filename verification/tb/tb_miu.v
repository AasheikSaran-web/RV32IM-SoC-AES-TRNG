`timescale 1ns/1ps
module tb_miu;

    reg  [31:0] addr;
    reg  [31:0] wdata_in;
    reg  [2:0]  funct3;
    reg         is_write;

    wire [31:0] mem_addr;
    wire [3:0]  byte_en;
    wire [31:0] mem_wdata;

    reg  [31:0] mem_rdata;
    wire [31:0] load_result;

    wire [1:0] byte_off = addr[1:0];
    assign mem_addr = {addr[31:2], 2'b00};

    assign byte_en =
        (funct3[1:0] == 2'b00) ? (4'b0001 << byte_off) :
        (funct3[1:0] == 2'b01) ? (4'b0011 << byte_off) :
        4'b1111;

    assign mem_wdata =
        (funct3[1:0] == 2'b00) ? {4{wdata_in[7:0]}} :
        (funct3[1:0] == 2'b01) ? {2{wdata_in[15:0]}} :
        wdata_in;

    wire [7:0]  byte_val  = (byte_off==2'd0) ? mem_rdata[7:0]  :
                            (byte_off==2'd1) ? mem_rdata[15:8] :
                            (byte_off==2'd2) ? mem_rdata[23:16]: mem_rdata[31:24];
    wire [15:0] half_val  = (byte_off==2'd0) ? mem_rdata[15:0] : mem_rdata[31:16];
    wire [31:0] word_val  = mem_rdata;

    assign load_result =
        (funct3 == 3'b000) ? {{24{byte_val[7]}}, byte_val}  :
        (funct3 == 3'b001) ? {{16{half_val[15]}}, half_val} :
        (funct3 == 3'b010) ? word_val :
        (funct3 == 3'b100) ? {24'b0, byte_val}              :
        (funct3 == 3'b101) ? {16'b0, half_val}              :
        32'bx;

    integer pass=0, fail=0;
    task check;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask
    task check4;
        input [3:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s] be=%b", label, got); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_miu.vcd");
        $dumpvars(0, tb_miu);

        is_write=1; funct3=3'b010;
        addr=32'h1000; wdata_in=32'hDEAD_BEEF; #1;
        check(mem_addr, 32'h1000, "SW_ADDR_ALIGN");
        check4(byte_en, 4'b1111, "SW_BYTE_EN");
        check(mem_wdata, 32'hDEAD_BEEF, "SW_WDATA");

        funct3=3'b001;
        addr=32'h1000; wdata_in=32'h0000_CAFE; #1;
        check4(byte_en, 4'b0011, "SH_OFF0_BE");
        check(mem_wdata[15:0], 16'hCAFE, "SH_OFF0_DATA");

        addr=32'h1002; wdata_in=32'h0000_BABE; #1;
        check(mem_addr, 32'h1000, "SH_OFF2_WADDR");
        check4(byte_en, 4'b1100, "SH_OFF2_BE");
        check(mem_wdata[31:16], 16'hBABE, "SH_OFF2_DATA");

        funct3=3'b000;
        addr=32'h1000; wdata_in=32'hAA; #1; check4(byte_en, 4'b0001, "SB_OFF0_BE");
        addr=32'h1001; wdata_in=32'hBB; #1; check4(byte_en, 4'b0010, "SB_OFF1_BE");
        addr=32'h1002; wdata_in=32'hCC; #1; check4(byte_en, 4'b0100, "SB_OFF2_BE");
        addr=32'h1003; wdata_in=32'hDD; #1; check4(byte_en, 4'b1000, "SB_OFF3_BE");

        is_write=0; funct3=3'b010;
        addr=32'h2000; mem_rdata=32'h1234_5678; #1;
        check(load_result, 32'h1234_5678, "LW");

        funct3=3'b001;
        addr=32'h2000; mem_rdata=32'hXXXX_1234; #1;
        check(load_result, 32'h0000_1234, "LH_OFF0_POS");

        addr=32'h2000; mem_rdata=32'hXXXX_8001; #1;
        check(load_result, 32'hFFFF_8001, "LH_OFF0_NEG_EXT");

        addr=32'h2002; mem_rdata=32'h8001_XXXX; #1;
        check(load_result, 32'hFFFF_8001, "LH_OFF2_NEG_EXT");

        funct3=3'b000;
        addr=32'h2000; mem_rdata=32'hXXXX_XX80; #1;
        check(load_result, 32'hFFFF_FF80, "LB_OFF0_NEG_EXT");
        addr=32'h2001; mem_rdata=32'hXXXX_7FXX; #1;
        check(load_result, 32'h0000_007F, "LB_OFF1_POS_EXT");
        addr=32'h2003; mem_rdata=32'hFF_XXXXXX; #1;
        check(load_result, 32'hFFFF_FFFF, "LB_OFF3_0xFF_NEG");

        funct3=3'b100;
        addr=32'h2000; mem_rdata=32'hXXXX_XXFF; #1;
        check(load_result, 32'h0000_00FF, "LBU_NO_SIGN_EXT");
        addr=32'h2000; mem_rdata=32'hXXXX_XX80; #1;
        check(load_result, 32'h0000_0080, "LBU_0x80_ZERO_EXT");

        funct3=3'b101;
        addr=32'h2000; mem_rdata=32'hXXXX_8000; #1;
        check(load_result, 32'h0000_8000, "LHU_NO_SIGN_EXT");

        $display("\n=== MIU Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule

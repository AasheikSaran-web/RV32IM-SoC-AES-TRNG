`timescale 1ns/1ps
module tb_decoder;

    reg  [31:0] instr;
    wire [4:0]  rd, rs1, rs2;
    wire [31:0] imm;
    wire [3:0]  alu_op;
    wire        alu_src;
    wire        mem_read, mem_write;
    wire [1:0]  mem_size;
    wire        mem_sign;
    wire        reg_write;
    wire        branch;
    wire        jal, jalr;
    wire        lui, auipc;
    wire        is_mul_div;
    wire        csr_op;
    wire        illegal;

    assign rd      = instr[11:7];
    assign rs1     = instr[19:15];
    assign rs2     = instr[24:20];

    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    assign imm = (opcode == 7'b0000011 || opcode == 7'b0010011 || opcode == 7'b1100111) ? imm_i :
                 (opcode == 7'b0100011) ? imm_s :
                 (opcode == 7'b1100011) ? imm_b :
                 (opcode == 7'b0110111 || opcode == 7'b0010111) ? imm_u :
                 (opcode == 7'b1101111) ? imm_j : 32'd0;

    assign lui    = (opcode == 7'b0110111);
    assign auipc  = (opcode == 7'b0010111);
    assign jal    = (opcode == 7'b1101111);
    assign jalr   = (opcode == 7'b1100111);
    assign branch = (opcode == 7'b1100011);
    assign mem_read  = (opcode == 7'b0000011);
    assign mem_write = (opcode == 7'b0100011);
    assign is_mul_div= (opcode == 7'b0110011) && (funct7 == 7'b0000001);
    assign csr_op    = (opcode == 7'b1110011) && (funct3 != 3'b000);
    assign illegal   = !(lui||auipc||jal||jalr||branch||mem_read||mem_write||
                         (opcode==7'b0110011)||(opcode==7'b0010011)||
                         (opcode==7'b1110011));

    assign reg_write = (opcode==7'b0110011||opcode==7'b0010011||
                        opcode==7'b0000011||opcode==7'b0110111||
                        opcode==7'b0010111||opcode==7'b1101111||
                        opcode==7'b1100111||opcode==7'b1110011) && (rd != 5'd0);
    assign alu_src   = (opcode==7'b0010011||opcode==7'b0000011||
                        opcode==7'b0100011||opcode==7'b1100111||
                        opcode==7'b0110111||opcode==7'b0010111);
    assign mem_size  = funct3[1:0];
    assign mem_sign  = funct3[2];

    assign alu_op    = {funct7[5] & ((opcode==7'b0110011) ||
                                     (opcode==7'b0010011 && funct3[1:0]==2'b01)), funct3};

    integer pass=0, fail=0;

    task check_bit;
        input got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%b exp=%b", label, got, exp); fail=fail+1; end
        end
    endtask

    task check_w;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s] %08h", label, got); pass=pass+1; end
            else begin $display("  FAIL [%0s] got=%08h exp=%08h", label, got, exp); fail=fail+1; end
        end
    endtask

    initial begin
        $dumpfile("tb_decoder.vcd");
        $dumpvars(0, tb_decoder);

        instr = {20'hABCDE, 5'd1, 7'b0110111}; #1;
        check_bit(lui, 1,     "LUI_decode");
        check_bit(reg_write,1,"LUI_regwrite");
        check_w(imm, 32'hABCDE000, "LUI_imm");
        check_w({27'd0,rd}, {27'd0,5'd1}, "LUI_rd");

        instr = {20'h12345, 5'd2, 7'b0010111}; #1;
        check_bit(auipc, 1, "AUIPC_decode");
        check_w(imm, 32'h12345000, "AUIPC_imm");

        instr = {1'b0, 10'b0000000100, 1'b0, 8'h00, 5'd3, 7'b1101111}; #1;
        check_bit(jal, 1, "JAL_decode");
        check_bit(reg_write, 1, "JAL_regwrite");
        check_w(imm, 32'd8, "JAL_imm8");

        instr = {12'd12, 5'd1, 3'b000, 5'd4, 7'b1100111}; #1;
        check_bit(jalr, 1, "JALR_decode");
        check_w(imm, 32'd12, "JALR_imm");

        instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 4'b1000, 1'b0, 7'b1100011}; #1;
        check_bit(branch, 1, "BEQ_decode");
        check_bit(reg_write, 0, "BEQ_no_regwrite");

        instr = {12'd4, 5'd6, 3'b010, 5'd5, 7'b0000011}; #1;
        check_bit(mem_read, 1,  "LW_decode");
        check_bit(reg_write,1,  "LW_regwrite");
        check_w(mem_size, 2'b10,"LW_size");
        check_w(imm, 32'd4,     "LW_imm");

        instr = {12'd2, 5'd8, 3'b100, 5'd7, 7'b0000011}; #1;
        check_bit(mem_read, 1,  "LBU_decode");
        check_bit(mem_sign, 1,  "LBU_unsigned");
        check_w(mem_size, 2'b00,"LBU_size");

        instr = {7'b0000000, 5'd9, 5'd10, 3'b010, 5'b01000, 7'b0100011}; #1;
        check_bit(mem_write, 1, "SW_decode");
        check_bit(reg_write, 0, "SW_no_regwrite");
        check_w(imm, 32'd8,     "SW_imm");

        instr = {12'hFFF, 5'd12, 3'b000, 5'd11, 7'b0010011}; #1;
        check_bit(alu_src, 1, "ADDI_alu_src");
        check_bit(reg_write,1,"ADDI_regwrite");
        check_w(imm, 32'hFFFF_FFFF, "ADDI_imm_neg");

        instr = {7'b0100000, 5'd5, 5'd14, 3'b101, 5'd13, 7'b0010011}; #1;
        check_w(alu_op, 4'b1101, "SRAI_aluop");

        instr = {7'b0000000, 5'd17, 5'd16, 3'b000, 5'd15, 7'b0110011}; #1;
        check_bit(alu_src, 0, "ADD_reg_src");
        check_w(alu_op, 4'b0000, "ADD_aluop");

        instr = {7'b0100000, 5'd20, 5'd19, 3'b000, 5'd18, 7'b0110011}; #1;
        check_w(alu_op, 4'b1000, "SUB_aluop");

        instr = {7'b0000001, 5'd23, 5'd22, 3'b000, 5'd21, 7'b0110011}; #1;
        check_bit(is_mul_div, 1, "MUL_decode");

        instr = {12'h340, 5'd25, 3'b001, 5'd24, 7'b1110011}; #1;
        check_bit(csr_op, 1, "CSR_decode");

        instr = 32'h0000_0073; #1;

        check_bit(illegal, 0, "ECALL_not_illegal");

        instr = 32'h0000_0000; #1;
        check_bit(illegal, 1, "ILLEGAL_instr");

        $display("\n=== DECODER Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

endmodule

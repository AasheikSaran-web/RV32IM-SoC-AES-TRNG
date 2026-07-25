module rv32i_cpu #(
    parameter RESET_ADDR = 32'h0000_0000
) (
    input                clk,
    input                rst_n,

    output        [31:0] imem_addr,
    output               imem_req,
    input         [31:0] imem_rdata,
    input                imem_ready,

    output        [31:0] dmem_addr,
    output        [31:0] dmem_wdata,
    output         [3:0] dmem_wstrb,
    output               dmem_req,
    input         [31:0] dmem_rdata,
    input                dmem_ready,

    input                timer_irq,
    input                soft_irq,
    input                ext_irq
);

    localparam OP_LUI      = 7'b0110111;
    localparam OP_AUIPC    = 7'b0010111;
    localparam OP_JAL      = 7'b1101111;
    localparam OP_JALR     = 7'b1100111;
    localparam OP_BRANCH   = 7'b1100011;
    localparam OP_LOAD     = 7'b0000011;
    localparam OP_STORE    = 7'b0100011;
    localparam OP_IMM      = 7'b0010011;
    localparam OP_REG      = 7'b0110011;
    localparam OP_FENCE    = 7'b0001111;
    localparam OP_SYSTEM   = 7'b1110011;

    localparam OP_CUSTOM0  = 7'b0001011;

    localparam ALU_ADD    = 5'd0;
    localparam ALU_SUB    = 5'd1;
    localparam ALU_SLL    = 5'd2;
    localparam ALU_SLT    = 5'd3;
    localparam ALU_SLTU   = 5'd4;
    localparam ALU_XOR    = 5'd5;
    localparam ALU_SRL    = 5'd6;
    localparam ALU_SRA    = 5'd7;
    localparam ALU_OR     = 5'd8;
    localparam ALU_AND    = 5'd9;
    localparam ALU_PASS_B = 5'd10;

    localparam ALU_MUL    = 5'd11;
    localparam ALU_MULH   = 5'd12;
    localparam ALU_MULHSU = 5'd13;
    localparam ALU_MULHU  = 5'd14;
    localparam ALU_DIV    = 5'd16;
    localparam ALU_DIVU   = 5'd17;
    localparam ALU_REM    = 5'd18;
    localparam ALU_REMU   = 5'd19;

    reg [31:0] ifid_pc;
    reg [31:0] ifid_instr;
    reg        ifid_valid;
    reg        ifid_predicted_taken;

    reg [31:0] idex_pc;
    reg [31:0] idex_rs1_data;
    reg [31:0] idex_rs2_data;
    reg [31:0] idex_imm;
    reg  [4:0] idex_rd;
    reg  [4:0] idex_rs1;
    reg  [4:0] idex_rs2;
    reg  [4:0] idex_alu_op;
    reg        idex_alu_src;
    reg        idex_mem_read;
    reg        idex_mem_write;
    reg  [2:0] idex_mem_size;
    reg        idex_reg_write;
    reg  [1:0] idex_result_src;
    reg        idex_branch;
    reg        idex_jal;
    reg        idex_jalr;
    reg  [2:0] idex_funct3;
    reg        idex_auipc;
    reg        idex_valid;

    reg [11:0] idex_csr_addr;
    reg        idex_csr_op;
    reg        idex_csr_write;
    reg        idex_is_ecall;
    reg        idex_is_ebreak;
    reg        idex_is_mret;
    reg        idex_predicted_taken;

    reg        idex_is_custom;
    reg  [6:0] idex_funct7;

    reg [31:0] exmem_alu_result;
    reg [31:0] exmem_rs2_data;
    reg [31:0] exmem_pc_plus4;
    reg  [4:0] exmem_rd;
    reg        exmem_mem_read;
    reg        exmem_mem_write;
    reg  [2:0] exmem_mem_size;
    reg        exmem_reg_write;
    reg  [1:0] exmem_result_src;
    reg        exmem_valid;

    reg [31:0] memwb_alu_result;
    reg [31:0] memwb_mem_data;
    reg [31:0] memwb_pc_plus4;
    reg  [4:0] memwb_rd;
    reg        memwb_reg_write;
    reg  [1:0] memwb_result_src;
    reg        memwb_valid;

    reg [31:0] pc;
    wire [31:0] pc_next;
    wire        pc_stall;
    wire        pipeline_flush;

    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] branch_target;

    reg [1:0] bht [0:63];

    reg [31:0] btb_target [0:63];
    reg [23:0] btb_tag    [0:63];
    reg        btb_valid  [0:63];

    wire [6:0] if_opcode = imem_rdata[6:0];
    wire if_is_branch = (if_opcode == 7'b1100011);
    wire if_is_jal    = (if_opcode == 7'b1101111);

    wire [5:0] bht_idx_if = pc[7:2];
    wire [1:0] bht_counter_if = bht[bht_idx_if];
    wire       bht_predict_taken = bht_counter_if[1];
    wire       btb_hit = btb_valid[bht_idx_if] && (btb_tag[bht_idx_if] == pc[31:8]);

    wire if_predict_taken = imem_ready && btb_hit &&
                            (if_is_jal || (if_is_branch && bht_predict_taken));
    wire [31:0] if_predict_target = btb_target[bht_idx_if];

    assign pc_next = pipeline_flush    ? branch_target :
                     if_predict_taken  ? if_predict_target :
                     pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= RESET_ADDR;
        else if (!pc_stall)
            pc <= pc_next;
    end

    assign imem_addr = pc;

    assign imem_req  = !(mem_stall || mul_div_stall || load_use_hazard);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifid_pc    <= 0;
            ifid_instr <= 32'h0000_0013;
            ifid_valid <= 0;
            ifid_predicted_taken <= 0;
        end else if (!mem_stall && !mul_div_stall) begin
            if (pipeline_flush) begin
                ifid_instr <= 32'h0000_0013;
                ifid_valid <= 0;
                ifid_predicted_taken <= 0;
            end else if (!pc_stall) begin
                ifid_pc    <= pc;
                ifid_instr <= imem_rdata;
                ifid_valid <= imem_ready;
                ifid_predicted_taken <= if_predict_taken;
            end else if (!load_use_hazard) begin

                ifid_valid <= 0;
            end
        end
    end

    wire [6:0]  opcode = ifid_instr[6:0];
    wire [4:0]  rd     = ifid_instr[11:7];
    wire [2:0]  funct3 = ifid_instr[14:12];
    wire [4:0]  rs1    = ifid_instr[19:15];
    wire [4:0]  rs2    = ifid_instr[24:20];
    wire [6:0]  funct7 = ifid_instr[31:25];

    wire [31:0] imm_i = {{20{ifid_instr[31]}}, ifid_instr[31:20]};
    wire [31:0] imm_s = {{20{ifid_instr[31]}}, ifid_instr[31:25], ifid_instr[11:7]};
    wire [31:0] imm_b = {{19{ifid_instr[31]}}, ifid_instr[31], ifid_instr[7],
                          ifid_instr[30:25], ifid_instr[11:8], 1'b0};
    wire [31:0] imm_u = {ifid_instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{ifid_instr[31]}}, ifid_instr[31], ifid_instr[19:12],
                          ifid_instr[20], ifid_instr[30:21], 1'b0};

    reg [31:0] imm_dec;
    always @(*) begin
        case (opcode)
            OP_IMM, OP_LOAD, OP_JALR: imm_dec = imm_i;
            OP_STORE:                  imm_dec = imm_s;
            OP_BRANCH:                 imm_dec = imm_b;
            OP_LUI, OP_AUIPC:         imm_dec = imm_u;
            OP_JAL:                    imm_dec = imm_j;
            default:                   imm_dec = 32'd0;
        endcase
    end

    reg [31:0] regfile [0:31];
    integer idx;

    wire wb_fwd_rs1 = memwb_reg_write && memwb_valid && (memwb_rd != 5'd0) && (memwb_rd == rs1);
    wire wb_fwd_rs2 = memwb_reg_write && memwb_valid && (memwb_rd != 5'd0) && (memwb_rd == rs2);
    wire [31:0] rf_rs1_data = (rs1 == 5'd0) ? 32'd0 : wb_fwd_rs1 ? wb_data : regfile[rs1];
    wire [31:0] rf_rs2_data = (rs2 == 5'd0) ? 32'd0 : wb_fwd_rs2 ? wb_data : regfile[rs2];

    reg [4:0]  dec_alu_op;
    reg        dec_alu_src;
    reg        dec_mem_read;
    reg        dec_mem_write;
    reg        dec_reg_write;
    reg [1:0]  dec_result_src;
    reg        dec_branch;
    reg        dec_jal;
    reg        dec_jalr;
    reg        dec_auipc;
    reg        dec_csr_op;
    reg        dec_csr_write;
    reg        dec_is_ecall;
    reg        dec_is_ebreak;
    reg        dec_is_mret;
    reg        dec_is_custom;

    always @(*) begin
        dec_alu_op    = ALU_ADD;
        dec_alu_src   = 0;
        dec_mem_read  = 0;
        dec_mem_write = 0;
        dec_reg_write = 0;
        dec_result_src = 2'b00;
        dec_branch    = 0;
        dec_jal       = 0;
        dec_jalr      = 0;
        dec_auipc     = 0;
        dec_csr_op    = 0;
        dec_csr_write = 0;
        dec_is_ecall  = 0;
        dec_is_ebreak = 0;
        dec_is_mret   = 0;
        dec_is_custom = 0;

        case (opcode)
            OP_LUI: begin
                dec_alu_op    = ALU_PASS_B;
                dec_alu_src   = 1;
                dec_reg_write = 1;
            end
            OP_AUIPC: begin
                dec_alu_op    = ALU_ADD;
                dec_alu_src   = 1;
                dec_reg_write = 1;
                dec_auipc     = 1;
            end
            OP_JAL: begin
                dec_jal       = 1;
                dec_reg_write = 1;
                dec_result_src = 2'b10;
            end
            OP_JALR: begin
                dec_jalr      = 1;
                dec_alu_src   = 1;
                dec_reg_write = 1;
                dec_result_src = 2'b10;
            end
            OP_BRANCH: begin
                dec_branch    = 1;
            end
            OP_LOAD: begin
                dec_alu_op    = ALU_ADD;
                dec_alu_src   = 1;
                dec_mem_read  = 1;
                dec_reg_write = 1;
                dec_result_src = 2'b01;
            end
            OP_STORE: begin
                dec_alu_op    = ALU_ADD;
                dec_alu_src   = 1;
                dec_mem_write = 1;
            end
            OP_IMM: begin
                dec_alu_src   = 1;
                dec_reg_write = 1;
                case (funct3)
                    3'b000: dec_alu_op = ALU_ADD;
                    3'b001: dec_alu_op = ALU_SLL;
                    3'b010: dec_alu_op = ALU_SLT;
                    3'b011: dec_alu_op = ALU_SLTU;
                    3'b100: dec_alu_op = ALU_XOR;
                    3'b101: dec_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: dec_alu_op = ALU_OR;
                    3'b111: dec_alu_op = ALU_AND;
                endcase
            end
            OP_REG: begin
                dec_reg_write = 1;
                if (funct7 == 7'b0000001) begin

                    case (funct3)
                        3'b000: dec_alu_op = ALU_MUL;
                        3'b001: dec_alu_op = ALU_MULH;
                        3'b010: dec_alu_op = ALU_MULHSU;
                        3'b011: dec_alu_op = ALU_MULHU;
                        3'b100: dec_alu_op = ALU_DIV;
                        3'b101: dec_alu_op = ALU_DIVU;
                        3'b110: dec_alu_op = ALU_REM;
                        3'b111: dec_alu_op = ALU_REMU;
                    endcase
                end else begin
                    case (funct3)
                        3'b000: dec_alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                        3'b001: dec_alu_op = ALU_SLL;
                        3'b010: dec_alu_op = ALU_SLT;
                        3'b011: dec_alu_op = ALU_SLTU;
                        3'b100: dec_alu_op = ALU_XOR;
                        3'b101: dec_alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                        3'b110: dec_alu_op = ALU_OR;
                        3'b111: dec_alu_op = ALU_AND;
                    endcase
                end
            end
            OP_CUSTOM0: begin

                dec_reg_write  = (rd != 5'd0);
                dec_result_src = 2'b00;
                dec_is_custom  = 1;
            end
            OP_FENCE: begin

            end
            OP_SYSTEM: begin
                if (funct3 != 3'b000) begin

                    dec_csr_op    = 1;
                    dec_reg_write = 1;
                    dec_result_src = 2'b11;

                    if (funct3[1:0] == 2'b01)
                        dec_csr_write = 1;
                    else
                        dec_csr_write = (rs1 != 5'd0);
                end else begin

                    case (ifid_instr[31:20])
                        12'h000: dec_is_ecall  = 1;
                        12'h001: dec_is_ebreak = 1;
                        12'h302: dec_is_mret   = 1;
                        default: ;
                    endcase
                end
            end
        endcase
    end

    wire load_use_hazard;
    assign load_use_hazard = idex_mem_read && idex_valid &&
                             ((idex_rd == rs1 && rs1 != 5'd0) ||
                              (idex_rd == rs2 && rs2 != 5'd0)) &&
                             (opcode != OP_LUI && opcode != OP_AUIPC &&
                              opcode != OP_JAL);

    wire mem_stall  = (exmem_mem_read || exmem_mem_write) && exmem_valid && !dmem_ready;
    wire fetch_stall = imem_req && !imem_ready;

    assign pc_stall = load_use_hazard || mem_stall || fetch_stall || mul_div_stall;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || (pipeline_flush && !mem_stall && !mul_div_stall) || (load_use_hazard && !mem_stall && !mul_div_stall)) begin
            idex_pc         <= 0;
            idex_rs1_data   <= 0;
            idex_rs2_data   <= 0;
            idex_imm        <= 0;
            idex_rd         <= 0;
            idex_rs1        <= 0;
            idex_rs2        <= 0;
            idex_alu_op     <= ALU_ADD;
            idex_alu_src    <= 0;
            idex_mem_read   <= 0;
            idex_mem_write  <= 0;
            idex_mem_size   <= 0;
            idex_reg_write  <= 0;
            idex_result_src <= 0;
            idex_branch     <= 0;
            idex_jal        <= 0;
            idex_jalr       <= 0;
            idex_auipc      <= 0;
            idex_funct3     <= 0;
            idex_valid      <= 0;
            idex_csr_addr   <= 0;
            idex_csr_op     <= 0;
            idex_csr_write  <= 0;
            idex_is_ecall   <= 0;
            idex_is_ebreak  <= 0;
            idex_is_mret    <= 0;
            idex_predicted_taken <= 0;
            idex_is_custom  <= 0;
            idex_funct7     <= 0;
        end else if (!mem_stall && !mul_div_stall) begin
            idex_pc         <= ifid_pc;
            idex_rs1_data   <= rf_rs1_data;
            idex_rs2_data   <= rf_rs2_data;
            idex_imm        <= imm_dec;
            idex_rd         <= rd;
            idex_rs1        <= rs1;
            idex_rs2        <= rs2;
            idex_alu_op     <= dec_alu_op;
            idex_alu_src    <= dec_alu_src;
            idex_mem_read   <= dec_mem_read;
            idex_mem_write  <= dec_mem_write;
            idex_mem_size   <= funct3;
            idex_reg_write  <= dec_reg_write;
            idex_result_src <= dec_result_src;
            idex_branch     <= dec_branch;
            idex_jal        <= dec_jal;
            idex_jalr       <= dec_jalr;
            idex_auipc      <= dec_auipc;
            idex_funct3     <= funct3;
            idex_valid      <= ifid_valid;
            idex_csr_addr   <= ifid_instr[31:20];
            idex_csr_op     <= dec_csr_op;
            idex_csr_write  <= dec_csr_write;
            idex_is_ecall   <= dec_is_ecall;
            idex_is_ebreak  <= dec_is_ebreak;
            idex_is_mret    <= dec_is_mret;
            idex_predicted_taken <= ifid_predicted_taken;
            idex_is_custom  <= dec_is_custom;
            idex_funct7     <= funct7;
        end
    end

    wire [1:0] fwd_a_sel;
    wire [1:0] fwd_b_sel;

    assign fwd_a_sel = (exmem_reg_write && exmem_valid && exmem_rd != 5'd0 &&
                        exmem_rd == idex_rs1) ? 2'b10 :
                       (memwb_reg_write && memwb_valid && memwb_rd != 5'd0 &&
                        memwb_rd == idex_rs1) ? 2'b01 : 2'b00;

    assign fwd_b_sel = (exmem_reg_write && exmem_valid && exmem_rd != 5'd0 &&
                        exmem_rd == idex_rs2) ? 2'b10 :
                       (memwb_reg_write && memwb_valid && memwb_rd != 5'd0 &&
                        memwb_rd == idex_rs2) ? 2'b01 : 2'b00;

    wire [31:0] wb_data;
    assign wb_data = (memwb_result_src == 2'b01) ? memwb_mem_data :
                     (memwb_result_src == 2'b10) ? memwb_pc_plus4 :
                     memwb_alu_result;

    wire [31:0] fwd_rs1 = (fwd_a_sel == 2'b10) ? exmem_alu_result :
                          (fwd_a_sel == 2'b01) ? wb_data :
                          idex_rs1_data;

    wire [31:0] fwd_rs2 = (fwd_b_sel == 2'b10) ? exmem_alu_result :
                          (fwd_b_sel == 2'b01) ? wb_data :
                          idex_rs2_data;

    wire [31:0] alu_b = idex_alu_src ? idex_imm : fwd_rs2;

    wire [31:0] alu_a = idex_auipc ? idex_pc : fwd_rs1;

    wire is_mul_op = idex_valid && (idex_alu_op == ALU_MUL  || idex_alu_op == ALU_MULH ||
                                    idex_alu_op == ALU_MULHSU || idex_alu_op == ALU_MULHU);

    reg  [1:0]  mul_cycle;
    reg         mul_busy;
    reg  [63:0] mul_result;
    reg  [4:0]  mul_op_saved;

    wire [32:0] mul_a_ext = (idex_alu_op == ALU_MULHU) ? {1'b0, alu_a} :
                            {alu_a[31], alu_a};
    wire [32:0] mul_b_ext = (idex_alu_op == ALU_MULHU || idex_alu_op == ALU_MULHSU) ?
                            {1'b0, alu_b} : {alu_b[31], alu_b};

    reg signed [32:0] mul_a_reg, mul_b_reg;
    reg signed [65:0] mul_partial;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_cycle   <= 0;
            mul_busy    <= 0;
            mul_result  <= 0;
            mul_op_saved <= 0;
            mul_a_reg   <= 0;
            mul_b_reg   <= 0;
            mul_partial <= 0;
        end else if (is_mul_op && mul_cycle == 0 && !mul_busy) begin

            mul_a_reg    <= $signed(mul_a_ext);
            mul_b_reg    <= $signed(mul_b_ext);
            mul_op_saved <= idex_alu_op;
            mul_cycle    <= 2'd1;
            mul_busy     <= 1;
        end else if (mul_cycle == 2'd1) begin

            mul_partial <= mul_a_reg * mul_b_reg;
            mul_cycle   <= 2'd2;
        end else if (mul_cycle == 2'd2) begin

            mul_result <= mul_partial[63:0];
            mul_cycle  <= 0;
            mul_busy   <= 0;
        end
    end

    wire mul_done  = (mul_cycle == 2'd2);
    wire mul_stall = is_mul_op && !mul_done;

    reg [31:0] mul_out;
    always @(*) begin
        case (mul_op_saved)
            ALU_MUL:    mul_out = mul_partial[31:0];
            ALU_MULH:   mul_out = mul_partial[63:32];
            ALU_MULHSU: mul_out = mul_partial[63:32];
            ALU_MULHU:  mul_out = mul_partial[63:32];
            default:    mul_out = mul_partial[31:0];
        endcase
    end

    wire is_div_op = idex_valid && (idex_alu_op == ALU_DIV  || idex_alu_op == ALU_DIVU ||
                                    idex_alu_op == ALU_REM  || idex_alu_op == ALU_REMU);

    reg         div_busy;
    reg  [5:0]  div_count;
    reg         div_signed;
    reg         div_is_rem;
    reg [31:0]  div_quotient;
    reg [31:0]  div_remainder;
    reg [31:0]  div_divisor;
    reg         div_neg_quot;
    reg         div_neg_rem;
    reg         div_special;
    reg [31:0]  div_special_q;
    reg [31:0]  div_special_r;

    wire div_start = is_div_op && !div_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_busy      <= 0;
            div_count     <= 0;
            div_signed    <= 0;
            div_is_rem    <= 0;
            div_quotient  <= 0;
            div_remainder <= 0;
            div_divisor   <= 0;
            div_neg_quot  <= 0;
            div_neg_rem   <= 0;
            div_special   <= 0;
            div_special_q <= 0;
            div_special_r <= 0;
        end else if (div_start) begin

            div_signed <= (idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM);
            div_is_rem <= (idex_alu_op == ALU_REM || idex_alu_op == ALU_REMU);
            div_busy   <= 1;
            div_count  <= 6'd1;

            if (alu_b == 32'd0) begin

                div_special   <= 1;
                div_special_q <= 32'hFFFFFFFF;
                div_special_r <= alu_a;
            end else if ((idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM) &&
                         alu_a == 32'h80000000 && alu_b == 32'hFFFFFFFF) begin

                div_special   <= 1;
                div_special_q <= 32'h80000000;
                div_special_r <= 32'd0;
            end else begin
                div_special <= 0;

                if ((idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM) && alu_a[31])
                    div_quotient <= ~alu_a + 32'd1;
                else
                    div_quotient <= alu_a;

                if ((idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM) && alu_b[31])
                    div_divisor <= ~alu_b + 32'd1;
                else
                    div_divisor <= alu_b;

                div_remainder <= 32'd0;

                div_neg_quot <= (idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM) &&
                                (alu_a[31] ^ alu_b[31]);
                div_neg_rem  <= (idex_alu_op == ALU_DIV || idex_alu_op == ALU_REM) &&
                                alu_a[31];
            end
        end else if (div_busy && div_special) begin

            div_busy <= 0;
        end else if (div_busy && div_count <= 6'd32) begin

            if ({div_remainder[30:0], div_quotient[31]} >= {1'b0, div_divisor}) begin
                div_remainder <= {div_remainder[30:0], div_quotient[31]} - div_divisor;
                div_quotient  <= {div_quotient[30:0], 1'b1};
            end else begin
                div_remainder <= {div_remainder[30:0], div_quotient[31]};
                div_quotient  <= {div_quotient[30:0], 1'b0};
            end
            div_count <= div_count + 6'd1;
        end else if (div_busy && div_count > 6'd32) begin

            div_busy <= 0;
        end
    end

    wire div_done  = div_busy && (div_special ? 1'b1 :
                     (div_count > 6'd32));
    wire div_stall = is_div_op && !div_done;

    wire [31:0] div_quot_final = div_neg_quot ? (~div_quotient + 32'd1) : div_quotient;
    wire [31:0] div_rem_final  = div_neg_rem  ? (~div_remainder + 32'd1) : div_remainder;
    wire [31:0] div_out = div_special ? (div_is_rem ? div_special_r : div_special_q) :
                          div_is_rem  ? div_rem_final : div_quot_final;

    wire mul_div_stall = mul_stall || div_stall;

    wire [31:0] aes_result;
    aes_instr u_aes_instr (
        .rs1    (fwd_rs1),
        .rs2    (fwd_rs2),
        .funct3 (idex_funct3),
        .funct7 (idex_funct7),
        .result (aes_result)
    );

    reg [31:0] alu_result;
    always @(*) begin
        case (idex_alu_op)
            ALU_ADD:    alu_result = alu_a + alu_b;
            ALU_SUB:    alu_result = alu_a - alu_b;
            ALU_SLL:    alu_result = alu_a << alu_b[4:0];
            ALU_SLT:    alu_result = {31'd0, $signed(alu_a) < $signed(alu_b)};
            ALU_SLTU:   alu_result = {31'd0, alu_a < alu_b};
            ALU_XOR:    alu_result = alu_a ^ alu_b;
            ALU_SRL:    alu_result = alu_a >> alu_b[4:0];
            ALU_SRA:    alu_result = $signed(alu_a) >>> alu_b[4:0];
            ALU_OR:     alu_result = alu_a | alu_b;
            ALU_AND:    alu_result = alu_a & alu_b;
            ALU_PASS_B: alu_result = alu_b;
            ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU:
                        alu_result = mul_out;
            ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU:
                        alu_result = div_out;
            default:    alu_result = 32'd0;
        endcase
    end

    localparam CSR_MSTATUS  = 12'h300;
    localparam CSR_MIE      = 12'h304;
    localparam CSR_MTVEC    = 12'h305;
    localparam CSR_MEPC     = 12'h341;
    localparam CSR_MCAUSE   = 12'h342;
    localparam CSR_MIP      = 12'h344;
    localparam CSR_MCYCLE   = 12'hB00;
    localparam CSR_MCYCLEH  = 12'hB80;
    localparam CSR_MINSTRET = 12'hB02;
    localparam CSR_MINSTRETH = 12'hB82;

    reg [31:0] csr_mstatus;
    reg [31:0] csr_mie;
    reg [31:0] csr_mtvec;
    reg [31:0] csr_mepc;
    reg [31:0] csr_mcause;
    reg [31:0] csr_mip;
    reg [63:0] csr_mcycle;
    reg [63:0] csr_minstret;

    reg [31:0] csr_rdata;
    always @(*) begin
        case (idex_csr_addr)
            CSR_MSTATUS:  csr_rdata = csr_mstatus;
            CSR_MIE:      csr_rdata = csr_mie;
            CSR_MTVEC:    csr_rdata = csr_mtvec;
            CSR_MEPC:     csr_rdata = csr_mepc;
            CSR_MCAUSE:   csr_rdata = csr_mcause;
            CSR_MIP:      csr_rdata = csr_mip;
            CSR_MCYCLE:   csr_rdata = csr_mcycle[31:0];
            CSR_MCYCLEH:  csr_rdata = csr_mcycle[63:32];
            CSR_MINSTRET: csr_rdata = csr_minstret[31:0];
            CSR_MINSTRETH: csr_rdata = csr_minstret[63:32];
            default:      csr_rdata = 32'd0;
        endcase
    end

    wire [31:0] csr_operand = idex_funct3[2] ? {27'd0, idex_rs1} : fwd_rs1;

    reg [31:0] csr_wdata;
    always @(*) begin
        case (idex_funct3[1:0])
            2'b01:   csr_wdata = csr_operand;
            2'b10:   csr_wdata = csr_rdata | csr_operand;
            2'b11:   csr_wdata = csr_rdata & ~csr_operand;
            default: csr_wdata = 32'd0;
        endcase
    end

    wire ex_ecall  = idex_valid && idex_is_ecall;
    wire ex_ebreak = idex_valid && idex_is_ebreak;
    wire ex_mret   = idex_valid && idex_is_mret;
    wire ex_trap   = ex_ecall || ex_ebreak;
    wire ex_csr_write = idex_valid && idex_csr_op && idex_csr_write;

    wire [31:0] trap_target = {csr_mtvec[31:2], 2'b00};
    wire [31:0] mret_target = csr_mepc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_mstatus  <= 32'h0000_1800;
            csr_mie      <= 32'd0;
            csr_mtvec    <= 32'd0;
            csr_mepc     <= 32'd0;
            csr_mcause   <= 32'd0;
            csr_mip      <= 32'd0;
            csr_mcycle   <= 64'd0;
            csr_minstret <= 64'd0;
        end else begin

            csr_mcycle <= csr_mcycle + 64'd1;

            csr_mip[11] <= ext_irq;
            csr_mip[7]  <= timer_irq;
            csr_mip[3]  <= soft_irq;

            if (memwb_valid && !mem_stall && !mul_div_stall)
                csr_minstret <= csr_minstret + 64'd1;

            if (ex_trap) begin
                csr_mepc    <= idex_pc;
                csr_mcause  <= ex_ecall ? 32'd11 : 32'd3;
                csr_mstatus[7]    <= csr_mstatus[3];
                csr_mstatus[3]    <= 1'b0;
                csr_mstatus[12:11] <= 2'b11;
            end

            else if (ex_mret) begin
                csr_mstatus[3]    <= csr_mstatus[7];
                csr_mstatus[7]    <= 1'b1;
                csr_mstatus[12:11] <= 2'b11;
            end

            else if (take_irq) begin
                csr_mepc    <= idex_pc;
                csr_mcause  <= irq_cause;
                csr_mstatus[7]    <= csr_mstatus[3];
                csr_mstatus[3]    <= 1'b0;
                csr_mstatus[12:11] <= 2'b11;
            end

            else if (ex_csr_write) begin
                case (idex_csr_addr)
                    CSR_MSTATUS:  csr_mstatus <= csr_wdata & 32'h0000_1888;
                    CSR_MIE:      csr_mie     <= csr_wdata;
                    CSR_MTVEC:    csr_mtvec   <= csr_wdata;
                    CSR_MEPC:     csr_mepc    <= {csr_wdata[31:2], 2'b00};
                    CSR_MCAUSE:   csr_mcause  <= csr_wdata;
                    CSR_MIP:      ;
                    CSR_MCYCLE:   csr_mcycle[31:0]   <= csr_wdata;
                    CSR_MCYCLEH:  csr_mcycle[63:32]  <= csr_wdata;
                    CSR_MINSTRET: csr_minstret[31:0] <= csr_wdata;
                    CSR_MINSTRETH: csr_minstret[63:32] <= csr_wdata;
                    default: ;
                endcase
            end
        end
    end

    reg branch_cond;
    always @(*) begin
        case (idex_funct3)
            3'b000: branch_cond = (fwd_rs1 == fwd_rs2);
            3'b001: branch_cond = (fwd_rs1 != fwd_rs2);
            3'b100: branch_cond = ($signed(fwd_rs1) < $signed(fwd_rs2));
            3'b101: branch_cond = ($signed(fwd_rs1) >= $signed(fwd_rs2));
            3'b110: branch_cond = (fwd_rs1 < fwd_rs2);
            3'b111: branch_cond = (fwd_rs1 >= fwd_rs2);
            default: branch_cond = 0;
        endcase
    end

    wire ex_actually_taken = (idex_branch && branch_cond) || idex_jal;
    wire [31:0] ex_computed_target = idex_pc + idex_imm;

    wire [31:0] ex_recovery_pc = ex_actually_taken ? ex_computed_target
                                                   : (idex_pc + 32'd4);

    wire ex_mispredict = idex_valid && (idex_branch || idex_jal) &&
                         (idex_predicted_taken != ex_actually_taken);

    wire ex_unpredicted_redirect = idex_valid &&
        (idex_jalr || idex_is_ecall || idex_is_ebreak || idex_is_mret);

    wire irq_meip   = ext_irq   && csr_mie[11] && csr_mstatus[3];
    wire irq_mtip   = timer_irq && csr_mie[7]  && csr_mstatus[3];
    wire irq_msip   = soft_irq  && csr_mie[3]  && csr_mstatus[3];
    wire take_irq   = (irq_meip || irq_mtip || irq_msip) && idex_valid
                      && !ex_trap && !mem_stall && !mul_div_stall;
    wire [31:0] irq_cause = irq_meip ? 32'h8000_000B :
                            irq_mtip ? 32'h8000_0007 : 32'h8000_0003;

    assign pipeline_flush = ex_mispredict || ex_unpredicted_redirect || take_irq;

    assign branch_target = ex_trap   ? trap_target :
                           ex_mret   ? mret_target :
                           idex_jalr ? (fwd_rs1 + idex_imm) & ~32'd1 :
                           take_irq  ? trap_target :
                           ex_recovery_pc;

    wire [5:0] bht_idx_ex = idex_pc[7:2];
    wire ex_is_branch_or_jal = idex_valid && (idex_branch || idex_jal) &&
                               !mem_stall && !mul_div_stall;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin : bht_btb_reset
            integer k;
            for (k = 0; k < 64; k = k + 1) begin
                bht[k]        <= 2'b01;
                btb_valid[k]  <= 1'b0;
                btb_tag[k]    <= 24'd0;
                btb_target[k] <= 32'd0;
            end
        end else if (ex_is_branch_or_jal) begin

            btb_target[bht_idx_ex] <= ex_computed_target;
            btb_tag[bht_idx_ex]    <= idex_pc[31:8];
            btb_valid[bht_idx_ex]  <= 1'b1;

            if (idex_branch) begin
                if (branch_cond && bht[bht_idx_ex] != 2'b11)
                    bht[bht_idx_ex] <= bht[bht_idx_ex] + 2'b01;
                else if (!branch_cond && bht[bht_idx_ex] != 2'b00)
                    bht[bht_idx_ex] <= bht[bht_idx_ex] - 2'b01;
            end
        end
    end

    wire [31:0] ex_pc_plus4 = idex_pc + 32'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exmem_alu_result <= 0;
            exmem_rs2_data   <= 0;
            exmem_pc_plus4   <= 0;
            exmem_rd         <= 0;
            exmem_mem_read   <= 0;
            exmem_mem_write  <= 0;
            exmem_mem_size   <= 0;
            exmem_reg_write  <= 0;
            exmem_result_src <= 0;
            exmem_valid      <= 0;
        end else if (!mem_stall && !mul_div_stall) begin

            exmem_alu_result <= idex_csr_op    ? csr_rdata  :
                                idex_is_custom ? aes_result :
                                alu_result;
            exmem_rs2_data   <= fwd_rs2;
            exmem_pc_plus4   <= ex_pc_plus4;
            exmem_rd         <= idex_rd;
            exmem_mem_read   <= idex_mem_read;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_size   <= idex_mem_size;
            exmem_reg_write  <= idex_reg_write;
            exmem_result_src <= idex_result_src;
            exmem_valid      <= idex_valid;
        end
    end

    reg [31:0] store_data;
    reg  [3:0] store_strb;

    always @(*) begin
        case (exmem_mem_size[1:0])
            2'b00: begin
                case (exmem_alu_result[1:0])
                    2'b00: begin store_data = {24'd0, exmem_rs2_data[7:0]};
                                 store_strb = 4'b0001; end
                    2'b01: begin store_data = {16'd0, exmem_rs2_data[7:0], 8'd0};
                                 store_strb = 4'b0010; end
                    2'b10: begin store_data = {8'd0, exmem_rs2_data[7:0], 16'd0};
                                 store_strb = 4'b0100; end
                    2'b11: begin store_data = {exmem_rs2_data[7:0], 24'd0};
                                 store_strb = 4'b1000; end
                endcase
            end
            2'b01: begin
                case (exmem_alu_result[1])
                    1'b0: begin store_data = {16'd0, exmem_rs2_data[15:0]};
                                store_strb = 4'b0011; end
                    1'b1: begin store_data = {exmem_rs2_data[15:0], 16'd0};
                                store_strb = 4'b1100; end
                endcase
            end
            default: begin
                store_data = exmem_rs2_data;
                store_strb = 4'b1111;
            end
        endcase
    end

    assign dmem_addr  = {exmem_alu_result[31:2], 2'b00};
    assign dmem_wdata = store_data;
    assign dmem_wstrb = exmem_mem_write ? store_strb : 4'b0000;
    assign dmem_req   = (exmem_mem_read || exmem_mem_write) && exmem_valid;

    reg [31:0] load_data;
    always @(*) begin
        case (exmem_mem_size)
            3'b000: begin
                case (exmem_alu_result[1:0])
                    2'b00: load_data = {{24{dmem_rdata[7]}},  dmem_rdata[7:0]};
                    2'b01: load_data = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: load_data = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: load_data = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin
                case (exmem_alu_result[1])
                    1'b0: load_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: load_data = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            3'b010: load_data = dmem_rdata;
            3'b100: begin
                case (exmem_alu_result[1:0])
                    2'b00: load_data = {24'd0, dmem_rdata[7:0]};
                    2'b01: load_data = {24'd0, dmem_rdata[15:8]};
                    2'b10: load_data = {24'd0, dmem_rdata[23:16]};
                    2'b11: load_data = {24'd0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: begin
                case (exmem_alu_result[1])
                    1'b0: load_data = {16'd0, dmem_rdata[15:0]};
                    1'b1: load_data = {16'd0, dmem_rdata[31:16]};
                endcase
            end
            default: load_data = dmem_rdata;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memwb_alu_result <= 0;
            memwb_mem_data   <= 0;
            memwb_pc_plus4   <= 0;
            memwb_rd         <= 0;
            memwb_reg_write  <= 0;
            memwb_result_src <= 0;
            memwb_valid      <= 0;
        end else if (!mem_stall && !mul_div_stall) begin
            memwb_alu_result <= exmem_alu_result;
            memwb_mem_data   <= load_data;
            memwb_pc_plus4   <= exmem_pc_plus4;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_result_src <= exmem_result_src;
            memwb_valid      <= exmem_valid;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 32; idx = idx + 1)
                regfile[idx] <= 32'd0;
        end else if (memwb_reg_write && memwb_valid && memwb_rd != 5'd0) begin
            regfile[memwb_rd] <= wb_data;
        end
    end

endmodule

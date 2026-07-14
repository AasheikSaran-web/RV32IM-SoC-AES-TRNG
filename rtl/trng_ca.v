`timescale 1ns/1ps
module trng_ca #(
    parameter AW = 32,
    parameter DW = 32,

    parameter integer RO0_HALF = 1,
    parameter integer RO1_HALF = 2,
    parameter integer RO2_HALF = 3,
    parameter integer RO3_HALF = 5,
    parameter integer RO4_HALF = 7
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0]  s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0]  s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0]  s_araddr, input s_arvalid,  output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg        s_rvalid, input s_rready,

    output            alarm_n
);

`ifndef SYNTHESIS
    reg ro_raw [0:4];
    initial begin
        ro_raw[0] = 1'b0; ro_raw[1] = 1'b1;
        ro_raw[2] = 1'b0; ro_raw[3] = 1'b1; ro_raw[4] = 1'b0;
    end
    always #(RO0_HALF) ro_raw[0] = ~ro_raw[0];
    always #(RO1_HALF) ro_raw[1] = ~ro_raw[1];
    always #(RO2_HALF) ro_raw[2] = ~ro_raw[2];
    always #(RO3_HALF) ro_raw[3] = ~ro_raw[3];
    always #(RO4_HALF) ro_raw[4] = ~ro_raw[4];
    wire [4:0] ro_async = {ro_raw[4], ro_raw[3], ro_raw[2], ro_raw[1], ro_raw[0]};
`else

    (* keep *) wire [4:0] ro_async;
    assign ro_async = 5'bzzzzz;
`endif

    reg [4:0] ro_ff1, ro_ff2, ro_ff3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ro_ff1 <= 5'd0; ro_ff2 <= 5'd0; ro_ff3 <= 5'd0;
        end else begin
            ro_ff1 <= ro_async;
            ro_ff2 <= ro_ff1;
            ro_ff3 <= ro_ff2;
        end
    end

    wire raw_jitter = ^(ro_ff2 ^ ro_ff3);

    reg meta_pos, meta_neg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) meta_pos <= 1'b0;
        else        meta_pos <= ro_ff1[0] ^ ro_ff1[2];
    end
    always @(negedge clk) begin
        meta_neg <= ro_ff1[1] ^ ro_ff1[3];
    end
    wire meta_bit = meta_pos ^ meta_neg;

    reg  vn_prev;
    reg  vn_bit;
    reg  vn_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vn_prev  <= 1'b0;
            vn_valid <= 1'b0;
            vn_bit   <= 1'b0;
        end else begin
            vn_valid <= 1'b0;
            vn_prev  <= raw_jitter ^ meta_bit;
            if ((vn_prev == 1'b0) && ((raw_jitter ^ meta_bit) == 1'b1)) begin
                vn_bit   <= 1'b1;
                vn_valid <= 1'b1;
            end else if ((vn_prev == 1'b1) && ((raw_jitter ^ meta_bit) == 1'b0)) begin
                vn_bit   <= 1'b0;
                vn_valid <= 1'b1;
            end
        end
    end

    reg [127:0] ca_state;

    reg  [6:0]  inj_counter;
    wire [6:0]  inj_addr = inj_counter ^ (inj_counter >> 1);
    wire [6:0]  inj_addr_masked = inj_addr & 7'h7F;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ca_state    <= 128'h5A3C9B17_E4F2D061_A8C70F35_29B4E68D;
            inj_counter <= 7'd0;
        end else begin

            begin : ca_update
                integer i;
                reg [127:0] ca_next;
                for (i = 0; i < 128; i = i + 1) begin
                    ca_next[i] = ca_state[(i+127)%128]
                                 ^ (ca_state[i] | ca_state[(i+1)%128]);
                end
                ca_state <= ca_next;
            end

            if (vn_valid) begin
                ca_state[inj_addr_masked] <= ca_state[inj_addr_masked] ^ vn_bit;
                inj_counter <= inj_counter + 7'd1;
            end

        end
    end

    reg [158:0] toep_seed;
    reg [7:0]   seed_init_cnt;
    reg         seed_ready;

    wire lfsr_fb = toep_seed[158] ^ toep_seed[30];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            toep_seed     <= 159'h1;
            seed_init_cnt <= 8'd0;
            seed_ready    <= 1'b0;
        end else if (!seed_ready) begin

            toep_seed     <= {toep_seed[157:0], lfsr_fb};
            seed_init_cnt <= seed_init_cnt + 8'd1;
            if (seed_init_cnt == 8'd158)
                seed_ready <= 1'b1;
        end

    end

    wire [31:0] toep_out;
    genvar gk, gi;
    generate
        for (gk = 0; gk < 32; gk = gk + 1) begin : toep_row
            wire [127:0] row_bits;
            for (gi = 0; gi < 128; gi = gi + 1) begin : toep_col
                assign row_bits[gi] = toep_seed[(gk + gi) % 159];
            end
            assign toep_out[gk] = ^(ca_state & row_bits);
        end
    endgenerate

    reg [31:0] rnd_reg;
    reg        rnd_valid;

    wire data_rd_pulse = s_arvalid && !s_rvalid && (s_araddr[3:0] == 4'h8);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rnd_reg   <= 32'd0;
            rnd_valid <= 1'b0;
        end else if (data_rd_pulse) begin
            rnd_valid <= 1'b0;
        end else if (seed_ready && !rnd_valid) begin
            rnd_reg   <= toep_out;
            rnd_valid <= 1'b1;
        end
    end

    localparam RCT_C = 12;
    reg [3:0]  rct_run;
    reg        rct_last;
    reg        rct_fail;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rct_run  <= 4'd0;
            rct_last <= 1'b0;
            rct_fail <= 1'b0;
        end else if (vn_valid) begin
            if (vn_bit == rct_last) begin
                if (rct_run >= RCT_C - 1) rct_fail <= 1'b1;
                else                       rct_run  <= rct_run + 4'd1;
            end else begin
                rct_run  <= 4'd1;
                rct_last <= vn_bit;
            end
        end
    end

    localparam APT_W   = 512;
    localparam APT_C_H = 325;
    localparam APT_C_L = 187;

    reg [9:0]  apt_window;
    reg [9:0]  apt_count;
    reg        apt_anchor;
    reg        apt_fail;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            apt_window <= 10'd0;
            apt_count  <= 10'd0;
            apt_anchor <= 1'b0;
            apt_fail   <= 1'b0;
        end else if (vn_valid) begin
            if (apt_window == 10'd0) begin

                apt_anchor <= vn_bit;
                apt_count  <= 10'd1;
                apt_window <= 10'd1;
            end else if (apt_window < APT_W) begin
                if (vn_bit == apt_anchor)
                    apt_count <= apt_count + 10'd1;
                apt_window <= apt_window + 10'd1;
            end else begin

                if (apt_count > APT_C_H || apt_count < APT_C_L)
                    apt_fail <= 1'b1;

                apt_window <= 10'd0;
                apt_count  <= 10'd0;
            end
        end
    end

    wire alarm_active = rct_fail || apt_fail;
    assign alarm_n = ~alarm_active;

    reg trng_enable;
    reg [31:0] seed_inject;
    reg        seed_wr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) seed_wr <= 1'b0;
        else begin
            seed_wr <= 1'b0;
            if (seed_wr)
                ca_state[31:0] <= ca_state[31:0] ^ seed_inject;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready   <= 1'b0; s_wready <= 1'b0;
            s_bvalid    <= 1'b0; s_bresp  <= 2'b00;
            trng_enable <= 1'b1;
            seed_inject <= 32'd0;
        end else begin
            s_awready <= 1'b0; s_wready <= 1'b0;
            if (s_awvalid && s_wvalid && !s_bvalid) begin
                s_awready <= 1'b1; s_wready <= 1'b1;
                casez (s_awaddr[3:0])
                    4'h0: begin
                        trng_enable <= s_wdata[0];
                        if (s_wdata[1]) seed_wr <= 1'b1;

                    end
                    4'hC: begin
                        seed_inject <= s_wdata;
                        seed_wr     <= 1'b1;
                    end
                    default: ;
                endcase
                s_bvalid <= 1'b1; s_bresp <= 2'b00;
            end
            if (s_bvalid && s_bready) s_bvalid <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 1'b0; s_rvalid <= 1'b0;
            s_rdata   <= 32'd0; s_rresp <= 2'b00;
        end else begin
            s_arready <= 1'b0;
            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1'b1; s_rresp <= 2'b00; s_rvalid <= 1'b1;
                casez (s_araddr[3:0])
                    4'h0: s_rdata <= {29'd0, alarm_active, trng_enable, 1'b0};
                    4'h4: s_rdata <= {28'd0, apt_fail, rct_fail,
                                      alarm_active, rnd_valid && seed_ready};
                    4'h8: begin
                        s_rdata <= rnd_valid ? rnd_reg : 32'hDEAD_BEEF;

                    end
                    4'hC: s_rdata <= seed_inject;
                    default: s_rdata <= 32'd0;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid <= 1'b0;
        end
    end

endmodule

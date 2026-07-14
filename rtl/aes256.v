module aes256 #(
    parameter AW = 32,
    parameter DW = 32
) (
    input             clk,
    input             rst_n,

    input  [AW-1:0]  s_awaddr, input s_awvalid, output reg s_awready,
    input  [DW-1:0]  s_wdata,  input [3:0] s_wstrb, input s_wvalid, output reg s_wready,
    output reg [1:0]  s_bresp, output reg s_bvalid, input s_bready,
    input  [AW-1:0]  s_araddr, input s_arvalid,  output reg s_arready,
    output reg [DW-1:0] s_rdata, output reg [1:0] s_rresp,
    output reg        s_rvalid, input s_rready
);

    function [7:0] sbox;
        input [7:0] x;
        case (x)
            8'h00:sbox=8'h63;8'h01:sbox=8'h7c;8'h02:sbox=8'h77;8'h03:sbox=8'h7b;
            8'h04:sbox=8'hf2;8'h05:sbox=8'h6b;8'h06:sbox=8'h6f;8'h07:sbox=8'hc5;
            8'h08:sbox=8'h30;8'h09:sbox=8'h01;8'h0a:sbox=8'h67;8'h0b:sbox=8'h2b;
            8'h0c:sbox=8'hfe;8'h0d:sbox=8'hd7;8'h0e:sbox=8'hab;8'h0f:sbox=8'h76;
            8'h10:sbox=8'hca;8'h11:sbox=8'h82;8'h12:sbox=8'hc9;8'h13:sbox=8'h7d;
            8'h14:sbox=8'hfa;8'h15:sbox=8'h59;8'h16:sbox=8'h47;8'h17:sbox=8'hf0;
            8'h18:sbox=8'had;8'h19:sbox=8'hd4;8'h1a:sbox=8'ha2;8'h1b:sbox=8'haf;
            8'h1c:sbox=8'h9c;8'h1d:sbox=8'ha4;8'h1e:sbox=8'h72;8'h1f:sbox=8'hc0;
            8'h20:sbox=8'hb7;8'h21:sbox=8'hfd;8'h22:sbox=8'h93;8'h23:sbox=8'h26;
            8'h24:sbox=8'h36;8'h25:sbox=8'h3f;8'h26:sbox=8'hf7;8'h27:sbox=8'hcc;
            8'h28:sbox=8'h34;8'h29:sbox=8'ha5;8'h2a:sbox=8'he5;8'h2b:sbox=8'hf1;
            8'h2c:sbox=8'h71;8'h2d:sbox=8'hd8;8'h2e:sbox=8'h31;8'h2f:sbox=8'h15;
            8'h30:sbox=8'h04;8'h31:sbox=8'hc7;8'h32:sbox=8'h23;8'h33:sbox=8'hc3;
            8'h34:sbox=8'h18;8'h35:sbox=8'h96;8'h36:sbox=8'h05;8'h37:sbox=8'h9a;
            8'h38:sbox=8'h07;8'h39:sbox=8'h12;8'h3a:sbox=8'h80;8'h3b:sbox=8'he2;
            8'h3c:sbox=8'heb;8'h3d:sbox=8'h27;8'h3e:sbox=8'hb2;8'h3f:sbox=8'h75;
            8'h40:sbox=8'h09;8'h41:sbox=8'h83;8'h42:sbox=8'h2c;8'h43:sbox=8'h1a;
            8'h44:sbox=8'h1b;8'h45:sbox=8'h6e;8'h46:sbox=8'h5a;8'h47:sbox=8'ha0;
            8'h48:sbox=8'h52;8'h49:sbox=8'h3b;8'h4a:sbox=8'hd6;8'h4b:sbox=8'hb3;
            8'h4c:sbox=8'h29;8'h4d:sbox=8'he3;8'h4e:sbox=8'h2f;8'h4f:sbox=8'h84;
            8'h50:sbox=8'h53;8'h51:sbox=8'hd1;8'h52:sbox=8'h00;8'h53:sbox=8'hed;
            8'h54:sbox=8'h20;8'h55:sbox=8'hfc;8'h56:sbox=8'hb1;8'h57:sbox=8'h5b;
            8'h58:sbox=8'h6a;8'h59:sbox=8'hcb;8'h5a:sbox=8'hbe;8'h5b:sbox=8'h39;
            8'h5c:sbox=8'h4a;8'h5d:sbox=8'h4c;8'h5e:sbox=8'h58;8'h5f:sbox=8'hcf;
            8'h60:sbox=8'hd0;8'h61:sbox=8'hef;8'h62:sbox=8'haa;8'h63:sbox=8'hfb;
            8'h64:sbox=8'h43;8'h65:sbox=8'h4d;8'h66:sbox=8'h33;8'h67:sbox=8'h85;
            8'h68:sbox=8'h45;8'h69:sbox=8'hf9;8'h6a:sbox=8'h02;8'h6b:sbox=8'h7f;
            8'h6c:sbox=8'h50;8'h6d:sbox=8'h3c;8'h6e:sbox=8'h9f;8'h6f:sbox=8'ha8;
            8'h70:sbox=8'h51;8'h71:sbox=8'ha3;8'h72:sbox=8'h40;8'h73:sbox=8'h8f;
            8'h74:sbox=8'h92;8'h75:sbox=8'h9d;8'h76:sbox=8'h38;8'h77:sbox=8'hf5;
            8'h78:sbox=8'hbc;8'h79:sbox=8'hb6;8'h7a:sbox=8'hda;8'h7b:sbox=8'h21;
            8'h7c:sbox=8'h10;8'h7d:sbox=8'hff;8'h7e:sbox=8'hf3;8'h7f:sbox=8'hd2;
            8'h80:sbox=8'hcd;8'h81:sbox=8'h0c;8'h82:sbox=8'h13;8'h83:sbox=8'hec;
            8'h84:sbox=8'h5f;8'h85:sbox=8'h97;8'h86:sbox=8'h44;8'h87:sbox=8'h17;
            8'h88:sbox=8'hc4;8'h89:sbox=8'ha7;8'h8a:sbox=8'h7e;8'h8b:sbox=8'h3d;
            8'h8c:sbox=8'h64;8'h8d:sbox=8'h5d;8'h8e:sbox=8'h19;8'h8f:sbox=8'h73;
            8'h90:sbox=8'h60;8'h91:sbox=8'h81;8'h92:sbox=8'h4f;8'h93:sbox=8'hdc;
            8'h94:sbox=8'h22;8'h95:sbox=8'h2a;8'h96:sbox=8'h90;8'h97:sbox=8'h88;
            8'h98:sbox=8'h46;8'h99:sbox=8'hee;8'h9a:sbox=8'hb8;8'h9b:sbox=8'h14;
            8'h9c:sbox=8'hde;8'h9d:sbox=8'h5e;8'h9e:sbox=8'h0b;8'h9f:sbox=8'hdb;
            8'ha0:sbox=8'he0;8'ha1:sbox=8'h32;8'ha2:sbox=8'h3a;8'ha3:sbox=8'h0a;
            8'ha4:sbox=8'h49;8'ha5:sbox=8'h06;8'ha6:sbox=8'h24;8'ha7:sbox=8'h5c;
            8'ha8:sbox=8'hc2;8'ha9:sbox=8'hd3;8'haa:sbox=8'hac;8'hab:sbox=8'h62;
            8'hac:sbox=8'h91;8'had:sbox=8'h95;8'hae:sbox=8'he4;8'haf:sbox=8'h79;
            8'hb0:sbox=8'he7;8'hb1:sbox=8'hc8;8'hb2:sbox=8'h37;8'hb3:sbox=8'h6d;
            8'hb4:sbox=8'h8d;8'hb5:sbox=8'hd5;8'hb6:sbox=8'h4e;8'hb7:sbox=8'ha9;
            8'hb8:sbox=8'h6c;8'hb9:sbox=8'h56;8'hba:sbox=8'hf4;8'hbb:sbox=8'hea;
            8'hbc:sbox=8'h65;8'hbd:sbox=8'h7a;8'hbe:sbox=8'hae;8'hbf:sbox=8'h08;
            8'hc0:sbox=8'hba;8'hc1:sbox=8'h78;8'hc2:sbox=8'h25;8'hc3:sbox=8'h2e;
            8'hc4:sbox=8'h1c;8'hc5:sbox=8'ha6;8'hc6:sbox=8'hb4;8'hc7:sbox=8'hc6;
            8'hc8:sbox=8'he8;8'hc9:sbox=8'hdd;8'hca:sbox=8'h74;8'hcb:sbox=8'h1f;
            8'hcc:sbox=8'h4b;8'hcd:sbox=8'hbd;8'hce:sbox=8'h8b;8'hcf:sbox=8'h8a;
            8'hd0:sbox=8'h70;8'hd1:sbox=8'h3e;8'hd2:sbox=8'hb5;8'hd3:sbox=8'h66;
            8'hd4:sbox=8'h48;8'hd5:sbox=8'h03;8'hd6:sbox=8'hf6;8'hd7:sbox=8'h0e;
            8'hd8:sbox=8'h61;8'hd9:sbox=8'h35;8'hda:sbox=8'h57;8'hdb:sbox=8'hb9;
            8'hdc:sbox=8'h86;8'hdd:sbox=8'hc1;8'hde:sbox=8'h1d;8'hdf:sbox=8'h9e;
            8'he0:sbox=8'he1;8'he1:sbox=8'hf8;8'he2:sbox=8'h98;8'he3:sbox=8'h11;
            8'he4:sbox=8'h69;8'he5:sbox=8'hd9;8'he6:sbox=8'h8e;8'he7:sbox=8'h94;
            8'he8:sbox=8'h9b;8'he9:sbox=8'h1e;8'hea:sbox=8'h87;8'heb:sbox=8'he9;
            8'hec:sbox=8'hce;8'hed:sbox=8'h55;8'hee:sbox=8'h28;8'hef:sbox=8'hdf;
            8'hf0:sbox=8'h8c;8'hf1:sbox=8'ha1;8'hf2:sbox=8'h89;8'hf3:sbox=8'h0d;
            8'hf4:sbox=8'hbf;8'hf5:sbox=8'he6;8'hf6:sbox=8'h42;8'hf7:sbox=8'h68;
            8'hf8:sbox=8'h41;8'hf9:sbox=8'h99;8'hfa:sbox=8'h2d;8'hfb:sbox=8'h0f;
            8'hfc:sbox=8'hb0;8'hfd:sbox=8'h54;8'hfe:sbox=8'hbb;8'hff:sbox=8'h16;
            default: sbox = 8'h00;
        endcase
    endfunction

    function [7:0] xtime;
        input [7:0] x;
        xtime = (x[7]) ? ({x[6:0],1'b0} ^ 8'h1b) : {x[6:0],1'b0};
    endfunction

    function [7:0] mul3;
        input [7:0] x;
        mul3 = xtime(x) ^ x;
    endfunction

    function [127:0] sub_bytes;
        input [127:0] s;
        integer i;
        reg [7:0] b;
        begin
            sub_bytes = 128'd0;
            for (i = 0; i < 16; i = i + 1)
                sub_bytes[8*i+7 -: 8] = sbox(s[8*i+7 -: 8]);
        end
    endfunction

    function [127:0] shift_rows;
        input [127:0] s;
        reg [7:0] b [0:15];
        integer ii;
        begin
            for (ii = 0; ii < 16; ii = ii + 1)
                b[ii] = s[127-8*ii -: 8];

            shift_rows = {b[0],b[5],b[10],b[15],
                          b[4],b[9],b[14],b[3],
                          b[8],b[13],b[2],b[7],
                          b[12],b[1],b[6],b[11]};
        end
    endfunction

    function [31:0] mix_col;
        input [31:0] col;
        reg [7:0] s0,s1,s2,s3;
        begin
            s0 = col[31:24]; s1 = col[23:16]; s2 = col[15:8]; s3 = col[7:0];
            mix_col = {xtime(s0)^mul3(s1)^s2^s3,
                       s0^xtime(s1)^mul3(s2)^s3,
                       s0^s1^xtime(s2)^mul3(s3),
                       mul3(s0)^s1^s2^xtime(s3)};
        end
    endfunction

    function [127:0] mix_columns;
        input [127:0] s;
        mix_columns = {mix_col(s[127:96]), mix_col(s[95:64]),
                       mix_col(s[63:32]),  mix_col(s[31:0])};
    endfunction

    function [31:0] sub_word;
        input [31:0] w;
        sub_word = {sbox(w[31:24]), sbox(w[23:16]), sbox(w[15:8]), sbox(w[7:0])};
    endfunction

    function [31:0] rot_word;
        input [31:0] w;
        rot_word = {w[23:0], w[31:24]};
    endfunction

    function [7:0] rcon;
        input [3:0] i;
        case (i)
            4'd0:  rcon = 8'h01; 4'd1: rcon = 8'h02; 4'd2: rcon = 8'h04;
            4'd3:  rcon = 8'h08; 4'd4: rcon = 8'h10; 4'd5: rcon = 8'h20;
            4'd6:  rcon = 8'h40; 4'd7: rcon = 8'h80; 4'd8: rcon = 8'h1b;
            4'd9:  rcon = 8'h36; 4'd10: rcon = 8'h6c; 4'd11: rcon = 8'hd8;
            4'd12: rcon = 8'hab; 4'd13: rcon = 8'h4d;
            default: rcon = 8'h00;
        endcase
    endfunction

    reg [255:0] key_reg;
    reg [127:0] din_reg;
    reg [127:0] dout_reg;
    reg         done_r;
    reg         busy_r;

    reg [31:0]  w [0:59];
    reg [127:0] round_key [0:14];

    localparam AES_IDLE   = 3'd0,
               AES_KEYSCHED = 3'd1,
               AES_ROUND  = 3'd2,
               AES_FINAL  = 3'd3,
               AES_DONE   = 3'd4;

    reg [2:0]  aes_state;
    reg [3:0]  round_cnt;
    reg [127:0] state_reg;

    reg [5:0]  ks_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aes_state <= AES_IDLE; done_r <= 0; busy_r <= 0;
            key_reg <= 0; din_reg <= 0; dout_reg <= 0;
            ks_cnt <= 0; round_cnt <= 0;
        end else begin
            case (aes_state)
                AES_IDLE: ;

                AES_KEYSCHED: begin

                    if (ks_cnt == 0) begin
                        w[0] <= key_reg[255:224]; w[1] <= key_reg[223:192];
                        w[2] <= key_reg[191:160]; w[3] <= key_reg[159:128];
                        w[4] <= key_reg[127:96];  w[5] <= key_reg[95:64];
                        w[6] <= key_reg[63:32];   w[7] <= key_reg[31:0];
                        ks_cnt <= 6'd8;
                    end else if (ks_cnt < 6'd60) begin

                        if (ks_cnt[2:0] == 3'd0) begin

                            w[ks_cnt]   <= w[ks_cnt-8] ^ sub_word(rot_word(w[ks_cnt-1]))
                                           ^ {rcon((ks_cnt>>3)-4'd1), 24'd0};
                            w[ks_cnt+1] <= w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(rot_word(w[ks_cnt-1]))
                                           ^ {rcon((ks_cnt>>3)-4'd1), 24'd0});
                            w[ks_cnt+2] <= w[ks_cnt-6] ^ (w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(rot_word(w[ks_cnt-1]))
                                           ^ {rcon((ks_cnt>>3)-4'd1), 24'd0}));
                            w[ks_cnt+3] <= w[ks_cnt-5] ^ (w[ks_cnt-6] ^ (w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(rot_word(w[ks_cnt-1]))
                                           ^ {rcon((ks_cnt>>3)-4'd1), 24'd0})));
                        end else begin

                            w[ks_cnt]   <= w[ks_cnt-8] ^ sub_word(w[ks_cnt-1]);
                            w[ks_cnt+1] <= w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(w[ks_cnt-1]));
                            w[ks_cnt+2] <= w[ks_cnt-6] ^ (w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(w[ks_cnt-1])));
                            w[ks_cnt+3] <= w[ks_cnt-5] ^ (w[ks_cnt-6] ^ (w[ks_cnt-7] ^ (w[ks_cnt-8] ^ sub_word(w[ks_cnt-1]))));
                        end
                        ks_cnt <= ks_cnt + 6'd4;
                    end else begin

                        begin : pack_rk
                            integer rk;
                            for (rk = 0; rk < 15; rk = rk + 1)
                                round_key[rk] <= {w[4*rk], w[4*rk+1], w[4*rk+2], w[4*rk+3]};
                        end

                        state_reg <= din_reg ^ {w[0],w[1],w[2],w[3]};
                        round_cnt <= 4'd1;
                        aes_state <= AES_ROUND;
                    end
                end

                AES_ROUND: begin

                    if (round_cnt < 4'd14) begin
                        state_reg <= mix_columns(shift_rows(sub_bytes(state_reg)))
                                     ^ round_key[round_cnt];
                        round_cnt <= round_cnt + 1;
                    end else
                        aes_state <= AES_FINAL;
                end

                AES_FINAL: begin

                    dout_reg  <= shift_rows(sub_bytes(state_reg)) ^ round_key[14];
                    aes_state <= AES_DONE;
                    done_r    <= 1'b1;
                    busy_r    <= 1'b0;
                end

                AES_DONE: ;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_awready <= 0; s_wready <= 0; s_bvalid <= 0; s_bresp <= 0;
        end else begin
            s_awready <= 0; s_wready <= 0;
            if (s_awvalid && s_wvalid && !s_bvalid) begin
                s_awready <= 1; s_wready <= 1;
                case (s_awaddr[6:0])
                    7'h00: begin
                        if (s_wdata[0] && !busy_r) begin
                            busy_r    <= 1'b1;
                            done_r    <= 1'b0;
                            ks_cnt    <= 6'd0;
                            aes_state <= AES_KEYSCHED;
                        end
                    end
                    7'h04: key_reg[255:224] <= s_wdata;
                    7'h08: key_reg[223:192] <= s_wdata;
                    7'h0C: key_reg[191:160] <= s_wdata;
                    7'h10: key_reg[159:128] <= s_wdata;
                    7'h14: key_reg[127:96]  <= s_wdata;
                    7'h18: key_reg[95:64]   <= s_wdata;
                    7'h1C: key_reg[63:32]   <= s_wdata;
                    7'h20: key_reg[31:0]    <= s_wdata;
                    7'h24: din_reg[127:96]  <= s_wdata;
                    7'h28: din_reg[95:64]   <= s_wdata;
                    7'h2C: din_reg[63:32]   <= s_wdata;
                    7'h30: din_reg[31:0]    <= s_wdata;
                endcase
                s_bvalid <= 1; s_bresp <= 2'b00;
            end
            if (s_bvalid && s_bready) s_bvalid <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_arready <= 0; s_rvalid <= 0; s_rdata <= 0; s_rresp <= 0;
        end else begin
            s_arready <= 0;
            if (s_arvalid && !s_rvalid) begin
                s_arready <= 1; s_rresp <= 2'b00; s_rvalid <= 1;
                case (s_araddr[6:0])
                    7'h00: s_rdata <= {22'd0, busy_r, done_r, 8'd0};
                    7'h04: s_rdata <= key_reg[255:224];
                    7'h08: s_rdata <= key_reg[223:192];
                    7'h0C: s_rdata <= key_reg[191:160];
                    7'h10: s_rdata <= key_reg[159:128];
                    7'h14: s_rdata <= key_reg[127:96];
                    7'h18: s_rdata <= key_reg[95:64];
                    7'h1C: s_rdata <= key_reg[63:32];
                    7'h20: s_rdata <= key_reg[31:0];
                    7'h34: s_rdata <= dout_reg[127:96];
                    7'h38: s_rdata <= dout_reg[95:64];
                    7'h3C: s_rdata <= dout_reg[63:32];
                    7'h40: s_rdata <= dout_reg[31:0];
                    default: s_rdata <= 32'd0;
                endcase
            end
            if (s_rvalid && s_rready) s_rvalid <= 0;
        end
    end

endmodule

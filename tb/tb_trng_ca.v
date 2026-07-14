`timescale 1ns/1ps
module tb_trng_ca;

    reg         clk, rst_n;
    reg  [31:0] s_awaddr;  reg s_awvalid; wire        s_awready;
    reg  [31:0] s_wdata;   reg [3:0] s_wstrb; reg s_wvalid; wire s_wready;
    wire [1:0]  s_bresp;   wire s_bvalid;  reg  s_bready;
    reg  [31:0] s_araddr;  reg s_arvalid; wire        s_arready;
    wire [31:0] s_rdata;   wire [1:0] s_rresp; wire s_rvalid; reg s_rready;
    wire        alarm_n;

    trng_ca dut (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(s_awaddr), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata(s_wdata),   .s_wstrb(s_wstrb),     .s_wvalid(s_wvalid),   .s_wready(s_wready),
        .s_bresp(s_bresp),   .s_bvalid(s_bvalid),   .s_bready(s_bready),
        .s_araddr(s_araddr), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rdata(s_rdata),   .s_rresp(s_rresp),     .s_rvalid(s_rvalid),   .s_rready(s_rready),
        .alarm_n(alarm_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer pass = 0, fail = 0;

    task check_eq;
        input [31:0] got, exp;
        input [127:0] label;
        begin
            if (got === exp) begin $display("  PASS [%0s]", label); pass = pass+1; end
            else begin $display("  FAIL [%0s] got=0x%08h exp=0x%08h", label, got, exp); fail = fail+1; end
        end
    endtask
    task check_nonzero;
        input [31:0] val;
        input [127:0] label;
        begin
            if (val !== 32'd0) begin $display("  PASS [%0s] 0x%08h (non-zero)", label, val); pass = pass+1; end
            else begin $display("  FAIL [%0s] got zero!", label); fail = fail+1; end
        end
    endtask
    task check_ne;
        input [31:0] a, b;
        input [127:0] label;
        begin
            if (a !== b) begin $display("  PASS [%0s] differ (0x%08h vs 0x%08h)", label, a, b); pass = pass+1; end
            else begin $display("  FAIL [%0s] identical = 0x%08h", label, a); fail = fail+1; end
        end
    endtask
    task check_bit_set;
        input       got;
        input [127:0] label;
        begin
            if (got === 1'b1) begin $display("  PASS [%0s]", label); pass = pass+1; end
            else begin $display("  FAIL [%0s] bit was 0", label); fail = fail+1; end
        end
    endtask
    task check_bit_clr;
        input       got;
        input [127:0] label;
        begin
            if (got === 1'b0) begin $display("  PASS [%0s]", label); pass = pass+1; end
            else begin $display("  FAIL [%0s] bit was 1", label); fail = fail+1; end
        end
    endtask

    task axi_write;
        input [31:0] addr, data;
        begin
            @(posedge clk); #1;
            s_awaddr = addr; s_awvalid = 1;
            s_wdata  = data; s_wstrb = 4'hF; s_wvalid = 1;
            s_bready = 1;

            @(posedge clk); #1;
            while (!s_awready || !s_wready) begin @(posedge clk); #1; end

            s_awvalid = 0; s_wvalid = 0;

            if (!s_bvalid) begin
                @(posedge clk); #1;
                while (!s_bvalid) begin @(posedge clk); #1; end
            end

            @(posedge clk); #1;
            s_bready = 0;
        end
    endtask

    reg [31:0] axi_rd;
    task axi_read;
        input [31:0] addr;
        begin
            @(posedge clk); #1;
            s_araddr = addr; s_arvalid = 1; s_rready = 1;

            @(posedge clk); #1;
            while (!s_arready) begin @(posedge clk); #1; end

            axi_rd    = s_rdata;
            s_arvalid = 0;

            @(posedge clk); #1;
            s_rready  = 0;
        end
    endtask

    integer i;
    reg [31:0] samples [0:63];

    initial begin
        $dumpfile("tb_trng_ca.vcd");
        $dumpvars(0, tb_trng_ca);

        s_awaddr=0; s_awvalid=0; s_wdata=0; s_wstrb=0; s_wvalid=0; s_bready=0;
        s_araddr=0; s_arvalid=0; s_rready=0;

        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;

        repeat(200) @(posedge clk);

        $display("\n--- CAMTRNG Unit Tests ---");

        $display("\n[1] STATUS.data_ready bit set after reset+seed init");
        axi_read(32'h0000_0004);
        $display("    STATUS = 0x%08h", axi_rd);
        check_bit_set(axi_rd[0], "STATUS_DATA_READY");

        $display("\n[2] STATUS.alarm bit is clear (no health failure)");
        check_bit_clr(axi_rd[1], "STATUS_ALARM_CLEAR");

        $display("\n[3] DATA register returns non-zero entropy");
        axi_read(32'h0000_0008);
        $display("    DATA = 0x%08h", axi_rd);
        check_nonzero(axi_rd, "DATA_NONZERO");

        $display("\n[4] Consecutive reads produce different values");
        axi_read(32'h0000_0008);
        samples[0] = axi_rd;
        repeat(10) @(posedge clk);
        axi_read(32'h0000_0008);
        samples[1] = axi_rd;
        $display("    RAND[0] = 0x%08h", samples[0]);
        $display("    RAND[1] = 0x%08h", samples[1]);
        check_ne(samples[0], samples[1], "CONSECUTIVE_DIFFER");

        $display("\n[5] 32-sample no-adjacent-duplicate check");
        begin : no_dup
            integer dups;
            dups = 0;
            for (i = 0; i < 32; i = i + 1) begin
                repeat(5) @(posedge clk);
                axi_read(32'h0000_0008);
                samples[i] = axi_rd;
            end
            for (i = 0; i < 31; i = i + 1) begin
                if (samples[i] === samples[i+1]) begin
                    $display("    WARN: samples[%0d]=samples[%0d]=0x%08h", i, i+1, samples[i]);
                    dups = dups + 1;
                end
            end
            if (dups == 0) begin
                $display("  PASS [NO_ADJ_DUPLICATES] all 31 adjacent pairs differ");
                pass = pass + 1;
            end else begin
                $display("  FAIL [NO_ADJ_DUPLICATES] %0d adjacent duplicates", dups);
                fail = fail + 1;
            end
        end

        $display("\n[6] Bit-balance: 1024 bits, expect 35-65%% ones");
        begin : balance
            integer ones;
            integer k;
            reg [31:0] w;
            ones = 0;
            for (i = 0; i < 32; i = i + 1) begin
                repeat(5) @(posedge clk);
                axi_read(32'h0000_0008);
                w = axi_rd;
                for (k = 0; k < 32; k = k + 1)
                    if (w[k]) ones = ones + 1;
            end
            $display("    ones = %0d / 1024 = %0d%%", ones, ones * 100 / 1024);
            if (ones >= 358 && ones <= 666) begin
                $display("  PASS [BIT_BALANCE]");
                pass = pass + 1;
            end else begin
                $display("  FAIL [BIT_BALANCE] out of range [358,666]");
                fail = fail + 1;
            end
        end

        $display("\n[7] alarm_n held HIGH for 500 cycles");
        begin : alarm_watch
            integer low_cnt;
            low_cnt = 0;
            for (i = 0; i < 500; i = i + 1) begin
                @(posedge clk);
                if (!alarm_n) low_cnt = low_cnt + 1;
            end
            if (low_cnt == 0) begin
                $display("  PASS [ALARM_INACTIVE]");
                pass = pass + 1;
            end else begin
                $display("  FAIL [ALARM_INACTIVE] alarm_n low %0d times", low_cnt);
                fail = fail + 1;
            end
        end

        $display("\n[8] CPU seed injection — DATA still valid after seed write");
        axi_write(32'h0000_000C, 32'hDEAD_CAFE);
        repeat(10) @(posedge clk);
        axi_read(32'h0000_0008);
        check_nonzero(axi_rd, "DATA_AFTER_SEED");

        $display("\n[9] CTRL disable/re-enable, data_ready recovers");
        axi_write(32'h0000_0000, 32'h0000_0000);
        repeat(5) @(posedge clk);
        axi_write(32'h0000_0000, 32'h0000_0001);
        repeat(20) @(posedge clk);
        axi_read(32'h0000_0004);
        check_bit_set(axi_rd[0], "CTRL_REENABLE_READY");

        $display("\n[10] Run-length test: max run <= 24 over 512 bits");
        begin : runlen
            integer max_run, cur_run, prev_b, cur_b;
            integer j;
            reg [511:0] bs;
            reg [31:0]  w2;
            for (i = 0; i < 16; i = i + 1) begin
                repeat(5) @(posedge clk);
                axi_read(32'h0000_0008);
                w2 = axi_rd;
                bs[i*32 +: 32] = w2;
            end
            max_run = 1; cur_run = 1; prev_b = bs[0];
            for (j = 1; j < 512; j = j + 1) begin
                cur_b = bs[j];
                if (cur_b === prev_b) begin
                    cur_run = cur_run + 1;
                    if (cur_run > max_run) max_run = cur_run;
                end else cur_run = 1;
                prev_b = cur_b;
            end
            $display("    max run = %0d bits", max_run);
            if (max_run <= 24) begin
                $display("  PASS [RUNLENGTH] max_run=%0d", max_run);
                pass = pass + 1;
            end else begin
                $display("  FAIL [RUNLENGTH] max_run=%0d > 24", max_run);
                fail = fail + 1;
            end
        end

        $display("\n=== CAMTRNG Results: %0d PASS, %0d FAIL ===", pass, fail);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("WATCHDOG TIMEOUT");
        $finish;
    end

endmodule

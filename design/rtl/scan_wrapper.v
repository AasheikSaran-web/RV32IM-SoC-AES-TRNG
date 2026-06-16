module scan_wrapper (

    input  clk_in,
    input  rst_n_in,

    input  tck,
    input  tms,
    input  tdi,
    output tdo,
    input  trstn,

    input  scan_in,
    output scan_out,

    output pad_uart0_tx,
    input  pad_uart0_rx,

    output pad_uart1_tx,
    input  pad_uart1_rx,

    output pad_spi0_sck,
    output pad_spi0_mosi,
    input  pad_spi0_miso,
    output pad_spi0_csn,

    output pad_spi1_sck,
    output pad_spi1_mosi,
    input  pad_spi1_miso,
    output pad_spi1_csn,

    inout  [31:0] pad_gpio,

    inout  pad_i2c_sda,
    inout  pad_i2c_scl,

    output pad_adc_soc,
    input  pad_adc_eoc,
    input  [11:0] pad_adc_data,
    output [2:0]  pad_adc_ch
);

    wire bscan_mode, bscan_update, bscan_capture, bscan_shift, bscan_tdi, bscan_tdo_wire;
    wire scan_en_tap, scan_mode_tap, scan_reset_tap;

    jtag_tap #(.IDCODE_VAL(32'h1002_4093)) u_tap (
        .tck          (tck),
        .tms          (tms),
        .tdi          (tdi),
        .tdo          (tdo),
        .trstn        (trstn),
        .bscan_mode   (bscan_mode),
        .bscan_update (bscan_update),
        .bscan_capture(bscan_capture),
        .bscan_shift  (bscan_shift),
        .bscan_tdi    (bscan_tdi),
        .bscan_tdo    (bscan_tdo_wire),
        .scan_en      (scan_en_tap),
        .scan_mode    (scan_mode_tap),
        .scan_reset   (scan_reset_tap)
    );

    wire scan_mode_active = scan_mode_tap || scan_en_tap;
    wire clk_muxed        = scan_mode_active ? tck   : clk_in;
    wire rst_n_muxed      = scan_mode_active ? trstn : rst_n_in;

    wire core_uart0_tx, core_uart0_rx;
    wire core_uart1_tx, core_uart1_rx;
    wire core_spi0_sck, core_spi0_mosi, core_spi0_miso, core_spi0_csn;
    wire core_spi1_sck, core_spi1_mosi, core_spi1_miso, core_spi1_csn;
    wire [31:0] core_gpio_out, core_gpio_in, core_gpio_oe;
    wire core_sda_out, core_sda_in, core_sda_oe;
    wire core_scl_out, core_scl_in, core_scl_oe;
    wire core_adc_soc, core_adc_eoc;
    wire [11:0] core_adc_data;
    wire [2:0]  core_adc_ch;

    wire [96:0] chain;
    assign chain[0] = bscan_tdi;

    bc_2 u_bc_uart0_tx (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .extest(bscan_mode), .si(chain[0]), .so(chain[1]),
        .core_in(core_uart0_tx), .pin_out(pad_uart0_tx)
    );

    bc_1 u_bc_uart0_rx (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .si(chain[1]), .so(chain[2]),
        .pin_in(pad_uart0_rx), .core_out(core_uart0_rx)
    );

    bc_2 u_bc_uart1_tx (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .extest(bscan_mode), .si(chain[2]), .so(chain[3]),
        .core_in(core_uart1_tx), .pin_out(pad_uart1_tx)
    );

    bc_1 u_bc_uart1_rx (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .si(chain[3]), .so(chain[4]),
        .pin_in(pad_uart1_rx), .core_out(core_uart1_rx)
    );

    bc_2 u_bc_spi0_sck  (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[4]),.so(chain[5]),.core_in(core_spi0_sck),.pin_out(pad_spi0_sck));
    bc_2 u_bc_spi0_mosi (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[5]),.so(chain[6]),.core_in(core_spi0_mosi),.pin_out(pad_spi0_mosi));
    bc_1 u_bc_spi0_miso (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.si(chain[6]),.so(chain[7]),.pin_in(pad_spi0_miso),.core_out(core_spi0_miso));
    bc_2 u_bc_spi0_csn  (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[7]),.so(chain[8]),.core_in(core_spi0_csn),.pin_out(pad_spi0_csn));

    bc_2 u_bc_spi1_sck  (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[8]),.so(chain[9]),.core_in(core_spi1_sck),.pin_out(pad_spi1_sck));
    bc_2 u_bc_spi1_mosi (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[9]),.so(chain[10]),.core_in(core_spi1_mosi),.pin_out(pad_spi1_mosi));
    bc_1 u_bc_spi1_miso (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.si(chain[10]),.so(chain[11]),.pin_in(pad_spi1_miso),.core_out(core_spi1_miso));
    bc_2 u_bc_spi1_csn  (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[11]),.so(chain[12]),.core_in(core_spi1_csn),.pin_out(pad_spi1_csn));

    genvar gi;
    generate
        for (gi = 0; gi < 32; gi = gi + 1) begin : gpio_bscan
            bc_4 u_bc_gpio (
                .capture_clk(tck), .update_clk(tck),
                .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
                .extest(bscan_mode),
                .si(chain[12 + gi*2]),
                .so(chain[12 + gi*2 + 1]),
                .core_out(core_gpio_out[gi]),
                .core_oe(core_gpio_oe[gi]),
                .pad(pad_gpio[gi]),
                .core_in(core_gpio_in[gi])
            );

            bc_7 u_bc_gpio_oe (
                .capture_clk(tck),
                .shift_en(bscan_shift), .capture_en(bscan_capture),
                .si(chain[12 + gi*2 + 1]),
                .so(chain[12 + gi*2 + 2]),
                .observe_in(core_gpio_oe[gi])
            );
        end
    endgenerate

    bc_4 u_bc_sda (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .extest(bscan_mode), .si(chain[76]), .so(chain[77]),
        .core_out(core_sda_out), .core_oe(core_sda_oe),
        .pad(pad_i2c_sda), .core_in(core_sda_in)
    );

    bc_4 u_bc_scl (
        .capture_clk(tck), .update_clk(tck),
        .capture_en(bscan_capture), .shift_en(bscan_shift), .update_en(bscan_update),
        .extest(bscan_mode), .si(chain[77]), .so(chain[78]),
        .core_out(core_scl_out), .core_oe(core_scl_oe),
        .pad(pad_i2c_scl), .core_in(core_scl_in)
    );

    bc_2 u_bc_adc_soc (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[78]),.so(chain[79]),.core_in(core_adc_soc),.pin_out(pad_adc_soc));

    bc_1 u_bc_adc_eoc (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.si(chain[79]),.so(chain[80]),.pin_in(pad_adc_eoc),.core_out(core_adc_eoc));

    genvar ai;
    generate
        for (ai = 0; ai < 12; ai = ai + 1) begin : adc_data_bscan
            bc_1 u_bc_adc_d (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.si(chain[80+ai]),.so(chain[81+ai]),.pin_in(pad_adc_data[ai]),.core_out(core_adc_data[ai]));
        end
    endgenerate

    genvar ci;
    generate
        for (ci = 0; ci < 3; ci = ci + 1) begin : adc_ch_bscan
            bc_2 u_bc_adc_ch (.capture_clk(tck),.update_clk(tck),.capture_en(bscan_capture),.shift_en(bscan_shift),.update_en(bscan_update),.extest(bscan_mode),.si(chain[92+ci]),.so(chain[93+ci]),.core_in(core_adc_ch[ci]),.pin_out(pad_adc_ch[ci]));
        end
    endgenerate

    assign bscan_tdo_wire = chain[95];

    wire soc_scan_in  = scan_en_tap ? scan_in  : 1'b0;
    assign scan_out   = soc_scan_in;

    riscv_soc u_soc (
        .clk      (clk_muxed),
        .rst_n    (rst_n_muxed),

        .uart0_tx (core_uart0_tx),
        .uart0_rx (core_uart0_rx),

        .uart1_tx (core_uart1_tx),
        .uart1_rx (core_uart1_rx),

        .spi0_sck (core_spi0_sck),
        .spi0_mosi(core_spi0_mosi),
        .spi0_miso(core_spi0_miso),
        .spi0_csn (core_spi0_csn),

        .spi1_sck (core_spi1_sck),
        .spi1_mosi(core_spi1_mosi),
        .spi1_miso(core_spi1_miso),
        .spi1_csn (core_spi1_csn),

        .gpio     (pad_gpio),

        .i2c_sda  (pad_i2c_sda),
        .i2c_scl  (pad_i2c_scl),

        .adc_soc  (core_adc_soc),
        .adc_eoc  (core_adc_eoc),
        .adc_data (core_adc_data),
        .adc_ch   (core_adc_ch)
    );

endmodule

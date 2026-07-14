module riscv_soc (
    input         clk,
    input         rst_n,

    output        spi_sck,
    output        spi_mosi,
    input         spi_miso,
    output        spi_cs0_n,
    output        spi_cs1_n,
    output        spi_cs2_n,
    output        spi_cs3_n,

    output        uart0_tx,
    input         uart0_rx,

    output        uart1_tx,
    input         uart1_rx,

    inout  [31:0] gpio_pins,

    inout         i2c_sda,
    inout         i2c_scl,

    input  [11:0] adc_data,
    input         adc_eoc,
    output        adc_soc,
    output [2:0]  adc_ch
);

    wire [31:0] imem_addr, imem_rdata;
    wire        imem_req, imem_ready;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0]  dmem_wstrb;
    wire        dmem_req, dmem_ready;
    wire        timer_irq, soft_irq, ext_irq;

    rv32i_cpu #(.RESET_ADDR(32'h0000_0000)) u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_req   (imem_req),
        .imem_rdata (imem_rdata),
        .imem_ready (imem_ready),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wstrb (dmem_wstrb),
        .dmem_req   (dmem_req),
        .dmem_rdata (dmem_rdata),
        .dmem_ready (dmem_ready),
        .timer_irq  (timer_irq),
        .soft_irq   (soft_irq),
        .ext_irq    (ext_irq)
    );

    wire [31:0] im_araddr;  wire im_arvalid, im_arready;
    wire [31:0] im_rdata;   wire [1:0] im_rresp; wire im_rvalid, im_rready;

    cpu_axi_adapter #(.READ_ONLY(1)) u_imem_axi (
        .clk       (clk), .rst_n     (rst_n),
        .cpu_addr  (imem_addr), .cpu_wdata(32'd0), .cpu_wstrb(4'd0),
        .cpu_req   (imem_req),  .cpu_rdata(imem_rdata), .cpu_ready(imem_ready),
        .m_araddr  (im_araddr), .m_arvalid(im_arvalid), .m_arready(im_arready),
        .m_rdata   (im_rdata),  .m_rresp  (im_rresp),   .m_rvalid(im_rvalid),
        .m_rready  (im_rready),
        .m_awaddr  (), .m_awvalid(), .m_awready(1'b1),
        .m_wdata   (), .m_wstrb  (), .m_wvalid (), .m_wready(1'b1),
        .m_bresp   (2'b0), .m_bvalid(1'b0), .m_bready()
    );

    wire [31:0] dm_araddr;  wire dm_arvalid, dm_arready;
    wire [31:0] dm_rdata;   wire [1:0] dm_rresp; wire dm_rvalid, dm_rready;
    wire [31:0] dm_awaddr;  wire dm_awvalid, dm_awready;
    wire [31:0] dm_wdata;   wire [3:0] dm_wstrb; wire dm_wvalid, dm_wready;
    wire [1:0]  dm_bresp;   wire dm_bvalid, dm_bready;

    cpu_axi_adapter #(.READ_ONLY(0)) u_dmem_axi (
        .clk       (clk), .rst_n     (rst_n),
        .cpu_addr  (dmem_addr), .cpu_wdata(dmem_wdata), .cpu_wstrb(dmem_wstrb),
        .cpu_req   (dmem_req),  .cpu_rdata(dmem_rdata), .cpu_ready(dmem_ready),
        .m_araddr  (dm_araddr), .m_arvalid(dm_arvalid), .m_arready(dm_arready),
        .m_rdata   (dm_rdata),  .m_rresp  (dm_rresp),   .m_rvalid(dm_rvalid),
        .m_rready  (dm_rready),
        .m_awaddr  (dm_awaddr), .m_awvalid(dm_awvalid), .m_awready(dm_awready),
        .m_wdata   (dm_wdata),  .m_wstrb  (dm_wstrb),   .m_wvalid(dm_wvalid),
        .m_wready  (dm_wready),
        .m_bresp   (dm_bresp),  .m_bvalid (dm_bvalid),  .m_bready(dm_bready)
    );

    wire [31:0] brom_araddr;  wire brom_arvalid, brom_arready;
    wire [31:0] brom_rdata;   wire [1:0] brom_rresp; wire brom_rvalid, brom_rready;

    wire [31:0] sram_pa_araddr; wire sram_pa_arvalid, sram_pa_arready;
    wire [31:0] sram_pa_rdata;  wire [1:0] sram_pa_rresp; wire sram_pa_rvalid, sram_pa_rready;

    axi_lite_xbar #(
        .N_SLV(8),
        .BASE0(32'h0000_0000), .MASK0(32'hFFFF_F000),
        .BASE1(32'h0200_0000), .MASK1(32'hFFFF_0000),
        .BASE2(32'h0C00_0000), .MASK2(32'hFC00_0000),
        .BASE3(32'h1000_0000), .MASK3(32'hFFFF_0000),
        .BASE4(32'h2000_0000), .MASK4(32'hFFFE_0000),
        .BASE5(32'h3000_0000), .MASK5(32'hFFFF_F000),
        .BASE6(32'h3000_1000), .MASK6(32'hFFFF_F000),
        .BASE7(32'h4000_0000), .MASK7(32'hFFFF_0000)
    ) u_imem_xbar (
        .clk(clk), .rst_n(rst_n),
        .m_awaddr(32'd0), .m_awvalid(1'b0), .m_awready(),
        .m_wdata(32'd0), .m_wstrb(4'd0), .m_wvalid(1'b0), .m_wready(),
        .m_bresp(), .m_bvalid(), .m_bready(1'b0),
        .m_araddr(im_araddr), .m_arvalid(im_arvalid), .m_arready(im_arready),
        .m_rdata(im_rdata), .m_rresp(im_rresp), .m_rvalid(im_rvalid), .m_rready(im_rready),

        .s0_awaddr(), .s0_awvalid(), .s0_awready(1'b1),
        .s0_wdata(),  .s0_wstrb(),   .s0_wvalid(), .s0_wready(1'b1),
        .s0_bresp(2'b0), .s0_bvalid(1'b0), .s0_bready(),
        .s0_araddr(brom_araddr), .s0_arvalid(brom_arvalid), .s0_arready(brom_arready),
        .s0_rdata(brom_rdata), .s0_rresp(brom_rresp), .s0_rvalid(brom_rvalid), .s0_rready(brom_rready),

        .s1_awaddr(),.s1_awvalid(),.s1_awready(1'b1),.s1_wdata(),.s1_wstrb(),.s1_wvalid(),.s1_wready(1'b1),
        .s1_bresp(2'b0),.s1_bvalid(1'b0),.s1_bready(),.s1_araddr(),.s1_arvalid(),.s1_arready(1'b1),
        .s1_rdata(32'd0),.s1_rresp(2'b0),.s1_rvalid(1'b0),.s1_rready(),
        .s2_awaddr(),.s2_awvalid(),.s2_awready(1'b1),.s2_wdata(),.s2_wstrb(),.s2_wvalid(),.s2_wready(1'b1),
        .s2_bresp(2'b0),.s2_bvalid(1'b0),.s2_bready(),.s2_araddr(),.s2_arvalid(),.s2_arready(1'b1),
        .s2_rdata(32'd0),.s2_rresp(2'b0),.s2_rvalid(1'b0),.s2_rready(),
        .s3_awaddr(),.s3_awvalid(),.s3_awready(1'b1),.s3_wdata(),.s3_wstrb(),.s3_wvalid(),.s3_wready(1'b1),
        .s3_bresp(2'b0),.s3_bvalid(1'b0),.s3_bready(),.s3_araddr(),.s3_arvalid(),.s3_arready(1'b1),
        .s3_rdata(32'd0),.s3_rresp(2'b0),.s3_rvalid(1'b0),.s3_rready(),

        .s4_awaddr(),.s4_awvalid(),.s4_awready(1'b1),.s4_wdata(),.s4_wstrb(),.s4_wvalid(),.s4_wready(1'b1),
        .s4_bresp(2'b0),.s4_bvalid(1'b0),.s4_bready(),
        .s4_araddr(sram_pa_araddr), .s4_arvalid(sram_pa_arvalid), .s4_arready(sram_pa_arready),
        .s4_rdata(sram_pa_rdata), .s4_rresp(sram_pa_rresp), .s4_rvalid(sram_pa_rvalid), .s4_rready(sram_pa_rready),

        .s5_awaddr(),.s5_awvalid(),.s5_awready(1'b1),.s5_wdata(),.s5_wstrb(),.s5_wvalid(),.s5_wready(1'b1),
        .s5_bresp(2'b0),.s5_bvalid(1'b0),.s5_bready(),.s5_araddr(),.s5_arvalid(),.s5_arready(1'b1),
        .s5_rdata(32'd0),.s5_rresp(2'b0),.s5_rvalid(1'b0),.s5_rready(),
        .s6_awaddr(),.s6_awvalid(),.s6_awready(1'b1),.s6_wdata(),.s6_wstrb(),.s6_wvalid(),.s6_wready(1'b1),
        .s6_bresp(2'b0),.s6_bvalid(1'b0),.s6_bready(),.s6_araddr(),.s6_arvalid(),.s6_arready(1'b1),
        .s6_rdata(32'd0),.s6_rresp(2'b0),.s6_rvalid(1'b0),.s6_rready(),
        .s7_awaddr(),.s7_awvalid(),.s7_awready(1'b1),.s7_wdata(),.s7_wstrb(),.s7_wvalid(),.s7_wready(1'b1),
        .s7_bresp(2'b0),.s7_bvalid(1'b0),.s7_bready(),.s7_araddr(),.s7_arvalid(),.s7_arready(1'b1),
        .s7_rdata(32'd0),.s7_rresp(2'b0),.s7_rvalid(1'b0),.s7_rready()
    );

    wire [31:0] clint_awaddr, clint_araddr, clint_wdata, clint_rdata;
    wire [3:0]  clint_wstrb;
    wire        clint_awvalid, clint_awready, clint_wvalid, clint_wready;
    wire [1:0]  clint_bresp; wire clint_bvalid, clint_bready;
    wire        clint_arvalid, clint_arready;
    wire [1:0]  clint_rresp; wire clint_rvalid, clint_rready;

    wire [31:0] plic_awaddr, plic_araddr, plic_wdata, plic_rdata;
    wire [3:0]  plic_wstrb;
    wire        plic_awvalid, plic_awready, plic_wvalid, plic_wready;
    wire [1:0]  plic_bresp; wire plic_bvalid, plic_bready;
    wire        plic_arvalid, plic_arready;
    wire [1:0]  plic_rresp; wire plic_rvalid, plic_rready;

    wire [31:0] apb_awaddr, apb_araddr, apb_wdata, apb_rdata;
    wire [3:0]  apb_wstrb;
    wire        apb_awvalid, apb_awready, apb_wvalid, apb_wready;
    wire [1:0]  apb_bresp; wire apb_bvalid, apb_bready;
    wire        apb_arvalid, apb_arready;
    wire [1:0]  apb_rresp; wire apb_rvalid, apb_rready;

    wire [31:0] sram_pb_awaddr, sram_pb_araddr, sram_pb_wdata, sram_pb_rdata;
    wire [3:0]  sram_pb_wstrb;
    wire        sram_pb_awvalid, sram_pb_awready, sram_pb_wvalid, sram_pb_wready;
    wire [1:0]  sram_pb_bresp; wire sram_pb_bvalid, sram_pb_bready;
    wire        sram_pb_arvalid, sram_pb_arready;
    wire [1:0]  sram_pb_rresp; wire sram_pb_rvalid, sram_pb_rready;

    wire [31:0] trng_awaddr, trng_araddr, trng_wdata, trng_rdata;
    wire [3:0]  trng_wstrb;
    wire        trng_awvalid, trng_awready, trng_wvalid, trng_wready;
    wire [1:0]  trng_bresp; wire trng_bvalid, trng_bready;
    wire        trng_arvalid, trng_arready;
    wire [1:0]  trng_rresp; wire trng_rvalid, trng_rready;

    axi_lite_xbar #(
        .N_SLV(8),
        .BASE0(32'h0000_0000), .MASK0(32'hFFFF_F000),
        .BASE1(32'h0200_0000), .MASK1(32'hFFFF_0000),
        .BASE2(32'h0C00_0000), .MASK2(32'hFC00_0000),
        .BASE3(32'h1000_0000), .MASK3(32'hFFFF_0000),
        .BASE4(32'h2000_0000), .MASK4(32'hFFFE_0000),
        .BASE5(32'h3000_0000), .MASK5(32'hFFFF_F000),
        .BASE6(32'h3000_1000), .MASK6(32'hFFFF_F000),
        .BASE7(32'h4000_0000), .MASK7(32'hFFFF_0000)
    ) u_dmem_xbar (
        .clk(clk), .rst_n(rst_n),
        .m_awaddr(dm_awaddr), .m_awvalid(dm_awvalid), .m_awready(dm_awready),
        .m_wdata(dm_wdata), .m_wstrb(dm_wstrb), .m_wvalid(dm_wvalid), .m_wready(dm_wready),
        .m_bresp(dm_bresp), .m_bvalid(dm_bvalid), .m_bready(dm_bready),
        .m_araddr(dm_araddr), .m_arvalid(dm_arvalid), .m_arready(dm_arready),
        .m_rdata(dm_rdata), .m_rresp(dm_rresp), .m_rvalid(dm_rvalid), .m_rready(dm_rready),

        .s0_awaddr(),.s0_awvalid(),.s0_awready(1'b1),.s0_wdata(),.s0_wstrb(),.s0_wvalid(),.s0_wready(1'b1),
        .s0_bresp(2'b0),.s0_bvalid(1'b0),.s0_bready(),.s0_araddr(),.s0_arvalid(),.s0_arready(1'b1),
        .s0_rdata(32'd0),.s0_rresp(2'b0),.s0_rvalid(1'b0),.s0_rready(),

        .s1_awaddr(clint_awaddr), .s1_awvalid(clint_awvalid), .s1_awready(clint_awready),
        .s1_wdata(clint_wdata), .s1_wstrb(clint_wstrb), .s1_wvalid(clint_wvalid), .s1_wready(clint_wready),
        .s1_bresp(clint_bresp), .s1_bvalid(clint_bvalid), .s1_bready(clint_bready),
        .s1_araddr(clint_araddr), .s1_arvalid(clint_arvalid), .s1_arready(clint_arready),
        .s1_rdata(clint_rdata), .s1_rresp(clint_rresp), .s1_rvalid(clint_rvalid), .s1_rready(clint_rready),

        .s2_awaddr(plic_awaddr), .s2_awvalid(plic_awvalid), .s2_awready(plic_awready),
        .s2_wdata(plic_wdata), .s2_wstrb(plic_wstrb), .s2_wvalid(plic_wvalid), .s2_wready(plic_wready),
        .s2_bresp(plic_bresp), .s2_bvalid(plic_bvalid), .s2_bready(plic_bready),
        .s2_araddr(plic_araddr), .s2_arvalid(plic_arvalid), .s2_arready(plic_arready),
        .s2_rdata(plic_rdata), .s2_rresp(plic_rresp), .s2_rvalid(plic_rvalid), .s2_rready(plic_rready),

        .s3_awaddr(apb_awaddr), .s3_awvalid(apb_awvalid), .s3_awready(apb_awready),
        .s3_wdata(apb_wdata), .s3_wstrb(apb_wstrb), .s3_wvalid(apb_wvalid), .s3_wready(apb_wready),
        .s3_bresp(apb_bresp), .s3_bvalid(apb_bvalid), .s3_bready(apb_bready),
        .s3_araddr(apb_araddr), .s3_arvalid(apb_arvalid), .s3_arready(apb_arready),
        .s3_rdata(apb_rdata), .s3_rresp(apb_rresp), .s3_rvalid(apb_rvalid), .s3_rready(apb_rready),

        .s4_awaddr(sram_pb_awaddr), .s4_awvalid(sram_pb_awvalid), .s4_awready(sram_pb_awready),
        .s4_wdata(sram_pb_wdata), .s4_wstrb(sram_pb_wstrb), .s4_wvalid(sram_pb_wvalid), .s4_wready(sram_pb_wready),
        .s4_bresp(sram_pb_bresp), .s4_bvalid(sram_pb_bvalid), .s4_bready(sram_pb_bready),
        .s4_araddr(sram_pb_araddr), .s4_arvalid(sram_pb_arvalid), .s4_arready(sram_pb_arready),
        .s4_rdata(sram_pb_rdata), .s4_rresp(sram_pb_rresp), .s4_rvalid(sram_pb_rvalid), .s4_rready(sram_pb_rready),

        .s5_awaddr(),.s5_awvalid(),.s5_awready(1'b1),.s5_wdata(),.s5_wstrb(),.s5_wvalid(),.s5_wready(1'b1),
        .s5_bresp(2'b0),.s5_bvalid(1'b0),.s5_bready(),.s5_araddr(),.s5_arvalid(),.s5_arready(1'b1),
        .s5_rdata(32'd0),.s5_rresp(2'b0),.s5_rvalid(1'b0),.s5_rready(),

        .s6_awaddr(trng_awaddr), .s6_awvalid(trng_awvalid), .s6_awready(trng_awready),
        .s6_wdata(trng_wdata), .s6_wstrb(trng_wstrb), .s6_wvalid(trng_wvalid), .s6_wready(trng_wready),
        .s6_bresp(trng_bresp), .s6_bvalid(trng_bvalid), .s6_bready(trng_bready),
        .s6_araddr(trng_araddr), .s6_arvalid(trng_arvalid), .s6_arready(trng_arready),
        .s6_rdata(trng_rdata), .s6_rresp(trng_rresp), .s6_rvalid(trng_rvalid), .s6_rready(trng_rready),

        .s7_awaddr(),.s7_awvalid(),.s7_awready(1'b1),.s7_wdata(),.s7_wstrb(),.s7_wvalid(),.s7_wready(1'b1),
        .s7_bresp(2'b0),.s7_bvalid(1'b0),.s7_bready(),.s7_araddr(),.s7_arvalid(),.s7_arready(1'b1),
        .s7_rdata(32'd0),.s7_rresp(2'b0),.s7_rvalid(1'b0),.s7_rready()
    );

    boot_rom u_brom (
        .clk(clk), .rst_n(rst_n),
        .s_araddr(brom_araddr), .s_arvalid(brom_arvalid), .s_arready(brom_arready),
        .s_rdata(brom_rdata), .s_rresp(brom_rresp), .s_rvalid(brom_rvalid), .s_rready(brom_rready),
        .s_awaddr(32'd0), .s_awvalid(1'b0), .s_awready(),
        .s_wdata(32'd0), .s_wstrb(4'd0), .s_wvalid(1'b0), .s_wready(),
        .s_bresp(), .s_bvalid(), .s_bready(1'b0)
    );

    sram_dp u_sram (
        .clk(clk), .rst_n(rst_n),
        .pa_araddr(sram_pa_araddr), .pa_arvalid(sram_pa_arvalid), .pa_arready(sram_pa_arready),
        .pa_rdata(sram_pa_rdata), .pa_rresp(sram_pa_rresp), .pa_rvalid(sram_pa_rvalid), .pa_rready(sram_pa_rready),
        .pa_awaddr(32'd0), .pa_awvalid(1'b0), .pa_awready(),
        .pa_wdata(32'd0), .pa_wstrb(4'd0), .pa_wvalid(1'b0), .pa_wready(),
        .pa_bresp(), .pa_bvalid(), .pa_bready(1'b0),
        .pb_araddr(sram_pb_araddr), .pb_arvalid(sram_pb_arvalid), .pb_arready(sram_pb_arready),
        .pb_rdata(sram_pb_rdata), .pb_rresp(sram_pb_rresp), .pb_rvalid(sram_pb_rvalid), .pb_rready(sram_pb_rready),
        .pb_awaddr(sram_pb_awaddr), .pb_awvalid(sram_pb_awvalid), .pb_awready(sram_pb_awready),
        .pb_wdata(sram_pb_wdata), .pb_wstrb(sram_pb_wstrb), .pb_wvalid(sram_pb_wvalid), .pb_wready(sram_pb_wready),
        .pb_bresp(sram_pb_bresp), .pb_bvalid(sram_pb_bvalid), .pb_bready(sram_pb_bready)
    );

    clint u_clint (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(clint_awaddr), .s_awvalid(clint_awvalid), .s_awready(clint_awready),
        .s_wdata(clint_wdata), .s_wstrb(clint_wstrb), .s_wvalid(clint_wvalid), .s_wready(clint_wready),
        .s_bresp(clint_bresp), .s_bvalid(clint_bvalid), .s_bready(clint_bready),
        .s_araddr(clint_araddr), .s_arvalid(clint_arvalid), .s_arready(clint_arready),
        .s_rdata(clint_rdata), .s_rresp(clint_rresp), .s_rvalid(clint_rvalid), .s_rready(clint_rready),
        .timer_irq(timer_irq), .soft_irq(soft_irq)
    );

    wire [15:0] plic_irq_src;

    plic #(.N_SRC(16)) u_plic (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(plic_awaddr), .s_awvalid(plic_awvalid), .s_awready(plic_awready),
        .s_wdata(plic_wdata), .s_wstrb(plic_wstrb), .s_wvalid(plic_wvalid), .s_wready(plic_wready),
        .s_bresp(plic_bresp), .s_bvalid(plic_bvalid), .s_bready(plic_bready),
        .s_araddr(plic_araddr), .s_arvalid(plic_arvalid), .s_arready(plic_arready),
        .s_rdata(plic_rdata), .s_rresp(plic_rresp), .s_rvalid(plic_rvalid), .s_rready(plic_rready),
        .irq_src(plic_irq_src),
        .ext_irq(ext_irq)
    );

    wire [31:0] paddr_bus;
    wire        psel0_bus, psel1_bus, psel2_bus, psel3_bus;
    wire        psel4_bus, psel5_bus, psel6_bus, psel7_bus;
    wire        penable_bus, pwrite_bus;
    wire [31:0] pwdata_bus;
    wire [3:0]  pstrb_bus;
    wire [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5, prdata6, prdata7;
    wire        pready0, pready1, pready2, pready3, pready4, pready5, pready6, pready7;

    axi_lite_apb_bridge u_apb_bridge (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(apb_awaddr), .s_awvalid(apb_awvalid), .s_awready(apb_awready),
        .s_wdata(apb_wdata), .s_wstrb(apb_wstrb), .s_wvalid(apb_wvalid), .s_wready(apb_wready),
        .s_bresp(apb_bresp), .s_bvalid(apb_bvalid), .s_bready(apb_bready),
        .s_araddr(apb_araddr), .s_arvalid(apb_arvalid), .s_arready(apb_arready),
        .s_rdata(apb_rdata), .s_rresp(apb_rresp), .s_rvalid(apb_rvalid), .s_rready(apb_rready),
        .paddr(paddr_bus), .penable(penable_bus), .pwrite(pwrite_bus),
        .pwdata(pwdata_bus), .pstrb(pstrb_bus),
        .psel0(psel0_bus), .psel1(psel1_bus), .psel2(psel2_bus), .psel3(psel3_bus),
        .psel4(psel4_bus), .psel5(psel5_bus), .psel6(psel6_bus), .psel7(psel7_bus),
        .prdata0(prdata0), .prdata1(prdata1), .prdata2(prdata2), .prdata3(prdata3),
        .prdata4(prdata4), .prdata5(prdata5), .prdata6(prdata6), .prdata7(prdata7),
        .pready0(pready0), .pready1(pready1), .pready2(pready2), .pready3(pready3),
        .pready4(pready4), .pready5(pready5), .pready6(pready6), .pready7(pready7)
    );

    wire uart0_irq;
    apb_uart u_uart0 (
        .CLK(clk),    .RSTN(rst_n),
        .PSEL(psel0_bus), .PENABLE(penable_bus), .PWRITE(pwrite_bus),
        .PADDR(paddr_bus[2:0]), .PWDATA(pwdata_bus), .PRDATA(prdata0),
        .PREADY(pready0), .PSLVERR(),
        .INT(uart0_irq),
        .OUT1N(), .OUT2N(), .RTSN(), .DTRN(),
        .CTSN(1'b1), .DSRN(1'b1), .DCDN(1'b1), .RIN(1'b1),
        .SIN(uart0_rx), .SOUT(uart0_tx)
    );

    wire uart1_irq;
    apb_uart u_uart1 (
        .CLK(clk),    .RSTN(rst_n),
        .PSEL(psel1_bus), .PENABLE(penable_bus), .PWRITE(pwrite_bus),
        .PADDR(paddr_bus[2:0]), .PWDATA(pwdata_bus), .PRDATA(prdata1),
        .PREADY(pready1), .PSLVERR(),
        .INT(uart1_irq),
        .OUT1N(), .OUT2N(), .RTSN(), .DTRN(),
        .CTSN(1'b1), .DSRN(1'b1), .DCDN(1'b1), .RIN(1'b1),
        .SIN(uart1_rx), .SOUT(uart1_tx)
    );

    wire [1:0] spi_events;
    wire       spi_irq = spi_events[1];

    apb_spi_master #(.BUFFER_DEPTH(8), .APB_ADDR_WIDTH(12)) u_spi (
        .HCLK(clk), .HRESETn(rst_n),
        .PADDR(paddr_bus[11:0]), .PWDATA(pwdata_bus), .PWRITE(pwrite_bus),
        .PSEL(psel2_bus), .PENABLE(penable_bus), .PRDATA(prdata2),
        .PREADY(pready2), .PSLVERR(),
        .events_o(spi_events),
        .spi_clk(spi_sck),
        .spi_csn0(spi_cs0_n), .spi_csn1(spi_cs1_n),
        .spi_csn2(spi_cs2_n), .spi_csn3(spi_cs3_n),
        .spi_mode(),
        .spi_sdo0(spi_mosi), .spi_sdo1(), .spi_sdo2(), .spi_sdo3(),
        .spi_sdi0(spi_miso), .spi_sdi1(1'b0), .spi_sdi2(1'b0), .spi_sdi3(1'b0)
    );

    wire i2c_irq;
    wire sda_in_w, sda_out_w, sda_oen_w;
    wire scl_in_w, scl_out_w, scl_oen_w;

    apb_i2c #(.APB_ADDR_WIDTH(12)) u_i2c (
        .HCLK(clk), .HRESETn(rst_n),
        .PADDR(paddr_bus[11:0]), .PWDATA(pwdata_bus), .PWRITE(pwrite_bus),
        .PSEL(psel3_bus), .PENABLE(penable_bus), .PRDATA(prdata3),
        .PREADY(pready3), .PSLVERR(),
        .interrupt_o(i2c_irq),
        .scl_pad_i(scl_in_w), .scl_pad_o(scl_out_w), .scl_padoen_o(scl_oen_w),
        .sda_pad_i(sda_in_w), .sda_pad_o(sda_out_w), .sda_padoen_o(sda_oen_w)
    );

    assign sda_in_w = i2c_sda;
    assign i2c_sda  = (!sda_oen_w) ? sda_out_w : 1'bz;
    assign scl_in_w = i2c_scl;
    assign i2c_scl  = (!scl_oen_w) ? scl_out_w : 1'bz;

    wire gpio_irq;
    apb_gpio #(.N_GPIO(32), .APB_ADDR_WIDTH(8)) u_gpio (
        .pclk(clk), .presetn(rst_n),
        .paddr(paddr_bus[7:0]), .psel(psel4_bus), .penable(penable_bus),
        .pwrite(pwrite_bus), .pwdata(pwdata_bus), .prdata(prdata4), .pready(pready4),
        .pslverr(),
        .gpio_pins(gpio_pins), .irq(gpio_irq)
    );

    wire [1:0] timer_irq_vec;
    wire timer_apb_irq = |timer_irq_vec;

    apb_timer #(.APB_ADDR_WIDTH(12), .TIMER_CNT(1)) u_timer (
        .HCLK(clk), .HRESETn(rst_n),
        .PADDR(paddr_bus[11:0]), .PWDATA(pwdata_bus), .PWRITE(pwrite_bus),
        .PSEL(psel5_bus), .PENABLE(penable_bus), .PRDATA(prdata5),
        .PREADY(pready5), .PSLVERR(),
        .irq_o(timer_irq_vec)
    );

    wire adc_irq;
    adc_if u_adc (
        .pclk(clk), .presetn(rst_n),
        .paddr(paddr_bus[7:0]), .psel(psel6_bus), .penable(penable_bus),
        .pwrite(pwrite_bus), .pwdata(pwdata_bus), .prdata(prdata6), .pready(pready6), .pslverr(),
        .adc_data(adc_data), .adc_eoc(adc_eoc), .adc_soc(adc_soc), .adc_ch(adc_ch), .irq(adc_irq)
    );

    assign prdata7 = 32'd0;
    assign pready7 = 1'b1;

    trng_ca u_trng (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(trng_awaddr), .s_awvalid(trng_awvalid), .s_awready(trng_awready),
        .s_wdata(trng_wdata), .s_wstrb(trng_wstrb), .s_wvalid(trng_wvalid), .s_wready(trng_wready),
        .s_bresp(trng_bresp), .s_bvalid(trng_bvalid), .s_bready(trng_bready),
        .s_araddr(trng_araddr), .s_arvalid(trng_arvalid), .s_arready(trng_arready),
        .s_rdata(trng_rdata), .s_rresp(trng_rresp), .s_rvalid(trng_rvalid), .s_rready(trng_rready),
        .alarm_n()
    );

    assign plic_irq_src = {8'b0,
                           adc_irq, i2c_irq, timer_apb_irq, gpio_irq,
                           spi_irq, 1'b0, uart1_irq, uart0_irq};

endmodule

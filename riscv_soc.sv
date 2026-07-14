`timescale 1ns/1ps

import reg_bus_pkg::*;

module riscv_soc (
    input  logic        clk,
    input  logic        rst_n,

    output logic        spi_sck,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_cs0_n,
    output logic        spi_cs1_n,
    output logic        spi_cs2_n,
    output logic        spi_cs3_n,

    output logic        uart0_tx,
    input  logic        uart0_rx,

    output logic        uart1_tx,
    input  logic        uart1_rx,

    inout  wire [31:0]  gpio_pins,

    inout  wire         i2c_sda,
    inout  wire         i2c_scl,

    input  logic [11:0] adc_data,
    input  logic        adc_eoc,
    output logic        adc_soc,
    output logic [2:0]  adc_ch
);

    // -------------------------------------------------------------------------
    // CPU memory interface signals
    // -------------------------------------------------------------------------
    logic [31:0] imem_addr, imem_rdata;
    logic        imem_req,  imem_ready;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_req,  dmem_ready;
    logic        timer_irq, soft_irq, ext_irq;

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

    // -------------------------------------------------------------------------
    // CPU → AXI-Lite adapters
    // -------------------------------------------------------------------------
    logic [31:0] im_araddr;  logic im_arvalid, im_arready;
    logic [31:0] im_rdata;   logic [1:0] im_rresp; logic im_rvalid, im_rready;

    cpu_axi_adapter #(.READ_ONLY(1)) u_imem_axi (
        .clk       (clk),        .rst_n    (rst_n),
        .cpu_addr  (imem_addr),  .cpu_wdata(32'd0),     .cpu_wstrb(4'd0),
        .cpu_req   (imem_req),   .cpu_rdata(imem_rdata),.cpu_ready(imem_ready),
        .m_araddr  (im_araddr),  .m_arvalid(im_arvalid),.m_arready(im_arready),
        .m_rdata   (im_rdata),   .m_rresp  (im_rresp),  .m_rvalid (im_rvalid),
        .m_rready  (im_rready),
        .m_awaddr  (), .m_awvalid(), .m_awready(1'b1),
        .m_wdata   (), .m_wstrb  (), .m_wvalid (), .m_wready(1'b1),
        .m_bresp   (2'b0), .m_bvalid(1'b0), .m_bready()
    );

    logic [31:0] dm_araddr;  logic dm_arvalid, dm_arready;
    logic [31:0] dm_rdata;   logic [1:0] dm_rresp; logic dm_rvalid, dm_rready;
    logic [31:0] dm_awaddr;  logic dm_awvalid, dm_awready;
    logic [31:0] dm_wdata;   logic [3:0] dm_wstrb; logic dm_wvalid, dm_wready;
    logic [1:0]  dm_bresp;   logic dm_bvalid, dm_bready;

    cpu_axi_adapter #(.READ_ONLY(0)) u_dmem_axi (
        .clk       (clk),        .rst_n    (rst_n),
        .cpu_addr  (dmem_addr),  .cpu_wdata(dmem_wdata),.cpu_wstrb(dmem_wstrb),
        .cpu_req   (dmem_req),   .cpu_rdata(dmem_rdata),.cpu_ready(dmem_ready),
        .m_araddr  (dm_araddr),  .m_arvalid(dm_arvalid),.m_arready(dm_arready),
        .m_rdata   (dm_rdata),   .m_rresp  (dm_rresp),  .m_rvalid (dm_rvalid),
        .m_rready  (dm_rready),
        .m_awaddr  (dm_awaddr),  .m_awvalid(dm_awvalid),.m_awready(dm_awready),
        .m_wdata   (dm_wdata),   .m_wstrb  (dm_wstrb),  .m_wvalid (dm_wvalid),
        .m_wready  (dm_wready),
        .m_bresp   (dm_bresp),   .m_bvalid (dm_bvalid), .m_bready (dm_bready)
    );

    // -------------------------------------------------------------------------
    // Instruction memory crossbar (read-only from CPU side)
    // Memory map:
    //   0x0000_0000 – Boot ROM     (4 KB)
    //   0x2000_0000 – SRAM port A  (read only, 128 KB)
    // -------------------------------------------------------------------------
    logic [31:0] brom_araddr;  logic brom_arvalid, brom_arready;
    logic [31:0] brom_rdata;   logic [1:0] brom_rresp; logic brom_rvalid, brom_rready;

    logic [31:0] sram_pa_araddr; logic sram_pa_arvalid, sram_pa_arready;
    logic [31:0] sram_pa_rdata;  logic [1:0] sram_pa_rresp; logic sram_pa_rvalid, sram_pa_rready;

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
        .m_wdata(32'd0),  .m_wstrb(4'd0),   .m_wvalid(1'b0), .m_wready(),
        .m_bresp(), .m_bvalid(), .m_bready(1'b0),
        .m_araddr(im_araddr), .m_arvalid(im_arvalid), .m_arready(im_arready),
        .m_rdata(im_rdata),   .m_rresp(im_rresp),     .m_rvalid(im_rvalid), .m_rready(im_rready),

        .s0_awaddr(), .s0_awvalid(), .s0_awready(1'b1),
        .s0_wdata(),  .s0_wstrb(),   .s0_wvalid(), .s0_wready(1'b1),
        .s0_bresp(2'b0), .s0_bvalid(1'b0), .s0_bready(),
        .s0_araddr(brom_araddr), .s0_arvalid(brom_arvalid), .s0_arready(brom_arready),
        .s0_rdata(brom_rdata),   .s0_rresp(brom_rresp),     .s0_rvalid(brom_rvalid), .s0_rready(brom_rready),

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
        .s4_rdata(sram_pa_rdata),   .s4_rresp(sram_pa_rresp),     .s4_rvalid(sram_pa_rvalid), .s4_rready(sram_pa_rready),

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

    // -------------------------------------------------------------------------
    // Data memory crossbar
    // Memory map:
    //   0x0200_0000 – CLINT        (64 KB)  → reg_bus via axil_to_regbus
    //   0x0C00_0000 – PLIC         (64 MB)  → reg_bus via axil_to_regbus
    //   0x1000_0000 – APB periph   (64 KB)  → AXI-Lite → APB bridge
    //   0x2000_0000 – SRAM port B  (128 KB)
    //   0x3000_1000 – TRNG         (4 KB)
    // -------------------------------------------------------------------------
    logic [31:0] clint_awaddr, clint_araddr, clint_wdata, clint_rdata;
    logic [3:0]  clint_wstrb;
    logic        clint_awvalid, clint_awready, clint_wvalid, clint_wready;
    logic [1:0]  clint_bresp;   logic clint_bvalid, clint_bready;
    logic        clint_arvalid, clint_arready;
    logic [1:0]  clint_rresp;   logic clint_rvalid, clint_rready;

    logic [31:0] plic_awaddr, plic_araddr, plic_wdata, plic_rdata;
    logic [3:0]  plic_wstrb;
    logic        plic_awvalid, plic_awready, plic_wvalid, plic_wready;
    logic [1:0]  plic_bresp;    logic plic_bvalid, plic_bready;
    logic        plic_arvalid,  plic_arready;
    logic [1:0]  plic_rresp;    logic plic_rvalid, plic_rready;

    logic [31:0] apb_awaddr, apb_araddr, apb_wdata, apb_rdata;
    logic [3:0]  apb_wstrb;
    logic        apb_awvalid, apb_awready, apb_wvalid, apb_wready;
    logic [1:0]  apb_bresp;     logic apb_bvalid, apb_bready;
    logic        apb_arvalid,   apb_arready;
    logic [1:0]  apb_rresp;     logic apb_rvalid, apb_rready;

    logic [31:0] sram_pb_awaddr, sram_pb_araddr, sram_pb_wdata, sram_pb_rdata;
    logic [3:0]  sram_pb_wstrb;
    logic        sram_pb_awvalid, sram_pb_awready, sram_pb_wvalid, sram_pb_wready;
    logic [1:0]  sram_pb_bresp;   logic sram_pb_bvalid, sram_pb_bready;
    logic        sram_pb_arvalid, sram_pb_arready;
    logic [1:0]  sram_pb_rresp;   logic sram_pb_rvalid, sram_pb_rready;

    logic [31:0] trng_awaddr, trng_araddr, trng_wdata, trng_rdata;
    logic [3:0]  trng_wstrb;
    logic        trng_awvalid, trng_awready, trng_wvalid, trng_wready;
    logic [1:0]  trng_bresp;    logic trng_bvalid, trng_bready;
    logic        trng_arvalid,  trng_arready;
    logic [1:0]  trng_rresp;    logic trng_rvalid, trng_rready;

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
        .m_wdata(dm_wdata),   .m_wstrb(dm_wstrb),     .m_wvalid(dm_wvalid),  .m_wready(dm_wready),
        .m_bresp(dm_bresp),   .m_bvalid(dm_bvalid),   .m_bready(dm_bready),
        .m_araddr(dm_araddr), .m_arvalid(dm_arvalid), .m_arready(dm_arready),
        .m_rdata(dm_rdata),   .m_rresp(dm_rresp),     .m_rvalid(dm_rvalid),  .m_rready(dm_rready),

        .s0_awaddr(),.s0_awvalid(),.s0_awready(1'b1),.s0_wdata(),.s0_wstrb(),.s0_wvalid(),.s0_wready(1'b1),
        .s0_bresp(2'b0),.s0_bvalid(1'b0),.s0_bready(),.s0_araddr(),.s0_arvalid(),.s0_arready(1'b1),
        .s0_rdata(32'd0),.s0_rresp(2'b0),.s0_rvalid(1'b0),.s0_rready(),

        .s1_awaddr(clint_awaddr), .s1_awvalid(clint_awvalid), .s1_awready(clint_awready),
        .s1_wdata(clint_wdata),   .s1_wstrb(clint_wstrb),     .s1_wvalid(clint_wvalid),  .s1_wready(clint_wready),
        .s1_bresp(clint_bresp),   .s1_bvalid(clint_bvalid),   .s1_bready(clint_bready),
        .s1_araddr(clint_araddr), .s1_arvalid(clint_arvalid), .s1_arready(clint_arready),
        .s1_rdata(clint_rdata),   .s1_rresp(clint_rresp),     .s1_rvalid(clint_rvalid),  .s1_rready(clint_rready),

        .s2_awaddr(plic_awaddr),  .s2_awvalid(plic_awvalid),  .s2_awready(plic_awready),
        .s2_wdata(plic_wdata),    .s2_wstrb(plic_wstrb),      .s2_wvalid(plic_wvalid),   .s2_wready(plic_wready),
        .s2_bresp(plic_bresp),    .s2_bvalid(plic_bvalid),    .s2_bready(plic_bready),
        .s2_araddr(plic_araddr),  .s2_arvalid(plic_arvalid),  .s2_arready(plic_arready),
        .s2_rdata(plic_rdata),    .s2_rresp(plic_rresp),      .s2_rvalid(plic_rvalid),   .s2_rready(plic_rready),

        .s3_awaddr(apb_awaddr),   .s3_awvalid(apb_awvalid),   .s3_awready(apb_awready),
        .s3_wdata(apb_wdata),     .s3_wstrb(apb_wstrb),       .s3_wvalid(apb_wvalid),    .s3_wready(apb_wready),
        .s3_bresp(apb_bresp),     .s3_bvalid(apb_bvalid),     .s3_bready(apb_bready),
        .s3_araddr(apb_araddr),   .s3_arvalid(apb_arvalid),   .s3_arready(apb_arready),
        .s3_rdata(apb_rdata),     .s3_rresp(apb_rresp),       .s3_rvalid(apb_rvalid),    .s3_rready(apb_rready),

        .s4_awaddr(sram_pb_awaddr), .s4_awvalid(sram_pb_awvalid), .s4_awready(sram_pb_awready),
        .s4_wdata(sram_pb_wdata),   .s4_wstrb(sram_pb_wstrb),     .s4_wvalid(sram_pb_wvalid),  .s4_wready(sram_pb_wready),
        .s4_bresp(sram_pb_bresp),   .s4_bvalid(sram_pb_bvalid),   .s4_bready(sram_pb_bready),
        .s4_araddr(sram_pb_araddr), .s4_arvalid(sram_pb_arvalid), .s4_arready(sram_pb_arready),
        .s4_rdata(sram_pb_rdata),   .s4_rresp(sram_pb_rresp),     .s4_rvalid(sram_pb_rvalid),  .s4_rready(sram_pb_rready),

        .s5_awaddr(),.s5_awvalid(),.s5_awready(1'b1),.s5_wdata(),.s5_wstrb(),.s5_wvalid(),.s5_wready(1'b1),
        .s5_bresp(2'b0),.s5_bvalid(1'b0),.s5_bready(),.s5_araddr(),.s5_arvalid(),.s5_arready(1'b1),
        .s5_rdata(32'd0),.s5_rresp(2'b0),.s5_rvalid(1'b0),.s5_rready(),

        .s6_awaddr(trng_awaddr),  .s6_awvalid(trng_awvalid),  .s6_awready(trng_awready),
        .s6_wdata(trng_wdata),    .s6_wstrb(trng_wstrb),      .s6_wvalid(trng_wvalid),   .s6_wready(trng_wready),
        .s6_bresp(trng_bresp),    .s6_bvalid(trng_bvalid),    .s6_bready(trng_bready),
        .s6_araddr(trng_araddr),  .s6_arvalid(trng_arvalid),  .s6_arready(trng_arready),
        .s6_rdata(trng_rdata),    .s6_rresp(trng_rresp),      .s6_rvalid(trng_rvalid),   .s6_rready(trng_rready),

        .s7_awaddr(),.s7_awvalid(),.s7_awready(1'b1),.s7_wdata(),.s7_wstrb(),.s7_wvalid(),.s7_wready(1'b1),
        .s7_bresp(2'b0),.s7_bvalid(1'b0),.s7_bready(),.s7_araddr(),.s7_arvalid(),.s7_arready(1'b1),
        .s7_rdata(32'd0),.s7_rresp(2'b0),.s7_rvalid(1'b0),.s7_rready()
    );

    // -------------------------------------------------------------------------
    // Boot ROM
    // -------------------------------------------------------------------------
    boot_rom u_brom (
        .clk(clk), .rst_n(rst_n),
        .s_araddr(brom_araddr), .s_arvalid(brom_arvalid), .s_arready(brom_arready),
        .s_rdata(brom_rdata),   .s_rresp(brom_rresp),     .s_rvalid(brom_rvalid), .s_rready(brom_rready),
        .s_awaddr(32'd0), .s_awvalid(1'b0), .s_awready(),
        .s_wdata(32'd0),  .s_wstrb(4'd0),   .s_wvalid(1'b0), .s_wready(),
        .s_bresp(), .s_bvalid(), .s_bready(1'b0)
    );

    // -------------------------------------------------------------------------
    // Dual-port SRAM
    // -------------------------------------------------------------------------
    sram_dp u_sram (
        .clk(clk), .rst_n(rst_n),
        .pa_araddr(sram_pa_araddr), .pa_arvalid(sram_pa_arvalid), .pa_arready(sram_pa_arready),
        .pa_rdata(sram_pa_rdata),   .pa_rresp(sram_pa_rresp),     .pa_rvalid(sram_pa_rvalid), .pa_rready(sram_pa_rready),
        .pa_awaddr(32'd0), .pa_awvalid(1'b0), .pa_awready(),
        .pa_wdata(32'd0),  .pa_wstrb(4'd0),   .pa_wvalid(1'b0),  .pa_wready(),
        .pa_bresp(), .pa_bvalid(), .pa_bready(1'b0),
        .pb_araddr(sram_pb_araddr), .pb_arvalid(sram_pb_arvalid), .pb_arready(sram_pb_arready),
        .pb_rdata(sram_pb_rdata),   .pb_rresp(sram_pb_rresp),     .pb_rvalid(sram_pb_rvalid), .pb_rready(sram_pb_rready),
        .pb_awaddr(sram_pb_awaddr), .pb_awvalid(sram_pb_awvalid), .pb_awready(sram_pb_awready),
        .pb_wdata(sram_pb_wdata),   .pb_wstrb(sram_pb_wstrb),     .pb_wvalid(sram_pb_wvalid), .pb_wready(sram_pb_wready),
        .pb_bresp(sram_pb_bresp),   .pb_bvalid(sram_pb_bvalid),   .pb_bready(sram_pb_bready)
    );

    // =========================================================================
    // PULP CLINT — AXI-Lite → reg_bus → clint_pulp
    // =========================================================================
    reg_req_t clint_reg_req;
    reg_rsp_t clint_reg_rsp;

    axil_to_regbus #(
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_clint_axil2reg (
        .clk       (clk),
        .rst_n     (rst_n),
        .s_awaddr  (clint_awaddr),  .s_awvalid(clint_awvalid), .s_awready(clint_awready),
        .s_wdata   (clint_wdata),   .s_wstrb  (clint_wstrb),   .s_wvalid (clint_wvalid),  .s_wready(clint_wready),
        .s_bresp   (clint_bresp),   .s_bvalid (clint_bvalid),  .s_bready (clint_bready),
        .s_araddr  (clint_araddr),  .s_arvalid(clint_arvalid), .s_arready(clint_arready),
        .s_rdata   (clint_rdata),   .s_rresp  (clint_rresp),   .s_rvalid (clint_rvalid),  .s_rready(clint_rready),
        .reg_req_o (clint_reg_req),
        .reg_rsp_i (clint_reg_rsp)
    );

    logic [1:0] clint_timer_irq;
    logic [1:0] clint_ipi;

    clint_pulp #(
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_clint (
        .clk_i      (clk),
        .rst_ni     (rst_n),
        .testmode_i (1'b0),
        .reg_req_i  (clint_reg_req),
        .reg_rsp_o  (clint_reg_rsp),
        .rtc_i      (clk),          // Use system clock as RTC; replace with slow RTC if available
        .timer_irq_o(clint_timer_irq),
        .ipi_o      (clint_ipi)
    );

    assign timer_irq = clint_timer_irq[0];
    assign soft_irq  = clint_ipi[0];

    // =========================================================================
    // PULP PLIC — AXI-Lite → reg_bus → plic_top_pulp
    // =========================================================================
    reg_req_t plic_reg_req;
    reg_rsp_t plic_reg_rsp;

    axil_to_regbus #(
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_plic_axil2reg (
        .clk       (clk),
        .rst_n     (rst_n),
        .s_awaddr  (plic_awaddr),  .s_awvalid(plic_awvalid), .s_awready(plic_awready),
        .s_wdata   (plic_wdata),   .s_wstrb  (plic_wstrb),   .s_wvalid (plic_wvalid),  .s_wready(plic_wready),
        .s_bresp   (plic_bresp),   .s_bvalid (plic_bvalid),  .s_bready (plic_bready),
        .s_araddr  (plic_araddr),  .s_arvalid(plic_arvalid), .s_arready(plic_arready),
        .s_rdata   (plic_rdata),   .s_rresp  (plic_rresp),   .s_rvalid (plic_rvalid),  .s_rready(plic_rready),
        .reg_req_o (plic_reg_req),
        .reg_rsp_i (plic_reg_rsp)
    );

    logic [15:0] plic_irq_src;

    plic_top_pulp #(
        .N_SOURCE (16),
        .N_TARGET (1),
        .MAX_PRIO (7),
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_plic (
        .clk_i        (clk),
        .rst_ni       (rst_n),
        .req_i        (plic_reg_req),
        .resp_o       (plic_reg_rsp),
        .le_i         (16'h0000),       // All sources level-triggered
        .irq_sources_i(plic_irq_src),
        .eip_targets_o(ext_irq)
    );

    // =========================================================================
    // APB bridge (AXI-Lite → APB)
    // =========================================================================
    logic [31:0] paddr_bus;
    logic        psel0_bus, psel1_bus, psel2_bus, psel3_bus;
    logic        psel4_bus, psel5_bus, psel6_bus, psel7_bus;
    logic        penable_bus, pwrite_bus;
    logic [31:0] pwdata_bus;
    logic [3:0]  pstrb_bus;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5, prdata6, prdata7;
    logic        pready0, pready1, pready2, pready3, pready4, pready5, pready6, pready7;

    axi_lite_apb_bridge u_apb_bridge (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(apb_awaddr), .s_awvalid(apb_awvalid), .s_awready(apb_awready),
        .s_wdata(apb_wdata),   .s_wstrb(apb_wstrb),     .s_wvalid(apb_wvalid),  .s_wready(apb_wready),
        .s_bresp(apb_bresp),   .s_bvalid(apb_bvalid),   .s_bready(apb_bready),
        .s_araddr(apb_araddr), .s_arvalid(apb_arvalid), .s_arready(apb_arready),
        .s_rdata(apb_rdata),   .s_rresp(apb_rresp),     .s_rvalid(apb_rvalid),  .s_rready(apb_rready),
        .paddr(paddr_bus),     .penable(penable_bus),    .pwrite(pwrite_bus),
        .pwdata(pwdata_bus),   .pstrb(pstrb_bus),
        .psel0(psel0_bus), .psel1(psel1_bus), .psel2(psel2_bus), .psel3(psel3_bus),
        .psel4(psel4_bus), .psel5(psel5_bus), .psel6(psel6_bus), .psel7(psel7_bus),
        .prdata0(prdata0), .prdata1(prdata1), .prdata2(prdata2), .prdata3(prdata3),
        .prdata4(prdata4), .prdata5(prdata5), .prdata6(prdata6), .prdata7(prdata7),
        .pready0(pready0), .pready1(pready1), .pready2(pready2), .pready3(pready3),
        .pready4(pready4), .pready5(pready5), .pready6(pready6), .pready7(pready7)
    );

    // =========================================================================
    // PULP UART0 (APB slave 0 → 0x1000_0000)
    // =========================================================================
    logic uart0_irq;
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

    // =========================================================================
    // PULP UART1 (APB slave 1 → 0x1000_1000)
    // =========================================================================
    logic uart1_irq;
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

    // =========================================================================
    // PULP SPI Master (APB slave 2 → 0x1000_2000)
    // =========================================================================
    logic [1:0] spi_events;
    logic       spi_irq;
    assign spi_irq = spi_events[1];

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

    // =========================================================================
    // PULP I2C Master (APB slave 3 → 0x1000_3000)
    // =========================================================================
    logic i2c_irq;
    logic sda_in_w, sda_out_w, sda_oen_w;
    logic scl_in_w, scl_out_w, scl_oen_w;

    apb_i2c #(.APB_ADDR_WIDTH(12)) u_i2c (
        .HCLK(clk), .HRESETn(rst_n),
        .PADDR(paddr_bus[11:0]), .PWDATA(pwdata_bus), .PWRITE(pwrite_bus),
        .PSEL(psel3_bus), .PENABLE(penable_bus), .PRDATA(prdata3),
        .PREADY(pready3), .PSLVERR(),
        .interrupt_o(i2c_irq),
        .scl_pad_i(scl_in_w), .scl_pad_o(scl_out_w), .scl_padoen_o(scl_oen_w),
        .sda_pad_i(sda_in_w), .sda_pad_o(sda_out_w), .sda_padoen_o(sda_oen_w)
    );

    assign sda_in_w  = i2c_sda;
    assign i2c_sda   = (!sda_oen_w) ? sda_out_w : 1'bz;
    assign scl_in_w  = i2c_scl;
    assign i2c_scl   = (!scl_oen_w) ? scl_out_w : 1'bz;

    // =========================================================================
    // PULP GPIO (APB slave 4 → 0x1000_4000) — APB → reg_bus → gpio_pulp
    // =========================================================================
    logic        gpio_psel, gpio_penable, gpio_pwrite, gpio_pready, gpio_pslverr;
    logic [31:0] gpio_paddr, gpio_pwdata, gpio_prdata;
    logic [3:0]  gpio_pstrb;

    assign gpio_psel    = psel4_bus;
    assign gpio_penable = penable_bus;
    assign gpio_pwrite  = pwrite_bus;
    assign gpio_paddr   = paddr_bus;
    assign gpio_pwdata  = pwdata_bus;
    assign gpio_pstrb   = pstrb_bus;
    assign prdata4      = gpio_prdata;
    assign pready4      = gpio_pready;

    reg_req_t gpio_reg_req;
    reg_rsp_t gpio_reg_rsp;

    apb_to_regbus #(
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_gpio_apb2reg (
        .pclk    (clk),
        .presetn (rst_n),
        .paddr   (gpio_paddr),
        .psel    (gpio_psel),
        .penable (gpio_penable),
        .pwrite  (gpio_pwrite),
        .pwdata  (gpio_pwdata),
        .pstrb   (gpio_pstrb),
        .prdata  (gpio_prdata),
        .pready  (gpio_pready),
        .pslverr (gpio_pslverr),
        .reg_req_o(gpio_reg_req),
        .reg_rsp_i(gpio_reg_rsp)
    );

    logic [31:0] gpio_out_w, gpio_tx_en_w, gpio_in_sync_w;
    logic        gpio_irq;

    gpio_pulp #(
        .N_GPIO   (32),
        .reg_req_t(reg_bus_pkg::reg_req_t),
        .reg_rsp_t(reg_bus_pkg::reg_rsp_t)
    ) u_gpio (
        .clk_i                (clk),
        .rst_ni               (rst_n),
        .gpio_in              (gpio_pins),
        .gpio_out             (gpio_out_w),
        .gpio_tx_en_o         (gpio_tx_en_w),
        .gpio_in_sync_o       (gpio_in_sync_w),
        .global_interrupt_o   (gpio_irq),
        .pin_level_interrupts_o(),
        .reg_req_i            (gpio_reg_req),
        .reg_rsp_o            (gpio_reg_rsp)
    );

    // Tristate GPIO pad drivers
    genvar gi;
    generate
        for (gi = 0; gi < 32; gi++) begin : gpio_pad_drv
            assign gpio_pins[gi] = gpio_tx_en_w[gi] ? gpio_out_w[gi] : 1'bz;
        end
    endgenerate

    // =========================================================================
    // PULP APB Timer (APB slave 5 → 0x1000_5000)
    // =========================================================================
    logic [1:0] timer_irq_vec;
    logic       timer_apb_irq;
    assign timer_apb_irq = |timer_irq_vec;

    apb_timer #(.APB_ADDR_WIDTH(12), .TIMER_CNT(1)) u_timer (
        .HCLK(clk), .HRESETn(rst_n),
        .PADDR(paddr_bus[11:0]), .PWDATA(pwdata_bus), .PWRITE(pwrite_bus),
        .PSEL(psel5_bus), .PENABLE(penable_bus), .PRDATA(prdata5),
        .PREADY(pready5), .PSLVERR(),
        .irq_o(timer_irq_vec)
    );

    // =========================================================================
    // ADC Interface (APB slave 6 → 0x1000_6000)
    // =========================================================================
    logic adc_irq;
    adc_if u_adc (
        .pclk(clk), .presetn(rst_n),
        .paddr(paddr_bus[7:0]), .psel(psel6_bus), .penable(penable_bus),
        .pwrite(pwrite_bus), .pwdata(pwdata_bus), .prdata(prdata6),
        .pready(pready6), .pslverr(),
        .adc_data(adc_data), .adc_eoc(adc_eoc),
        .adc_soc(adc_soc),  .adc_ch(adc_ch),
        .irq(adc_irq)
    );

    assign prdata7 = 32'd0;
    assign pready7 = 1'b1;

    // =========================================================================
    // CAMTRNG (AXI-Lite slave → 0x3000_1000)
    // =========================================================================
    trng_ca u_trng (
        .clk(clk), .rst_n(rst_n),
        .s_awaddr(trng_awaddr),  .s_awvalid(trng_awvalid), .s_awready(trng_awready),
        .s_wdata(trng_wdata),    .s_wstrb(trng_wstrb),     .s_wvalid(trng_wvalid),  .s_wready(trng_wready),
        .s_bresp(trng_bresp),    .s_bvalid(trng_bvalid),   .s_bready(trng_bready),
        .s_araddr(trng_araddr),  .s_arvalid(trng_arvalid), .s_arready(trng_arready),
        .s_rdata(trng_rdata),    .s_rresp(trng_rresp),     .s_rvalid(trng_rvalid),  .s_rready(trng_rready),
        .alarm_n()
    );

    // =========================================================================
    // PLIC interrupt source mapping
    // irq_src[0]  = uart0_irq
    // irq_src[1]  = uart1_irq
    // irq_src[2]  = (reserved)
    // irq_src[3]  = spi_irq
    // irq_src[4]  = gpio_irq
    // irq_src[5]  = timer_apb_irq  (apb_timer)
    // irq_src[6]  = i2c_irq
    // irq_src[7]  = adc_irq
    // irq_src[15:8] = reserved
    // =========================================================================
    assign plic_irq_src = {8'b0,
                           adc_irq, i2c_irq, timer_apb_irq, gpio_irq,
                           spi_irq, 1'b0, uart1_irq, uart0_irq};

endmodule

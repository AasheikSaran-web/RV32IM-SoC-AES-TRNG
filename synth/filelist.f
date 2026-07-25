// ============================================================
//  RV32IM SoC – Synthesis File List
//  Compatible with: Synopsys DC, Cadence Genus, VCS/Xcelium
//  Excludes: simulation-only behavioral models (apb_uart_beh.v)
//
//  Usage:
//    Design Compiler : read_file -format sverilog -f filelist.f
//    Genus           : read_hdl -f filelist.f
//    VCS lint        : vcs -sv -f filelist.f
// ============================================================

// ---------- Package (must be first for SV type resolution) ----------
+incdir+./rtl/pulp
./rtl/pulp/reg_bus_pkg.sv

// ---------- PULP Platform open-source IPs ----------
./rtl/pulp/apb_to_regbus.sv
./rtl/pulp/axil_to_regbus.sv

./rtl/pulp/gpio_pulp.sv
./rtl/pulp/plic_top_pulp.sv
./rtl/pulp/clint_pulp.sv

./rtl/pulp/apb_timer.sv
./rtl/pulp/timer_unit.sv

./rtl/pulp/apb_uart.sv
./rtl/pulp/uart_baudgen.sv
./rtl/pulp/uart_interrupt.sv
./rtl/pulp/uart_receiver.sv
./rtl/pulp/uart_transmitter.sv

./rtl/pulp/apb_i2c.sv
./rtl/pulp/i2c_master_defines.sv
./rtl/pulp/i2c_master_bit_ctrl.sv
./rtl/pulp/i2c_master_byte_ctrl.sv
./rtl/pulp/slib_clock_div.sv
./rtl/pulp/slib_counter.sv
./rtl/pulp/slib_edge_detect.sv
./rtl/pulp/slib_fifo.sv
./rtl/pulp/slib_input_filter.sv
./rtl/pulp/slib_input_sync.sv
./rtl/pulp/slib_mv_filter.sv

./rtl/pulp/apb_spi_master.sv
./rtl/pulp/spi_master_apb_if.sv
./rtl/pulp/spi_master_clkgen.sv
./rtl/pulp/spi_master_controller.sv
./rtl/pulp/spi_master_fifo.sv
./rtl/pulp/spi_master_rx.sv
./rtl/pulp/spi_master_tx.sv

// ---------- Custom peripherals ----------
./rtl/adc_if.v
./rtl/aes256.v
./rtl/aes_instr.v
./rtl/apb_gpio.v
./rtl/axi_lite_apb_bridge.v
./rtl/axi_lite_xbar.v
./rtl/boot_rom.v
./rtl/bscan_cell.v
./rtl/clint.v
./rtl/cpu_axi_adapter.v
./rtl/gpio.v
./rtl/i2c_master.v
./rtl/jtag_tap.v
./rtl/plic.v
./rtl/scan_wrapper.v
./rtl/spi.v
./rtl/sram_dp.v
./rtl/timer.v
./rtl/trng.v
./rtl/trng_ca.v
./rtl/uart.v

// ---------- CPU core ----------
./rtl/rv32i_cpu.v

// ---------- SoC top-level ----------
./rtl/riscv_soc.sv

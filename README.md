## RV32IM SoC with AES Custom Instructions and CAMTRNG

A synthesizable RV32IM 5-stage pipeline processor integrated into a full SoC with AES hardware acceleration (custom-0 ISA extension) and a cellular-automaton TRNG (CAMTRNG).

---

## Repository Layout

```
design/
  rv32i_cpu.v              RV32IM 5-stage pipeline (IF/ID/EX/MEM/WB), MUL/DIV, AES custom-0 decode
  riscv_soc.v              Top-level SoC: CPU + AXI crossbar + all peripherals
  rtl/
    aes_instr.v            AES custom instruction unit: aes.esb / aes.emx / aes.ks1 / aes.ks2
    trng_ca.v              CAMTRNG: ring oscillators, Von Neumann debiaser, Rule-30 CA, Toeplitz hash
    boot_rom.v             64-entry read-only boot ROM
    sram_dp.v              Dual-port SRAM (data + instruction)
    clint.v                Core-local interrupt controller (mtime, mtimecmp)
    plic.v                 Platform-level interrupt controller (8 sources, 4 priorities)
    uart.v                 UART 16550-compatible (TX/RX FIFOs, baud divider)
    spi.v                  SPI master (CPOL/CPHA 0-3, 8-bit shift, CS control)
    gpio.v                 32-bit GPIO with direction and interrupt enable
    timer.v                64-bit timer with compare and interrupt
    i2c_master.v           I2C master (START/STOP, 7-bit address, ACK)
    adc_if.v               ADC interface (SAR-style, 12-bit, APB slave)
    cpu_axi_adapter.v      CPU load/store to AXI-Lite bridge
    axi_lite_xbar.v        4-master 8-slave AXI-Lite crossbar
    axi_lite_apb_bridge.v  AXI-Lite to APB bridge
    jtag_tap.v             JTAG TAP controller (IEEE 1149.1)
    bscan_cell.v           Boundary-scan cell
    scan_wrapper.v         Full-chip scan insertion wrapper

verification/
  run_sim.sh               Master simulation script (iverilog)
  tb/
    tb_aes_instr.v         AES custom instruction unit test (22 vectors, FIPS-197 KAT)
    tb_trng_ca.v           CAMTRNG unit test (AXI-Lite, entropy quality, health monitors)
    tb_pc_gen.v            PC generation unit test
    tb_decoder.v           Instruction decoder unit test
    tb_regfile.v           Register file unit test
    tb_alu.v               ALU unit test
    tb_branch.v            Branch comparator unit test
    tb_mdu.v               Multiply/divide unit test
    tb_miu.v               Memory interface unit test
    tb_hazard.v            Hazard detection unit test
    core_sanity_tb.v       Full CPU pipeline sanity test
    riscv_soc_tb.v         Full SoC integration test

dft/
  scan_insert.tcl          Scan chain insertion script (Synopsys DC)
  atpg_script.tcl          ATPG test pattern generation script (Synopsys TetraMAX)
```

---

## How to Run Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`).

```bash
# Run all unit testbenches
./verification/run_sim.sh unit

# Run CPU pipeline sanity test
./verification/run_sim.sh sanity

# Run full SoC integration test
./verification/run_sim.sh soc

# Run everything
./verification/run_sim.sh all
```

Logs are written to `sim_logs/`. Each test prints `PASS` or `FAIL` per check, and a summary line at the end.

---

## AES Custom Instructions

| Mnemonic   | funct3 | funct7[6:5] | funct7[4:0] | Operation                              |
|------------|--------|-------------|-------------|----------------------------------------|
| aes.esb    | 000    | bs[1:0]     | 00001       | S-box lookup, result XORed into rs1    |
| aes.emx    | 000    | bs[1:0]     | 00010       | S-box + MixColumns column, XOR rs1     |
| aes.ks1    | 001    | -           | -           | Key schedule round constant + SubWord  |
| aes.ks2    | 010    | -           | -           | Key schedule XOR combine               |

---

## CAMTRNG Register Map (AXI-Lite base)

| Offset | Name   | Description                                      |
|--------|--------|--------------------------------------------------|
| 0x00   | CTRL   | [0] enable, [1] seed strobe                      |
| 0x04   | STATUS | [0] data_ready, [1] alarm, [2] rct_fail, [3] apt_fail |
| 0x08   | DATA   | 32-bit random output (read clears data_ready)    |
| 0x0C   | SEED   | CPU seed injection (XORed into CA state[31:0])   |

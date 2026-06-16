#!/bin/bash
# run_sim.sh — Compile and simulate all verification testbenches
# Requires: Icarus Verilog (iverilog) or ModelSim/Questa
# Usage: ./run_sim.sh [unit|sanity|soc|all]

set -e
PASS=0; FAIL=0
RTL=./rtl
TB=./tb
LOG=./sim_logs
mkdir -p $LOG

SIM=${SIM:-iverilog}   # set SIM=vlog for ModelSim

run_iverilog() {
    local name=$1; shift
    echo "=== Running $name ==="
    if iverilog -g2012 -o $LOG/${name}.out "$@" && vvp $LOG/${name}.out 2>&1 | tee $LOG/${name}.log; then
        # Match "  FAIL [" (actual check failure) — not "0 FAIL" in a summary line
        if grep -qE "^\s+FAIL \[|FAIL:.*=" $LOG/${name}.log; then
            echo "[RESULT] $name: SOME FAILURES"
            FAIL=$((FAIL+1))
        else
            echo "[RESULT] $name: PASSED"
            PASS=$((PASS+1))
        fi
    else
        echo "[RESULT] $name: COMPILE/RUN ERROR"
        FAIL=$((FAIL+1))
    fi
    echo ""
}

TARGET=${1:-all}

# ---------------------------------------------------------------
# Unit testbenches (self-contained models, no RTL deps)
# ---------------------------------------------------------------
if [[ $TARGET == "unit" || $TARGET == "all" ]]; then
    run_iverilog tb_pc_gen     $TB/tb_pc_gen.v
    run_iverilog tb_decoder    $TB/tb_decoder.v
    run_iverilog tb_regfile    $TB/tb_regfile.v
    run_iverilog tb_alu        $TB/tb_alu.v
    run_iverilog tb_branch     $TB/tb_branch.v
    run_iverilog tb_mdu        $TB/tb_mdu.v
    run_iverilog tb_miu        $TB/tb_miu.v
    run_iverilog tb_hazard     $TB/tb_hazard.v
    # AES custom instruction unit test (FIPS-197 known-answer vectors)
    run_iverilog tb_aes_instr  $RTL/aes_instr.v $TB/tb_aes_instr.v
    # CAMTRNG unit test (AXI-Lite, entropy quality, alarm health monitor)
    run_iverilog tb_trng_ca    $RTL/trng_ca.v $TB/tb_trng_ca.v
fi

# ---------------------------------------------------------------
# Core sanity TB (instantiates rv32i_cpu)
# ---------------------------------------------------------------
if [[ $TARGET == "sanity" || $TARGET == "all" ]]; then
    run_iverilog core_sanity   \
        $RTL/../rv32i_cpu.v    \
        $TB/core_sanity_tb.v
fi

# ---------------------------------------------------------------
# Full SoC testbench
# ---------------------------------------------------------------
if [[ $TARGET == "soc" || $TARGET == "all" ]]; then
    run_iverilog riscv_soc_tb  \
        $RTL/../rv32i_cpu.v    \
        $RTL/boot_rom.v        \
        $RTL/sram_dp.v         \
        $RTL/clint.v           \
        $RTL/plic.v            \
        $RTL/uart.v            \
        $RTL/spi.v             \
        $RTL/gpio.v            \
        $RTL/timer.v           \
        $RTL/i2c_master.v      \
        $RTL/adc_if.v          \
        $RTL/trng_ca.v         \
        $RTL/aes_instr.v       \
        $RTL/cpu_axi_adapter.v \
        $RTL/axi_lite_xbar.v   \
        $RTL/axi_lite_apb_bridge.v \
        $RTL/../riscv_soc.v    \
        $TB/riscv_soc_tb.v
fi

# ---------------------------------------------------------------
# JTAG / Scan wrapper testbench (boundary scan)
# ---------------------------------------------------------------
if [[ $TARGET == "dft" || $TARGET == "all" ]]; then
    run_iverilog jtag_tap_tb   \
        $RTL/jtag_tap.v        \
        $RTL/bscan_cell.v      \
        $RTL/scan_wrapper.v    \
        $RTL/../rv32i_cpu.v    \
        $RTL/boot_rom.v        \
        $RTL/sram_dp.v         \
        $RTL/clint.v           \
        $RTL/plic.v            \
        $RTL/uart.v            \
        $RTL/spi.v             \
        $RTL/gpio.v            \
        $RTL/timer.v           \
        $RTL/i2c_master.v      \
        $RTL/adc_if.v          \
        $RTL/trng_ca.v         \
        $RTL/aes_instr.v       \
        $RTL/cpu_axi_adapter.v \
        $RTL/axi_lite_xbar.v   \
        $RTL/axi_lite_apb_bridge.v \
        $RTL/../riscv_soc.v    \
        $TB/tb_jtag_tap.v 2>&1 | tee $LOG/dft.log || true
fi

echo "================================================"
echo "SUMMARY: $PASS passed, $FAIL failed"
echo "Logs in: $LOG/"
echo "================================================"
[[ $FAIL -eq 0 ]]

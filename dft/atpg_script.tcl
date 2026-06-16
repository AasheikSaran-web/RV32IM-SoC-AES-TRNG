# atpg_script.tcl — Tetramax ATPG Script
# Config 1: Stuck-at fault coverage targeting >95% as per DFT requirements
# Config 2: Boundary scan EXTEST via BSD Compiler (separate flow)
#
# Usage: tmax -shell -load atpg_script.tcl

# ---------------------------------------------------------------
# 0. Setup
# ---------------------------------------------------------------
set DESIGN_NAME  "riscv_soc"
set REPORT_DIR   "../dft/reports"
set PATTERN_DIR  "../dft/patterns"

file mkdir $REPORT_DIR
file mkdir $PATTERN_DIR

# ---------------------------------------------------------------
# 1. Read scan-inserted netlist and STIL test protocol
# ---------------------------------------------------------------
read_netlist  ../dft/results/${DESIGN_NAME}_scan.v -design $DESIGN_NAME
read_netlist  ../lib/stdcells_tt.v                 -library

# SPF / STIL protocol from DFT Compiler
read_spf ../dft/reports/${DESIGN_NAME}_scan.spf

run_build_model $DESIGN_NAME

# ---------------------------------------------------------------
# 2. DRC — verify protocol before ATPG
# ---------------------------------------------------------------
run_drc ../dft/reports/${DESIGN_NAME}_scan.spf
redirect ${REPORT_DIR}/atpg_drc.rpt { report_scan_cell }

# ---------------------------------------------------------------
# 3. Target fault models
# ---------------------------------------------------------------
# Primary: Stuck-at (Config 1)
add_faults -all
# Optional transition delay (comment out if not required by fab)
# add_faults -all -fault_type transition

# ---------------------------------------------------------------
# 4. ATPG — full stuck-at pattern generation
# ---------------------------------------------------------------
set_atpg -capture_cycles 2
set_atpg -fill random
set_atpg -abort_limit 100
set_atpg -pattern_filter effectiveness

run_atpg -auto_compression

# ---------------------------------------------------------------
# 5. Fault coverage report
# ---------------------------------------------------------------
report_faults -summary
redirect ${REPORT_DIR}/fault_summary.rpt   { report_faults -summary }
redirect ${REPORT_DIR}/fault_detail.rpt    { report_faults -all }

# Check coverage target (>95% for tape-out sign-off)
set fc [get_fault_coverage]
echo "Stuck-at fault coverage: ${fc}%"
if { $fc < 95.0 } {
    echo "WARNING: Fault coverage below 95% target"
} else {
    echo "PASS: Fault coverage target met"
}

# ---------------------------------------------------------------
# 6. Write patterns
# ---------------------------------------------------------------
# WGL format (for simulation validation)
write_patterns ${PATTERN_DIR}/${DESIGN_NAME}_stuck_at.wgl \
    -format wgl \
    -replace

# STIL format (for ATE)
write_patterns ${PATTERN_DIR}/${DESIGN_NAME}_stuck_at.stil \
    -format stil \
    -replace

# Verilog simulation patterns
write_patterns ${PATTERN_DIR}/${DESIGN_NAME}_stuck_at_sim.v \
    -format verilog \
    -parallel \
    -replace

# ---------------------------------------------------------------
# 7. Pattern simulation (functional verification of ATPG patterns)
# ---------------------------------------------------------------
run_simulation ${PATTERN_DIR}/${DESIGN_NAME}_stuck_at_sim.v
redirect ${REPORT_DIR}/sim_summary.rpt { report_simulation -summary }

# ---------------------------------------------------------------
# 8. Summary report
# ---------------------------------------------------------------
redirect ${REPORT_DIR}/atpg_summary.rpt {
    report_statistics
    report_scan_cell
    report_faults -summary
}

echo "ATPG complete."
echo "Patterns written to: $PATTERN_DIR"
echo "Reports written to:  $REPORT_DIR"

# ---------------------------------------------------------------
# Appendix: Boundary Scan (Config 2) — BSD Compiler flow
# Run separately with Synopsys BSD Compiler after scan_insert.tcl
# ---------------------------------------------------------------
# Steps (not executed here):
#   1. bsd_shell -f bsd_compile.tcl
#   2. read_verilog  ${DESIGN_NAME}_scan.v
#   3. read_bsdl     scan_wrapper.bsdl
#   4. verify_bsd
#   5. write_extest_patterns  -output extest.stil
#   6. run_bsd_simulation extest.stil

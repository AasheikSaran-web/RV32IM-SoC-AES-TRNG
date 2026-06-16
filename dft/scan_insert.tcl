# scan_insert.tcl — DFT Compiler Scan Insertion Script
# Config 1: Stuck-at fault scan (SNPS DFT Compiler / DC Compiler)
# Target: riscv_soc (after synthesis by Design Compiler)
#
# Usage: dc_shell -f scan_insert.tcl

# ---------------------------------------------------------------
# 0. Setup
# ---------------------------------------------------------------
set DESIGN_NAME    "riscv_soc"
set LIB_PATH       "../lib"
set NETLIST_IN     "../syn/results/${DESIGN_NAME}_syn.v"
set SDC_FILE       "../syn/constraints/${DESIGN_NAME}.sdc"
set NETLIST_OUT    "../dft/results/${DESIGN_NAME}_scan.v"
set REPORT_DIR     "../dft/reports"

file mkdir $REPORT_DIR
file mkdir "../dft/results"

# ---------------------------------------------------------------
# 1. Load technology library
# ---------------------------------------------------------------
set_app_var target_library     [list ${LIB_PATH}/stdcells_tt.db]
set_app_var link_library       [list * ${LIB_PATH}/stdcells_tt.db]
set_app_var symbol_library     [list generic.sdb]

# ---------------------------------------------------------------
# 2. Read synthesized netlist
# ---------------------------------------------------------------
read_verilog $NETLIST_IN
current_design $DESIGN_NAME
link

# ---------------------------------------------------------------
# 3. Apply timing constraints (needed for DRC-clean scan)
# ---------------------------------------------------------------
source $SDC_FILE

# ---------------------------------------------------------------
# 4. DFT Specification — Config 1 (Basic Scan / Stuck-at)
# ---------------------------------------------------------------
set_dft_signal -view existing_dft -type ScanClock -port clk -timing {45 55}
set_dft_signal -view existing_dft -type Reset      -port rst_n -active_state 0

# Dedicated scan ports brought out to top-level
set_dft_signal -view spec -type ScanDataIn  -port scan_in
set_dft_signal -view spec -type ScanDataOut -port scan_out
set_dft_signal -view spec -type ScanEnable  -port scan_en   -active_state 1

# Clock mux for scan: functional clk replaced by test clock
# (scan_wrapper already muxes clk/tck — DFT Compiler uses scan_mode port)
set_dft_signal -view spec -type TestMode    -port scan_mode  -active_state 1
set_dft_signal -view spec -type ScanClock   -port tck        -timing {45 55}

# ---------------------------------------------------------------
# 5. Scan configuration
# ---------------------------------------------------------------
set_scan_configuration \
    -style multiplexed_flip_flop \
    -chain_count 4 \
    -clock_mixing no_mix \
    -internal_clocks none

# Avoid scan stitching across clock domains
set_dft_configuration -fix_clock on
set_dft_configuration -fix_reset on
set_dft_configuration -fix_set   on

# ---------------------------------------------------------------
# 6. DFT pre-check
# ---------------------------------------------------------------
dft_drc -verbose
redirect "${REPORT_DIR}/dft_drc_pre.rpt" { dft_drc -verbose }

# ---------------------------------------------------------------
# 7. Preview scan chain assignment
# ---------------------------------------------------------------
preview_dft -show all
redirect "${REPORT_DIR}/preview_dft.rpt" { preview_dft -show all }

# ---------------------------------------------------------------
# 8. Insert scan chains
# ---------------------------------------------------------------
insert_dft

# ---------------------------------------------------------------
# 9. Post-insertion DRC
# ---------------------------------------------------------------
dft_drc -verbose
redirect "${REPORT_DIR}/dft_drc_post.rpt" { dft_drc -verbose }

# ---------------------------------------------------------------
# 10. Write scan netlist and test protocol
# ---------------------------------------------------------------
change_names -rules verilog -hierarchy
write_verilog -pg -hierarchy $NETLIST_OUT

write_scan_def  -output "${REPORT_DIR}/${DESIGN_NAME}.scandef"
write_test_protocol -test_mode InternalTest \
                    -output "${REPORT_DIR}/${DESIGN_NAME}_scan.spf"

# ---------------------------------------------------------------
# 11. Reports
# ---------------------------------------------------------------
redirect "${REPORT_DIR}/scan_chain_info.rpt" {
    report_scan_chain -show all
}
redirect "${REPORT_DIR}/scan_path.rpt" {
    report_scan_path -chain all -view all
}
redirect "${REPORT_DIR}/dft_signal.rpt" {
    report_dft_signal -view all
}

echo "Scan insertion complete. Netlist: $NETLIST_OUT"

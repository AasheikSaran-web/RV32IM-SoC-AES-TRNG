## ============================================================
##  Cadence Genus – Synthesis Script
##  Target: RV32IM SoC with AES / TRNG @ 65nm
##
##  Usage:
##    genus -legacy_ui -f synth_genus.tcl | tee synth_genus.log
## ============================================================

set TOP_MODULE   riscv_soc
set TARGET_LIB   "your_std_cell.lib"   ;# replace with your PDK .lib
set SYNTH_FREQ   500                   ;# MHz
set CLK_NAME     clk

set RESULTS_DIR  ./results
file mkdir $RESULTS_DIR

# ----- Library -----
set_db init_lib_search_path {.}
set_db library $TARGET_LIB

# ----- Read RTL -----
read_hdl -sv -f ../filelist.f
elaborate $TOP_MODULE
check_design -unresolved

# ----- Constraints -----
set CLK_PERIOD [expr {1000.0 / $SYNTH_FREQ}]
create_clock -period $CLK_PERIOD -name $CLK_NAME [get_db ports $CLK_NAME]
set_input_delay  0.3 -clock $CLK_NAME [remove_from_collection [all_inputs] [get_db ports $CLK_NAME]]
set_output_delay 0.3 -clock $CLK_NAME [all_outputs]

# ----- Synthesis -----
syn_generic
syn_map
syn_opt

# ----- Reports -----
report timing   > ${RESULTS_DIR}/timing.rpt
report area     > ${RESULTS_DIR}/area.rpt
report power    > ${RESULTS_DIR}/power.rpt
report qor      > ${RESULTS_DIR}/qor.rpt

# ----- Outputs -----
write_hdl       > ${RESULTS_DIR}/${TOP_MODULE}_netlist.v
write_sdc       > ${RESULTS_DIR}/${TOP_MODULE}.sdc

echo "Genus synthesis done. Results in $RESULTS_DIR"

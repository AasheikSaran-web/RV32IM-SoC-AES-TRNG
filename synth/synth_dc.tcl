## ============================================================
##  Synopsys Design Compiler – Synthesis Script
##  Target: RV32IM SoC with AES / TRNG @ 28nm
##
##  Usage:
##    dc_shell -f synth_dc.tcl | tee synth_dc.log
## ============================================================

# ----- User-configurable settings -----
set TOP_MODULE   riscv_soc
set TARGET_LIB   "your_28nm_std_cell.db"  ;# replace with your 28nm PDK .db
set SYNTH_FREQ   1000                     ;# MHz (28nm supports higher frequency)
set CLK_NAME     clk
set RST_NAME     rst_n

set RESULTS_DIR  ./results

# ----- Setup -----
file mkdir $RESULTS_DIR
set_app_var target_library  $TARGET_LIB
set_app_var link_library    "* $TARGET_LIB"

# ----- Read RTL -----
set_svf ${RESULTS_DIR}/${TOP_MODULE}.svf
analyze -format sverilog -vcs {-f ../filelist.f}
elaborate $TOP_MODULE

current_design $TOP_MODULE
link

# ----- Constraints -----
set CLK_PERIOD [expr {1000.0 / $SYNTH_FREQ}]
create_clock -period $CLK_PERIOD -name $CLK_NAME [get_ports $CLK_NAME]
set_dont_touch_network [get_clocks $CLK_NAME]
set_clock_uncertainty  0.1 [get_clocks $CLK_NAME]
set_input_delay  0.3 -clock $CLK_NAME [remove_from_collection [all_inputs]  [get_ports $CLK_NAME]]
set_output_delay 0.3 -clock $CLK_NAME [all_outputs]
set_driving_cell -lib_cell your_28nm_buf_cell [all_inputs]
set_load 0.02 [all_outputs]  ;# lower load cap at 28nm

# ----- Compile -----
check_design
compile_ultra -no_autoungroup

# ----- Reports -----
report_timing  -nworst 10                       > ${RESULTS_DIR}/timing.rpt
report_area                                     > ${RESULTS_DIR}/area.rpt
report_power                                    > ${RESULTS_DIR}/power.rpt
report_constraint -all_violators                > ${RESULTS_DIR}/constraints.rpt
check_design                                    > ${RESULTS_DIR}/check_design.rpt

# ----- Outputs -----
write -format verilog -hierarchy -output ${RESULTS_DIR}/${TOP_MODULE}_netlist.v
write_sdc                                         ${RESULTS_DIR}/${TOP_MODULE}.sdc
write_sdf -version 3.0                            ${RESULTS_DIR}/${TOP_MODULE}.sdf

echo "Synthesis complete. Results in $RESULTS_DIR"

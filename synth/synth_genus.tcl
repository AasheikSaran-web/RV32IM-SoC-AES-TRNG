set TOP_MODULE   riscv_soc
set TARGET_LIB   "your_28nm_std_cell.lib"
set SYNTH_FREQ   1000
set CLK_NAME     clk

set RESULTS_DIR  ./results
file mkdir $RESULTS_DIR

set_db init_lib_search_path {.}
set_db library $TARGET_LIB

read_hdl -sv -f ../filelist.f
elaborate $TOP_MODULE
check_design -unresolved

set CLK_PERIOD [expr {1000.0 / $SYNTH_FREQ}]
create_clock -period $CLK_PERIOD -name $CLK_NAME [get_db ports $CLK_NAME]
set_input_delay  0.3 -clock $CLK_NAME [remove_from_collection [all_inputs] [get_db ports $CLK_NAME]]
set_output_delay 0.3 -clock $CLK_NAME [all_outputs]

syn_generic
syn_map
syn_opt

report timing   > ${RESULTS_DIR}/timing.rpt
report area     > ${RESULTS_DIR}/area.rpt
report power    > ${RESULTS_DIR}/power.rpt
report qor      > ${RESULTS_DIR}/qor.rpt

write_hdl       > ${RESULTS_DIR}/${TOP_MODULE}_netlist.v
write_sdc       > ${RESULTS_DIR}/${TOP_MODULE}.sdc

echo "Genus synthesis done. Results in $RESULTS_DIR"


set project_root [file dirname [file normalize [info script]]]
cd $project_root
set targetDir [file join $project_root build propel]
set projectName "my_soc"
if {[info exists ::env(PROPEL_HOME)] && $::env(PROPEL_HOME) ne ""} {
    set propelRegenLsccBase [file normalize $::env(PROPEL_HOME)]
} else {
    set propel_executable [auto_execok propelbld]
    if {$propel_executable eq ""} {
        error "Cannot locate Propel Builder. Set PROPEL_HOME to the Propel installation directory."
    }
    set propelRegenLsccBase [file normalize [file join [file dirname [lindex $propel_executable 0]] .. .. .. ..]]
}

set custom_ip_dir [file join $project_root propel_ip_local rapiscan_ip_APB_register_1.0.3]
set firmware_mem [file normalize [file join $project_root riscv_mc_helloworld build riscv_mc_helloworld.mem]]
set generated_project_dir [file join $targetDir $projectName]
set generation_marker [file join $generated_project_dir .generated_by_propel_rebuild]
set generation_started_marker [file join $generated_project_dir .propel_rebuild_in_progress]

if {![file isdirectory $custom_ip_dir]} {
    error "Required local Propel IP package not found: $custom_ip_dir"
}
if {![file isfile $firmware_mem]} {
    error "SDK firmware memory image not found. Run the SDK Makefile first: $firmware_mem"
}

file mkdir $targetDir
if {[file exists $generated_project_dir]} {
    if {![file isfile $generation_marker] && ![file isfile $generation_started_marker]} {
        error "Refusing to overwrite an unmarked directory: $generated_project_dir"
    }
    file delete -force $generated_project_dir
}

if {[file exists "$targetDir"] != 1} {
    puts "$targetDir doesn't exist. Please update this setting in tcl file first."
    return
}

if {[file exists "$propelRegenLsccBase"] != 1} {
    puts "$propelRegenLsccBase doesn't exist. Please update this setting in tcl file first."
    return
}

sbp_create_project  -name "$projectName" -path "$targetDir" -device {LIFCL-17-7MG121I}  -speed {7_High-Performance_1.0V} -language {verilog} -board {NA}  -psc "$propelRegenLsccBase/templates/MachXO3D_Template01/MachXO3D_Template01.psc"
set marker_channel [open $generation_started_marker w]
puts $marker_channel "Generation started by propel_rebuild.tcl"
close $marker_channel

sbp_design save

sbp_delete "$projectName/clk_i" -type port
sbp_delete "$projectName/rstn_i" -type port



sbp_config_ip -vlnv {latticesemi.com:ip:cpu0:2.8.0}  -meta_vlnv {latticesemi.com:ip:riscv_mc:2.8.0} -cfg_value {DEBUG_ENABLE: true,  SOFT_JTAG: false,  JTAG_CHANNEL_EXTEND: false,  PIC_ENABLE: false,  TIMER_ENABLE: false}
sbp_config_ip -vlnv {latticesemi.com:ip:gpio0:1.8.0}  -meta_vlnv {latticesemi.com:ip:gpio:1.8.0} -cfg_value {IO_LINES_COUNT: 2,  EXTERNAL_BUF: false,  OUT_RESET_VAL_INPUT: 0,  DIRECTION_DEF_VAL_INPUT: 3,  IF_USER_INTF: APB}
set firmware_mem_config [format \
    {INTERFACE: AHBL, ADDR_DEPTH: 8192, MEMORY_TYPE: LRAM, PORT_COUNT: 2, INIT_MEM: true, INIT_CHK: hex, INIT_FILE_IN: %s, REGMODE_S0: true, REGMODE_S1: true} \
    [string map {\\ /} [file join riscv_mc_helloworld build riscv_mc_helloworld.mem]]]
sbp_config_ip -vlnv {latticesemi.com:ip:system0:2.4.0} -meta_vlnv {latticesemi.com:ip:system_memory:2.4.0} -cfg_value $firmware_mem_config
sbp_config_ip -vlnv {latticesemi.com:ip:uart0:1.4.0}  -meta_vlnv {latticesemi.com:ip:uart:1.4.0} -cfg_value {SYS_CLOCK_FREQ: 18.0}
sbp_config_ip -vlnv {latticesemi.com:module:ahbl0:1.4.0}  -meta_vlnv {latticesemi.com:module:ahb_lite_interconnect:1.4.0} -cfg_value {TOTAL_MASTER_CNT: 1,  TOTAL_SLAVE_CNT: 2}
sbp_config_ip -vlnv {latticesemi.com:module:ahbl2apb0:1.2.0}  -meta_vlnv {latticesemi.com:module:ahb_lite_to_apb_bridge:1.2.0} -cfg_value {APB_CLK_EN: true}
sbp_config_ip -vlnv {latticesemi.com:module:apb0:1.3.0}  -meta_vlnv {latticesemi.com:module:apb_interconnect:1.3.0} -cfg_value {TOTAL_MASTER_CNT: 1,  TOTAL_SLAVE_CNT: 3}
sbp_config_ip -vlnv {latticesemi.com:module:pll0:1.9.1}  -meta_vlnv {latticesemi.com:module:pll:1.9.1} -cfg_value {gui_refclk_freq: 18.0,  gui_fbk_mode: INTCLKOP,  gui_clk_op_freq: 54.0,  gui_clk_os_en: true,  gui_clk_os_freq: 18.0,  gui_en_pll_reset: false,  gui_pll_lock_sticky: true}
sbp_config_ip -vlnv {rapiscan:ip:APB2Fabric:1.0.3} -meta_loc $custom_ip_dir -cfg_value {}



sbp_add_component -vlnv {latticesemi.com:ip:cpu0:2.8.0} -name cpu0_inst
sbp_add_component -vlnv {latticesemi.com:ip:gpio0:1.8.0} -name gpio0_inst
sbp_add_component -vlnv {latticesemi.com:ip:system0:2.4.0} -name system0_inst
sbp_add_component -vlnv {latticesemi.com:ip:uart0:1.4.0} -name uart0_inst
sbp_add_component -vlnv {latticesemi.com:module:ahbl0:1.4.0} -name ahbl0_inst
sbp_add_component -vlnv {latticesemi.com:module:ahbl2apb0:1.2.0} -name ahbl2apb0_inst
sbp_add_component -vlnv {latticesemi.com:module:apb0:1.3.0} -name apb0_inst
sbp_add_component -vlnv {latticesemi.com:module:pll0:1.9.1} -name pll0_inst
sbp_add_component -vlnv {rapiscan:ip:APB2Fabric:1.0.3} -name APB2Fabric_inst

sbp_add_gluelogic -name expr_0_inst -logicinfo [sbp_create_glue_logic equation expr_0 {} { {
 "expr": "O = A & B",
 "module_name": "expr_0"
}
}]

sbp_add_port -direction out APB2Fabric_inst_APB_M00_penable_slv_o_port
sbp_add_port -direction in APB2Fabric_inst_APB_M00_pready_slv_i_port
sbp_add_port -direction out APB2Fabric_inst_APB_M00_pselx_slv_o_port
sbp_add_port -direction in APB2Fabric_inst_APB_M00_pslverr_slv_i_port
sbp_add_port -direction out APB2Fabric_inst_APB_M00_pwrite_slv_o_port
sbp_add_port -direction out apb_clk_o
sbp_add_port -direction out apb_resetn_o
sbp_add_port -direction in osc_clk
sbp_add_port -direction in rstn_i
sbp_add_port -direction in uart_rxd_00_i
sbp_add_port -direction out uart_txd_00_o
sbp_add_port -from 31 -to 0 -direction out APB2Fabric_inst_APB_M00_paddr_slv_o_portbus
sbp_add_port -from 31 -to 0 -direction in APB2Fabric_inst_APB_M00_prdata_slv_i_portbus
sbp_add_port -from 31 -to 0 -direction out APB2Fabric_inst_APB_M00_pwdata_slv_o_portbus
sbp_add_port -from 1 -to 0 -direction inout gpio_00_io

sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_penable_slv_o" "$projectName/APB2Fabric_inst_APB_M00_penable_slv_o_port" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_pready_slv_i" "$projectName/APB2Fabric_inst_APB_M00_pready_slv_i_port" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_pselx_slv_o" "$projectName/APB2Fabric_inst_APB_M00_pselx_slv_o_port" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_pslverr_slv_i" "$projectName/APB2Fabric_inst_APB_M00_pslverr_slv_i_port" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_pwrite_slv_o" "$projectName/APB2Fabric_inst_APB_M00_pwrite_slv_o_port" 
sbp_connect_net "$projectName/gpio0_inst/resetn_i" "$projectName/uart0_inst/rst_n_i" "$projectName/cpu0_inst/system_resetn_o" "$projectName/system0_inst/ahbl_hresetn_i" "$projectName/apb0_inst/apb_presetn_i" "$projectName/ahbl0_inst/ahbl_hresetn_i" "$projectName/ahbl2apb0_inst/rst_n_i" "$projectName/ahbl2apb0_inst/presetn_i" "$projectName/APB2Fabric_inst/rst_n_i" "$projectName/apb_resetn_o" 
sbp_connect_net "$projectName/expr_0_inst/O" "$projectName/cpu0_inst/rst_n_i" 
sbp_connect_net "$projectName/expr_0_inst/A" "$projectName/rstn_i" 
sbp_connect_net "$projectName/pll0_inst/clki_i" "$projectName/osc_clk" 
sbp_connect_net "$projectName/cpu0_inst/clk_i" "$projectName/system0_inst/ahbl_hclk_i" "$projectName/ahbl0_inst/ahbl_hclk_i" "$projectName/pll0_inst/clkop_o" "$projectName/ahbl2apb0_inst/clk_i" 
sbp_connect_net "$projectName/gpio0_inst/clk_i" "$projectName/uart0_inst/clk_i" "$projectName/apb0_inst/apb_pclk_i" "$projectName/pll0_inst/clkos_o" "$projectName/ahbl2apb0_inst/pclk_i" "$projectName/APB2Fabric_inst/clk_i" "$projectName/apb_clk_o" 
sbp_connect_net "$projectName/expr_0_inst/B" "$projectName/pll0_inst/lock_o" 
sbp_connect_net "$projectName/uart0_inst/rxd_i" "$projectName/uart_rxd_00_i" 
sbp_connect_net "$projectName/uart0_inst/txd_o" "$projectName/uart_txd_00_o" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_paddr_slv_o" "$projectName/APB2Fabric_inst_APB_M00_paddr_slv_o_portbus" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_prdata_slv_i" "$projectName/APB2Fabric_inst_APB_M00_prdata_slv_i_portbus" 
sbp_connect_net "$projectName/APB2Fabric_inst/APB_M00_pwdata_slv_o" "$projectName/APB2Fabric_inst_APB_M00_pwdata_slv_o_portbus" 
sbp_connect_net "$projectName/gpio0_inst/gpio_io" "$projectName/gpio_00_io" 

sbp_connect_interface_net "$projectName/ahbl0_inst/AHBL_M00" "$projectName/system0_inst/AHBL_S1" 
sbp_connect_interface_net "$projectName/ahbl0_inst/AHBL_M01" "$projectName/ahbl2apb0_inst/AHBL_S0" 
sbp_connect_interface_net "$projectName/ahbl2apb0_inst/APB_M0" "$projectName/apb0_inst/APB_S00" 
sbp_connect_interface_net "$projectName/apb0_inst/APB_M00" "$projectName/APB2Fabric_inst/APB_S00" 
sbp_connect_interface_net "$projectName/apb0_inst/APB_M01" "$projectName/gpio0_inst/APB_S0" 
sbp_connect_interface_net "$projectName/apb0_inst/APB_M02" "$projectName/uart0_inst/APB_S0" 
sbp_connect_interface_net "$projectName/cpu0_inst/AHBL_M0_INSTR" "$projectName/system0_inst/AHBL_S0" 
sbp_connect_interface_net "$projectName/cpu0_inst/AHBL_M1_DATA" "$projectName/ahbl0_inst/AHBL_S00" 





sbp_assign_addr_seg -offset 'h40000000 "$projectName/apb0_inst/APB_M01" "$projectName/gpio0_inst/APB_S0"
sbp_assign_addr_seg -offset 'h00000000 "$projectName/cpu0_inst/AHBL_M0_INSTR" "$projectName/system0_inst/AHBL_S0"
sbp_assign_addr_seg -offset 'h00000000 "$projectName/ahbl0_inst/AHBL_M00" "$projectName/system0_inst/AHBL_S1"
sbp_assign_addr_seg -offset 'h00009000 "$projectName/apb0_inst/APB_M02" "$projectName/uart0_inst/APB_S0"
sbp_assign_addr_seg -offset 'h00008000 "$projectName/apb0_inst/APB_M00" "$projectName/APB2Fabric_inst/APB_S00"

 
sbp_design set_strategy -name par_place_iterator -value 10
sbp_design set_strategy -name par_stop_zero -value True

sbp_design save
sbp_design generate
file delete -force $generation_started_marker
set marker_channel [open $generation_marker w]
puts $marker_channel "Generated by propel_rebuild.tcl"
close $marker_channel



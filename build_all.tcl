set project_root [file dirname [file normalize [info script]]]

proc get_install_root {environment_name default_path} {
    if {[info exists ::env($environment_name)] && $::env($environment_name) ne ""} {
        return [file normalize $::env($environment_name)]
    }
    return [file normalize $default_path]
}

proc require_file {path description} {
    if {![file isfile $path]} {
        error "$description not found: $path"
    }
}

proc run_tool {description executable script} {
    puts "\n=== $description ==="
    flush stdout
    if {[catch {exec $executable $script >@stdout 2>@stderr} message options]} {
        puts stderr "$description failed: $message"
        return -options $options $message
    }
}

set propel_home [get_install_root PROPEL_HOME "C:/lscc/propel/2025.1"]
set radiant_home [get_install_root RADIANT_HOME "C:/lscc/radiant/2025.2"]
set sdk_root [file join $propel_home sdk]
set make_executable [file join $sdk_root build_tools bin make.exe]
set propel_executable [file join $propel_home builder rtf bin nt64 propelbldc.exe]
set radiant_executable [file join $radiant_home bin nt64 radiantc.exe]
set pgr_executable [file join $radiant_home programmer bin nt64 pgrcmd.exe]
set firmware_project [file join $project_root riscv_mc_helloworld]
set firmware_makefile [file join $firmware_project Makefile]
set propel_script [file join $project_root propel_rebuild.tcl]
set radiant_script [file join $project_root radiant_setup_template.tcl]

require_file $make_executable "Propel SDK make utility"
require_file $propel_executable "Propel Builder console"
require_file $radiant_executable "Radiant console"
require_file $firmware_makefile "Firmware Makefile"
require_file $propel_script "Propel recreation script"
require_file $radiant_script "Radiant build script"

set ::env(PROPEL_HOME) $propel_home
set ::env(RADIANT_HOME) $radiant_home
cd $project_root

puts "\n=== RISC-V firmware build ==="
flush stdout
set original_directory [pwd]
cd $firmware_project
set make_status [catch {exec $make_executable all >@stdout 2>@stderr} make_message make_options]
cd $original_directory
if {$make_status} {
    puts stderr "RISC-V firmware build failed: $make_message"
    return -options $make_options $make_message
}

set firmware_mem [file join $firmware_project build riscv_mc_helloworld.mem]
require_file $firmware_mem "Generated SDK memory image"

run_tool "Propel design recreation and RTL generation" $propel_executable $propel_script

set generated_project [file join $project_root build propel my_soc]
set generated_design [file join $generated_project my_soc my_soc.sbx]
set generated_rtl [file join $generated_project my_soc my_soc.v]
set generated_marker [file join $generated_project .generated_by_propel_rebuild]
foreach generated_file [list $generated_design $generated_rtl $generated_marker] {
    require_file $generated_file "Expected Propel output"
}

run_tool "Radiant synthesis through bitstream generation" $radiant_executable $radiant_script

set bitstream [file join $project_root impl_1 my_soc_impl_1.bit]
require_file $bitstream "Radiant bitstream"
puts "\nBuild completed successfully: $bitstream"

set xcf_file ""
foreach xcf_candidate [list \
    [file join $project_root source impl_1.xcf] \
    [file join $project_root impl_1 impl_1.xcf] \
    [file join $project_root impl_1 my_soc_impl_1.xcf]] {
    if {[file isfile $xcf_candidate]} {
        set xcf_file $xcf_candidate
        break
    }
}

if {$xcf_file eq ""} {
    puts "\n=== FPGA programming skipped ==="
    puts "No .xcf programming file found (expected [file join $project_root source impl_1.xcf])."
} elseif {![file isfile $pgr_executable]} {
    puts "\n=== FPGA programming skipped ==="
    puts "Radiant Programmer executable not found: $pgr_executable"
} else {
    set pgr_log [file join $project_root impl_1 my_soc_pgr.log]
    puts "\n=== FPGA programming ==="
    puts "Using XCF file: $xcf_file"
    flush stdout
    if {[catch {exec $pgr_executable -infile $xcf_file -logfile $pgr_log >@stdout 2>@stderr} pgr_message]} {
        puts stderr "FPGA programming did not complete (FPGA or cable may be unavailable): $pgr_message"
        if {[file isfile $pgr_log]} {
            puts stderr "Programmer log: $pgr_log"
        }
    } else {
        puts "FPGA programmed successfully using: $xcf_file"
    }
}

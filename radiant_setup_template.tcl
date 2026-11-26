set project_root [file dirname [file normalize [info script]]]
set radiant_project [file join $project_root my_soc.rdf]
set builder_design_dir [file join $project_root build propel my_soc my_soc]
set device "LIFCL-17-7MG121I"
set performance "7_High-Performance_1.0V"

set source_files [list \
    [file join $builder_design_dir lib latticesemi.com ip gpio0 1.8.0 gpio0.ipx] \
    [file join $project_root my_soc my_soc_Top.v] \
    [file join $builder_design_dir lib latticesemi.com module ahbl2apb0 1.2.0 ahbl2apb0.ipx] \
    [file join $builder_design_dir lib latticesemi.com ip cpu0 2.8.0 cpu0.ipx] \
    [file join $builder_design_dir my_soc.v] \
    [file join $builder_design_dir lib latticesemi.com module apb0 1.3.0 apb0.ipx] \
    [file join $builder_design_dir lib latticesemi.com ip system0 2.4.0 system0.ipx] \
    [file join $builder_design_dir lib rapiscan ip APB2Fabric 1.0.3 APB2Fabric.ipx] \
    [file join $builder_design_dir lib latticesemi.com ip uart0 1.4.0 uart0.ipx] \
    [file join $builder_design_dir lib latticesemi.com module ahbl0 1.4.0 ahbl0.ipx] \
    [file join $builder_design_dir lib latticesemi.com module pll0 1.9.1 pll0.ipx]]

foreach source_file $source_files {
    if {![file isfile $source_file]} {
        error "Required Radiant source file not found: $source_file"
    }
}

set registered_sources {}
if {[file isfile $radiant_project]} {
    set project_channel [open $radiant_project r]
    set project_xml [read $project_channel]
    close $project_channel

    set project_without_reveal [regsub -all \
        {(?s)[ \t]*<Source name="[^"]+"[^>]*type_short="(Reveal|RVA)"[^>]*>.*?</Source>[ \t]*\r?\n?} \
        $project_xml "\n"]
    if {$project_without_reveal ne $project_xml} {
        set project_channel [open $radiant_project w]
        puts -nonewline $project_channel $project_without_reveal
        close $project_channel
        set project_xml $project_without_reveal
        puts "Removed Reveal debugger and analyzer sources from the project."
    }

    foreach {element source_name} [regexp -all -inline {<Source name="([^"]+)"} $project_xml] {
        lappend registered_sources [file normalize [file join $project_root $source_name]]
    }
}

cd $project_root
if {[file isfile $radiant_project]} {
    prj_open $radiant_project
    prj_set_device -part $device -performance $performance
} else {
    prj_create -name "my_soc" -impl "impl_1" -dev $device \
        -performance $performance -synthesis "synplify"
}

set normalized_sources {}
foreach source_file $source_files {
    lappend normalized_sources [file normalize $source_file]
}

foreach registered_source $registered_sources {
    if {[file extension $registered_source] eq ".ipx" || [file tail $registered_source] eq "my_soc.v"} {
        if {[lsearch -exact $normalized_sources $registered_source] < 0} {
            prj_remove_source $registered_source
        }
    }
}

foreach source_file $source_files {
    set normalized_source [file normalize $source_file]
    if {[lsearch -exact $registered_sources $normalized_source] < 0} {
        prj_add_source $source_file
    }
}

prj_save
puts "Running synthesis, map, place-and-route, and bitstream generation..."
prj_run_bitstream -forceAll

set bitstream [file join $project_root impl_1 my_soc_impl_1.bit]
if {![file isfile $bitstream]} {
    error "Radiant completed without producing the expected bitstream: $bitstream"
}
puts "Bitstream generated: $bitstream"

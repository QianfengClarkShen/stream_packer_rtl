proc findFiles { basedir pattern } {
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}
    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
        lappend fileList $fileName
    }
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        set subDirList [findFiles $dirName $pattern]
        if { [llength $subDirList] > 0 } {
            foreach subDirFile $subDirList {
                lappend fileList $subDirFile
            }
        }
    }
    return $fileList
}

set script_dir [file dirname [info script]]
set rtl_dir [file normalize $script_dir/../rtl]

read_verilog -library xil_defaultlib -sv [findFiles $rtl_dir "*.sv"]

for {set bytes_in 4} {$bytes_in <= 64} {set bytes_in [expr ${bytes_in}*2]} {
    for {set bytes_out 4} { $bytes_out <= 64} {set bytes_out [expr ${bytes_out}*2]} {
        synth_design -top stream_packer -part xcvu37p-fsvh2892-2L-e -mode out_of_context -define BYTES_IN=$bytes_in -define BYTES_OUT=$bytes_out
        report_utilization -file in_${bytes_in}_out_${bytes_out}.rpt
    }
}

exit
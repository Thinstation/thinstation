# WHen script is sourced, the variable $dir must contain the
# full path name of this file's directory.

if {$::tcl_platform(os) eq "Windows NT"} {
    namespace eval twapi {
        variable version 1.1
        # Patch level is a period or letter followed by a number (like Tcl)
        # . - release, a - alpha, b - beta
        variable patchlevel .5
    }
    package ifneeded twapi $twapi::version [list source [file join $dir twapi.tcl]]
}

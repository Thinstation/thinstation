namespace eval ::dnd {
    proc _load {dir} {
	set version 1.0
	load [file join $dir libtkdnd1.0.so] tkdnd
	source [file join $dir tkdnd.tcl]
	package provide tkdnd 1.0
	rename ::dnd::_load {}
    }
}

package ifneeded tkdnd 1.0  [list ::dnd::_load $dir]

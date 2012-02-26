if {[catch {package require Tcl 8.2}]} return
package ifneeded Tktable 2.9  [list load [file join $dir Tktable29.dll] Tktable]

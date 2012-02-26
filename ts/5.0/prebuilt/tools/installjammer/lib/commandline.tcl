## $Id$
##
## BEGIN LICENSE BLOCK
##
## Copyright (C) 2002  Damon Courtney
## 
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## version 2 as published by the Free Software Foundation.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License version 2 for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the
##     Free Software Foundation, Inc.
##     51 Franklin Street, Fifth Floor
##     Boston, MA  02110-1301, USA.
##
## END LICENSE BLOCK

proc ::InstallJammer::AddDefaultCommandLineOptions {} {
    SafeArraySet ::InstallJammer::InstallCommandLineOptions {
        debug { Debugging Switch Yes No {}
            "run installer in debug mode"
        }

        debugconsole { ShowConsole Switch Yes No {}
            "run installer with a debug console open"
        }

        mode { InstallMode Choice No No {Console Default Silent Standard}
            "set the mode to run the installer in"
        }

        test { Testing Switch Yes No {}
            "run installer without installing any files"
        }

        prefix { InstallDir String No No {}
            "set the installation directory"
        }
    }

    SafeArraySet ::InstallJammer::UninstallCommandLineOptions {
        debug { Debugging Switch Yes No {}
            "run uninstaller in debug mode"
        }

        debugconsole { ShowConsole Switch Yes No {}
            "run uninstaller with a debug console open"
        }

        mode { UninstallMode Choice No No {Console Silent Standard}
            "set the mode to run the uninstaller in"
        }

        test { Testing Switch Yes No {}
            "run uninstaller without uninstalling any files"
        }
    }
}

proc ::InstallJammer::ClearCommandLineOptions {} {
    global widg

    unset -nocomplain ::InstallJammer::InstallCommandLineOptions
    unset -nocomplain ::InstallJammer::UninstallCommandLineOptions

    $widg(InstallCommandLineOptionsTable)   clear
    $widg(UninstallCommandLineOptionsTable) clear
}

proc ::InstallJammer::LoadCommandLineOptions {} {
    global widg

    if {[info exists widg(InstallCommandLineOptionsTable)]} {
        variable ::InstallJammer::InstallCommandLineOptions

        set table $widg(InstallCommandLineOptionsTable)

        $table clear

        foreach option [lsort [array names InstallCommandLineOptions]] {
            set values [list $option]
            foreach x $InstallCommandLineOptions($option) {
                lappend values $x
            }
            $table insert end root #auto -values $values
        }
    }

    if {[info exists widg(UninstallCommandLineOptionsTable)]} {
        variable ::InstallJammer::UninstallCommandLineOptions

        set table $widg(UninstallCommandLineOptionsTable)

        $table clear

        foreach option [lsort [array names UninstallCommandLineOptions]] {
            set values [list $option]
            foreach x $UninstallCommandLineOptions($option) {
                lappend values $x
            }
            $table insert end root #auto -values $values
        }
    }
}

proc ::InstallJammer::GetCommandLineOptionData { args } {
    global widg

    array set _args {
        -build        0
        -includedebug 1
    }
    array set _args $args

    if {![info exists _args(-setup)]} {
        return -code error "must specify -setup"
    }

    set setup $_args(-setup)

    upvar #0 ::InstallJammer::${setup}CommandLineOptions options

    if {[info exists widg(${setup}CommandLineOptionsTable)]} {
        set table $widg(${setup}CommandLineOptionsTable)
        foreach row [eval [list $table get items] [$table items root]] {
            set debug [lindex $row 3]
            if {!$_args(-includedebug) && $debug} { continue }
            set CommandLineOptions([lindex $row 0]) [lrange $row 1 end]
        }
    } else {
        foreach option [array names options] {
            set debug [lindex $options($option) 2]
            if {!$_args(-includedebug) && $debug} { continue }
            set CommandLineOptions($option) $options($option)
        }
    }

    if {$_args(-build)} {
        return [ReadableArrayGet CommandLineOptions \
                    ::InstallJammer::CommandLineOptions]
    } else {
        return [ReadableArrayGet CommandLineOptions \
                    ::InstallJammer::${setup}CommandLineOptions]
    }
}

proc ::InstallJammer::NewCommandLineOption { table } {
    ## Option VirtualText Type Debug Hide Values Description
    set values [list {} {} "Switch" "No" "No" {} {}]

    set item [$table insert end root #auto -values $values]

    $table see item $item
    $table edit start $item 0

    Modified
}

proc ::InstallJammer::DeleteCommandLineOption { table } {
    eval [list $table delete] [$table selection get]
    Modified
}

proc ::InstallJammer::EditStartCommandLine { table item col } {
    return 1
}

proc ::InstallJammer::EditFinishCommandLine { table item col } {
    variable ::InstallJammer::CommandLineOptions

    if {$col == 0} {
        set old [$table get value $item 0]
        set new [string trimleft [string trim [$table edit editvalue]] /-]

        set options [lsearch -all -exact [$table get col 0] $new]
        if {$new ne $old && [llength $options] > 0} {
            ::InstallJammer::Error -message \
                "An option with that name already exists."
            $table edit cancel
            return 1
        }

        $table edit editvalue $new
    }

    return 1
}

proc ::InstallJammer::EditCommandLineOptionChoices { table item } {
    set ::TMP [$table edit editvalue]

    ::editor::new -title "Editing Command Line Option Choices" -variable ::TMP

     $table edit editvalue [string trim $::TMP]
     ClearTmpVars

     set entry [$table edit entrypath]
     $entry selection range 0 end
     after idle [list focus $entry]
}

proc ::InstallJammer::EditCommandLineOptionDescription { table item } {
    set ::TMP [$table edit editvalue]
    ::editor::new -title "Editing Command Line Option Description" \
        -variable ::TMP
    $table edit editvalue [string trim $::TMP]
    ClearTmpVars

    set entry [$table edit entrypath]
    $entry selection range 0 end
    after idle [list focus $entry]
}

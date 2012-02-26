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

proc CheckRunStatus {} {
    global conf

    if {!$conf(cmdline)} {
        if {![info exists ::tk_patchLevel]} {
            puts "InstallJammer must be run in a graphical environment."
            exit 1
        }

        return
    }

    ## We're running in command-line mode.

    ::InstallJammer::CommonInit

    if {$conf(windows)} {
        ## Windows needs to load BWidgets for the message dialogs.
        package require BWidget 2.0
        BWidget::use png
        BWidget::use ttk
        set ::BWidget::iconLibrary InstallJammerIcons
        SetIconTheme
    }

    ## Open the file passed in.
    Open [lindex $::argv end]

    ## Build the installer.
    ::InstallJammer::CommandLineBuild
}

## ::InstallJammer::CommandLineBuild
##
##    Do a little bit of setup before calling the InstallJammer Build
##    procedure.
##
proc ::InstallJammer::CommandLineBuild {} {
    global conf
    global info

    ::Build

    if {$conf(buildAndTest)} {
        set platform       [::InstallJammer::Platform]
        set info(Platform) $platform

        set executable [::InstallJammer::SubstText [$platform get Executable]]
        set executable [InstallDir output/$executable]
	if {![file exists $executable]} {
            ::InstallJammer::Message -title Error \
                -message "Could not find install executable to test."
	} else {
	    if {!$conf(silent)} {
                set msg "Testing $executable"
                if {$conf(testInTestMode)} {
                    append msg " without installing files"
                }
                append msg "..."
                BuildLog $msg
            }

            if {$conf(testInTestMode)} {
                exec $executable --test &
            } else {
                exec $executable &
            }
	}
    }

    ::exit [expr {$conf(totalBuildErrors) > 0}]
}

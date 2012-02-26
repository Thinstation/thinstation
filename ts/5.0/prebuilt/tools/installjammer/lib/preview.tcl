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

namespace eval ::InstallJammer {}
namespace eval ::InstallJammer::preview {}

proc ::InstallJammer::PreviewWindow { id } {
    global conf
    global info
    global widg

    ::InstallJammer::SaveActiveComponent

    if {[$id is action]} { set id [$id parent] }

    set setup [$id setup]

    if {![info exists conf(PreviewInterp)]} {
        ::InstallJammer::preview::Initialize
    }

    set interp $conf(PreviewInterp)

    ## Do some cleanup from the last preview.  Destroy the wizard
    ## so that it can be recreated and then destroy any install
    ## components we may have created last time.
    $interp eval {
        if {[info exists info(Wizard)]} {
            destroy $info(Wizard)
        }

        foreach obj [::itcl::find objects -class InstallComponent] {
            itcl::delete object $obj
        }
    }

    foreach file [ThemeFiles $setup] {
        $interp eval [list source [::InstallJammer::ThemeFile $setup $file]]
    }

    ## Source in the init for the install.  We'll use this to
    ## create the wizard.
    set installdir [::InstallJammer::ThemeDir $setup]
    $interp eval [list source [file join $installdir init.tcl]]

    $interp eval [list set ::id $id]
    set opts [$id serialize]
    lappend opts -parent [list]
    $interp eval [list eval InstallComponent $id $opts]

    ## Add any actions that are AddWidget components.  We
    ## want to preview the window with the widgets the user
    ## has added.
    foreach child [$id children] {
        if {[$child component] eq "AddWidget"} {
            set opts [$child serialize]
            lappend opts -parent $id
            $interp eval [list eval InstallComponent $child $opts]
        }
    }

    $interp eval [list array set info [array get info]]

    set platform [::InstallJammer::Platform]
    foreach var $conf(PlatformVars) {
        if {[$platform get $var value]} {
            $interp eval [list set info($var) $value]
        }
    }

    set prop ::InstallJammer::Properties
    $interp eval [list array set $prop [array get $prop]]

    $interp eval [::InstallJammer::GetTextData -build 1 -setups $setup]
    $interp eval ::InstallJammer::InitText

    set pane [$id component]
    variable ::InstallJammer::panes
    foreach img [$panes($pane) images] {
        set file [::InstallJammer::SubstText [$id get $img]]

        if {[file pathtype $file] eq "relative"} {
            ## The image file's path is relative.  Look for it
            ## first in our project directory and then in the
            ## InstallJammer Images/ directory.
            if {[file exists [file join $info(ProjectDir) $file]]} {
                set file [file join $info(ProjectDir) $file]
            } elseif {[file exists [file join $conf(pwd) Images $file]]} {
                set file [file join $conf(pwd) Images $file]
            }
        }

        if {$conf(windows)} { set file [string tolower $file] }

        $interp eval [list set images($id,$img) $file]

	if {![file exists $file]} {
	    $interp eval [list image create photo $file]
	} else {
	    $interp eval [list image create photo $file -file $file]
	}
    }

    $interp eval [read_file [::InstallJammer::GetPaneSourceFile $id]]

    foreach include [$panes($pane) includes] {
        if {[info exists panes($include)]} {
            set setup [$panes($include) setup]
            set file [::InstallJammer::ThemeFile $setup $include.tcl]
            $interp eval [read_file $file]
        }
    }

    $interp eval {
        ## Setup some default information for previews.
        array set info {
            Language                    "en"

            InstallType                 "Custom"

            Errors                      "Error messages go here."

            GuiMode                     1

            SpaceRequired               0

            FileBeingInstalled          "some file.txt"
            FileBeingInstalledText      "Installing some file.txt"

            GroupBeingInstalled         "Program Files"
            GroupBeingInstalledText     "Installing Program Files..."

            FileBeingUninstalled        "some file.txt"
            FileBeingUninstalledText    "Removing some file.txt"

            GroupBeingUninstalled       "files"
            GroupBeingUninstalledText   "Removing files..."
        }

        if {[$id setup] eq "Install"} {
            set info(Status) <%FileBeingInstalledText%>
        } else {
            set info(Status) <%FileBeingUninstalledText%>
        }

        ThemeInit

        $info(Wizard) configure -autobuttons 0
        ::InstallJammer::CenterWindow $info(Wizard)

        bind $info(Wizard) <<WizardCancel>> ::InstallJammer::preview::Done
        bind $info(Wizard) <<WizardFinish>> ::InstallJammer::preview::Done

        if {[$id is window]} {
            set top .[$id name]
            if {[winfo exists $top]} { destroy $top }
        }

        if {[$info(Wizard) exists $id]} {
            $info(Wizard) delete $id
        }

        if {[catch { ::InstallJammer::CreateWindow $info(Wizard) $id 1 } win]} {
            ::InstallJammer::MessageBox -title "Error creating preview" \
                -message "Error creating preview window: $::errorInfo"
        }

        ## Execute any AddWidget actions.
        ::InstallJammer::ExecuteActions $id -conditions 0 -type AddWidget

        if {[$id is window]} {
            set top $win

            if {[winfo exists $top]} {
                wm protocol $top WM_DELETE_WINDOW {
                    ::InstallJammer::preview::Done
                }
                bind $top <1> "::InstallJammer::preview::Done; break"
            }

            wm deiconify $top

            ::InstallJammer::UpdateWidgets -step $id -buttons 0
        } else {
            $info(Wizard) raise $id
            $info(Wizard) show
            set top $info(Wizard)
            ::InstallJammer::UpdateWidgets -step $id
        }

        if {[winfo exists $top]} {
            foreach c [Children $top] {
                ## Animate any progress bars in the pane.
                switch -glob -- [string tolower [winfo class $c]] {
                    "*progress*" {
                        ::InstallJammer::preview::AnimateProgressBar $c 0
                    }

                    "*scrollbar*" { continue }
                }

                catch { $c configure -command ::InstallJammer::preview::Done }
            }
        }

        if {[winfo exists $top]} {
            raise $top
            tkwait variable ::InstallJammer::preview::Done
        }

        $id destroy
    } ;## $interp eval
}

proc ::InstallJammer::preview::AnimateProgressBar { path {percent 0} } {
    if {$percent > 100} { set percent 0 }

    if {[winfo exists $path]} {
        $path configure -value $percent
        after 10 [lreplace [info level 0] end end [incr percent]]
    }
}

proc ::InstallJammer::preview::Initialize {} {
    global conf
    global info

    set conf(PreviewInterp) [interp create]
    set interp $conf(PreviewInterp)

    interp alias $interp puts {} puts

    $interp eval [list set ::InstallJammer 1]
    $interp eval [list set ::auto_path $::auto_path]

    $interp eval [list source [file join [info library] init.tcl]]

    $interp eval {
        package require installkit
        package require Tk
        package require tile
	package require Itcl
        package require BWidget

        if {$::tcl_platform(platform) eq "unix"} { tile::setTheme jammer }

        BWidget::use png
        BWidget::use ttk
    }

    foreach file {common.tcl installapi.tcl utils.tcl preview.tcl install.tcl} {
        $interp eval [list source [file join $conf(lib) $file]]
    }

    ## Source in action procs.
    $interp eval [BuildActionsData Install 0]
    $interp eval [BuildActionsData Uninstall 0]
    
    ## Source in all the Common files.
    foreach file [ThemeFiles Common] {
        $interp eval [list source [::InstallJammer::ThemeFile Common $file]]
    }

    $interp eval [list array set info [array get info]]

    $interp eval [list set conf(lib) $conf(lib)]

    set platform [::InstallJammer::Platform]
    foreach var $conf(PlatformVars) {
        if {[$platform get $var value]} {
            $interp eval [list set info($var) $value]
        }
    }

    $interp eval {
        set ::BWidget::iconLibrary InstallJammerIcons
        SetIconTheme

        wm withdraw .

        ThemeSetup

        set ::info(InstallID) "InstallID"

        proc ::InstallJammer::InitText {} {}

        unset ::InstallJammer
        ::InstallJammer::CommonInit
        set ::InstallJammer 1

        set info(Wizard) .wizard
    }
}

proc ::InstallJammer::preview::Done { args } {
    if {[$::id is window]} { destroy $::win }
    destroy $::info(Wizard)

    if {[::InstallJammer::CommandExists ::CreateWindow.$::id]} {
        rename ::CreateWindow.$::id ""
    }

    if {[::InstallJammer::CommandExists ::CreateWindow.[$::id component]]} {
        rename ::CreateWindow.[$::id component] ""
    }

    set ::InstallJammer::preview::Done 1
}

proc ::InstallJammer::preview::Cleanup {} {
    global conf

    if {[info exists conf(PreviewInterp)]} {
        interp delete $conf(PreviewInterp)
        unset conf(PreviewInterp)
    }
}

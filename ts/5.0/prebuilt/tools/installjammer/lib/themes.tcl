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

proc ::InstallJammer::ThemeDir { {file ""} } {
    global conf
    global info

    variable ::InstallJammer::themes

    ## See if the ThemeDir stored in the install is good.
    set dir $info(ThemeDir)
    if {[file pathtype $info(ThemeDir)] eq "relative"} {
        set dir [file join $conf(pwd) Themes $info(ThemeDir)]
    }

    if {![file exists $dir] && [info exists themes($info(Theme))]} {
        ## Grab the default directory for this theme.
        set dir $themes($info(Theme))
    }

    if {![file exists $dir]} {
        set name [join [split $info(Theme) _] " "]
        return -code error "Cannot find theme directory for $name theme"
    }

    if {[string length $file]} { set dir [file join $dir $file] }

    if {$conf(windows) && [file exists $dir]} {
        set dir [file attributes $dir -longname]
    }

    return $dir
}

proc ::InstallJammer::LoadThemeConfig { arrayName } {
    upvar 1 $arrayName array
    set themefile [::InstallJammer::ThemeDir theme.cfg]
    if {![file exists $themefile]} { return 0 }

    array set array [read_file $themefile]
    return 1
}

proc LoadTheme { args } {
    global conf
    global info
    global widg

    variable ::InstallJammer::theme
    variable ::InstallJammer::panes

    if {![::InstallJammer::LoadThemeConfig theme]} {
        ::InstallJammer::Error -message "Cannot find theme directory"
        return 0
    }

    if {[info exists theme(Width)]} {
        SafeSet info(WizardWidth) $theme(Width)
    }
    if {[info exists theme(Height)]} {
        SafeSet info(WizardHeight) $theme(Height)
    }

    set themedir [::InstallJammer::ThemeDir]

    set conf(ThemeDir) $themedir

    unset -nocomplain panes
    unset -nocomplain conf(PaneList,Install)
    unset -nocomplain conf(PaneList,Uninstall)

    ::InstallJammer::DeletePaneObjects

    ::InstallJammer::DeleteWindowProcs

    foreach setup $conf(ThemeDirs) {
        set directory [file join $themedir $setup]
        set ::InstallJammer::loadtheme::setup    $setup
        set ::InstallJammer::loadtheme::setupdir $setup
        
        foreach file [glob -nocomplain -directory $directory *.pane] {
            set ::InstallJammer::loadtheme::deffile $file
            set ::InstallJammer::loadtheme::tclfile [file root $file].tcl
            namespace eval ::InstallJammer::loadtheme [read_file $file]
        }

        set common [file join $themedir Common]
        foreach file [glob -nocomplain -directory $common *.pane] {
            set ::InstallJammer::loadtheme::setupdir Common
            set ::InstallJammer::loadtheme::deffile $file
            set ::InstallJammer::loadtheme::tclfile [file root $file].tcl
            namespace eval ::InstallJammer::loadtheme [read_file $file]
        }

        unset -nocomplain sort
        unset -nocomplain order
        foreach pane $conf(PaneList,$setup) {
            set obj $panes($pane)
            lappend sort([$obj order]) $pane
        }

        foreach i [lsort -real [array names sort]] {
            eval lappend order $sort($i)
        }

        set conf(PaneList,$setup) $order

        if {[info exists widg(${setup}PanesMenu)]} {
            $widg(${setup}PanesMenu) delete 0 end

            foreach pane $conf(PaneList,$setup) {
                set id    $panes($pane)
                set types [$id installtypes]
                if {[lsearch -exact $types "Common"] > -1} { continue }
                $widg(${setup}PanesMenu) add command -label [$id title] \
                    -command [list ::InstallJammer::AddPane $setup $pane]
            }
        }
    }

    set projectdir [file dirname $info(ProjectFile)]

    foreach dir [list $themedir $projectdir] {
        ::InstallJammer::LoadMessages -dir $dir

        set file [file join $dir theme.tcl]
        if {[file exists $file]} { uplevel #0 source [list $file] }

        foreach subdir $conf(ThemeSourceDirs) {
            set directory [file join $dir $subdir]

            set file [file join $directory defaults.tcl]
            if {[file exists $file]} { uplevel #0 source [list $file] }
        }
    }

    return 1
}

proc ::InstallJammer::loadtheme::Pane { name title {preview 1} } {
    global conf

    variable pane
    variable active
    variable tclfile
    variable deffile
    variable setup
    variable setupdir
    variable actioncount 0

    lappend conf(PaneList,$setup) $name

    set pane [::InstallJammer::Pane ::#auto \
        -title $title -name $name -parent Standard -preview $preview]

    $pane setup   $setupdir
    $pane deffile $deffile
    $pane tclfile $tclfile

    set active pane

    return $pane
}

proc ::InstallJammer::loadtheme::Window { name title {preview 1} } {
    set obj [::InstallJammer::loadtheme::Pane $name $title $preview]
    $obj property Toplevel hidden Toplevel Yes
}

proc ::InstallJammer::loadtheme::Property { name type pretty 
                                          {value ""} {choices ""} } {
    variable pane
    $pane property $name $type $pretty $value $choices
}

proc ::InstallJammer::loadtheme::Text { name {pretty ""} {subst 1} } {
    variable pane
    if {[lempty $pretty]} { set pretty $name }
    $pane text $name $pretty $subst
}

proc ::InstallJammer::loadtheme::Condition { name args } {
    variable pane
    variable active
    $pane condition $active $name $args
}

proc ::InstallJammer::loadtheme::File { filename } {
    variable pane
    $pane file $filename
}

proc ::InstallJammer::loadtheme::Help { property text } {
    variable pane
    $pane help $property $text
}

proc ::InstallJammer::loadtheme::InstallTypes { args } {
    variable pane
    $pane configure -installtypes $args
}

proc ::InstallJammer::loadtheme::Action { name args } {
    variable pane
    variable actioncount
    variable active action[incr0 actioncount]
    $pane action $name $args
}

proc ::InstallJammer::loadtheme::Order { order } {
    variable pane
    $pane configure -order $order
}

proc ::InstallJammer::loadtheme::Include { args } {
    variable pane
    eval $pane includes $args
}

proc ::InstallJammer::loadtheme::proc { name arguments body } {
    if {![string match "::*" $name]} { set name ::$name }
    ::proc $name $arguments $body
}

proc ThemeFiles { setup } {
    global conf
    set dir [file join $conf(ThemeDir) $setup]

    set files [list setup.tcl init.tcl main.tcl utils.tcl]

    set list [list]
    foreach file $files {
        set filename [file join $dir $file]
        if {[file exists $filename]} { lappend list $file }
    }

    return $list
}

proc ::InstallJammer::ThemeFile { setup filename } {
    set file [InstallDir Theme/$setup/$filename]
    if {[file exists $file]} { return $file }

    return [::InstallJammer::ThemeDir [file join $setup $filename]]
}

proc RestoreThemeWindows {} {
    global conf
    global info
    global widg

    Status "Restoring theme windows..."
    update idletasks

    set theme [file join $conf(pwd) Themes $info(Theme)]
    foreach setup $conf(ThemeDirs) {
	set windows [file join $theme $setup windows.tcl]
	if {![file exists $windows]} { return }
	file copy -force $windows $info(ProjectDir)
	namespace eval ::InstallJammer::preview [read_file $windows]
    }
    set item [$widg(DialogTree) selection get]
    if {![lempty $item]} { ::Dialogs::raise $item }
    Modified

    Status "Done restoring theme windows." 3000
    update idletasks
}

proc RestoreTheme { {option ""} } {
    global conf
    global info
    global widg

    if {$option != "-new"} {
	Status "Restoring original theme..."
	update idletasks
    }

    set ans no
    if {[string equal $option "-save"]} { set ans yes }
    if {[string equal $option "-prompt"]} {
	set parent $widg(InstallJammer)
	set ans [tk_messageBox -type yesnocancel \
	    -title "Restore Theme" -parent $parent -message \
	    "Do you want to keep your current settings for this install?"]
	if {[string equal $ans "cancel"]} { return }
    }
    set save [string equal $ans "yes"]

    set theme [file join $conf(pwd) Themes $info(Theme)]
    set info(ThemeDir) $theme

    foreach dir $conf(ThemeSourceDirs) {
	set projectdir [file join $info(ProjectDir) $dir]
	if {![file exists $projectdir]} { file mkdir $projectdir }

	foreach file [glob -nocomplain -types f [file join $theme $dir *]] {
	    file copy -force $file [file join $info(ProjectDir) $dir]
	}
    }

    if {!$save} {
        foreach dir $conf(ThemeDirs) {
            set dir [file join $info(ProjectDir) $dir]
            file delete -force [file join $dir windows.tcl]
            file delete -force [file join $dir defaults.tcl]
            foreach file [glob -nocomplain -dir $dir *.msg] {
                file delete -force $file
            }
        }
    }

    Modified

    if {![string equal $option "-noload"] && ![string equal $option "-new"]} {
	LoadTheme $info(ProjectDir)
    }

    if {![string equal $option "-new"]} {
	Status "Done restoring original theme." 3000
	update idletasks
    }
}

proc SaveTheme {} {
    global conf
    global info
    
    Status "Saving new theme..."
    update idletasks

    ClearTmpVars

    set top [::InstallJammer::TopName .__save_theme]

    toplevel     $top
    wm withdraw  $top
    update idletasks
    wm geometry  $top 240x100
    wm title     $top "Save New Theme"
    wm protocol  $top WM_DELETE_WINDOW "set ::TMP 0"
    wm resizable $top 0 0
    ::InstallJammer::CenterWindow $top 240 100

    set b [Buttons $top \
    	-okcmd "set ::TMP 1" \
    	-cancelcmd "set ::TMP 0" \
    	-helpcmd "Help SaveTheme"]

    pack [frame $top.sp1 -height 5]

    label $top.l -text "New Theme Name:"
    pack  $top.l -anchor w

    ENTRY $top.e -width 40 -textvariable ::TMPARRAY(theme)
    pack  $top.e -anchor w
    focus $top.e
    $top.e icursor end

    pack [frame $top.sp2 -height 20]

    bind $top <Key-Return> "$b.ok invoke"

    if {![::InstallComponents::Dialog $top]} { return }

    set theme [join $::TMPARRAY(theme) _]

    if {[lempty $theme]} { return }

    set themedir [file join $conf(pwd) Themes $theme]

    if {[file exists $themedir]} {
	tk_messageBox -title "Theme Exists" -message \
	    "That theme already exists."
	return
    }

    foreach setup $conf(ThemeDirs) {
	set dir [file join $themedir $setup]
	file mkdir $dir

	foreach file [ThemeFiles $setup] {
	    file copy [file join $info(ProjectDir) $setup $file] $dir	
	}
    }

    Status "Done saving new theme." 3000
    update idletasks
}

proc ::InstallJammer::ThemeList {} {
    global conf
    global preferences

    variable ::InstallJammer::themes

    if {![array exists themes]} {
        if {[string length $preferences(CustomThemeDir)]} {
            lappend dirs $preferences(CustomThemeDir)
        }
        lappend dirs [file join $conf(pwd) Themes]

        foreach dir $dirs {
            foreach themedir [glob -nocomplain -type d -dir $dir *] {
                set name [file tail $themedir]
                set file [file join $themedir theme.cfg]
                if {[file exists $file] && ![info exists themes($name)]} {
                    set themes($name) $themedir
                }
            }
        }

        if {![array exists themes]} {
            ::InstallJammer::MessageBox -title "No Themes" \
                -message "Could not locate any install themes!"
            ::exit
        }
    }

    return [lsort [array names themes]]
}

proc ::InstallJammer::DeletePaneObjects {} {
    eval ::itcl::delete object \
        [::itcl::find object -class ::InstallJammer::Pane]
}

proc ::InstallJammer::DeleteWindowProcs {} {
    foreach proc [info commands CreateWindow.*] {
        rename $proc ""
    }
}

proc ::InstallJammer::GetPaneSourceFile { id {ext .tcl} } {
    set setup [$id setup]

    set file [InstallDir Theme/$setup/$id$ext]
    if {[file exists $file]} { return $file }

    return [[$id object] tclfile]
}

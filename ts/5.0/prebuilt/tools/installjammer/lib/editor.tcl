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

namespace eval ::editor { 
    variable base .editor
    variable varName ""
    variable textBox ""

proc new { args } {
    global conf
    global info
    global widg
    global preferences

    variable base
    variable result
    variable varName
    variable textBox $base.middle.text

    variable lang     ""
    variable lastlang ""

    array set _args {
        -text            ""
        -font            "TkTextFont"
        -title           "Editor"
        -command         ""
        -variable        ""

        -language        "English"
        -languages       0
        -languagecommand ""
    }
    array set _args $args

    set varName $_args(-variable)

    toplevel     $base
    wm withdraw  $base
    wm transient $base $widg(InstallJammer)
    wm title     $base $_args(-title)
    wm protocol  $base WM_DELETE_WINDOW ::editor::cancel

    set geometry [::InstallJammer::GetWindowGeometry Editor 400x300]
    wm geometry $base $geometry
    if {$geometry eq "400x300"} { ::InstallJammer::CenterWindow $base 400 300 }

    bind $base <Escape>         ::editor::cancel
    bind $base <Control-Return> ::editor::ok

    frame $base.top -height 24

    WinButton $base.top.cut -image [GetImage editcut16] \
	-command "::edit::cut $textBox"
    pack $base.top.cut -side left
    DynamicHelp::register $base.top.cut balloon Cut

    WinButton $base.top.copy -image [GetImage editcopy16] \
	-command "::edit::copy $textBox"
    pack $base.top.copy -side left
    DynamicHelp::register $base.top.copy balloon Copy

    WinButton $base.top.paste -image [GetImage editpaste16] \
	-command "::edit::paste $textBox"
    pack $base.top.paste -side left
    DynamicHelp::register $base.top.paste balloon Paste

    WinButton $base.top.delete -image [GetImage editdelete16] \
	-command "::edit::delete $textBox"
    pack $base.top.delete -side left
    DynamicHelp::register $base.top.delete balloon Delete

    WinButton $base.top.undo -image [GetImage actundo16] \
        -command "::edit::undo $textBox"
    pack $base.top.undo -side left
    DynamicHelp::register $base.top.undo balloon Undo

    WinButton $base.top.redo -image [GetImage actredo16] \
        -command "::edit::redo $textBox"
    pack $base.top.redo -side left
    DynamicHelp::register $base.top.redo balloon Redo

    Separator $base.top.sp1 -orient vertical -relief ridge
    pack $base.top.sp1 -side left -fill y -pady 4 -padx 4

    WinButton $base.top.import -image [GetImage fileopen16] \
	-command ::editor::import
    pack $base.top.import -side left
    DynamicHelp::register $base.top.import balloon "Import a File"

    if {$_args(-languages)} {
        set ::editor::lang $_args(-language)
        set ::editor::lastlang $_args(-language)

        Separator $base.top.sp2 -orient vertical -relief ridge
        pack $base.top.sp1 -side left -fill y -pady 4 -padx 4

        ::ttk::combobox $base.top.lang \
            -state readonly -textvariable ::editor::lang \
            -values [concat All [::InstallJammer::GetLanguages]]
        pack $base.top.lang -side left

        bind $base.top.lang <<ComboboxSelected>> $_args(-languagecommand)
    }

    WinButton $base.top.cancel -image [GetImage buttoncancel16] \
	-command ::editor::cancel
    pack $base.top.cancel -side right
    DynamicHelp::register $base.top.cancel balloon "Cancel Changes"

    WinButton $base.top.ok -image [GetImage buttonok16] \
	-command ::editor::ok
    pack $base.top.ok -side right
    DynamicHelp::register $base.top.ok balloon "Save Changes"

    ScrolledWindow $base.middle
    text $base.middle.text -undo 1 -font $_args(-font)
    $base.middle setwidget $textBox

    bind $base.middle.text <Control-Return> "::editor::ok; break"
    bind $base.middle.text <<Selection>> [list ::editor::AdjustSelection]

    pack $base.top -fill x
    pack $base.middle -expand 1 -fill both

    if {[string length $_args(-variable)]} {
        upvar #0 $_args(-variable) var
        if {[info exists var]} { $textBox insert 1.0 $var }
    } else {
        $textBox insert 1.0 $_args(-text)
    }

    $textBox edit reset
    $textBox edit modified 0

    focus $textBox

    AdjustSelection

    wm deiconify $base

    raise $base

    BWidget::grab set $base

    tkwait window $base

    return $result
}

proc language { {language ""} } {
    if {[string length $language]} {
        set ::editor::lastlang $::editor::lang
        set ::editor::lang $language
    }
    return $::editor::lang
}

proc lastlanguage {} {
    if {[info exists ::editor::lastlang]} { return $::editor::lastlang }
}

proc settext { text } {
    variable textBox
    variable varName

    if {[string length $varName]} { set $varName $text }

    $textBox delete 1.0 end
    $textBox insert 1.0 $text

    $textBox edit reset
    $textBox edit modified 0

    focus $textBox

    AdjustSelection
}

proc gettext {} {
    variable textBox
    $textBox get 1.0 end
}

proc modified {} {
    variable textBox
    $textBox edit modified
}

proc cancel {} {
    global preferences

    variable base
    variable textBox

    variable result 0

    if {[$textBox edit modified]} {
        set ans [::InstallJammer::MessageBox \
            -type yesnocancel -title "Text Modified" \
            -message "Text has been modified.  Do you want to save changes?"]

        if {$ans eq "cancel"} {
            focus $textBox
            return
        }

        if {$ans eq "yes"} { return [ok] }
    }

    set preferences(Geometry,Editor) [wm geometry $base]

    destroy $base
}

proc ok {} {
    global preferences

    variable base
    variable varName
    variable textBox

    variable result 1

    upvar #0 $varName var
    set var [string range [$textBox get 1.0 end] 0 end-1]

    set preferences(Geometry,Editor) [wm geometry $base]

    destroy $base
}

proc import {} {
    variable base
    variable textBox
    set file [mpi_getOpenFile -parent $base]
    if {[lempty $file]} { return }

    ## If anything is selected, we're replacing the selection with the imported
    ## file.  Delete the selection first.
    set sel [$textBox tag ranges sel]
    if {![lempty $sel]} { eval $textBox delete $sel }

    $textBox insert insert [read_file $file]
}

proc AdjustSelection {} {
    variable base
    variable textBox

    if {[lempty [::edit::curselection $textBox]]} {
	$base.top.cut    configure -state disabled
	$base.top.copy   configure -state disabled
	$base.top.delete configure -state disabled
    } else {
	$base.top.cut    configure -state normal
	$base.top.copy   configure -state normal
	$base.top.delete configure -state normal
    }
}

} ; ## namespace eval ::editor

namespace eval ::edit {

proc ::edit::cut {w} {
    if {![string length $w]} { return }
    ::edit::copy $w
    ::edit::delete $w
}

proc ::edit::copy {w} {
    if {![string length $w]} { return }
    clipboard clear
    clipboard append [::edit::curselection $w]
}

proc ::edit::paste {w} {
    if {![string length $w]} { return }
    ::edit::delete $w
    $w insert insert [clipboard get]
}

proc ::edit::delete {w} {
    if {![string length $w]} { return }
    catch { $w delete sel.first sel.last }
}

proc ::edit::selectall {w} {
    if {![string length $w]} { return }
    switch -- [winfo class $w] {
	"Entry" {
	    $w selection range 0 end
	}

	"Text" {
	    if {![lempty [curselection $w]]} {
		eval $w tag remove sel [$w tag ranges sel]
	    }
	    $w tag add sel 1.0 end
	}
    }
}

proc ::edit::undo {w} {
    if {![string length $w]} { return }
    catch { $w edit undo }
}

proc ::edit::redo {w} {
    if {![string length $w]} { return }
    catch { $w edit redo }
}

proc ::edit::curselection {w} {
    if {![string length $w]} { return }
    switch -- [winfo class $w] {
	"Entry" {
	    if {![$w selection present]} { return }
	    set idx1 [$w index sel.first]
	    set idx2 [$w index sel.last]
	    set text [string range [$w get] $idx1 $idx2]
	}

	"Text" {
	    if {[catch {$w get sel.first sel.last} text]} { return }
	}
    }
    return $text
}

} ; ## namespace eval ::editor

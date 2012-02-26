# ----------------------------------------------------------------------------
#  dialog.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: dialog.tcl,v 1.13 2003/10/20 21:23:52 damonc Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#     - Dialog::create
#     - Dialog::configure
#     - Dialog::cget
#     - Dialog::getframe
#     - Dialog::add
#     - Dialog::itemconfigure
#     - Dialog::itemcget
#     - Dialog::invoke
#     - Dialog::setfocus
#     - Dialog::enddialog
#     - Dialog::draw
#     - Dialog::withdraw
#     - Dialog::_destroy
# ----------------------------------------------------------------------------

namespace eval Dialog {
    Widget::define Dialog dialog ButtonBox

    Widget::bwinclude Dialog ButtonBox .bbox \
        remove {
            -orient -background
        } initialize {
            -spacing 10 -padx 10
        }

    Widget::declare Dialog {
        {-background    Color    "SystemButtonFace" 0}
        {-title         String   ""      0}
	{-geometry      String   ""      0}
        {-modal         Enum     local   0 {none local global}}
        {-bitmap        String   ""      1}
        {-image         String   ""      1}
        {-separator     Boolean  0       1}
        {-cancel        Int      -1      0 "%d >= -1"}
        {-parent        String   ""      0}
        {-side          Enum     bottom  1 {bottom left top right}}
        {-anchor        Enum     c       1 {n e w s c}}
	{-class         String   Dialog  1}
        {-transient     Boolean  1       1}
        {-place         Enum     center  1 {none center left right above below}}
        {-placerelative Boolean  1       1}

        {-bg            Synonym  -background}
    }

    if {![BWidget::using ttk]} {
        Widget::addmap Dialog "" :cmd   {-background {}}
        Widget::addmap Dialog "" .frame {-background {}}
    }

    bind Dialog <Destroy> [list Dialog::_destroy %W]
}


# ----------------------------------------------------------------------------
#  Command Dialog::create
# ----------------------------------------------------------------------------
proc Dialog::create { path args } {
    Widget::initArgs Dialog $args maps

    # Check to see if the -class flag was specified
    array set _args $maps(Dialog)
    set class "Dialog"
    if {[info exists _args(-class)]} { set class $_args(-class) }

    if {[string equal $::tcl_platform(platform) "unix"]} {
	set re raised
	set bd 1
    } else {
	set re flat
	set bd 0
    }
    toplevel $path -relief $re -borderwidth $bd -class $class \
        -background $::BWidget::colors(SystemButtonFace)
    wm protocol $path WM_DELETE_WINDOW [list Dialog::cancel $path]

    Widget::initFromODB Dialog $path $maps(Dialog)

    bindtags $path [list $path $class all]
    wm overrideredirect $path 1
    wm title $path [Widget::cget $path -title]

    set parent [Widget::getoption $path -parent]
    if {![winfo exists $parent]} {
        set parent [winfo parent $path]
        if {$parent ne "."} { Widget::setoption $path -parent $parent }
    }

    if {[Widget::getoption $path -transient]} {
	wm transient $path [winfo toplevel $parent]
    }
    wm withdraw $path

    set side [Widget::cget $path -side]
    if {[string equal $side "left"] || [string equal $side "right"]} {
        set orient vertical
    } else {
        set orient horizontal
    }

    eval [list ButtonBox::create $path.bbox] $maps(.bbox) -orient $orient
    set frame [frame $path.frame -relief flat -borderwidth 0]

    set opts [list]

    if {![BWidget::using ttk]} {
        set bg [$path cget -background]
        lappend opts -background $bg
        $path configure -background $bg
        $frame configure -background $bg
    }

    if {[set bitmap [Widget::getoption $path -image]] != ""} {
        eval [list label $path.label -image $bitmap] $opts
    } elseif {[set bitmap [Widget::getoption $path -bitmap]] != ""} {
        eval [list label $path.label -bitmap $bitmap] $opts
    }
    if {[Widget::getoption $path -separator]} {
        eval [list Separator::create $path.sep -orient $orient] $opts
    }

    Widget::getVariable $path data
    set data(nbut)     0
    set data(realized) 0

    bind $path <Return> [list Dialog::ok $path]
    bind $path <Escape> [list Dialog::cancel $path]

    return [Widget::create Dialog $path]
}


# ----------------------------------------------------------------------------
#  Command Dialog::configure
# ----------------------------------------------------------------------------
proc Dialog::configure { path args } {
    set res [Widget::configure $path $args]

    if { [Widget::hasChanged $path -title title] } {
        wm title $path $title
    }
    if { [Widget::hasChanged $path -background bg] } {
        if { [winfo exists $path.label] } {
            $path.label configure -background $bg
        }
        if { [winfo exists $path.sep] } {
            Separator::configure $path.sep -background $bg
        }
    }
    return $res
}


# ----------------------------------------------------------------------------
#  Command Dialog::cget
# ----------------------------------------------------------------------------
proc Dialog::cget { path option } {
    return [Widget::cget $path $option]
}


# ----------------------------------------------------------------------------
#  Command Dialog::getframe
# ----------------------------------------------------------------------------
proc Dialog::getframe { path } {
    return $path.frame
}


# ----------------------------------------------------------------------------
#  Command Dialog::add
# ----------------------------------------------------------------------------
proc Dialog::add { path args } {
    Widget::getVariable $path data

    set idx $data(nbut)
    set cmd [list ButtonBox::add $path.bbox \
		 -command [list Dialog::enddialog $path $idx]]
    set res [eval $cmd -value $idx $args]
    incr data(nbut)
    return $res
}


# ----------------------------------------------------------------------------
#  Command Dialog::itemconfigure
# ----------------------------------------------------------------------------
proc Dialog::itemconfigure { path index args } {
    return [eval [list ButtonBox::itemconfigure $path.bbox $index] $args]
}


# ----------------------------------------------------------------------------
#  Command Dialog::itemcget
# ----------------------------------------------------------------------------
proc Dialog::itemcget { path index option } {
    return [ButtonBox::itemcget $path.bbox $index $option]
}


# ----------------------------------------------------------------------------
#  Command Dialog::invoke
# ----------------------------------------------------------------------------
proc Dialog::invoke { path index } {
    ButtonBox::invoke $path.bbox $index
}


# ----------------------------------------------------------------------------
#  Command Dialog::setfocus
# ----------------------------------------------------------------------------
proc Dialog::setfocus { path index } {
    ButtonBox::setfocus $path.bbox $index
}


# ----------------------------------------------------------------------------
#  Command Dialog::enddialog
# ----------------------------------------------------------------------------
proc Dialog::enddialog { path result {destroy 0} } {
    Widget::getVariable $path data

    if {$result ne -1} {
        if {[ButtonBox::index $path.bbox $result] > -1} {
            set result [ButtonBox::itemcget $path.bbox $result -value]
        }
    }

    set data(result) $result

    event generate $path <<DialogEnd>>

    if {$destroy} {
        destroy $path
    }

    return $result
}


# ----------------------------------------------------------------------------
#  Command Dialog::draw
# ----------------------------------------------------------------------------
proc Dialog::draw { path {focus ""} {overrideredirect 0} {geometry ""} } {
    Widget::getVariable $path data

    set parent [Widget::getoption $path -parent]
    if {!$data(realized)} {
        set data(realized) 1
        if {[llength [winfo children $path.bbox]]} {
            set side [Widget::getoption $path -side]
            if {[string equal $side "left"] || [string equal $side "right"]} {
                set pad  -padx
                set fill y
            } else {
                set pad  -pady
                set fill x
            }

            pack $path.bbox -side $side \
                -anchor [Widget::getoption $path -anchor] -padx 1m -pady {5 10}

            if {[winfo exists $path.sep]} {
                pack $path.sep -side $side -fill $fill $pad 2m
            }
        }

        if {[winfo exists $path.label]} {
            pack $path.label -side left -anchor n -padx {10 5} -pady 3m
        }

        pack $path.frame -padx 1m -pady 1m -fill both -expand yes
    }

    if {![string length $geometry]} {
        set geometry [Widget::getoption $path -geometry]
    }

    set width    0
    set height   0
    set place    [Widget::getoption $path -place]
    set usePlace [expr ![string equal $place "none"]]
    if {[string length $geometry]} {
        set split [split $geometry x+-]

        ## If the list is greater than 2 elements, we were given
        ## X and Y coordinates, so we don't want to place the window.
        if {[llength $split] > 2} {
            set usePlace 0
        } else {
            BWidget::lassign $split width height
        }
    }

    wm geometry $path $geometry

    if {$usePlace} {
        set relative [Widget::getoption $path -placerelative]
        if {$relative && [winfo exists $parent]} {
            BWidget::place $path $width $height $place $parent
        } else {
            BWidget::place $path $width $height $place
        }
    }

    update idletasks
    wm overrideredirect $path $overrideredirect
    wm deiconify $path

    # patch by Bastien Chevreux (bach@mwgdna.com)
    # As seen on Windows systems *sigh*
    # When the toplevel is withdrawn, the tkwait command will wait forever.
    #  So, check that we are not withdrawn
    if {![winfo exists $parent] || \
        ([wm state [winfo toplevel $parent]] != "withdrawn")} {
	tkwait visibility $path
    }

    BWidget::focus set $path
    if {[winfo exists $focus]} {
        focus -force $focus
    } else {
        ButtonBox::setfocus $path.bbox default
    }

    if {[set grab [Widget::cget $path -modal]] != "none"} {
        BWidget::grab $grab $path
        set res [Dialog::wait $path]
        withdraw $path
        return $res
    }
}


proc Dialog::wait { path } {
    Widget::getVariable $path data

    if {[info exists data(result)]} { unset data($result) }

    tkwait variable [Widget::widgetVar $path data(result)]
    if {[info exists data(result)]} {
        set res $data(result)
        unset data(result)
    } else {
        set res -1
    }

    return $res
}


# ----------------------------------------------------------------------------
#  Command Dialog::withdraw
# ----------------------------------------------------------------------------
proc Dialog::withdraw { path } {
    BWidget::grab release $path
    BWidget::focus release $path
    if {[winfo exists $path]} {
        wm withdraw $path
    }
}


proc Dialog::ok { path } {
    ButtonBox::invoke $path.bbox default
}


proc Dialog::cancel { path } {
    ButtonBox::invoke $path.bbox [Widget::getoption $path -cancel]
}


# ----------------------------------------------------------------------------
#  Command Dialog::_destroy
# ----------------------------------------------------------------------------
proc Dialog::_destroy { path } {
    BWidget::grab  release $path
    BWidget::focus release $path
    Widget::destroy $path
}

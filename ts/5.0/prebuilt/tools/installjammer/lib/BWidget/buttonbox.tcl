# ----------------------------------------------------------------------------
#  buttonbox.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - ButtonBox::create
#     - ButtonBox::configure
#     - ButtonBox::cget
#     - ButtonBox::add
#     - ButtonBox::itemconfigure
#     - ButtonBox::itemcget
#     - ButtonBox::setfocus
#     - ButtonBox::invoke
#     - ButtonBox::index
#
#   Private Commands:
#     - ButtonBox::_redraw
# ----------------------------------------------------------------------------

namespace eval ButtonBox {
    Widget::define ButtonBox buttonbox Button

    namespace eval Button {
        Widget::declare ButtonBox::Button {
            {-tags              String    ""            0}
            {-hide              Boolean   0             0}
            {-value             String    ""            0}
            {-spacing           Int       -1            0 "%d >= -1"}
        }
    }

    if {[BWidget::using ttk]} {
        Widget::tkinclude ButtonBox ttk::frame :cmd \
            remove { -class -colormap -container -padx -pady -visual }
    } else {
        Widget::tkinclude ButtonBox frame :cmd \
            remove { -class -colormap -container -padx -pady -visual }
    }

    Widget::declare ButtonBox {
        {-orient      Enum       horizontal 0 {horizontal vertical}}
        {-state       Enum       "normal"   0 {disabled normal}}
        {-homogeneous Boolean    1          0}
        {-spacing     Int        10         0 "%d >= 0"}
        {-padx        Int        1          0}
        {-pady        Int        1          0}
        {-default     String     -1         0} 
        {-rows        Int        "0"        0}
        {-columns     Int        "0"        0}
    }

    bind ButtonBox <Map>     [list ButtonBox::_realize %W]
    bind ButtonBox <Destroy> [list ButtonBox::_destroy %W]
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::create
# ----------------------------------------------------------------------------
proc ButtonBox::create { path args } {
    Widget::initArgs ButtonBox $args maps

    if {[BWidget::using ttk]} {
        eval [list ttk::frame $path -class ButtonBox] $maps(:cmd)
    } else {
        eval [list frame $path -class ButtonBox] $maps(:cmd)
    }

    Widget::initFromODB ButtonBox $path $maps(ButtonBox)

    # For 8.4+ we don't want to inherit the padding
    if {![BWidget::using ttk]
        && [info tclversion] >= 8.4} { $path configure -padx 0 -pady 0 }

    Widget::getVariable $path data

    set data(max)      0
    set data(nbuttons) 0
    set data(realized) 0
    set data(buttons)  [list]
    set data(widgets)  [list]
    set data(default)  [Widget::getoption $path -default]

    return [Widget::create ButtonBox $path]
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::configure
# ----------------------------------------------------------------------------
proc ButtonBox::configure { path args } {
    Widget::getVariable $path data

    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -default val]} {
        _select_default $path
    }

    if {[Widget::hasChanged $path -state val]} {
	foreach i $data(buttons) {
	    $path.b$i configure -state $val
	}
    }

    set opts [list -rows -columns -orient -homogeneous]
    if {[eval [list Widget::anyChangedX $path] $opts]} { _redraw $path }

    return $res
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::cget
# ----------------------------------------------------------------------------
proc ButtonBox::cget { path option } {
    return [Widget::cget $path $option]
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::add -- (Deprecated.  Use ButtonBox::insert end)
# ----------------------------------------------------------------------------
proc ButtonBox::add { path args } {
    return [eval insert $path end $args]
}


proc ButtonBox::insert { path idx args } {
    Widget::getVariable $path data
    Widget::getVariable $path tags

    set but $path.b$data(nbuttons)

    set class Button
    if {[BWidget::using ttk]} { set class TTKButton }
    array set maps [Widget::splitArgs $args $class ButtonBox::Button]

    Widget::init ButtonBox::Button $but#bbox $maps(ButtonBox::Button)

    set spacing [Widget::getOption -spacing -1 $but#bbox $path]

    ## Save the current spacing setting for this button.  Buttons
    ## appended to the end of the box have their spacing applied
    ## to their left while all other have their spacing applied
    ## to their right.
    if {[string equal $idx "end"] && $data(nbuttons)} {
	set data(spacing,$data(nbuttons)) [list left $spacing]
        lappend data(widgets) $but
	lappend data(buttons) $data(nbuttons)
    } else {
	set data(spacing,$data(nbuttons)) [list right $spacing]
        set data(widgets) [linsert $data(widgets) $idx $but]
        set data(buttons) [linsert $data(buttons) $idx $data(nbuttons)]
    }

    set opts [list]
    if {![BWidget::using ttk]} {
        lappend opts -padx [Widget::getoption $path -padx]
        lappend opts -pady [Widget::getoption $path -pady]
    }

    eval [list Button::create $but] $opts $maps(:cmd) $maps($class)

    foreach tag [Widget::getoption $but#bbox -tags] {
        lappend tags($tag) $but
        if {![info exists tags($tag,state)]} { set tags($tag,state) 1 }
    }

    _redraw_idle $path

    incr data(nbuttons)

    _select_default $path

    return $but
}


proc ButtonBox::delete { path index } {
    Widget::getVariable $path data
    Widget::getVariable $path tags

    set button $path.b$i
    set widget $button#bbox

    set i [lindex $data(buttons) $index]
    set data(buttons) [lreplace $data(buttons) $index $index]
    set data(widgets) [lreplace $data(widgets) $index $index]

    foreach tag [Widget::getoption $widget -tags] {
        set tags($tag) [BWidget::lremove $tags($tag) $button]
        if {![llength $tags($tag)]} {
            unset tags($tag) tags($tag,state)
        }
    }

    Widget::destroy $widget 0

    destroy $button

    _redraw_idle $path
}


proc ButtonBox::buttons { path {first ""} {last ""} } {
    Widget::getVariable $path data
    if {![string length $first]} { return $data(widgets) }
    if {![string length $last]}  { return [lindex $data(widgets) $first] }
    return [lrange $data(widgets) $first $last]
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::itemconfigure
# ----------------------------------------------------------------------------
proc ButtonBox::itemconfigure { path index args } {
    Widget::getVariable $path data

    set idx    [index $path $index]
    set button $path.b$idx

    set class Button
    if {[BWidget::using ttk]} { set class TTKButton }

    if {![llength $args]} {
        set res [${class}::configure $button]
        eval lappend res [Widget::configure $button#bbox [list]]
        return [lsort $res]
    }

    if {[llength $args] == 1} {
        if {[Widget::optionExists Button $args]} {
            return [${class}::configure $button $args]
        } else {
            return [Widget::configure $button#bbox $args]
        }
    }

    array set maps [Widget::splitArgs $args $class ButtonBox::Button]

    if {[info exists maps(ButtonBox::Button)]} {
        set oldtags [Widget::getoption $button#bbox -tags]

        Widget::configure $button#bbox $maps(ButtonBox::Button)

        if {[Widget::hasChanged $button#bbox -tags newtags]} {
            Widget::getVariable $path tags

            foreach tag $oldtags {
                set tags($tag) [BWidget::lremove $tags($tag) $button]
                if {![llength $tags($tag)]} {
                    unset tags($tag) tags($tag,state)
                }
            }

            foreach tag $newtags {
                lappend tags($tag) $button
                if {![info exists tags($tag,state)]} { set tags($tag,state) 1 }
            }
        }

        set redraw 0

        if {[Widget::hasChanged $button#bbox -spacing spacing]} {
            set redraw 1
            set data(spacing,$idx) [lreplace $data(spacing,$idx) 1 1 $spacing]
        }

        if {[Widget::hasChanged $button#bbox -hide hide]} {
            set redraw 1
        }

        if {$redraw} { _redraw_idle $path }
    }

    if {[llength $maps(:cmd)] || [llength $maps($class)]} {
        eval [list ${class}::configure $button] $maps(:cmd) $maps($class)
    }
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::itemcget
# ----------------------------------------------------------------------------
proc ButtonBox::itemcget { path index option } {
    set button $path.b[index $path $index]
    if {[Widget::optionExists Button $option]} {
        return [Button::cget $button $option]
    } else {
        return [Widget::cget $button#bbox $option]
    }
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::setfocus
# ----------------------------------------------------------------------------
proc ButtonBox::setfocus { path index } {
    set but $path.b[index $path $index]
    if {[winfo exists $but]} { focus $but }
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::invoke
# ----------------------------------------------------------------------------
proc ButtonBox::invoke { path index } {
    set but $path.b[index $path $index]
    if {[winfo exists $but]} { $but invoke }
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::index
# ----------------------------------------------------------------------------
proc ButtonBox::index { path index } {
    Widget::getVariable $path data

    set n [expr {$data(nbuttons) - 1}]

    if {[string is integer -strict $index]} {
        set res $index
	if {$index > $n} { set res $n }
        return $res
    }

    if {[string equal $index "default"]} {
        set res [Widget::getoption $path -default]
    } elseif {[string equal $index "end"] || [string equal $index "last"]} {
	set res $n
    } elseif {[set res [lsearch -exact $data(widgets) $index]] > -1} {
        ## They passed us a widget that is in the box.
    } else {
	## Search the text and name of each button in the
        ## box and return the index that matches.
	foreach i $data(buttons) {
	    set w $path.b$i
	    lappend text  [$w cget -text]
	    lappend names [$w cget -name]
	}
        set len [llength $data(buttons)]
	set res [lsearch -exact [concat $names $text] $index]
        if {$res >= $len} { set res [expr {$res - $len}] }
    }
    return $res
}


# ButtonBox::gettags --
#
#	Return a list of all the tags on all the buttons in a buttonbox.
#
# Arguments:
#	path      the buttonbox to query.
#
# Results:
#	taglist   a list of tags on the buttons in the buttonbox

proc ButtonBox::gettags { path } {
    Widget::getVariable $path tags

    set tags [list]

    foreach tag [array names tags] {
        if {![string match "*,state" $tag]} { lappend tags $tag }
    }
    return $tags
}


# ButtonBox::setbuttonstate --
#
#	Set the state of a given button tag.  If this makes any buttons
#       enable-able (ie, all of their tags are TRUE), enable them.
#
# Arguments:
#	path        the button box widget name
#	tag         the tag to modify
#	state       the new state of $tag (0 or 1)
#
# Results:
#	None.

proc ButtonBox::setbuttonstate { path tag state } {
    Widget::getVariable $path tags

    if {![info exists tags($tag)]} { return }

    set tags($tag,state) $state
    foreach button $tags($tag) {
        set expression 1
        foreach buttontag [Widget::getoption $button#bbox -tags] {
            lappend expression && $tags($buttontag,state)
        }

        if {[expr $expression]} {
            set state normal
        } else {
            set state disabled
        }

        $button configure -state $state
    }
}

# ButtonBox::getbuttonstate --
#
#	Retrieve the state of a given button tag.
#
# Arguments:
#	path        the button box widget name
#	tag         the tag to modify
#
# Results:
#	None.

proc ButtonBox::getbuttonstate { path tag } {
    Widget::getVariable $path tags

    if {![info exists tags($tag)]} {
        return -code error "unknown tag \"$tag\""
    }

    return $tags($tag,state)
}


proc ButtonBox::_select_default { path } {
    Widget::getVariable $path data

    set default [Widget::getoption $path -default]
    set data(default) [ButtonBox::index $path $default]

    foreach i $data(buttons) {
        set button $path.b$i
        if {$i == $data(default)} {
            if {[BWidget::using ttk]} {
                $button state focus
            } else {
                $button configure -default active
            }
        } else {
            if {[BWidget::using ttk]} {
                $button state !focus
            } else {
                $button configure -default normal
            }
        }
        incr i
    }
}


proc ButtonBox::_redraw_idle { path } {
    Widget::getVariable $path data

    if {![info exists data(redraw)]} {
        set data(redraw) 1
        after idle [list ButtonBox::_redraw $path]
    }
}


# ----------------------------------------------------------------------------
#  Command ButtonBox::_redraw
# ----------------------------------------------------------------------------
proc ButtonBox::_redraw { path } {
    Widget::getVariable $path data
    Widget::getVariable $path buttons

    set data(redraw) 1

    ## We re-grid the buttons from left-to-right.  As we go through
    ## each button, we check its spacing and which direction the
    ## spacing applies to.  Once spacing has been applied to an index,
    ## it is not changed.  This means spacing takes precedence from
    ## left-to-right.

    set rows [Widget::getoption $path -rows]
    set cols [Widget::getoption $path -columns]

    set idx     0
    set rowidx  0
    set colidx  0
    set idxs [list]
    foreach i $data(buttons) {
	set dir     [lindex $data(spacing,$i) 0]
	set spacing [lindex $data(spacing,$i) 1]
        set but $path.b$i
        if {[string equal [Widget::getoption $path -orient] "horizontal"]} {
            if {![Widget::getoption $but#bbox -hide]} {
                grid $but -column $idx -row $rowidx -sticky nsew
            } else {
                grid remove $but
            }

            if {[Widget::getoption $path -homogeneous]} {
                set req [winfo reqwidth $but]
                if { $req > $data(max) } {
                    grid columnconfigure $path [expr {2*$i}] -minsize $req
                    set data(max) $req
                }
                grid columnconfigure $path $idx -minsize $data(max) -weight 1
            } else {
                grid columnconfigure $path $idx -weight 0
            }

	    set col [expr {$idx - 1}]
	    if {[string equal $dir "right"]} { set col [expr {$idx + 1}] }
	    if {$col > 0 && [lsearch -exact $idxs $col] < 0} {
		lappend idxs $col
		grid columnconfigure $path $col -minsize $spacing
	    }

            incr colidx

            if {$cols > 0 && $colidx >= $cols} {
                set idx -2
                incr rowidx
                set colidx 0
            }
        } else {
            if {![Widget::getoption $but#bbox -hide]} {
                grid $but -column $colidx -row $idx -sticky nsew
            } else {
                grid remove $but
            }

            grid rowconfigure $path $idx -weight 0

	    set row [expr {$idx - 1}]
	    if {[string equal $dir "right"]} { set row [expr {$idx + 1}] }
	    if {$row > 0 && [lsearch -exact $idxs $row] < 0} {
		lappend idxs $row
		grid rowconfigure $path $row -minsize $spacing
	    }

            incr rowidx

            if {$rows > 0 && $rowidx >= $rows} {
                set idx -2
                incr colidx
                set rowidx 0
            }
        }
        incr idx 2
    }

    unset data(redraw)
}


proc ButtonBox::_realize { path } {
    Widget::getVariable $path data

    if {!$data(realized)} {
        set data(realized) 1
        ButtonBox::_redraw $path
    }
}


proc ButtonBox::_destroy { path } {
    Widget::getVariable $path data

    foreach i $data(buttons) {
        set button $path.b$i
        Widget::destroy $button#bbox 0
    }

    Widget::destroy $path
}

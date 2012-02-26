# -----------------------------------------------------------------------------
#  scrollw.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: scrollw.tcl,v 1.11 2004/02/04 00:11:29 hobbs Exp $
# -----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - ScrolledWindow::cget
#     - ScrolledWindow::configure
#     - ScrolledWindow::create
#     - ScrolledWindow::getframe
#     - ScrolledWindow::setwidget
#
#   Private Commands:
#     - ScrolledWindow::_realize
#     - ScrolledWindow::_set_hscroll
#     - ScrolledWindow::_set_vscroll
#     - ScrolledWindow::_setData
# -----------------------------------------------------------------------------

namespace eval ScrolledWindow {
    Widget::define ScrolledWindow scrollw

    Widget::tkinclude ScrolledWindow frame :cmd \
        remove { -class -colormap -visual }

    Widget::declare ScrolledWindow {
        {-class       String     "ScrolledWindow" 1}
	{-scrollbar   Enum	 both 0 {none both vertical horizontal}}
	{-auto	      Enum	 both 0 {none both vertical horizontal}}
	{-sides	      Enum	 se   0 {ne en nw wn se es sw ws}}
	{-size	      Int	 0    1 "%d >= 0"}
	{-ipad	      Int	 1    1 "%d >= 0"}
	{-managed     Boolean	 1    1}
    }

    bind ScrolledWindow <Map>     [list ScrolledWindow::_realize %W]
    bind ScrolledWindow <Destroy> [list ScrolledWindow::_destroy %W]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::create
# -----------------------------------------------------------------------------
proc ScrolledWindow::create { path args } {
    Widget::initArgs ScrolledWindow $args maps

    ## Do a special check for the -class option.
    array set _args $args
    set class ScrolledWindow
    if {[info exists _args(-class)]} { set class $_args(-class) }

    eval [list frame $path -class $class] $maps(:cmd)

    Widget::initFromODB ScrolledWindow $path $args

    Widget::getVariable $path data

    ## If they specified a class other than ScrolledWindow, make
    ## sure the bindtags include ScrolledWindow so that our
    ## bindings will be enabled.
    if {![string equal $class "ScrolledWindow"]} {
        set top [winfo toplevel $path]
        bindtags $path [list $path $class ScrolledWindow $top all]
    }

    set bg [$path cget -background]

    set useTtk 0
    if {[BWidget::using ttk] && ![BWidget::using aqua]} {
        set useTtk 1
        ttk::scrollbar $path.vscroll
        ttk::scrollbar $path.hscroll -orient horizontal
    } else {
        scrollbar $path.hscroll \
                -highlightthickness 0 -takefocus 0 \
                -orient	 horiz	\
                -relief	 sunken	\
                -bg	 $bg
        scrollbar $path.vscroll \
                -highlightthickness 0 -takefocus 0 \
                -orient	 vert	\
                -relief	 sunken	\
                -bg	 $bg
    }

    set data(vmin)     -1
    set data(vmax)     -1
    set data(hmin)     -1
    set data(hmax)     -1

    set data(afterId)  ""
    set data(realized) 0

    _setData $path \
	    [Widget::cget $path -scrollbar] \
	    [Widget::cget $path -auto] \
	    [Widget::cget $path -sides]

    if {[Widget::cget $path -managed]} {
	set data(hsb,packed) $data(hsb,present)
	set data(vsb,packed) $data(vsb,present)
    } else {
	set data(hsb,packed) 0
	set data(vsb,packed) 0
    }

    if {!$useTtk} {
        set sbsize [Widget::cget $path -size]

        if {$sbsize} {
            $path.vscroll configure -width $sbsize
            $path.hscroll configure -width $sbsize
        }
    }

    set data(ipad) [Widget::cget $path -ipad]

    if {$data(hsb,packed)} {
	grid $path.hscroll -column 1 -row $data(hsb,row) \
		-sticky ew -ipady $data(ipad)
    }
    if {$data(vsb,packed)} {
	grid $path.vscroll -column $data(vsb,column) -row 1 \
		-sticky ns -ipadx $data(ipad)
    }

    grid columnconfigure $path 1 -weight 1
    grid rowconfigure	 $path 1 -weight 1

    return [Widget::create ScrolledWindow $path]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::getframe
# -----------------------------------------------------------------------------
proc ScrolledWindow::getframe { path } {
    return $path
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::setwidget
# -----------------------------------------------------------------------------
proc ScrolledWindow::setwidget { path widget } {
    Widget::getVariable $path data

    if {[info exists data(widget)] && [winfo exists $data(widget)]
	&& ![string equal $data(widget) $widget]} {
	grid remove $data(widget)
	$data(widget) configure -xscrollcommand "" -yscrollcommand ""
    }

    set data(widget) $widget
    grid $widget -in $path -row 1 -column 1 -sticky news

    $path.hscroll configure -command [list $widget xview]
    $path.vscroll configure -command [list $widget yview]
    $widget configure \
        -xscrollcommand [list ScrolledWindow::_set_hscroll $path] \
        -yscrollcommand [list ScrolledWindow::_set_vscroll $path]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::getwidget
# -----------------------------------------------------------------------------
proc ScrolledWindow::getwidget { path } {
    Widget::getVariable $path data
    if {[info exists data(widget)]} { return $data(widget) }
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::configure
# -----------------------------------------------------------------------------
proc ScrolledWindow::configure { path args } {
    Widget::getVariable $path data

    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -background bg]} {
	catch { $path.hscroll configure -background $bg }
	catch { $path.vscroll configure -background $bg }
    }

    if {[Widget::hasChanged $path -scrollbar scrollbar]
        || [Widget::hasChanged $path -auto  auto]
        || [Widget::hasChanged $path -sides sides]} {
	_setData $path $scrollbar $auto $sides

        BWidget::lassign [$path.hscroll get] vmin vmax
	set data(hsb,packed) [expr {$data(hsb,present) && \
		(!$data(hsb,auto) || ($vmin != 0 || $vmax != 1))}]

        BWidget::lassign [$path.vscroll get] vmin vmax
	set data(vsb,packed) [expr {$data(vsb,present) && \
		(!$data(vsb,auto) || ($vmin != 0 || $vmax != 1))}]

	set data(ipad) [Widget::cget $path -ipad]

	if {$data(hsb,packed)} {
	    grid $path.hscroll -column 1 -row $data(hsb,row) \
                -sticky ew -ipady $data(ipad)
	}
	if {$data(vsb,packed)} {
	    grid $path.vscroll -column $data(vsb,column) -row 1 \
                -sticky ns -ipadx $data(ipad)
	}
    }
    return $res
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::cget
# -----------------------------------------------------------------------------
proc ScrolledWindow::cget { path option } {
    return [Widget::cget $path $option]
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_set_hscroll
# -----------------------------------------------------------------------------
proc ScrolledWindow::_set_hscroll { path vmin vmax } {
    Widget::getVariable $path data

    $path.hscroll set $vmin $vmax

    set data(hmin) $vmin
    set data(hmax) $vmax

    _redraw_after $path
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_set_vscroll
# -----------------------------------------------------------------------------
proc ScrolledWindow::_set_vscroll { path vmin vmax } {
    Widget::getVariable $path data

    $path.vscroll set $vmin $vmax

    set data(vmin) $vmin
    set data(vmax) $vmax

    _redraw_after $path
}


proc ScrolledWindow::_setData {path scrollbar auto sides} {
    Widget::getVariable $path data

    set sb    [lsearch -exact {none horizontal vertical both} $scrollbar]
    set auto  [lsearch -exact {none horizontal vertical both} $auto]

    set data(hsb,present)  [expr {($sb & 1) != 0}]
    set data(hsb,auto)	   [expr {($auto & 1) != 0}]
    set data(hsb,row)	   [expr {[string match *n* $sides] ? 0 : 2}]

    set data(vsb,present)  [expr {($sb & 2) != 0}]
    set data(vsb,auto)	   [expr {($auto & 2) != 0}]
    set data(vsb,column)   [expr {[string match *w* $sides] ? 0 : 2}]
}


proc ScrolledWindow::_redraw_after { path } {
    Widget::getVariable $path data
    after cancel $data(afterId)
    set data(afterId) [after 5 [list ScrolledWindow::_redraw $path]]
}


proc ScrolledWindow::_redraw { path } {
    if {![Widget::exists $path]} { return }

    Widget::getVariable $path data

    if {!$data(realized)} { return }

    if {$data(hsb,present) && $data(hsb,auto)} {
        if {$data(hsb,packed) && $data(hmin) == 0 && $data(hmax) == 1} {
            set data(hsb,packed) 0
            grid remove $path.hscroll
        } elseif {!$data(hsb,packed) && ($data(hmin)!=0 || $data(hmax)!=1)} {
            set data(hsb,packed) 1
            grid $path.hscroll -column 1 -row $data(hsb,row) \
                    -sticky ew -ipady $data(ipad)
        }
    }

    if {$data(vsb,present) && $data(vsb,auto)} {
        if {$data(vsb,packed) && $data(vmin) == 0 && $data(vmax) == 1} {
            set data(vsb,packed) 0
            grid remove $path.vscroll
        } elseif {!$data(vsb,packed) && ($data(vmin)!=0 || $data(vmax)!=1) } {
            set data(vsb,packed) 1
            grid $path.vscroll -column $data(vsb,column) -row 1 \
                    -sticky ns -ipadx $data(ipad)
        }
    }
}


# -----------------------------------------------------------------------------
#  Command ScrolledWindow::_realize
# -----------------------------------------------------------------------------
proc ScrolledWindow::_realize { path } {
    Widget::getVariable $path data
    set data(realized) 1
}


proc ScrolledWindow::_destroy { path } {
    Widget::getVariable $path data
    after cancel $data(afterId)
    Widget::destroy $path
}

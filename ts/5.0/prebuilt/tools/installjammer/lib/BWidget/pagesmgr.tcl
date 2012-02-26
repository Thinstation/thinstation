# ------------------------------------------------------------------------------
#  pagesmgr.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: pagesmgr.tcl,v 1.6 2003/10/20 21:23:52 damonc Exp $
# ------------------------------------------------------------------------------
#  Index of commands:
#
#   Public Command
#     - PagesManager::add
#     - PagesManager::cget
#     - PagesManager::create
#     - PagesManager::compute_size
#     - PagesManager::configure
#     - PagesManager::delete
#     - PagesManager::getframe
#     - PagesManager::page
#     - PagesManager::pages
#     - PagesManager::raise
#
#   Private Commands
#     - PagesManager::_test_page
# ------------------------------------------------------------------------------

namespace eval PagesManager {
    Widget::define PagesManager pagesmgr

    Widget::tkinclude PagesManager frame :cmd \
        remove { -class -colormap -container -visual }
}


# ------------------------------------------------------------------------------
#  Command PagesManager::create
# ------------------------------------------------------------------------------
proc PagesManager::create { path args } {
    Widget::initArgs PagesManager $args maps

    eval [list frame $path] $maps(:cmd) -class PagesManager

    Widget::initFromODB PagesManager $path $maps(PagesManager)

    Widget::getVariable $path data

    set data(pages)  [list]
    set data(select) ""

    grid rowconfigure    $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    return [Widget::create PagesManager $path]
}


# ------------------------------------------------------------------------------
#  Command PagesManager::configure
# ------------------------------------------------------------------------------
proc PagesManager::configure { path args } {
    return [Widget::configure $path $args]
}


# ------------------------------------------------------------------------------
#  Command PagesManager::cget
# ------------------------------------------------------------------------------
proc PagesManager::cget { path option } {
    return [Widget::cget $path $option]
}


proc PagesManager::itemcget { path page option } {
    _test_page $path $page
    return [$path.f$page cget $option]
}


proc PagesManager::itemconfigure { path page args } {
    _test_page $path $page
    return [eval [list $path.f$page configure] $args]
}


# ------------------------------------------------------------------------------
#  Command PagesManager::compute_size
# ------------------------------------------------------------------------------
proc PagesManager::compute_size { path } {
    Widget::getVariable $path data

    set wmax 0
    set hmax 0
    update idletasks
    foreach page $data(pages) {
        set w    [winfo reqwidth  $path.f$page]
        set h    [winfo reqheight $path.f$page]
        set wmax [expr {$w>$wmax ? $w : $wmax}]
        set hmax [expr {$h>$hmax ? $h : $hmax}]
    }
    configure $path -width $wmax -height $hmax
}


# ------------------------------------------------------------------------------
#  Command PagesManager::add
# ------------------------------------------------------------------------------
proc PagesManager::add { path page } {
    Widget::getVariable $path data

    set page [Widget::nextIndex $path $page]

    if {[exists $path $page]} {
        return -code error "page \"$page\" already exists"
    }

    lappend data(pages) $page

    frame $path.f$page -relief flat \
	    -background [Widget::cget $path -background] -borderwidth 0

    return $path.f$page
}


# ------------------------------------------------------------------------------
#  Command PagesManager::delete
# ------------------------------------------------------------------------------
proc PagesManager::delete { path page } {
    Widget::getVariable $path data

    set pos [_test_page $path $page]
    set data(pages) [lreplace $data(pages) $pos $pos]
    if {[string equal $data(select) $page]} {
        set data(select) ""
    }
    destroy $path.f$page
}


# ------------------------------------------------------------------------------
#  Command PagesManager::raise
# ------------------------------------------------------------------------------
proc PagesManager::raise { path {page ""} } {
    Widget::getVariable $path data

    if {![string equal $page ""]} {
        _test_page $path $page

        if {![string equal $page $data(select)]} {
            if {![string equal $data(select) ""]} {
                grid forget [getframe $path $data(select)]
            }
            grid [getframe $path $page] -row 0 -column 0 -sticky news
            set data(select) $page
        }
    }
    return $data(select)
}


# ------------------------------------------------------------------------------
#  Command PagesManager::page - deprecated, use pages
# ------------------------------------------------------------------------------
proc PagesManager::page { path first {last ""} } {
    Widget::getVariable $path data

    if { $last == "" } {
        return [lindex $data(pages) $first]
    } else {
        return [lrange $data(pages) $first $last]
    }
}


# ------------------------------------------------------------------------------
#  Command PagesManager::pages
# ------------------------------------------------------------------------------
proc PagesManager::pages { path {first ""} {last ""} } {
    Widget::getVariable $path data

    if { ![string length $first] } {
	return $data(pages)
    }

    if { ![string length $last] } {
        return [lindex $data(pages) $first]
    } else {
        return [lrange $data(pages) $first $last]
    }
}


# ------------------------------------------------------------------------------
#  Command PagesManager::getframe
# ------------------------------------------------------------------------------
proc PagesManager::getframe { path page } {
    _test_page $path $page
    return $path.f$page
}


proc PagesManager::exists { path page } {
    Widget::getVariable $path data
    return [expr [lsearch -exact $data(pages) $page] > -1]
}


# ------------------------------------------------------------------------------
#  Command PagesManager::_test_page
# ------------------------------------------------------------------------------
proc PagesManager::_test_page { path page } {
    Widget::getVariable $path data

    if {[set pos [lsearch -exact $data(pages) $page]] == -1} {
        return -code error "page \"$page\" does not exists"
    }
    return $pos
}

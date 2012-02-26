# -----------------------------------------------------------------------------
#  preferences.tcl
#
#       Implement a preferences window with a Tree on the left side to
#       show layered preference groups and a PagesManager on the right
#       to display a different frame for each group.
#
#  $Id$
# -----------------------------------------------------------------------------
#  Index of commands:
#     - Preferences::create
#     - Preferences::configure
#     - Preferences::cget
#     - Preferences::getframe
#     - Preferences::insert
#     - Preferences::delete
#     - Preferences::nodes
#     - Preferences::raise
#     - Preferences::open
#     - Preferences::close
#     - Preferences::toggle
# -----------------------------------------------------------------------------

namespace eval Preferences {
    if {[info tclversion] < 8.4} {
        Widget::define Preferences preferences PanedWindow Tree ScrolledWindow
    } else {
        Widget::define Preferences preferences Tree ScrolledWindow
    }

    Widget::declare Preferences::Node {
        {-pagewindow      String    ""    1}
        {-haspage         Boolean   1     1}
        {-created         Boolean   0     1}
        {-createpage      Boolean   0     1}
        {-raisecommand    String    ""    0}
        {-createcommand   String    ""    0}
    }

    Widget::tkinclude Preferences frame :cmd \
        include { -relief -borderwidth -bd -width -height }

    Widget::bwinclude Preferences Tree .panes.treeframe.t \
        prefix { tree -background -cursor -borderwidth
                 -highlightbackground -highlightcolor -highlightthickness
                 -relief -selectbackground -selectforeground -padx } \
        remove { -bd -bg } \
	initialize { -highlightthickness 0 }

    Widget::declare Preferences {
        {-background   String     ""         0}
	{-padx         Padding    "0"        0}
	{-resizable    Boolean    "1"        1}

        {-treewidth    Int        "200"      0}
        {-treestretch  Enum       "never"    0 {always first last middle never}}

        {-pagewidth    Int        "200"      0 "%d > 0"}
        {-pagestretch  Enum       "always"   0 {always first last middle never}}

        {-bg           Synonym    -background}
    }
}


# -----------------------------------------------------------------------------
#  Command Preferences::create
# -----------------------------------------------------------------------------
proc Preferences::create { path args } {
    Widget::initArgs Preferences $args maps

    eval frame $path $maps(:cmd) -class Preferences

    Widget::initFromODB Preferences $path $maps(Preferences)

    Widget::getVariable $path data
    Widget::getVariable $path pane1
    Widget::getVariable $path pane2

    set data(select) ""

    set resizable [Widget::cget $path -resizable]

    if {$resizable} {
        PanedWindow $path.panes -sashpad 2 -sashwidth 2 -sashrelief ridge
    } else {
        frame $path.panes
    }

    pack $path.panes -expand 1 -fill both

    set pane1 [frame $path.panes.treeframe]
    set pane2 [frame $path.panes.mainframe]

    if {$resizable} {
        $path.panes add $pane1 \
            -width   [Widget::getoption $path -treewidth] \
            -stretch [Widget::getoption $path -treestretch]
        $path.panes add $pane2 -stretch last \
            -width   [Widget::getoption $path -pagewidth] \
            -stretch [Widget::getoption $path -pagestretch]
    } else {
        pack $pane1 -side left -fill y
        pack $pane2 -side left -fill both -expand 1
    }

    ScrolledWindow $pane1.sw
    pack $pane1.sw -expand 1 -fill both

    eval Tree $pane1.t -linesfill #CACACA -padx 2 $maps(.panes.treeframe.t)
    $pane1.sw setwidget $pane1.t
    $pane1.t bindText  <1> [list $path raise]
    $pane1.t bindImage <1> [list $path raise]
    $pane1.t bindText  <Double-1> [list $path toggle]
    $pane1.t bindImage <Double-1> [list $path toggle]

    frame $pane2.f
    grid rowconfigure    $pane2.f 0 -weight 1
    grid columnconfigure $pane2.f 0 -weight 1

    set padx [Widget::getoption $path -padx]
    pack $pane2.f -side left -expand 1 -fill both -padx $padx

    return [Widget::create Preferences $path]
}


# -----------------------------------------------------------------------------
#  Command Preferences::configure
# -----------------------------------------------------------------------------
proc Preferences::configure { path args } {
    Widget::getVariable $path pane1
    Widget::getVariable $path pane2

    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -background bg]} {
        $path configure -background $bg
        $path.panes configure -background $bg
        $pane2.f configure -background $bg
    }

    if {[Widget::hasChanged $path -treewidth width]} {
        $path.panes paneconfigure $pane1 -width $width
    }

    if {[Widget::hasChanged $path -treestretch stretch]} {
        $path.panes paneconfigure $pane1 -stretch $stretch
    }

    if {[Widget::hasChanged $path -pagewidth width]} {
        $path.panes paneconfigure $pane2 -width $width
    }

    if {[Widget::hasChanged $path -pagestretch stretch]} {
        $path.panes paneconfigure $pane2 -stretch $stretch
    }

    if {[Widget::hasChanged $path -padx padx]} {
        pack configure $pane2.f -padx $padx
    }

    return $res
}


proc Preferences::cget { path option } {
    switch -- $option {
        "-treewidth" {
            Widget::getVariable $path pane1
            return [$path.panes panecget $pane1 -width]

        }

        "-treestretch" {
            Widget::getVariable $path pane1
            return [$path.panes panecget $pane1 -stretch]
        }

        "-pagewidth" {
            Widget::getVariable $path pane2
            return [$path.panes panecget $pane2 -width]
        }

        "-pagestretch" {
            Widget::getVariable $path pane2
            return [$path.panes panecget $pane2 -stretch]
        }

        default {
            return [Widget::cget $path $option]
        }
    }
}


proc Preferences::itemconfigure { path node args } {
    Widget::getVariable $path pane1

    if {![llength $args]} {
        set res [eval $pane1.t itemconfigure $node $args]
        eval lappend res [Widget::configure $path.$node $args]
        return [lsort $res]
    }

    if {[llength $args] == 1} {
        if {[Widget::optionExists Tree::Node $args]} {
            return [Tree::itemconfigure $pane1.t $node $args]
        } else {
            return [Widget::configure $path.$node $args]
        }
    }

    array set maps [Widget::splitArgs $args Preferences::Node Tree::Node]

    if {[info exists maps(Tree::Node)]} {
        eval [list Tree::itemconfigure $pane1.t $node] $maps(Tree::Node)
    }

    if {[info exists maps(Preferences::Node)]} {
        Widget::configure $path.$node $maps(Preferences::Node)
    }
}


proc Preferences::itemcget { path node option } {
    Widget::getVariable $path pane1
    if {[Widget::optionExists Preferences::Node $option]} {
        return [Widget::cget $path.$node $option]
    } else {
        return [$pane1.t itemcget $node $option]
    }
}


proc Preferences::getframe { path {node ""} } {
    Widget::getVariable $path pane2

    if {[string length $node] && ![exists $path $node]} {
        return -code error "node \"$node\" does not exist"
    }

    if {![string length $node]} { return $pane2.f }

    if {![Widget::getoption $path.$node -haspage]} { return }

    set window [Widget::getoption $path.$node -pagewindow]
    if {![winfo exists $window]} { _create_node $path $node }
    return $window
}


proc Preferences::gettree { path } {
    Widget::getVariable $path pane1
    return $pane1.t
}


proc Preferences::insert { path idx parent node args } {
    Widget::getVariable $path data
    Widget::getVariable $path pane1
    Widget::getVariable $path pane2

    array set maps [list Preferences::Node {} Tree::Node {}]
    array set maps [Widget::splitArgs $args Preferences::Node Tree::Node]

    set node [Widget::nextIndex $path $node]

    ## Add a node in the tree.
    set n [eval [list $pane1.t insert $idx $parent $node] $maps(Tree::Node)]

    Widget::init Preferences::Node $path.$n $maps(Preferences::Node)

    set window [Widget::getoption $path.$node -pagewindow]
    if {![string length $window]} {
        Widget::setoption $path.$node -pagewindow $pane2.f.f$node
    }

    if {[Widget::getoption $path.$node -haspage]
        && [Widget::getoption $path.$n -createpage]} { _create_node $path $n }

    return $n
}


proc Preferences::delete { path args } {
    Widget::getVariable $path data
    Widget::getVariable $path pane1
    Widget::getVariable $path pane2

    foreach node $args {
        destroy $pane2.f.f$node
        $pane1.t delete $node
        Widget::destroy $path.$node 0
        if {[info exists data($node,realized)]} { unset data($node,realized) }
    }
    
    if {![exists $path $data(select)]} { set data(select) "" }
}


proc Preferences::nodes { path node {first ""} {last ""} } {
    Widget::getVariable $path pane1
    return [$pane1.t nodes $node $first $last]
}


proc Preferences::parent { path node } {
    Widget::getVariable $path pane1
    return [$pane1.t parent $node]
}


proc Preferences::exists { path node } {
    Widget::getVariable $path pane1
    return [Tree::exists $pane1.t $node]
}


proc Preferences::reset { path } {
    Widget::getVariable $path data
    if {[string length $data(select)]} {
        grid remove [Widget::getoption $path.$data(select) -pagewindow]
        set data(select) ""
        Preferences::selection $path clear
    }
}


proc Preferences::raise { path {node ""} } {
    Widget::getVariable $path data
    Widget::getVariable $path pane1
    Widget::getVariable $path pane2

    if {![string length $node]} { return $data(select) }

    Tree::selection $pane1.t set $node

    if {![Widget::getoption $path.$node -haspage]} { return }

    if {[string equal $data(select) $node]} { return }

    set old $data(select)

    set data(select) $node

    set window [Widget::getoption $path.$node -pagewindow]

    if {![winfo exists $window]} { _create_node $path $node }

    if {![info exists data($node,realized)]} {
        set data($node,realized) 1
        set cmd [Widget::getoption $path.$node -createcommand]
        if {[string length $cmd]} { uplevel #0 $cmd }
    }

    set cmd [Widget::getoption $path.$node -raisecommand]
    if {[string length $cmd]} { uplevel #0 $cmd }
    
    if {![string equal $data(select) $old]} {
        set oldwindow ""
        if {[string length $old]} {
            set oldwindow [Widget::getoption $path.$old -pagewindow]

            if {![string equal $window $oldwindow]} {
                grid remove [Widget::getoption $path.$old -pagewindow]
            }
        }
        if {![string equal $window $oldwindow]} {
            grid $window -in $pane2.f -sticky news
        }
    }
}


proc Preferences::open { path node {recurse 0} } {
    Widget::getVariable $path pane1
    $pane1.t opentree $node $recurse
}


proc Preferences::close { path node {recurse 0} } {
    Widget::getVariable $path pane1
    $pane1.t closetree $node $recurse
}


proc Preferences::toggle { path node } {
    Widget::getVariable $path pane1
    $pane1.t toggle $node
}


proc Preferences::selection { path args } {
    Widget::getVariable $path pane1
    return [eval $pane1.t selection $args]
}


proc Preferences::index { path node } {
    Widget::getVariable $path pane1
    return [eval $pane1.t index $node]
}


proc Preferences::edit { path args } {
    Widget::getVariable $path pane1
    return [eval $pane1.t edit $args]
}


proc Preferences::see { path node } {
    Widget::getVariable $path pane1
    return [$pane1.t see $node]
}


proc Preferences::_create_node { path node } {
    Widget::getVariable $path pane2
    set frame  $pane2.f.f$node
    set window [Widget::getoption $path.$node -pagewindow]
    if {![string equal $frame $window] || [winfo exists $frame]} { return }

    Widget::setoption $path.$node -created 1

    frame $frame
}

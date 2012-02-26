# ----------------------------------------------------------------------------
#  tree.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: tree.tcl,v 1.51 2004/04/26 18:42:03 hobbs Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - Tree::create
#     - Tree::configure
#     - Tree::cget
#     - Tree::insert
#     - Tree::itemconfigure
#     - Tree::itemcget
#     - Tree::bindText
#     - Tree::bindImage
#     - Tree::delete
#     - Tree::move
#     - Tree::reorder
#     - Tree::selection
#     - Tree::exists
#     - Tree::parent
#     - Tree::index
#     - Tree::nodes
#     - Tree::see
#     - Tree::opentree
#     - Tree::closetree
#     - Tree::edit
#     - Tree::xview
#     - Tree::yview
#
#   Private Commands:
#     - Tree::_update_edit_size
#     - Tree::_destroy
#     - Tree::_see
#     - Tree::_recexpand
#     - Tree::_subdelete
#     - Tree::_update_scrollregion
#     - Tree::_cross_event
#     - Tree::_draw_node
#     - Tree::_draw_subnodes
#     - Tree::_update_nodes
#     - Tree::_draw_tree
#     - Tree::_redraw_tree
#     - Tree::_redraw_selection
#     - Tree::_redraw_idle
#     - Tree::_drag_cmd
#     - Tree::_drop_cmd
#     - Tree::_over_cmd
#     - Tree::_auto_scroll
#     - Tree::_scroll
# ----------------------------------------------------------------------------

namespace eval Tree {
    Widget::define Tree tree DragSite DropSite DynamicHelp

    namespace eval Node {
        Widget::declare Tree::Node {
            {-text       String     ""      0}
            {-font       String     ""      0}
            {-image      String     ""      0}
            {-window     String     ""      0}
            {-fill       Color      "SystemButtonText"   0}
            {-data       String     ""      0}
            {-open       Boolean    0       0}
	    {-selectable Boolean    1       0}
            {-drawcross  Enum       auto    0 {auto allways never}}
	    {-padx       Int        -1      0 "%d >= -1"}
	    {-deltax     Int        -1      0 "%d >= -1"}
	    {-anchor     String     "w"     0 ""}
        }
    }

    DynamicHelp::include Tree::Node balloon

    Widget::tkinclude Tree canvas .c \
        remove {
            -insertwidth -insertbackground -insertborderwidth -insertofftime
            -insertontime -selectborderwidth -closeenough -confine -scrollregion
            -xscrollincrement -yscrollincrement -width -height
        } initialize {
            -background #FFFFFF -relief sunken -borderwidth 2 
	    -takefocus 1 -highlightthickness 1 -width 200
        }

    DragSite::include Tree "TREE_NODE" 1
    DropSite::include Tree {
        TREE_NODE {copy {} move {}}
    }

    Widget::declare Tree {
        {-deltax            Int        10       0 "%d >= 0"}
        {-deltay            Int        15       0 "%d >= 0"}
        {-padx              Int        20       0 "%d >= 0"}
        {-font              String     "TkTextFont" 0}
        {-background        Color      "SystemWindow"  0}
        {-selectbackground  Color      "SystemHighlight"  0}
        {-selectforeground  Color      "SystemHighlightText" 0}
	{-selectcommand     String     ""       0}
        {-selectmode        Enum       "single" 0 {extended none single}}
        {-width             TkResource ""       0 listbox}
        {-height            TkResource ""       0 listbox}
        {-selectfill        Boolean    0        0}
        {-showlines         Boolean    1        0}
        {-linesfill         Color      "SystemButtonText"  0}
        {-linestipple       TkResource ""       0 {label -bitmap}}
	{-crossfill         Color      "SystemButtonText"  0}
        {-redraw            Boolean    1        0}
        {-opencmd           String     ""       0}
        {-closecmd          String     ""       0}
        {-dropovermode      Flag       "wpn"    0 "wpn"}
        {-dropcmd           String     "Tree::_drag_and_drop" 0}

        {-crossopenimage    String     ""       0}
        {-crosscloseimage   String     ""       0}
        {-crossopenbitmap   String     ""       0}
        {-crossclosebitmap  String     ""       0}

        {-bg                Synonym    -background}
    }

    Widget::addmap Tree "" .c { -deltay -yscrollincrement }

    bind Tree <FocusIn>   [list after idle {BWidget::refocus %W %W.c}]
    bind Tree <Destroy>   [list Tree::_destroy %W]
    bind Tree <Configure> [list Tree::_update_scrollregion %W]

    bind TreeSentinalStart <Button-1> {
	if {$::Tree::sentinal(%W)} {
	    set ::Tree::sentinal(%W) 0
	    break
	}
    }

    bind TreeSentinalEnd <Button-1> {
	set ::Tree::sentinal(%W) 0
    }

    bind TreeFocus <Button-1> [list focus %W]

    BWidget::bindMouseWheel TreeCanvas

    variable _edit
    set _edit(editing) 0
}


# ----------------------------------------------------------------------------
#  Command Tree::create
# ----------------------------------------------------------------------------
proc Tree::create { path args } {
    Widget::initArgs Tree $args maps

    eval [list frame $path -class Tree] $maps(:cmd)

    # For 8.4+ we don't want to inherit the padding
    if {[info tclversion] > 8.3} { $path configure -padx 0 -pady 0 }

    Widget::initFromODB Tree $path $maps(Tree)

    set ::Tree::sentinal($path.c) 0

    Widget::getVariable $path data

    set data(root)         [list [list]]
    set data(selnodes)     [list]
    set data(upd,level)    0
    set data(upd,nodes)    [list]
    set data(upd,afterid)  ""
    set data(dnd,scroll)   ""
    set data(dnd,afterid)  ""
    set data(dnd,selnodes) [list]
    set data(dnd,node)     ""

    ## The items array contains a list of canvas items
    ## for each node in the tree.  The list contains:
    ##
    ## lineItem textItem crossItem windowItem boxItem
    ##
    Widget::getVariable $path items

    eval [list canvas $path.c] $maps(.c) -xscrollincrement 8
    bindtags $path.c [list TreeSentinalStart TreeFocus $path.c Canvas \
	    TreeCanvas [winfo toplevel $path] all TreeSentinalEnd]
    pack $path.c -expand yes -fill both
    $path.c bind cross <ButtonPress-1> [list Tree::_cross_event $path]

    # Added by ericm@scriptics.com
    # These allow keyboard traversal of the tree
    bind $path.c <KeyPress-Up>    [list Tree::_keynav up $path]
    bind $path.c <KeyPress-Down>  [list Tree::_keynav down $path]
    bind $path.c <KeyPress-Right> [list Tree::_keynav right $path]
    bind $path.c <KeyPress-Left>  [list Tree::_keynav left $path]
    bind $path.c <KeyPress-space> [list +Tree::_keynav space $path]

    # These allow keyboard control of the scrolling
    bind $path.c <Control-KeyPress-Up>    [list $path.c yview scroll -1 units]
    bind $path.c <Control-KeyPress-Down>  [list $path.c yview scroll  1 units]
    bind $path.c <Control-KeyPress-Left>  [list $path.c xview scroll -1 units]
    bind $path.c <Control-KeyPress-Right> [list $path.c xview scroll  1 units]
    # ericm@scriptics.com

    DragSite::setdrag $path $path.c Tree::_init_drag_cmd \
	    [Widget::cget $path -dragendcmd] 1
    DropSite::setdrop $path $path.c Tree::_over_cmd Tree::_drop_cmd 1

    Widget::create Tree $path

    set w [Widget::cget $path -width]
    set h [Widget::cget $path -height]
    set dy [Widget::cget $path -deltay]
    $path.c configure -width [expr {$w*8}] -height [expr {$h*$dy}]

    set mode [Widget::getoption $path -selectmode]
    if {$mode ne "none"} {
        Tree::bindText  $path <Double-1> [list $path toggle]
        Tree::bindImage $path <Double-1> [list $path toggle]
        Tree::bindText  $path <Button-1> [list $path selection set]
        Tree::bindImage $path <Button-1> [list $path selection set]
    }

    if {$mode eq "extended"} {
        Tree::bindText  $path <Control-Button-1> [list $path selection toggle]
        Tree::bindImage $path <Control-Button-1> [list $path selection toggle]
    }

    # Add sentinal bindings for double-clicking on items, to handle the 
    # gnarly Tk bug wherein:
    # ButtonClick
    # ButtonClick
    # On a canvas item translates into button click on the item, button click
    # on the canvas, double-button on the item, single button click on the
    # canvas (which can happen if the double-button on the item causes some
    # other event to be handled in between when the button clicks are examined
    # for the canvas)
    $path.c bind TreeItemSentinal <Double-Button-1> \
	[list set ::Tree::sentinal($path.c) 1]
    # ericm


    set image  [Widget::getoption $path -crossopenimage]
    set bitmap [Widget::getoption $path -crossopenbitmap]
    if {![string length $image] && ![string length $bitmap]} {
        Widget::setoption $path -crossopenimage [BWidget::Icon tree-minus]
    }

    set image  [Widget::getoption $path -crosscloseimage]
    set bitmap [Widget::getoption $path -crossclosebitmap]
    if {![string length $image] && ![string length $bitmap]} {
        Widget::setoption $path -crosscloseimage [BWidget::Icon tree-plus]
    }

    return $path
}


# ----------------------------------------------------------------------------
#  Command Tree::configure
# ----------------------------------------------------------------------------
proc Tree::configure { path args } {
    Widget::getVariable $path data

    set res [Widget::configure $path $args]

    set ch1 [expr {[Widget::hasChanged $path -deltax val]
                   || [Widget::hasChanged $path -deltay dy]
                   || [Widget::hasChanged $path -padx val]
                   || [Widget::hasChanged $path -showlines val]
                   || [Widget::hasChanged $path -font font]}]

    set ch2 [expr {[Widget::hasChanged $path -selectbackground val] |
                   [Widget::hasChanged $path -selectforeground val]}]

    if {[Widget::hasChanged $path -linesfill fill]
        || [Widget::hasChanged $path -linestipple stipple] } {
        $path.c itemconfigure line  -fill $fill -stipple $stipple
    }

    if {[Widget::hasChanged $path -crossfill fill]} {
        $path.c itemconfigure cross -foreground $fill
    }

    if {[Widget::hasChanged $path -selectfill fill]} {
	# Make sure that the full-width boxes have either all or none
	# of the standard node bindings
	if {$fill} {
	    foreach event [$path.c bind "node"] {
		$path.c bind "box" $event [$path.c bind "node" $event]
	    }
	} else {
	    foreach event [$path.c bind "node"] {
		$path.c bind "box" $event {}
	    }
	}
    }

    if { $ch1 } {
        _redraw_idle $path 3
    } elseif { $ch2 } {
        _redraw_idle $path 1
    }

    if { [Widget::hasChanged $path -height h] } {
        $path.c configure -height [expr {$h*$dy}]
    }
    if { [Widget::hasChanged $path -width w] } {
        $path.c configure -width [expr {$w*8}]
    }

    if { [Widget::hasChanged $path -redraw bool] && $bool } {
        set upd $data(upd,level)
        set data(upd,level) 0
        _redraw_idle $path $upd
    }

    set force [Widget::hasChanged $path -dragendcmd dragend]
    DragSite::setdrag $path $path.c Tree::_init_drag_cmd $dragend $force
    DropSite::setdrop $path $path.c Tree::_over_cmd Tree::_drop_cmd

    return $res
}


# ----------------------------------------------------------------------------
#  Command Tree::cget
# ----------------------------------------------------------------------------
proc Tree::cget { path option } {
    return [Widget::cget $path $option]
}


# ----------------------------------------------------------------------------
#  Command Tree::insert
# ----------------------------------------------------------------------------
proc Tree::insert { path index parent node args } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    set node [Widget::nextIndex $path $node]

    if {[info exists data($node)]} {
        return -code error "node \"$node\" already exists"
    }

    if {![info exists data($parent)]} {
        return -code error "node \"$parent\" does not exist"
    }

    Widget::init Tree::Node $path.$node $args

    if {[string equal $index "end"]} {
        lappend data($parent) $node
    } else {
        set data($parent) [linsert $data($parent) [incr index] $node]
    }
    set data($node) [list $parent]

    if {[string equal $parent "root"]} {
        _redraw_idle $path 3
    } elseif {[Tree::visible $path $parent]} {
        # parent is visible...
        if {[Widget::getoption $path.$parent -open]} {
            # ...and opened -> redraw whole
            _redraw_idle $path 3
        } else {
            # ...and closed -> redraw cross
            lappend data(upd,nodes) $parent 8
            _redraw_idle $path 2
        }
    }

    return $node
}


# ----------------------------------------------------------------------------
#  Command Tree::itemconfigure
# ----------------------------------------------------------------------------
proc Tree::itemconfigure { path node args } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {[string equal $node "root"] || ![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    set result [Widget::configure $path.$node $args]

    _set_help $path $node

    if { [visible $path $node] } {
        set lopt   {}
        set flag   0
        foreach opt {-window -image -drawcross -font -text -fill} {
            set flag [expr {$flag << 1}]
            if {[Widget::hasChanged $path.$node $opt val]} {
                set flag [expr {$flag | 1}]
            }
        }

        if {[Widget::hasChanged $path.$node -open val]} {
            if {[llength $data($node)] > 1} {
                # node have subnodes - full redraw
                _redraw_idle $path 3
            } else {
                # force a redraw of the plus/minus sign
                set flag [expr {$flag | 8}]
            }
        }

	if {$data(upd,level) < 3 && [Widget::hasChanged $path.$node -padx x]} {
	    _redraw_idle $path 3
	}

	if { $data(upd,level) < 3 && $flag } {
            if { [set idx [lsearch -exact $data(upd,nodes) $node]] == -1 } {
                lappend data(upd,nodes) $node $flag
            } else {
                incr idx
                set flag [expr {[lindex $data(upd,nodes) $idx] | $flag}]
                set data(upd,nodes) [lreplace $data(upd,nodes) $idx $idx $flag]
            }
            _redraw_idle $path 2
        }
    }
    return $result
}


# ----------------------------------------------------------------------------
#  Command Tree::itemcget
# ----------------------------------------------------------------------------
proc Tree::itemcget { path node option } {
    Widget::getVariable $path data
    set node [_node_name $path $node]
    if {[string equal $node "root"] || ![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    return [Widget::cget $path.$node $option]
}


# ----------------------------------------------------------------------------
#  Command Tree::bindText
# ----------------------------------------------------------------------------
proc Tree::bindText { path event script } {
    if {[string length $script]} {
	append script " \[Tree::_get_node_name [list $path] current 2\]"
    }
    $path.c bind "node" $event $script
    if {[Widget::getoption $path -selectfill]} {
	$path.c bind "box" $event $script
    } else {
	$path.c bind "box" $event {}
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::bindImage
# ----------------------------------------------------------------------------
proc Tree::bindImage { path event script } {
    if {[string length $script]} {
	append script " \[Tree::_get_node_name [list $path] current 2\]"
    }
    $path.c bind "img" $event $script
    if {[Widget::getoption $path -selectfill]} {
	$path.c bind "box" $event $script
    } else {
	$path.c bind "box" $event {}
    }
}


proc Tree::bindTree { path args } {
    return [eval [list bind $path.c] $args]
}


proc Tree::clear { path } {
    eval [list Tree::delete $path] [Tree::nodes $path root]
}


# ----------------------------------------------------------------------------
#  Command Tree::delete
# ----------------------------------------------------------------------------
proc Tree::delete { path args } {
    Widget::getVariable $path data

    foreach lnodes $args {
	foreach node $lnodes {
            set node [_node_name $path $node]
	    if { ![string equal $node "root"] && [info exists data($node)] } {
		set parent [lindex $data($node) 0]
		set idx	   [lsearch -exact $data($parent) $node]
		set data($parent) [lreplace $data($parent) $idx $idx]
		_subdelete $path [list $node]
	    }
	}
    }

    _redraw_idle $path 3
}


# ----------------------------------------------------------------------------
#  Command Tree::move
# ----------------------------------------------------------------------------
proc Tree::move { path parent node index } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if { [string equal $node "root"] || ![info exists data($node)] } {
        return -code error "node \"$node\" does not exist"
    }
    if { ![info exists data($parent)] } {
        return -code error "node \"$parent\" does not exist"
    }
    set p $parent
    while {![string equal $p "root"]} {
        if {[string equal $p $node]} {
            return -code error "node \"$parent\" is a descendant of \"$node\""
        }
        set p [Tree::parent $path $p]
    }

    set oldp        [lindex $data($node) 0]
    set idx         [lsearch -exact $data($oldp) $node]
    set data($oldp) [lreplace $data($oldp) $idx $idx]
    set data($node) [concat [list $parent] [lrange $data($node) 1 end]]

    if {[string equal $index "end"]} {
        lappend data($parent) $node
    } else {
        set data($parent) [linsert $data($parent) [incr index] $node]
    }

    if {([string equal $oldp "root"] ||
          ([visible $path $oldp] && [Widget::getoption $path.$oldp -open]))
          || ([string equal $parent "root"] ||
          ([visible $path $parent]
               && [Widget::getoption $path.$parent -open]))} {
        _redraw_idle $path 3
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::reorder
# ----------------------------------------------------------------------------
proc Tree::reorder { path node neworder } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if { ![info exists data($node)] } {
        return -code error "node \"$node\" does not exist"
    }
    set children [lrange $data($node) 1 end]
    if { [llength $children] } {
        set children [BWidget::lreorder $children $neworder]
        set data($node) [linsert $children 0 [lindex $data($node) 0]]
        if { [visible $path $node] && [Widget::getoption $path.$node -open] } {
            _redraw_idle $path 3
        }
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::selection
# ----------------------------------------------------------------------------
proc Tree::selection { path cmd args } {
    Widget::getVariable $path data

    switch -- $cmd {
	toggle {
            foreach node $args {
                set node [_node_name $path $node]
                if {![info exists data($node)]} {
		    return -code error "$path selection toggle: 
                        Cannot toggle unknown node \"$node\"."
		}
	    }

            foreach node $args {
                set node [_node_name $path $node]
                if {[set idx [lsearch -exact $data(selnodes) $node]] != -1} {
                    set data(selnodes) [lreplace $data(selnodes) $idx $idx]
		} else {
                    lappend data(selnodes) $node
		}
            }
	}

        set {
            foreach node $args {
                set node [_node_name $path $node]
                if {![info exists data($node)]} {
		    return -code error "$path selection set: \
                        Cannot select unknown node \"$node\"."
		}
	    }
            set data(selnodes) {}
            foreach node $args {
                set node [_node_name $path $node]
		if { [Widget::getoption $path.$node -selectable] } {
		    if { [lsearch -exact $data(selnodes) $node] == -1 } {
			lappend data(selnodes) $node
		    }
		}
            }
	    _call_selectcmd $path
        }

        add {
            foreach node $args {
                set node [_node_name $path $node]
                if {![info exists data($node)]} {
		    return -code error "$path selection add: \
                        Cannot select unknown node \"$node\"."
		}
	    }

            foreach node $args {
                set node [_node_name $path $node]
		if {[Widget::getoption $path.$node -selectable]} {
		    if {[lsearch -exact $data(selnodes) $node] == -1} {
			lappend data(selnodes) $node
		    }
		}
            }
	    _call_selectcmd $path
        }

	range {
	    # Here's our algorithm:
	    #    make a list of all nodes, then take the range from node1
	    #    to node2 and select those nodes
	    #
	    # This works because of how this widget handles redraws:
	    #    The tree is always completely redrawn, and always from
	    #    top to bottom. So the list of visible nodes *is* the
	    #    list of nodes, and we can use that to decide which nodes
	    #    to select.

	    if {[llength $args] != 2} {
		return -code error \
                    [BWidget::wrongNumArgsString \
                        "$path selection range node1 node2"]
	    }

	    foreach {node1 node2} $args break

            set node1 [_node_name $path $node1]
            set node2 [_node_name $path $node2]
	    if {![info exists data($node1)]} {
		return -code error "$path selection range: \
                    Cannot start range at unknown node \"$node1\"."
	    }
	    if {![info exists data($node2)]} {
		return -code error "$path selection range: \
                    Cannot end range at unknown node \"$node2\"."
	    }

	    set nodes {}
	    foreach nodeItem [$path.c find withtag node] {
		set node [Tree::_get_node_name $path $nodeItem 2]
		if { [Widget::getoption $path.$node -selectable] } {
		    lappend nodes $node
		}
	    }

	    # surles: Set the root string to the first element on the list.
	    if {$node1 == "root"} {
		set node1 [lindex $nodes 0]
	    }

	    if {$node2 == "root"} {
		set node2 [lindex $nodes 0]
	    }

	    # Find the first visible ancestor of node1, starting with node1
	    while {[set index1 [lsearch -exact $nodes $node1]] == -1} {
		set node1 [lindex $data($node1) 0]
	    }

	    # Find the first visible ancestor of node2, starting with node2
	    while {[set index2 [lsearch -exact $nodes $node2]] == -1} {
		set node2 [lindex $data($node2) 0]
	    }

	    # If the nodes were given in backwards order, flip the
	    # indices now
	    if {$index2 < $index1} {
		incr index1 $index2
		set index2 [expr {$index1 - $index2}]
		set index1 [expr {$index1 - $index2}]
	    }

	    set data(selnodes) [lrange $nodes $index1 $index2]
	    _call_selectcmd $path
	}

        remove {
            foreach node $args {
                set node [_node_name $path $node]
                if { [set idx [lsearch -exact $data(selnodes) $node]] != -1 } {
                    set data(selnodes) [lreplace $data(selnodes) $idx $idx]
                }
            }
	    _call_selectcmd $path
        }

        clear {
	    if {[llength $args] != 0} {
		return -code error \
                    [BWidget::wrongNumArgsString "$path selection clear"]
	    }
            set data(selnodes) {}
	    _call_selectcmd $path
        }

        get {
	    if {[llength $args] != 0} {
		return -code error \
                    [BWidget::wrongNumArgsString "$path selection get"]
	    }
            return $data(selnodes)
        }

        includes {
	    if {[llength $args] != 1} {
		return -code error \
                    [BWidget::wrongNumArgsString \
                        "$path selection includes node"]
	    }
	    set node [lindex $args 0]
            set node [_node_name $path $node]
            return [expr {[lsearch -exact $data(selnodes) $node] != -1}]
        }

        default {
            return
        }
    }

    event generate $path <<TreeSelect>>

    _redraw_idle $path 1
}


proc Tree::getcanvas { path } {
    return $path.c
}


# ----------------------------------------------------------------------------
#  Command Tree::exists
# ----------------------------------------------------------------------------
proc Tree::exists { path node } {
    Widget::getVariable $path data
    set node [_node_name $path $node]
    return [info exists data($node)]
}


# ----------------------------------------------------------------------------
#  Command Tree::visible
# ----------------------------------------------------------------------------
proc Tree::visible { path node } {
    Widget::getVariable $path items
    set node [_node_name $path $node]
    return [info exists items($node)]
}


# ----------------------------------------------------------------------------
#  Command Tree::parent
# ----------------------------------------------------------------------------
proc Tree::parent { path node } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }
    return [lindex $data($node) 0]
}


# ----------------------------------------------------------------------------
#  Command Tree::index
# ----------------------------------------------------------------------------
proc Tree::index { path node } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {[string equal $node "root"] || ![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }
    set parent [lindex $data($node) 0]
    return [expr {[lsearch -exact $data($parent) $node] - 1}]
}


# ----------------------------------------------------------------------------
#  Tree::find
#     Returns the node given a position.
#  findInfo     @x,y ?confine?
#               lineNumber
# ----------------------------------------------------------------------------
proc Tree::find { path findInfo {confine ""} } {
    if {[regexp -- {^@([0-9]+),([0-9]+)$} $findInfo match x y]} {
        set x [$path.c canvasx $x]
        set y [$path.c canvasy $y]
    } elseif {[regexp -- {^[0-9]+$} $findInfo lineNumber]} {
        set dy [Widget::cget $path -deltay]
        set y  [expr {$dy*($lineNumber+0.5)}]
        set confine ""
    } else {
        return -code error "invalid find spec \"$findInfo\""
    }

    set found  0
    set region [$path.c bbox all]
    if {[llength $region]} {
        set xi [lindex $region 0]
        set xs [lindex $region 2]
        foreach id [$path.c find overlapping $xi $y $xs $y] {
            set ltags [$path.c gettags $id]
            set item  [lindex $ltags 1]
            if { [string equal $item "node"] ||
                 [string equal $item "img"]  ||
                 [string equal $item "win"] } {
                # item is the label or image/window of the node
                set node  [Tree::_get_node_name $path $id 2]
                set found 1
                break
            }
        }
    }

    if {$found} {
        if {[string equal $confine "confine"]} {
            # test if x stand inside node bbox
	    set padx [_get_node_padx $path $node]
            set xi [expr {[lindex [$path.c coords n:$node] 0] - $padx}]
            set xs [lindex [$path.c bbox n:$node] 2]
            if {$x >= $xi && $x <= $xs} {
                return $node
            }
        } else {
            return $node
        }
    }

    return
}


# ----------------------------------------------------------------------------
#  Command Tree::line
#     Returns the line where is drawn a node.
# ----------------------------------------------------------------------------
proc Tree::line { path node } {
    Widget::getVariable $path items
    set node [_node_name $path $node]
    set line [lindex $items($node) 0]
    if {[string length $line]} { return $line }
    return -1
}


# ----------------------------------------------------------------------------
#  Command Tree::nodes
# ----------------------------------------------------------------------------
proc Tree::nodes { path node {first ""} {last ""} } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    if {![string length $first]} {
        return [lrange $data($node) 1 end]
    }

    if {![string length $last]} {
        return [lindex [lrange $data($node) 1 end] $first]
    } else {
        return [lrange [lrange $data($node) 1 end] $first $last]
    }
}


# Tree::visiblenodes --
#
#	Retrieve a list of all the nodes in a tree.
#
# Arguments:
#	path	Tree to retrieve nodes for.
#       node    Starting node.
#
# Results:
#	nodes	list of nodes in the tree.

proc Tree::visiblenodes { path {node root} } {
    Widget::getVariable $path data

    set nodes [list]
    foreach node [lrange $data($node) 1 end] {
        lappend nodes $node
        if {[Widget::getoption $path.$node -open]} {
            eval lappend nodes [Tree::visiblenodes $path $node]
        }
    }

    return $nodes
}

# ----------------------------------------------------------------------------
#  Command Tree::see
# ----------------------------------------------------------------------------
proc Tree::see { path node } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set node [_node_name $path $node]
    if {[Widget::getoption $path -redraw] && $data(upd,afterid) != ""} {
        after cancel $data(upd,afterid)
        _redraw_tree $path
    }

    if {[info exists items($node)]} {
        Tree::_see $path [lindex $items($node) 1]
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::opentree
# ----------------------------------------------------------------------------
# JDC: added option recursive
proc Tree::opentree { path node {recursive 1} } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {[string equal $node "root"] || ![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    _recexpand $path $node 1 $recursive [Widget::getoption $path -opencmd]
    _redraw_idle $path 3
}


# ----------------------------------------------------------------------------
#  Command Tree::closetree
# ----------------------------------------------------------------------------
proc Tree::closetree { path node {recursive 1} } {
    Widget::getVariable $path data

    set node [_node_name $path $node]
    if {[string equal $node "root"] || ![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    _recexpand $path $node 0 $recursive [Widget::getoption $path -closecmd]
    _redraw_idle $path 3
}


proc Tree::toggle { path node } {
    if {[Tree::itemcget $path $node -open]} {
        $path closetree $node 0
    } else {
        $path opentree $node 0
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::edit
# ----------------------------------------------------------------------------
proc Tree::edit { path node text {verifycmd ""} {clickres 0} {select 1}} {
    variable _edit
    Widget::getVariable $path data
    Widget::getVariable $path items

    set node [_node_name $path $node]
    if { [Widget::getoption $path -redraw] && $data(upd,afterid) != "" } {
        after cancel $data(upd,afterid)
        _redraw_tree $path
    }

    if {[info exists items($node)]} {
        set _edit(editing) 1

        set idn [lindex $items($node) 1]

        Tree::_see $path $idn

        set oldfg  [$path.c itemcget $idn -fill]
        set sbg    [Widget::cget $path -selectbackground]
        set coords [$path.c coords $idn]
        set x      [lindex $coords 0]
        set y      [lindex $coords 1]
        set ht     [$path.c cget -highlightthickness]
        set bd     [expr {[$path.c cget -borderwidth] + $ht}]
        set w      [expr {[winfo width $path] - 2 * $bd}]
        set wmax   [expr {[$path.c canvasx $w] - $x}]

        set _edit(wait) 0
        set _edit(path) $path
        set _edit(node) $node
        set _edit(text) $text

        $path.c itemconfigure $idn    -fill [Widget::cget $path -background]
        $path.c itemconfigure s:$node -fill {} -outline {}

        set frame  [frame $path.edit \
                    -relief flat -borderwidth 0 -highlightthickness 0 \
                    -background [Widget::cget $path -background]]
        set ent    [entry $frame.edit \
                    -width              0     \
                    -relief             solid \
                    -borderwidth        1     \
                    -highlightthickness 0     \
                    -foreground         [Widget::getoption $path.$node -fill] \
                    -background         [Widget::cget $path -background] \
                    -selectforeground   [Widget::cget $path -selectforeground] \
                    -selectbackground   $sbg  \
                    -font               [_get_option $path $node -font] \
                    -textvariable       Tree::_edit(text)]
        pack $ent -ipadx 8 -anchor w

        set _edit(frame) $frame
        set _edit(entry) $ent

        set idw [$path.c create window $x $y -window $frame -anchor w]
        trace variable Tree::_edit(text) w \
	    [list Tree::_update_edit_size $path $ent $idw $wmax]
        tkwait visibility $ent
        grab  $frame
        BWidget::focus set $ent

        _update_edit_size $path $ent $idw $wmax
        update

        if {$select} {
            $ent selection range 0 end
            $ent icursor end
            $ent xview end
        }

        bindtags $ent [list $ent Entry]
        bind $ent <Escape> {set Tree::_edit(wait) 0}
        bind $ent <Return> {set Tree::_edit(wait) 1}
        if {$clickres == 0 || $clickres == 1} {
            bind $frame <Button>  [list set Tree::_edit(wait) $clickres]
        }

        set ok 0
        while {!$ok} {
            focus -force $ent
            tkwait variable Tree::_edit(wait)
            if {!$_edit(wait) || ![llength $verifycmd] ||
                 [uplevel \#0 $verifycmd [list $_edit(text)]]} {
                set ok 1
            }
        }

        trace vdelete Tree::_edit(text) w \
	    [list Tree::_update_edit_size $path $ent $idw $wmax]
        grab release $frame
        BWidget::focus release $ent

        set _edit(editing) 0

        destroy $frame
        $path.c delete $idw
        $path.c itemconfigure $idn    -fill $oldfg
        $path.c itemconfigure s:$node -fill $sbg -outline $sbg

        if {$_edit(wait)} {
            return $_edit(text)
        }
    }
}


proc Tree::editing { path } {
    variable _edit
    if {$_edit(editing) && $_edit(path) eq $path} { return 1 }
    return 0
}


# ----------------------------------------------------------------------------
#  Command Tree::xview
# ----------------------------------------------------------------------------
proc Tree::xview { path args } {
    return [eval [linsert $args 0 $path.c xview]]
}


# ----------------------------------------------------------------------------
#  Command Tree::yview
# ----------------------------------------------------------------------------
proc Tree::yview { path args } {
    return [eval [linsert $args 0 $path.c yview]]
}


proc Tree::search { path args } {
    Widget::getVariable $path data

    array set _args {
        -pattern  *
    }
    array set _args $args

    return [array names data $_args(-pattern)]
}


proc Tree::level { path node } {
    Widget::getVariable $path data

    if {[string equal $node "root"]} { return 0 }

    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exists"
    }

    set level  1
    set parent [lindex $data($node) 0]
    while {![string equal $parent "root"]} {
        incr level
        set parent [lindex $data($parent) 0]
    }

    return $level
}


proc Tree::_call_selectcmd { path } {
    Widget::getVariable $path data

    set selectcmd [Widget::getoption $path -selectcommand]
    if {[llength $selectcmd]} {
	lappend selectcmd $path
	lappend selectcmd $data(selnodes)
	uplevel \#0 $selectcmd
    }
    return
}


# ----------------------------------------------------------------------------
#  Command Tree::_update_edit_size
# ----------------------------------------------------------------------------
proc Tree::_update_edit_size { path entry idw wmax args } {
    set entw [winfo reqwidth $entry]
    if {$entw + 8 >= $wmax} {
        $path.c itemconfigure $idw -width $wmax
    } else {
        $path.c itemconfigure $idw -width 0
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_see
# ----------------------------------------------------------------------------
proc Tree::_see { path idn } {
    set bbox [$path.c bbox $idn]
    set scrl [$path.c cget -scrollregion]

    set ymax [lindex $scrl 3]
    set dy   [$path.c cget -yscrollincrement]
    set yv   [$path yview]
    set yv0  [expr {round([lindex $yv 0]*$ymax/$dy)}]
    set yv1  [expr {round([lindex $yv 1]*$ymax/$dy)}]
    set y    [expr {int([lindex [$path.c coords $idn] 1]/$dy)}]

    if {$y < $yv0} {
        $path.c yview scroll [expr {$y-$yv0}] units
    } elseif { $y >= $yv1 } {
        $path.c yview scroll [expr {$y-$yv1+1}] units
    }

    set xmax [lindex $scrl 2]
    set dx   [$path.c cget -xscrollincrement]
    set xv   [$path xview]
    set x0   [expr {int([lindex $bbox 0]/$dx)}]
    set xv0  [expr {round([lindex $xv 0]*$xmax/$dx)}]
    set xv1  [expr {round([lindex $xv 1]*$xmax/$dx)}]

    if {$x0 >= $xv1 || $x0 < $xv0} {
	$path.c xview scroll [expr {$x0-$xv0}] units
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_recexpand
# ----------------------------------------------------------------------------
# JDC : added option recursive
proc Tree::_recexpand { path node expand recursive cmd } {
    Widget::getVariable $path data

    if {[Widget::getoption $path.$node -open] != $expand} {
        Widget::setoption $path.$node -open $expand
        if {[llength $cmd]} {
            uplevel \#0 $cmd [list $node]
        }
    }

    if {$recursive} {
	foreach subnode [lrange $data($node) 1 end] {
	    _recexpand $path $subnode $expand $recursive $cmd
	}
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_subdelete
# ----------------------------------------------------------------------------
proc Tree::_subdelete { path lnodes } {
    Widget::getVariable $path data

    set sel $data(selnodes)

    while {[llength $lnodes]} {
        set lsubnodes [list]
        foreach node $lnodes {
            foreach subnode [lrange $data($node) 1 end] {
                lappend lsubnodes $subnode
            }
            unset data($node)
	    set idx [lsearch -exact $sel $node]
	    if {$idx >= 0} {
		set sel [lreplace $sel $idx $idx]
	    }
            if {[set win [Widget::getoption $path.$node -window]] != ""} {
                destroy $win
            }
            Widget::destroy $path.$node 0
        }
        set lnodes $lsubnodes
    }

    set data(selnodes) $sel
}


# ----------------------------------------------------------------------------
#  Command Tree::_update_scrollregion
# ----------------------------------------------------------------------------
proc Tree::_update_scrollregion { path } {
    set bd   [$path.c cget -borderwidth]
    set ht   [$path.c cget -highlightthickness]
    set bd   [expr {2 * ($bd + $ht)}]
    set w    [expr {[winfo width  $path] - $bd}]
    set h    [expr {[winfo height $path] - $bd}]
    set xinc [$path.c cget -xscrollincrement]
    set yinc [$path.c cget -yscrollincrement]
    set bbox [$path.c bbox node]
    if {[llength $bbox]} {
        set xs [lindex $bbox 2]
        set ys [lindex $bbox 3]

        if {$w < $xs} {
            set w [expr {int($xs)}]
            if {[set r [expr {$w % $xinc}]]} {
                set w [expr {$w+$xinc-$r}]
            }
        }
        if {$h < $ys} {
            set h [expr {int($ys)}]
            if {[set r [expr {$h % $yinc}]]} {
                set h [expr {$h+$yinc-$r}]
            }
        }
    }

    $path.c configure -scrollregion [list 0 0 $w $h]

    if {[Widget::getoption $path -selectfill]} {
        _redraw_selection $path
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_cross_event
# ----------------------------------------------------------------------------
proc Tree::_cross_event { path } {
    Widget::getVariable $path data

    set node [Tree::_get_node_name $path current 1]
    if {[Widget::getoption $path.$node -open]} {
        Tree::itemconfigure $path $node -open 0
        if {[llength [set cmd [Widget::getoption $path -closecmd]]]} {
            uplevel \#0 $cmd [list $node]
        }
    } else {
        Tree::itemconfigure $path $node -open 1
        if {[llength [set cmd [Widget::getoption $path -opencmd]]]} {
            uplevel \#0 $cmd [list $node]
        }
    }
}


proc Tree::_draw_cross { path node open x y } {
    Widget::getVariable $path items
    set idc [lindex $items($node) 2]

    if {$open} {
        set img [Widget::cget $path -crossopenimage]
        set bmp [Widget::cget $path -crossopenbitmap]
    } else {
        set img [Widget::cget $path -crosscloseimage]
        set bmp [Widget::cget $path -crossclosebitmap]
    }

    ## If we already have a cross for this node, we just adjust the image.
    if {[string length $idc]} {
        if {![string length $img]} {
            $path.c itemconfigure $idc -bitmap $bmp
        } else {
            $path.c itemconfigure $idc -image $img
        }
        return $idc
    }

    if {![Widget::getoption $path -showlines]} { set x [expr {$x + 6}] }

    ## Create a new image for the cross.  If the user has specified an
    ## image, it overrides a bitmap.
    if {![string length $img]} {
        set idc [$path.c create bitmap $x $y \
            -bitmap     $bmp \
            -background [$path.c cget -background] \
            -foreground [Widget::getoption $path -crossfill] \
            -tags       [list cross c:$node] -anchor c]
    } else {
        set idc [$path.c create image $x $y \
            -image      $img \
            -tags       [list cross c:$node] -anchor c]
    }

    return $idc
}


# ----------------------------------------------------------------------------
#  Command Tree::_draw_node
# ----------------------------------------------------------------------------
proc Tree::_draw_node { path node x0 y0 deltax deltay padx showlines } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set x1 [expr {$x0+$deltax+5}]
    set y1 $y0
    if {$showlines} {
        set i [$path.c create line $x0 $y0 $x1 $y0 \
            -fill    [Widget::getoption $path -linesfill]   \
            -stipple [Widget::getoption $path -linestipple] \
            -tags    line]

        lappend items($node) $i
    } else {
        lappend items($node) ""
    }

    set i [$path.c create text [expr {$x1+$padx}] $y0 \
        -anchor w \
        -text   [Widget::getoption $path.$node -text] \
        -fill   [Widget::getoption $path.$node -fill] \
        -font   [_get_option $path $node -font] \
    	-tags   [Tree::_get_node_tags $path $node [list node n:$node]]]
    lappend items($node) $i

    set len [expr {[llength $data($node)] > 1}]
    set dc  [Widget::getoption $path.$node -drawcross]
    set exp [Widget::getoption $path.$node -open]

    if {$len && $exp} {
        set y1 [_draw_subnodes $path [lrange $data($node) 1 end] \
                [expr {$x0+$deltax}] $y0 $deltax $deltay $padx $showlines]
    }

    if {![string equal $dc "never"] && ($len || [string equal $dc "allways"])} {
        lappend items($node) [_draw_cross $path $node $exp $x0 $y0]
    } else {
        lappend items($node) ""
    }

    if {[set win [Widget::getoption $path.$node -window]] != ""} {
	set a [Widget::cget $path.$node -anchor]
        set i [$path.c create window $x1 $y0 -window $win -anchor $a \
		-tags [Tree::_get_node_tags $path $node [list win i:$node]]]
        lappend items($node) $i
    } elseif {[set img [Widget::getoption $path.$node -image]] != ""} {
	set a [Widget::cget $path.$node -anchor]
        set i [$path.c create image $x1 $y0 -image $img -anchor $a \
		-tags   [Tree::_get_node_tags $path $node [list img i:$node]]]
        lappend items($node) $i
    } else {
        lappend items($node) ""
    }

    set nid [lindex $items($node) 1]
    set iid [lindex $items($node) 3]
    set box [$path.c bbox $nid $iid]
    set id [$path.c create rect 0 [lindex $box 1] \
		[winfo screenwidth $path] [lindex $box 3] \
		-tags [Tree::_get_node_tags $path $node [list box b:$node]] \
		-fill {} -outline {}]
    $path.c lower $id
    lappend items($node) $id

    _set_help $path $node

    return $y1
}


# ----------------------------------------------------------------------------
#  Command Tree::_draw_subnodes
# ----------------------------------------------------------------------------
proc Tree::_draw_subnodes { path nodes x0 y0 deltax deltay padx showlines } {
    set y1 $y0
    foreach node $nodes {
	set padx   [_get_node_padx $path $node]
	set deltax [_get_node_deltax $path $node]
        set yp $y1
        set y1 [_draw_node $path $node $x0 [expr {$y1+$deltay}] \
                $deltax $deltay $padx $showlines]
    }
    if {$showlines && [llength $nodes]} {
	if {$y0 < 0} {
	    # Adjust the drawing of the line to the first root node
	    # to start at the vertical point (not go up).
	    incr y0 $deltay
	}
        set id [$path.c create line $x0 $y0 $x0 [expr {$yp+$deltay}] \
                    -fill    [Widget::getoption $path -linesfill]   \
                    -stipple [Widget::getoption $path -linestipple] \
                    -tags    line]

        $path.c lower $id
    }
    return $y1
}


# ----------------------------------------------------------------------------
#  Command Tree::_update_nodes
# ----------------------------------------------------------------------------
proc Tree::_update_nodes { path } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    foreach {node flag} $data(upd,nodes) {
        if {![info exists items($node)]} { continue }
        set idn [lindex $items($node) 1]

	set padx   [_get_node_padx $path $node]
	set deltax [_get_node_deltax $path $node]
	set c  [$path.c coords $idn]
	set x1 [expr {[lindex $c 0]-$padx}]
	set x0 [expr {$x1-$deltax-5}]
	set y0 [lindex $c 1]
	if {$flag & 48} {
	    # -window or -image modified
	    set win  [Widget::getoption $path.$node -window]
	    set img  [Widget::getoption $path.$node -image]
	    set anc  [Widget::cget $path.$node -anchor]
            set idi  [lindex $items($node) 3]
	    set type [lindex [$path.c gettags $idi] 1]
	    if {[string length $win]} {
		if {[string equal $type "win"]} {
		    $path.c itemconfigure $idi -window $win
		} else {
		    $path.c delete $idi
                    set tags [_get_node_tags $path $node [list win i:$node]]
		    set idi [$path.c create window $x1 $y0 -window $win \
                        -anchor $anc -tags $tags]
                    set items($node) [lreplace $items($node) 3 3 $idi]
		}
	    } elseif {[string length $img]} {
		if {[string equal $type "img"]} {
		    $path.c itemconfigure $idi -image $img
		} else {
		    $path.c delete $idi
                    set tags [_get_node_tags $path $node [list win i:$node]]
		    set idi [$path.c create image $x1 $y0 -image $img \
                        -anchor $anc -tags $tags]
                    set items($node) [lreplace $items($node) 3 3 $idi]
		}
	    } else {
		$path.c delete $idi
                set items($node) [lreplace $items($node) 3 3 ""]
	    }
	}

	if {$flag & 8} {
	    # -drawcross modified
	    set len [expr {[llength $data($node)] > 1}]
	    set dc  [Widget::getoption $path.$node -drawcross]
	    set exp [Widget::getoption $path.$node -open]

	    if {![string equal $dc "never"]
		&& ($len || [string equal $dc "allways"])} {
		set idc [_draw_cross $path $node $exp $x0 $y0]
                set items($node) [lreplace $items($node) 2 2 $idc]
	    } else {
                set idc [lindex $items($node) 2]
		$path.c delete $idc
                set items($node) [lreplace $items($node) 2 2 ""]
	    }
	}

	if {$flag & 7} {
	    # -font, -text or -fill modified
	    $path.c itemconfigure $idn \
		-text [Widget::getoption $path.$node -text] \
		-fill [Widget::getoption $path.$node -fill] \
		-font [_get_option $path $node -font]
	}
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_draw_tree
# ----------------------------------------------------------------------------
proc Tree::_draw_tree { path } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    if {[info exists items]} { unset items }

    $path.c delete all
    set cursor [$path.c cget -cursor]
    $path.c configure -cursor watch

    set x0 8
    if {![Widget::getoption $path -showlines]} { set x0 0 }

    Tree::_draw_subnodes $path [lrange $data(root) 1 end] $x0 \
        [expr {-[Widget::cget $path -deltay]/2}] \
        [Widget::getoption $path -deltax] \
        [Widget::cget $path -deltay] \
        [Widget::getoption $path -padx]   \
        [Widget::getoption $path -showlines]
    $path.c configure -cursor $cursor
}


# ----------------------------------------------------------------------------
#  Command Tree::_redraw_tree
# ----------------------------------------------------------------------------
proc Tree::_redraw_tree { path } {
    Widget::getVariable $path data

    if {[Widget::getoption $path -redraw]} {
        if {$data(upd,level) == 2} {
            _update_nodes $path
        } elseif {$data(upd,level) == 3} {
            _draw_tree $path
        }
        _redraw_selection $path
        _update_scrollregion $path
        set data(upd,nodes)   {}
        set data(upd,level)   0
        set data(upd,afterid) ""
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_redraw_selection
# ----------------------------------------------------------------------------
proc Tree::_redraw_selection { path } {
    Widget::getVariable $path data

    set selbg [Widget::cget $path -selectbackground]
    set selfg [Widget::cget $path -selectforeground]
    set fill  [Widget::getoption $path -selectfill]
    if {$fill} {
        set scroll [$path.c cget -scrollregion]
        if {[llength $scroll]} {
            set xmax [expr {[lindex $scroll 2]-1}]
        } else {
            set xmax [winfo width $path]
        }
    }
    foreach id [$path.c find withtag sel] {
        set node [Tree::_get_node_name $path $id 1]
        $path.c itemconfigure "n:$node" \
            -fill [Widget::getoption $path.$node -fill]
    }
    $path.c delete sel
    foreach node $data(selnodes) {
        set bbox [$path.c bbox "n:$node"]
        if {[llength $bbox]} {
            if {$fill} {
		# get the image to (if any), as it may have different height
		set bbox [$path.c bbox "n:$node" "i:$node"]
                set bbox [list 0 [lindex $bbox 1] $xmax [lindex $bbox 3]]
            }
            set id [$path.c create rectangle $bbox -tags [list sel s:$node] \
			-fill $selbg -outline $selbg]
            $path.c itemconfigure "n:$node" -fill $selfg
            $path.c lower $id
        }
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_redraw_idle
# ----------------------------------------------------------------------------
proc Tree::_redraw_idle { path level } {
    Widget::getVariable $path data

    if {[Widget::getoption $path -redraw] && $data(upd,afterid) == ""} {
        set data(upd,afterid) [after idle [list Tree::_redraw_tree $path]]
    }
    if {$level > $data(upd,level)} {
        set data(upd,level) $level
    }
    return ""
}


# ----------------------------------------------------------------------------
#  Command Tree::_init_drag_cmd
# ----------------------------------------------------------------------------
proc Tree::_init_drag_cmd { path X Y top } {
    set path [winfo parent $path]
    set ltags [$path.c gettags current]
    set item  [lindex $ltags 1]
    if {[string equal $item "node"]
        || [string equal $item "img"]
        || [string equal $item "win"]} {
        set node [Tree::_get_node_name $path current 2]
        if {[llength [set cmd [Widget::getoption $path -draginitcmd]]]} {
            return [uplevel \#0 $cmd [list $path $node $top]]
        }
        if {[set type [Widget::getoption $path -dragtype]] == ""} {
            set type "TREE_NODE"
        }
        if {[set img [Widget::getoption $path.$node -image]] != ""} {
            pack [label $top.l -image $img -padx 0 -pady 0]
        }
        return [list $type {copy move link} $node]
    }
    return {}
}


# ----------------------------------------------------------------------------
#  Command Tree::_drop_cmd
# ----------------------------------------------------------------------------
proc Tree::_drop_cmd { path source X Y op type dnddata } {
    set path [winfo parent $path]
    Widget::getVariable $path data

    $path.c delete drop
    if {[string length $data(dnd,afterid)]} {
        after cancel $data(dnd,afterid)
        set data(dnd,afterid) ""
    }
    set data(dnd,scroll) ""
    if {[llength $data(dnd,node)]
	&& [llength [set cmd [Widget::getoption $path -dropcmd]]]} {
	return [uplevel \#0 $cmd \
                [list $path $source $data(dnd,node) $op $type $dnddata]]
    }
    return 0
}


# ----------------------------------------------------------------------------
#  Command Tree::_over_cmd
# ----------------------------------------------------------------------------
proc Tree::_over_cmd { path source event X Y op type dnddata } {
    set path [winfo parent $path]
    Widget::getVariable $path data

    if {[string equal $event "leave"]} {
        # we leave the window tree
        $path.c delete drop
        if {[string length $data(dnd,afterid)]} {
            after cancel $data(dnd,afterid)
            set data(dnd,afterid) ""
        }
        set data(dnd,scroll) ""
        return 0
    }

    if {[string equal $event "enter"]} {
        # we enter the window tree - dnd data initialization
        set mode [Widget::getoption $path -dropovermode]
        set data(dnd,mode) 0
        foreach c {w p n} {
            set data(dnd,mode) [expr {($data(dnd,mode) << 1) 
                                | ([string first $c $mode] != -1)}]
        }
        set bbox [$path.c bbox all]
        if {[llength $bbox]} {
            set data(dnd,xs) [lindex $bbox 2]
            set data(dnd,empty) 0
        } else {
            set data(dnd,xs) 0
            set data(dnd,empty) 1
        }
        set data(dnd,node) {}
    }

    set x [expr {$X-[winfo rootx $path]}]
    set y [expr {$Y-[winfo rooty $path]}]

    $path.c delete drop
    set data(dnd,node) {}

    # test for auto-scroll unless mode is widget only
    if {$data(dnd,mode) != 4 && [_auto_scroll $path $x $y] != ""} { return 2 }

    if {$data(dnd,mode) & 4} {
        # dropovermode includes widget
        set target [list widget]
        set vmode  4
    } else {
        set target [list ""]
        set vmode  0
    }

    if {($data(dnd,mode) & 2) && $data(dnd,empty)} {
        # dropovermode includes position and tree is empty
        lappend target [list root 0]
        set vmode  [expr {$vmode | 2}]
    }

    set xs $data(dnd,xs)
    set xc [$path.c canvasx $x]
    if {$xc <= $xs} {
        set yc   [$path.c canvasy $y]
        set dy   [$path.c cget -yscrollincrement]
        set line [expr {int($yc/$dy)}]
        set xi   0
        set yi   [expr {$line*$dy}]
        set ys   [expr {$yi+$dy}]
        set found 0
        foreach id [$path.c find overlapping $xi $yi $xs $ys] {
            set ltags [$path.c gettags $id]
            set item  [lindex $ltags 1]
            if {[string equal $item "node"]
                || [string equal $item "img"]
                || [string equal $item "win"]} {
                # item is the label or image/window of the node
                set node [Tree::_get_node_name $path $id 2]
		set found 1
		break
	    }
	}

	if {$found} {
	    set padx   [_get_node_padx $path $node]
	    set deltax [_get_node_deltax $path $node]
            set xi [expr {[lindex [$path.c coords n:$node] 0] - $padx - 1}]
                if {$data(dnd,mode) & 1} {
                    # dropovermode includes node
                    lappend target $node
                    set vmode [expr {$vmode | 1}]
                } else {
                    lappend target ""
                }

                if {$data(dnd,mode) & 2} {
                    # dropovermode includes position
                    if {$yc >= $yi+$dy/2} {
                        # position is after $node
                        if {[Widget::getoption $path.$node -open] &&
                             [llength $data($node)] > 1} {
                            # $node is open and have subnodes
                            # drop position is 0 in children of $node
                            set parent $node
                            set index  0
                            set xli    [expr {$xi-5}]
                        } elseif {[Widget::getoption $path.$node -open]} {
                            ## $node is open but has no children.
                            set parent $node
                            set index  0
                            set xli    [expr {$xi-5}]
                        } else {
                            # $node is not open and doesn't have subnodes
                            # drop position is after $node in children of
                            # parent of $node
                            set parent [lindex $data($node) 0]
                            set index  [lsearch -exact $data($parent) $node]
                            set xli    [expr {$xi - $deltax - 5}]
                        }
                        set yl $ys
                    } else {
                        # position is before $node
                        # drop position is before $node in children of parent
                        # of $node
                        set parent [lindex $data($node) 0]
                        set index \
                            [expr {[lsearch -exact $data($parent) $node] - 1}]
                        set xli    [expr {$xi - $deltax - 5}]
                        set yl     $yi
                    }
                    lappend target [list $parent $index]
                    set vmode  [expr {$vmode | 2}]
                } else {
                    lappend target {}
                }

                if {($vmode & 3) == 3} {
                    # result have both node and position
                    # we compute what is the preferred method
                    if {$yc-$yi <= 3 || $ys-$yc <= 3} {
                        lappend target "position"
                    } else {
                        lappend target "node"
                    }
                }
            }
        }

    if {$vmode && [llength [set cmd [Widget::getoption $path -dropovercmd]]]} {
        # user-defined dropover command
        set res     [uplevel \#0 $cmd \
                        [list $path $source $target $op $type $dnddata]]
        set code    [lindex $res 0]
        set newmode 0
        if {$code & 1} {
            # update vmode
            set mode [lindex $res 1]
            if {($vmode & 1) && [string equal $mode "node"]} {
                set newmode 1
            } elseif {($vmode & 2) && [string equal $mode "position"]} {
                set newmode 2
            } elseif {($vmode & 4) && [string equal $mode "widget"]} {
                set newmode 4
            }
        }
        set vmode $newmode
    } else {
        if {($vmode & 3) == 3} {
            # result have both item and position
            # we choose the preferred method
            if {[string equal [lindex $target 3] "position"]} {
                set vmode [expr {$vmode & ~1}]
            } else {
                set vmode [expr {$vmode & ~2}]
            }
        }

        if {$data(dnd,mode) == 4 || $data(dnd,mode) == 0} {
            # dropovermode is widget or empty - recall is not necessary
            set code 1
        } else {
            set code 3
        }
    }

    if {!$data(dnd,empty)} {
	# draw dnd visual following vmode
	if {$vmode & 1} {
	    set data(dnd,node) [list "node" [lindex $target 1]]
	    $path.c create rectangle $xi $yi $xs $ys -tags drop
	} elseif {$vmode & 2} {
	    set data(dnd,node) [concat "position" [lindex $target 2]]
	    $path.c create line \
                [list $xli [expr {$yl-$dy/2}] $xli $yl $xs $yl] -tags drop
	} elseif {$vmode & 4} {
	    set data(dnd,node) [list "widget"]
	} else {
	    set code [expr {$code & 2}]
	}
    }

    if {$code & 1} {
        DropSite::setcursor based_arrow_down
    } else {
        DropSite::setcursor dot
    }
    return $code
}


# Tree::_drag_and_drop --
#
#	A default command to handle drag-and-drop functions local to this
#       tree.  With this as the default -dropcmd, the user can simply
#       enable drag-and-drop and be able to move items within this tree
#       with no further code.
#
# Arguments:
#       Standard arguments passed to a dropcmd.
#
# Results:
#	none
proc Tree::_drag_and_drop { path from endItem operation type startItem } {
    ## This proc only handles drag-and-drop commands within itself.
    ## If the widget this came from is not our widget (minus the canvas),
    ## we don't want to do anything.  They need to handle this themselves.
    if {[winfo parent $from] != $path} { return }

    set place [lindex $endItem 0]

    switch -- $place {
        "node" {
            set node   [lindex $endItem 1]
            set parent [$path parent $node]
            set index  [$path index $node]
        }

        "position" {
            set parent [lindex $endItem 1]
            set index  [lindex $endItem 2]
        } 

        default {
            return
        }
    }

    if {[string equal $operation "copy"]} {
        set options [Widget::options $path.$startItem]
        eval $path insert $idx [list $startItem#auto] $options
    } else {
        $path move $parent $startItem $index
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::_auto_scroll
# ----------------------------------------------------------------------------
proc Tree::_auto_scroll { path x y } {
    Widget::getVariable $path data

    set xmax   [winfo width  $path]
    set ymax   [winfo height $path]
    set scroll {}
    if {$y <= 6} {
        if {[lindex [$path.c yview] 0] > 0} {
            set scroll [list yview -1]
            DropSite::setcursor sb_up_arrow
        }
    } elseif {$y >= $ymax-6} {
        if {[lindex [$path.c yview] 1] < 1} {
            set scroll [list yview 1]
            DropSite::setcursor sb_down_arrow
        }
    } elseif {$x <= 6} {
        if {[lindex [$path.c xview] 0] > 0} {
            set scroll [list xview -1]
            DropSite::setcursor sb_left_arrow
        }
    } elseif {$x >= $xmax-6} {
        if {[lindex [$path.c xview] 1] < 1} {
            set scroll [list xview 1]
            DropSite::setcursor sb_right_arrow
        }
    }

    if {[string length $data(dnd,afterid)]
        && ![string equal $data(dnd,scroll) $scroll]} {
        after cancel $data(dnd,afterid)
        set data(dnd,afterid) ""
    }

    set data(dnd,scroll) $scroll
    if {[string length $scroll] && ![string length $data(dnd,afterid)]} {
        set data(dnd,afterid) [after 200 [list Tree::_scroll $path $scroll]]
    }
    return $data(dnd,afterid)
}


# ----------------------------------------------------------------------------
#  Command Tree::_scroll
# ----------------------------------------------------------------------------
proc Tree::_scroll { path cmd dir } {
    Widget::getVariable $path data

    if {($dir == -1 && [lindex [$path.c $cmd] 0] > 0)
        || ($dir == 1  && [lindex [$path.c $cmd] 1] < 1)} {
        $path.c $cmd scroll $dir units
        set data(dnd,afterid) [after 100 [list Tree::_scroll $path $cmd $dir]]
    } else {
        set data(dnd,afterid) ""
        DropSite::setcursor dot
    }
}

# Tree::_keynav --
#
#	Handle navigational keypresses on the tree.
#
# Arguments:
#	which      tag indicating the direction of motion:
#                  up         move to the node graphically above current
#                  down       move to the node graphically below current
#                  left       close current if open, else move to parent
#                  right      open current if closed, else move to child
#                  open       open current if closed, close current if open
#       win        name of the tree widget
#
# Results:
#	None.

proc Tree::_keynav {which path} {
    # Keyboard navigation is riddled with special cases.  In order to avoid
    # the complex logic, we will instead make a list of all the visible,
    # selectable nodes, then do a simple next or previous operation.

    # One easy way to get all of the visible nodes is to query the canvas
    # object for all the items with the "node" tag; since the tree is always
    # completely redrawn, this list will be in vertical order.
    set nodes {}
    foreach nodeItem [$path.c find withtag node] {
	set node [Tree::_get_node_name $path $nodeItem 2]
	if {[Widget::cget $path.$node -selectable]} {
	    lappend nodes $node
	}
    }

    # Keyboard navigation is all relative to the current node
    # surles: Get the current node for single or multiple selection schemas.
    set node [_get_current_node $path]

    switch -exact -- $which {
	"up" {
	    # Up goes to the node that is vertically above the current node
	    # (NOT necessarily the current node's parent)
            if {![string length $node]} { return }

	    set index [lsearch -exact $nodes $node]
	    incr index -1
	    if {$index >= 0} {
		$path selection set [lindex $nodes $index]
		_set_current_node $path [lindex $nodes $index]
		$path see [lindex $nodes $index]
		return
	    }
	}

	"down" {
	    # Down goes to the node that is vertically below the current node
            if {![string length $node]} {
		$path selection set [lindex $nodes 0]
		_set_current_node $path [lindex $nodes 0]
		$path see [lindex $nodes 0]
		return
	    }

	    set index [lsearch -exact $nodes $node]
	    incr index
	    if {$index < [llength $nodes]} {
		$path selection set [lindex $nodes $index]
		_set_current_node $path [lindex $nodes $index]
		$path see [lindex $nodes $index]
		return
	    }
	}

	"right" {
	    # On a right arrow, if the current node is closed, open it.
	    # If the current node is open, go to its first child
            if {![string length $node]} { return }

            if {[Widget::getoption $path.$node -open]} {
                if { [llength [$path nodes $node]] } {
		    set index [lsearch -exact $nodes $node]
		    incr index
		    if {$index < [llength $nodes]} {
			$path selection set [lindex $nodes $index]
			_set_current_node $path [lindex $nodes $index]
			$path see [lindex $nodes $index]
			return
		    }
                }
            } else {
                $path itemconfigure $node -open 1
                if {[llength [set cmd [Widget::getoption $path -opencmd]]]} {
                    uplevel \#0 $cmd [list $node]
                }
                return
            }
	}

	"left" {
	    # On a left arrow, if the current node is open, close it.
	    # If the current node is closed, go to its parent.
            if {![string length $node]} { return }

	    if {[Widget::getoption $path.$node -open]} {
		$path itemconfigure $node -open 0
                if {[llength [set cmd [Widget::getoption $path -closecmd]]]} {
                    uplevel \#0 $cmd [list $node]
                }
		return
	    } else {
		set parent [$path parent $node]
	        if {[string equal $parent "root"]} {
		    set parent $node
                } else {
                    while {![$path itemcget $parent -selectable]} {
		        set parent [$path parent $parent]
		        if {[string equal $parent "root"]} {
			    set parent $node
			    break
		        }
                    }
		}
		$path selection set $parent
		_set_current_node $path $parent
		$path see $parent
		return
	    }
	}

	"space" {
            if {[string length $node]} {
                Tree::toggle $path $node
            }
	}
    }
}

# Tree::_get_current_node --
#
#	Get the current node for either single or multiple
#	node selection trees.  If the tree allows for 
#	multiple selection, return the cursor node.  Otherwise,
#	if there is a selection, return the first node in the
#	list.  If there is no selection, return the root node.
#
# arguments:
#       win        name of the tree widget
#
# Results:
#	The current node.

proc Tree::_get_current_node {win} {
    if {[info exists selectTree::selectCursor($win)]} {
	set result $selectTree::selectCursor($win)
    } elseif {[llength [set selList [$win selection get]]]} {
	set result [lindex $selList 0]
    } else {
	set result ""
    }
    return $result
}

# Tree::_set_current_node --
#
#	Set the current node for either single or multiple
#	node selection trees.
#
# arguments:
#       win        Name of the tree widget
#	node	   The current node.
#
# Results:
#	None.

proc Tree::_set_current_node {win node} {
    if {[info exists selectTree::selectCursor($win)]} {
	set selectTree::selectCursor($win) $node
    }
    return
}

# Tree::_get_node_name --
#
#	Given a canvas item, get the name of the tree node represented by that
#	item.
#
# Arguments:
#	path		tree to query
#	item		Optional canvas item to examine; if omitted, 
#			defaults to "current"
#	tagindex	Optional tag index, since the n:nodename tag is not
#			in the same spot for all canvas items.  If omitted,
#			defaults to "end-1", so it works with "current" item.
#
# Results:
#	node	name of the tree node.

proc Tree::_get_node_name {path {item current} {tagindex end-1}} {
    return [string range [lindex [$path.c gettags $item] $tagindex] 2 end]
}

# Tree::_get_node_padx --
#
#	Given a node in the tree, return it's padx value.  If the value is
#	less than 0, default to the padx of the entire tree.
#
# Arguments:
#	path		Tree to query
#	node		Node in the tree
#
# Results:
#	padx		The numeric padx value
proc Tree::_get_node_padx {path node} {
    set padx [Widget::getoption $path.$node -padx]
    if {$padx < 0} { set padx [Widget::getoption $path -padx] }
    return $padx
}

# Tree::_get_node_deltax --
#
#	Given a node in the tree, return it's deltax value.  If the value is
#	less than 0, default to the deltax of the entire tree.
#
# Arguments:
#	path		Tree to query
#	node		Node in the tree
#
# Results:
#	deltax		The numeric deltax value
proc Tree::_get_node_deltax {path node} {
    set deltax [Widget::getoption $path.$node -deltax]
    if {$deltax < 0} { set deltax [Widget::getoption $path -deltax] }
    return $deltax
}


# Tree::_get_node_tags --
#
#	Given a node in the tree, return a list of tags to apply to its
#       canvas item.
#
# Arguments:
#	path		Tree to query
#	node		Node in the tree
#	tags		A list of tags to add to the final list
#
# Results:
#	list		The list of tags to apply to the canvas item
proc Tree::_get_node_tags {path node {tags ""}} {
    eval [linsert $tags 0 lappend list TreeItemSentinal]
    if {[Widget::getoption $path.$node -helptext] == ""} { return $list }

    switch -- [Widget::getoption $path.$node -helptype] {
	balloon {
	    lappend list BwHelpBalloon
	}
	variable {
	    lappend list BwHelpVariable
	}
    }
    return $list
}

# Tree::_set_help --
#
#	Register dynamic help for a node in the tree.
#
# Arguments:
#	path		Tree to query
#	node		Node in the tree
#       force		Optional argument to force a reset of the help
#
# Results:
#	none
proc Tree::_set_help { path node } {
    Widget::getVariable $path help

    set item $path.$node
    set opts [list -helptype -helptext -helpvar]
    foreach {cty ctx cv} [eval [linsert $opts 0 Widget::hasChangedX $item]] break
    set text [Widget::getoption $item -helptext]

    ## If we've never set help for this item before, and text is not blank,
    ## we need to setup help.  We also need to reset help if any of the
    ## options have changed.
    if { (![info exists help($node)] && $text != "") || $cty || $ctx || $cv } {
	set help($node) 1
	set type [Widget::getoption $item -helptype]
        switch $type {
            balloon {
		DynamicHelp::register $path.c balloon n:$node $text
		DynamicHelp::register $path.c balloon i:$node $text
		DynamicHelp::register $path.c balloon b:$node $text
            }
            variable {
		set var [Widget::getoption $item -helpvar]
		DynamicHelp::register $path.c variable n:$node $var $text
		DynamicHelp::register $path.c variable i:$node $var $text
		DynamicHelp::register $path.c variable b:$node $var $text
            }
        }
    }
}

proc Tree::_mouse_select { path cmd args } {
    eval [linsert $args 0 selection $path $cmd]
    switch -- $cmd {
        "add" - "clear" - "remove" - "set" - "toggle" {
            event generate $path <<TreeSelect>>
        }
    }
}


proc Tree::_node_name { path node } {
    set map [list & _ | _ ^ _ ! _]
    return  [string map $map $node]
}


proc Tree::_get_option { path node option {default ""} } {
    return [Widget::getOption $option $default $path.$node $path]
}


# ----------------------------------------------------------------------------
#  Command Tree::_destroy
# ----------------------------------------------------------------------------
proc Tree::_destroy { path } {
    Widget::getVariable $path data

    if {[string length $data(upd,afterid)]} {
        after cancel $data(upd,afterid)
    }

    if {[string length $data(dnd,afterid)]} {
        after cancel $data(dnd,afterid)
    }

    _subdelete $path [lrange $data(root) 1 end]
    Widget::destroy $path
}

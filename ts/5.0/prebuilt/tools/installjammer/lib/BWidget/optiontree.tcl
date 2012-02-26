# ----------------------------------------------------------------------------
#  optiontree.tcl
#  $Id$
# ----------------------------------------------------------------------------
#  Index of commands:
# ----------------------------------------------------------------------------

namespace eval OptionTree {
    Widget::define OptionTree optiontree Tree

    namespace eval Node {
        Widget::declare OptionTree::Node {
            {-type              Enum      "none"  1
                {checkbutton none radiobutton}}
            {-command            String    ""      0}
            {-variable           String    ""      0}
            
            {-on                 Boolean   "0"     0}
            {-value              String    ""      0}
            {-onvalue            String    ""      0}
            {-offvalue           String    ""      0}

            {-state              Enum      "normal" 0 {disabled normal}}
            {-disabledforeground Color     "SystemDisabledText" 0}
        }
    }

    Widget::declare OptionTree {
        {-command             String       ""   0}
        {-toggleselect        Boolean      1    1}

        {-radioimage          String       ""   1}
        {-radioselectimage    String       ""   1}

        {-checkimage          String       ""   1}
        {-checkselectimage    String       ""   1}
    }

    bind OptionTree <Destroy> [list OptionTree::_destroy %W]
}


proc OptionTree::create { path args } {
    set opath $path#opttree

    array set maps [list Tree {} .c {} OptionTree {}]
    array set maps [Widget::splitArgs $args Tree OptionTree]

    eval [list Tree::create $path -bg #FFFFFF -showlines 0] $maps(Tree)
    eval [list $path.c configure] $maps(.c)

    Widget::initFromODB OptionTree $opath $maps(OptionTree)

    if {![string length [Widget::getoption $opath -radioimage]]} {
        Widget::setoption $opath -radioimage [BWidget::Icon radio-off]
    }

    if {![string length [Widget::getoption $opath -radioselectimage]]} {
        Widget::setoption $opath -radioselectimage [BWidget::Icon radio-on]
    }

    if {![string length [Widget::getoption $opath -checkimage]]} {
        Widget::setoption $opath -checkimage [BWidget::Icon check-off]
    }

    if {![string length [Widget::getoption $opath -checkselectimage]]} {
        Widget::setoption $opath -checkselectimage [BWidget::Icon check-on]
    }

    set opts [list]
    
    ## Figure out the dimensions of our images and setup
    ## the tree's defaults.  If the user passes in these
    ## options, they will be overridden.
    set image  [Widget::getoption $opath -checkimage]
    set width  [image width $image]
    set height [image height $image]
    lappend opts -padx [expr {$width + 4}]
    lappend opts -deltax $width -deltay [expr {$height + 4}]

    eval [list Tree::configure $path] $opts $maps(Tree)

    bindtags $path [list $path OptionTree Tree [winfo toplevel $path] all]

    set toggle [Widget::getoption $opath -toggleselect]

    $path bindText  <Button-1> [list OptionTree::_select $path $toggle]
    $path bindText  <Double-1> [list OptionTree::_select $path 1]
    $path bindImage <Button-1> [list OptionTree::_select $path 1]
    $path bindImage <Double-1> [list OptionTree::_select $path 1]

    set c [$path getcanvas]
    bind $c <Key-space> [list OptionTree::_select $path 1]

    proc ::$path { cmd args } \
    	"return \[OptionTree::_path_command [list $path] \$cmd \$args\]"

    return $path
}


proc OptionTree::cget { path option } {
    if {[string match "*#opttree" $path]} {
        set opath $path
    } else {
        set opath $path#opttree
    }

    if {[Widget::optionExists Tree $option]} {
        return [Tree::cget $path $option]
    } else {
        return [Widget::cget $opath $option]
    }
}


proc OptionTree::clear { path } {
    eval [list OptionTree::delete $path] [Tree::nodes $path root]
}


proc OptionTree::configure { path args } {
    set opath $path#opttree

    if {![llength $args]} {
        set res [Tree::configure $path]
        eval lappend res [Widget::configure $opath $args]
        return [lsort $res]
    }

    if {[llength $args] == 1} {
        if {[Widget::optionExists Tree $args]} {
            return [Tree::configure $path $args]
        } else {
            return [Widget::configure $opath $args]
        }
    }

    array set maps [list Tree {} .c {} OptionTree {}]
    array set maps [Widget::splitArgs $args Tree OptionTree]

    if {[llength $maps(Tree)] || [llength $maps(.c)]} {
        eval [list Tree::configure $path] $maps(Tree) $maps(.c)
    }

    if {[llength $maps(OptionTree)]} {
        Widget::configure $opath $maps(OptionTree)
    }
}


proc OptionTree::delete { path args } {
    Widget::getVariable $path traces
    Widget::getVariable $path variables

    foreach node $args {
        eval [list OptionTree::delete $path] [$path nodes $node]

        Widget::destroy $path.$node#opttree 0

        if {![info exists variables($node)]} { continue }

        set varName $variables($node)
        set command [list OptionTree::_redraw_node $path $node 0]
        uplevel #0 [list trace remove variable $varName write $command]

        if {[set idx [lsearch -exact $traces($varName) $node]] > -1} {
            set traces($varName) [lreplace $traces($varName) $idx $idx]
        }
    }

    eval [list Tree::delete $path] $args
}


proc OptionTree::insert { path index parent node args } {
    array set maps [Widget::splitArgs $args OptionTree::Node Tree::Node]

    set deltax [Widget::getoption $path -deltax]
    if {[string equal $parent "root"]} {
        set deltax 0
    } else {
        ## If this item is going into a parent node that has
        ## a deltax of 0 but has opted to draw a cross, we need
        ## to adjust the deltax to make room for the cross.
        set dx [Widget::getoption $path.$parent -deltax]
        set dc [Widget::getoption $path.$parent -drawcross]
        if {$dx == 0 && $dc ne "never"} {
            Tree::itemconfigure $path $parent -deltax 10
        }
    }

    set args [concat -deltax $deltax $maps(Tree::Node)]
    set node [eval [list Tree::insert $path $index $parent $node] $args]

    set onode $path.$node#opttree
    Widget::init OptionTree::Node $onode $maps(OptionTree::Node)

    ## If this item has no type, and it has no image, and
    ## the user didn't pass us a -padx, set the default
    ## -padx to 4 pixels.  Items without images look too
    ## spaced in the OptionTree due to every other item
    ## always having an image.
    set type [Widget::getoption $onode -type]
    array set tmp $maps(Tree::Node)
    if {[string equal $type "none"] && ![info exists tmp(-padx)]
        && ![string length [Tree::itemcget $path $node -image]]} {
        Tree::itemconfigure $path $node -padx 4
    }

    OptionTree::_set_variable $path $node
    OptionTree::_redraw_node  $path $node 0

    return $node
}


proc OptionTree::itemcget { path node option } {
    set onode $path.$node#opttree

    if {[Widget::optionExists OptionTree::Node $option]} {
        return [Widget::getoption $onode $option]
    } else {
        return [Tree::itemcget $path $node $option]
    }
}


proc OptionTree::itemconfigure { path node args } {
    set onode $path.$node#opttree

    if {![llength $args]} {
        set res [Tree::itemconfigure $path $node]
        eval lappend res [Widget::configure $onode $args]
        return [lsort $res]
    }

    if {[llength $args] == 1} {
        if {[Widget::optionExists Tree::Node $args]} {
            return [Tree::itemconfigure $path $node $args]
        } else {
            return [Widget::configure $onode $args]
        }
    }

    array set maps [Widget::splitArgs $args OptionTree::Node Tree::Node]

    if {[info exists maps(Tree::Node)]} {
        eval [list Tree::itemconfigure $path $node] $maps(Tree::Node)
    }

    set oldVarName [Widget::getoption $onode -variable]

    if {[info exists maps(OptionTree::Node)]} {
        Widget::configure $onode $maps(OptionTree::Node)
    }

    set redraw 0

    if {[Widget::hasChanged $onode -variable varName]} {
        Widget::getVariable $path traces
        if {[string length $oldVarName]} {
            set idx [lsearch -exact $traces($oldVarName) $node]
            set traces($oldVarName) [lreplace $traces($oldVarName) $idx $idx]

            set command [list OptionTree::_redraw_node $path $node 0]
            uplevel #0 [list trace remove variable $oldVarName write $command]
        }

        OptionTree::_set_variable $path $node

        set redraw 1
    }

    if {[Widget::anyChangedX $onode -on -value -onvalue -offvalue -state]} {
        set redraw 1
    }

    if {$redraw} { _redraw_node $path $node 1 }
}


proc OptionTree::toggle { path node {force 0} } {
    set onode $path.$node#opttree

    if {$force || [Widget::getoption $onode -state] ne "disabled"} {
        if {[Widget::getoption $onode -on]} {
            OptionTree::itemconfigure $path $node -on 0
        } else {
            OptionTree::itemconfigure $path $node -on 1
        }

        event generate $path <<TreeModify>>
    }
}


proc OptionTree::_path_command { path cmd larg } {
    if {[string length [info commands ::OptionTree::$cmd]]} {
        return [eval [linsert $larg 0 OptionTree::$cmd $path]]
    } else {
        return [eval [linsert $larg 0 Tree::$cmd $path]]
    }
}


proc OptionTree::_select { path toggle {node ""} } {
    if {$node eq ""} { set node [$path selection get] }

    set opath $path#opttree
    set onode $path.$node#opttree

    $path selection set $node

    if {[Widget::getoption $onode -state] ne "disabled" && $toggle} {
        OptionTree::toggle $path $node
        set cmd [Widget::cgetOption -command "" $onode $opath]
        OptionTree::_eval_command $path $node $cmd
    }

    event generate $path <<TreeSelect>>
}


proc OptionTree::_eval_command { path node command } {
    if {[string length $command]} {
        set onode   $path.$node#opttree
        set parent  [Tree::parent $path $node]
        set varName [Widget::getoption $onode -variable]
        set map     [list %W $path %p $parent %n $node %v $varName]

        uplevel #0 [string map $map $command]
    }
}


proc OptionTree::_set_variable { path node } {
    Widget::getVariable $path traces
    Widget::getVariable $path variables

    set onode $path.$node#opttree

    set varName [Widget::getoption $onode -variable]
    if {![string length $varName]} { return }

    set variables($node) $varName
    lappend traces($varName) $node

    set command [list OptionTree::_redraw_node $path $node 0]
    uplevel #0 [list trace add variable $varName write $command]
}


proc OptionTree::_redraw_node { path node force args } {
    set opath $path#opttree
    set onode $path.$node#opttree

    set varName [Widget::getoption $onode -variable]

    set opts [list]

    if {[Widget::getoption $onode -state] eq "disabled"} {
        lappend opts -fill [Widget::getoption $onode -disabledforeground]
    }

    switch -- [Widget::getoption $onode -type] {
        "checkbutton" {
            set on [Widget::getoption $onode -on]

            if {[string length $varName]} {
                upvar #0 $varName var

                set onvalue  [Widget::getoption $onode -onvalue]
                set offvalue [Widget::getoption $onode -offvalue]

                if {$force || ![info exists var]} {
                    if {$onvalue  eq ""} { set onvalue  1 }
                    if {$offvalue eq ""} { set offvalue 0 }
                    if {$on} {
                        set var $onvalue
                    } else {
                        set var $offvalue
                    }
                } else {
                    if {$offvalue eq "" && [string is false -strict $var]} {
                        set on 0
                    } elseif {$onvalue eq "" && [string is true -strict $var]} {
                        set on 1
                    } elseif {$var == $onvalue} {
                        set on 1
                    } else {
                        set on 0
                    }
                }
            }

            if {$on} {
                set image [Widget::getoption $opath -checkselectimage]
            } else {
                set image [Widget::getoption $opath -checkimage]
            }

            Widget::setoption $onode -on $on
            lappend opts -image $image
        }

        "radiobutton" {
            ## If no variable exists, the radiobutton always appears on.
            set on 1
            set image [Widget::getoption $opath -radioselectimage]

            if {[string length $varName]} {
                upvar #0 $varName var

                set value [Widget::getoption $onode -value]

                if {$force} { set var $value }

                ## If the radiobuton's variable does not exist,
                ## it stays on until it does.
                if {[info exists var] && $var != $value} {
                    set on 0
                    set image [Widget::getoption $opath -radioimage]
                }
            }

            Widget::setoption $onode -on $on
            lappend opts -image $image
        }
    }

    eval [list Tree::itemconfigure $path $node] $opts
}


proc OptionTree::_destroy { path } {
    Widget::getVariable $path traces

    OptionTree::delete $path root

    foreach varName [array names traces] {
        foreach node $traces($varName) {
            set command [list OptionTree::_redraw_node $path $node 0]
            uplevel #0 [list trace remove variable $varName write $command]
        }
    }

    Widget::destroy $path#opttree
}

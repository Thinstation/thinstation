# -----------------------------------------------------------------------------
#  $Id$
# -----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - Properties::create
#     - Properties::configure
#     - Properties::cget
#     - Properties::getframe
#     - Properties::insert
#     - Properties::delete
#     - Properties::nodes
#     - Properties::raise
#     - Properties::open
#     - Properties::close
#     - Properties::toggle
#
#   Private Commands:
#     - Properties::_resize
#     - Properties::_destroy
# -----------------------------------------------------------------------------

package require Tk 8.4
package require Tktable

namespace eval Properties {
    Widget::define Properties properties ComboBox Button

    Widget::declare Properties::Node {
	{-data               String  ""        0}
	{-open               Boolean "0"       0}
	{-text               String  ""        0}
	{-font               String  ""        0} 
	{-state              Enum    "normal"  0 {normal disabled hidden}}
	{-width              Int     "0"       0}
	{-height             Int     "0"       0}
	{-window             String  ""        0}
        {-multiline          Boolean "0"       0}

	{-padx               Padding ""        0 "%d >= 0"}
	{-pady               Padding "0 8"     0 "%d >= 0"}
	{-ipadx              Int     ""        0 "%d >= 0"}
	{-ipady              Int     ""        0 "%d >= 0"}
        {-cellpadx           Int     ""        0 "%d >= 0"}
        {-cellpady           Int     ""        0 "%d >= 0"}
        {-selectable         Boolean 1         0}

        {-browseargs         String      ""        0}

	{-opencommand        String  ""        0}
	{-closecommand       String  ""        0}
	{-editstartcommand   String  ""        0}
	{-editfinishcommand  String  ""        0}
	{-editcancelcommand  String  ""        0}
    }

    DynamicHelp::include Properties::Node balloon

    Widget::declare Properties::Property {
	{-data               String      ""        0}
	{-text               String      ""        0}
	{-font               String      ""        0} 
	{-state              Enum        "normal"  0 {normal disabled hidden}}
	{-value              String      ""        0}
	{-window             String      ""        0}
	{-variable           String      ""        0}
	{-editable           Boolean     "1"       0}
	{-editwindow         String      ""        0}

	{-values             String      ""        0}
        {-valuescommand      String      ""        0}
        
        {-browseargs         String      ""        0}
	{-browsebutton       Boolean     "0"       0}
        {-browsecommand      String      ""        0}

        {-postcommand        String      ""        0}
	{-modifycommand      String      ""        0}

	{-editstartcommand   String      ""        0}
	{-editfinishcommand  String      ""        0}
	{-editcancelcommand  String      ""        0}
    }

    DynamicHelp::include Properties::Property balloon

    Widget::tkinclude Properties canvas .c \
	remove {
	    -insertwidth -insertbackground -insertborderwidth -insertofftime
	    -insertontime -selectborderwidth -closeenough -confine -scrollregion
            -state
	} initialize {
	    -relief flat -borderwidth 2 -takefocus 1
	    -highlightthickness 0 -width 400
	}

    Widget::declare Properties {
	{-font               String      "TkTextFont" 0}
	{-state              Enum        "normal"  0 {normal disabled}}
	{-expand             Boolean     "0"       0}
	{-redraw             Boolean     "1"       0}
	{-drawmode           Enum        "normal"  0 {normal slow fast}}
        {-multiline          Boolean     "0"       0}

	{-padx               Padding     "0"       0 "%d >= 0"}
	{-pady               Padding     "4"       0 "%d >= 0"}
	{-ipadx              Int         "4"       0 "%d >= 0"}
	{-ipady              Int         "4"       0 "%d >= 0"}
        {-cellpadx           Int         "2"       0 "%d >= 0"}
        {-cellpady           Int         "1"       0 "%d >= 0"}

        {-browseargs         String      ""        0}
        {-helpcolumn         Enum        "label"   1 {both label value}}

	{-opencommand        String      ""        0}
	{-closecommand       String      ""        0}
	{-editstartcommand   String      ""        0}
	{-editfinishcommand  String      ""        0}
	{-editcancelcommand  String      ""        0}
    }

    bind Properties <Map>       [list Properties::_realize %W]
    bind Properties <Destroy>   [list Properties::_destroy %W]
    bind Properties <Configure> [list Properties::_resize %W]

    bind PropertiesTable <1>        [list Properties::_button_1 %W %x %y]
    bind PropertiesTable <Double-1> [list Properties::_double_button_1 %W %x %y]

    bind Properties <FocusIn>   [list after idle {BWidget::refocus %W %W.c}]
    bind PropertiesCanvas <1>   [list Properties::_focus_canvas %W]

    BWidget::bindMouseWheel PropertiesCanvas
}


# -----------------------------------------------------------------------------
#  Command Properties::create
# -----------------------------------------------------------------------------
proc Properties::create { path args } {
    Widget::initArgs Properties $args maps

    frame $path -class Properties -bd 0 -highlightthickness 0 \
    	-relief flat -takefocus 0

    Widget::initFromODB Properties $path $maps(Properties)

    eval [list canvas $path.c] -width 400 $maps(.c)
    bindtags $path.c [concat PropertiesCanvas [bindtags $path.c]]
    pack $path.c -expand 1 -fill both

    $path.c bind c: <1>        [list Properties::_toggle_cross $path]
    $path.c bind l: <1>        [list Properties::_select_node  $path]
    $path.c bind l: <Double-1> [list Properties::_toggle_cross $path]

    Widget::getVariable $path data

    set data(selected)    ""
    set data(realized)    0
    set data(redrawlevel) 0

    set data(nodes,root)  [list]

    return [Widget::create Properties $path]
}


# -----------------------------------------------------------------------------
#  Command Properties::configure
# -----------------------------------------------------------------------------
proc Properties::configure { path args } {
    set res [Widget::configure $path $args]

    set redraw [Widget::anyChangedX $path -padx -pady -ipadx -ipady -expand]

    if {[Widget::hasChanged $path -font font]} {
        _configure_tables $path -font $font
        set redraw 1
    }

    if {[Widget::hasChanged $path -state state]} {
        _configure_tables $path -state $state
    }

    if {$redraw && [Widget::getoption $path -redraw]} {
        _redraw_idle $path
    }

    return $res
}


# -----------------------------------------------------------------------------
#  Command Properties::cget
# -----------------------------------------------------------------------------
proc Properties::cget { path option } {
    return [Widget::cget $path $option]
}


proc Properties::itemcget { path node option } {
    if {![Properties::exists $path $node]} {
        return -code error "node \"$node\" does not exist"
    }
    return [Widget::cget $path.$node $option]
}


proc Properties::itemconfigure { path node args } {
    Widget::getVariable $path data

    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    set lastState [Widget::getoption $path.$node -state]

    if {![string equal $data($node) "root"]} {
        set lastVar [Widget::getoption $path.$node -variable]
    }

    set res [Widget::configure $path.$node $args]

    if {[string equal $data($node) "root"]} {
	set redraw 0

	## We always redraw when a node is opened or closed, regardless
	## of the -redraw option for the widget.
	if {[Widget::hasChanged $path.$node -open open]} {
            set redraw 1

            if {$open} {
                set command [_option $path root $node -opencommand]
                _eval_command $path root $node $command
            } else {
                set command [_option $path root $node -closecommand]
                _eval_command $path root $node $command
            }
        }

	if {[Widget::hasChanged $path.$node -state state]} {
	    ## If we're changing to or from a hidden state, we need
	    ## to redraw all the tables.  Otherwise, we're just
	    ## changing from normal or disabled and no redraw is
	    ## necessary.
	    if {[string equal $state "hidden"]
	    	|| [string equal $lastState "hidden"]} {
		## Only redraw if the user wants us to.
		if {[Widget::getoption $path -redraw]} { set redraw 1 }
	    }
	}

	if {$redraw} { _redraw_idle $path 2 }
    } else {
	if {[Widget::hasChanged $path.$node -state state]} {
	    ## If we're changing to or from a hidden state, we need
	    ## to redraw all the tables.  Otherwise, we're just
	    ## changing from normal or disabled and no redraw is
	    ## necessary.
	    if {[string equal $state "hidden"]
	    	|| [string equal $lastState "hidden"]} {
		## Only redraw if the user wants us to.
		if {[Widget::getoption $path -redraw]} { _redraw_idle $path }
	    }
	}

        if {[Widget::hasChanged $path.$node -value value]} {
            set varName [Widget::getoption $path.$node -variable]
            if {[string length $varName]} {
                upvar #0 $varName var
                set var $value
            } else {
                _redraw_properties $path $data($node)
            }
        }

        if {[Widget::hasChanged $path.$node -variable variable]} {
            _trace_variable $path $node
        }

        if {[Widget::anyChangedX $path.$node -helpvar -helptype -helptext]} {
            _configure_help $path $node 1
        }
    }

    return $res
}


proc Properties::tagcget { path node which option } {
    Widget::getVariable $path data

    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exists"
    }

    set parent $data($node)
    if {$parent eq "root"} {
        set table $path.t$node
    } else {
        set table $path.t$parent
    }

    if {[$table tag exists $node-$which]} {
        return [$table tag cget $node-$which $option]
    }

    if {[$table tag exists $parent-$which]} {
        return [$table tag cget $parent-$which $option]
    }

    return [$table cget $option]
}


proc Properties::tagconfigure { path node which args } {
    Widget::getVariable $path data

    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exists"
    }

    switch -- $which {
        "label" {
            set col 0
        }

        "value" {
            set col 1
        }

        default {
            return [BWidget::badOptionString value $which [list label value]]
        }
    }

    set tag $node-$which

    set parent $data($node)
    if {$parent eq "root"} {
        set table  $path.t$node
        set parent $node
    } else {
        set table $path.t$parent
    }

    if {![winfo exists $table]} {
        _create_root_node $path root $parent
    }

    return [eval [list $table tag configure $tag] $args]
}


# -----------------------------------------------------------------------------
#  Command Properties::insert
# -----------------------------------------------------------------------------
proc Properties::insert { path idx parent node args } {
    Widget::getVariable $path data

    if {![info exists data(nodes,$parent)]} {
        return -code error "node \"$parent\" does not exist"
    }

    set node [Widget::nextIndex $path $node]

    if {[info exists data($node)]} {
        return -code error "node \"$node\" already exists"
    }

    set drawmode [Widget::getoption $path -drawmode]

    if {[string equal $parent "root"]} {
	Widget::init Properties::Node $path.$node $args

        set data($node) $parent
	set data(nodes,$node) [list]

        if {$idx eq "end"} {
            lappend data(nodes,root) $node
        } else {
            set data(nodes,root) [linsert $data(nodes,root) $idx $node]
        }

        if {[string equal $drawmode "fast"]} {
            _create_root_node $path $parent $node
        }
    } else {
	Widget::init Properties::Property $path.$node $args

        set data($node) $parent
        set varName [Widget::getoption $path.$node -variable]
        if {![string equal $varName ""] && ![string match "::*" $varName]} {
            Widget::setoption $path.$node -variable ::$varName
        }

        if {$idx eq "end"} {
            lappend data(nodes,$parent) $node
        } else {
            set data(nodes,$parent) [linsert $data(nodes,$parent) $idx $node]
        }

        if {[string length $varName]} { _trace_variable $path $node }
    }

    if {[Widget::getoption $path -redraw]} { _redraw_idle $path }

    return $node
}


# -----------------------------------------------------------------------------
#  Command Properties::delete
# -----------------------------------------------------------------------------
proc Properties::delete { path args } {
    Widget::getVariable $path data

    foreach node $args {
        if {[info exists data(editing)] && $node eq $data(editing)} {
            Properties::edit $path cancel
        }

	set pnode $data($node)
	Widget::destroy $path.$node 0
	if {[string equal $pnode "root"]} {
	    destroy $path.t$node

            foreach prop $data(nodes,$node) {
                Widget::destroy $path.$node 0
                Properties::_untrace_variable $path $node
            }

	    unset data(nodes,$node)
	}

        if {[info exists data(nodes,$pnode)]} {
            set data(nodes,$pnode) [BWidget::lremove $data(nodes,$pnode) $node]
        }
    }

    if {[Widget::getoption $path -redraw]} { _redraw_idle $path }
}


# -----------------------------------------------------------------------------
#  Command Properties::nodes
# -----------------------------------------------------------------------------
proc Properties::nodes { path node {first ""} {last ""} } {
    Widget::getVariable $path data

    if {![info exists data(nodes,$node)]} {
        return -code error "node \"$node\" does not exist"
    }

    if {![string length $first]} { return $data(nodes,$node) }
    if {![string length $last]}  { return [lindex $data(nodes,$node) $first] }
    return [lrange $data(nodes,$node) $first $last]
}


# -----------------------------------------------------------------------------
#  Command Properties::open
# -----------------------------------------------------------------------------
proc Properties::open { path node {recurse 0} } {
    $path itemconfigure $node -open 1
}


# -----------------------------------------------------------------------------
#  Command Properties::close
# -----------------------------------------------------------------------------
proc Properties::close { path node {recurse 0} } {
    Widget::getVariable $path data

    $path itemconfigure $node -open 0

    ## If we're editing a property in the table we're closing,
    ## finish the edit.
    if {[info exists data(editing)]
        && [lsearch -exact $data(nodes,$node) $data(editing)] > -1} {
        $path edit finish
    }
}


# -----------------------------------------------------------------------------
#  Command Properties::toggle
# -----------------------------------------------------------------------------
proc Properties::toggle { path node } {
    if {[Widget::getoption $path.$node -open]} {
        Properties::close $path $node
    } else {
        Properties::open $path $node
    }
}


proc Properties::edit { path command {node ""} {focus ""} } {
    Widget::getVariable $path data
    Widget::getVariable $path nodes

    if {[info exists data(editing)] && ![info exists data($data(editing))]} {
        unset data(editing)
    }

    switch -- $command {
	"start" {
            if {![info exists data($node)]} {
                return -code error "node \"$node\" does not exist"
            }

	    _start_edit $path $path.t$data($node) $node $focus
	}

	"finish" - "cancel" {
	    if {![info exists data(editing)]} { return }

	    set node   $data(editing)
	    set parent $data($node)
            set table  $path.t$parent

	    set cmd [_option $path $parent $node -edit${command}command]
            if {![_eval_command $path $parent $node $cmd]} { return }

            ## If this is a cancel, reset the original value.
            if {[string equal $command "cancel"]} {
                $path itemconfigure $node -value $data(value)
                event generate $path <<PropertiesEditCancel>>
            } else {
                event generate $path <<PropertiesEditFinish>>
            }

	    destroy $path.edit

            Widget::getVariable $path.$parent tableData
            set row $nodes($parent,$node)
            set tableData($row,1) [_get_value $path $node]
            $table selection clear all

            set vars [list editing editpath entrypath browsepath valuespath]
            foreach var $vars {
                if {[info exists data($var)]} { unset data($var) }
            }
	}

        "reread" {
	    if {[info exists data(editing)]} {
                upvar #0 [Properties::variable $path $data(editing)] var
                set var $data(value)
            }
        }

	"active" - "current" {
	    if {[info exists data(editing)]} { return $data(editing) }
	}

        "value"      -
        "values"     -
        "editable"   -
        "editpath"   -
        "entrypath"  -
        "editwindow" -
        "browsepath" -
        "valuespath" {
	    if {[info exists data(editing)]} { return $data($command) }
        }

        default {
            return -code error "invalid edit property \"$command\""
        }
    }
}


# ----------------------------------------------------------------------------
#  Command Tree::xview
# ----------------------------------------------------------------------------
proc Properties::xview { path args } {
    return [eval [list $path.c xview] $args]
}


# ----------------------------------------------------------------------------
#  Command Tree::yview
# ----------------------------------------------------------------------------
proc Properties::yview { path args } {
    return [eval [list $path.c yview] $args]
}


proc Properties::exists { path node } {
    return [Widget::exists $path.$node]
}


proc Properties::reorder { path node neworder } {
    Widget::getVariable $path data

    if {![info exists data(nodes,$node)]} {
        return -code error "node \"$node\" does not exist"
    }

    set data(nodes,$node) $neworder
    _redraw_idle $path
}


proc Properties::redraw { path } {
    Widget::getVariable $path data

    _redraw_nodes  $path
    _resize        $path

    set data(redrawlevel) 0
}


proc Properties::parent { path node } {
    Widget::getVariable $path data
    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }
    return $data($node)
}


proc Properties::bindLabel { path args } {
    Widget::getVariable $path data
    Widget::getVariable $path events
    Widget::getVariable $path labelEvents

    if {![llength $args]} {
        set list [list]
        foreach event [lsort [array names labelEvents]] {
            lappend list $event $labelEvents($event)
        }
        return $list
    } elseif {[llength $args] == 1} {
        set event [lindex $args 0]
        if {![info exists labelEvents($event)]} { return }
        return $labelEvents($event)
    } elseif {[llength $args] != 2} {
        set err [BWidget::wrongNumArgsString "$path bindLabel ?event? ?script?"]
        return -code error $err
    }

    BWidget::lassign $args event script
    if {![string length $script]} {
        if {[info exists events($event)]} { unset events($event) }
        if {[info exists labelEvents($event)]} { unset labelEvents($event) }
    } else {
        set events($event) 1
        set labelEvents($event) $script
    }
}

proc Properties::bindValue { path args } {
    Widget::getVariable $path data
    Widget::getVariable $path events
    Widget::getVariable $path valueEvents

    if {![llength $args]} {
        set list [list]
        foreach event [lsort [array names valueEvents]] {
            lappend list $event $valueEvents($event)
        }
        return $list
    } elseif {[llength $args] == 1} {
        set event [lindex $args 0]
        if {![info exists valueEvents($event)]} { return }
        return $valueEvents($event)
    } elseif {[llength $args] != 2} {
        set err [BWidget::wrongNumArgsString "$path bindValue ?event? ?script?"]
        return -code error $err
    }

    BWidget::lassign $args event script
    if {![string length $script]} {
        if {[info exists events($event)]} { unset events($event) }
        if {[info exists valueEvents($event)]} { unset valueEvents($event) }
    } else {
        set events($event) 1
        set valueEvents($event) $script
    }
}


proc Properties::variable { path node } {
    Widget::getVariable $path data
    if {![info exists data($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    set varName [Widget::getoption $path.$node -variable]
    if {![string length $varName]} {
        set varName [Widget::varForOption $path.$node -value]
    }
    return $varName
}

proc Properties::_handle_event { table coords event map } {
    set path [winfo parent $table]

    Widget::getVariable $path data
    Widget::getVariable $path nodes

    set row [$table index @$coords row]
    set col [$table index @$coords col]

    if {$col == 0} {
        Widget::getVariable $path labelEvents events
    } elseif {$col == 1} {
        Widget::getVariable $path valueEvents events
    }

    if {![info exists events($event)]} { return }

    set node   $nodes($table,$row)
    set parent $data($node)
    lappend map %p $parent %n $node

    uplevel #0 [string map $map $events($event)]
}


proc Properties::_create_root_node { path parent node } {
    Widget::getVariable $path data

    set table $path.t$node
    if {[winfo exists $table]} { return }

    set bg    [Widget::cget $path -background]
    set font  [Widget::cget $path -font]
    set padx  [_option $path root $node -cellpadx]
    set pady  [_option $path root $node -cellpady]
    set width [Widget::cget $path -width]
    set multi [_option $path root $node -multiline]

    table $table -cols 2 -rows 0 -colstretchmode last \
        -state disabled -anchor w -justify left -highlightthickness 0 \
        -background $bg -font $font -resizeborder col \
        -bordercursor sb_h_double_arrow -cursor "" -multiline $multi \
        -maxheight 10000 -maxheight 10000 -padx $padx -pady $pady \
        -variable [Widget::widgetVar $path.$node tableData]

    $table tag configure sel    -relief sunken -background $bg \
        -foreground #000000
    $table tag configure active -relief sunken -background $bg \
        -foreground #000000

    $table tag col $node-label 0
    $table tag col $node-value 1

    DynamicHelp::add $table -col 1 \
        -command [list Properties::_display_text_balloon $path %W %r]

    set top [winfo toplevel $table]
    bindtags $table [list $table PropertiesTable Table $top all]

    set width -[expr {$width / 2}]
    $table width 0 $width 1 $width
}


proc Properties::_start_edit { path table node {focus ""} } {
    Widget::getVariable $path data
    Widget::getVariable $path nodes

    set parent $data($node)
    set state  [_option $path $parent $node -state normal]

    if {[string equal $state "disabled"]} { return }

    if {[info exists data(editing)]} {
        Properties::edit $path finish

        if {[info exists data(editing)]} {
            ## We couldn't finish editing because of a validation check failure.
            return
        }
    }

    foreach var [list editpath entrypath browsepath valuespath] {
        set data($var) ""
    }

    set var [Properties::variable $path $node]

    set font     [_option $path $parent $node -font]
    set window   [Widget::getoption $path.$node -editwindow]
    set values   [Widget::getoption $path.$node -values]
    set valcmd   [Widget::getoption $path.$node -valuescommand]
    set editable [Widget::getoption $path.$node -editable]

    set combobox 0
    if {[string length $values] || [string length $valcmd]} { set combobox 1 }

    frame $path.edit

    if {![string length $window]} {
	if {![Widget::getoption $path.$node -browsebutton]} {
            if {!$combobox} {
		set widget $path.edit.e
                set entry  $widget
		Entry $entry -bd 1 -font $font -textvariable $var \
                    -editable $editable
	    } else {
                set widget  $path.edit.cb
		set entry   $widget.e
                set modcmd  [Widget::getoption $path.$node -modifycommand]
                set postcmd [Widget::getoption $path.$node -postcommand]

                if {[string length $valcmd]} {
                    _eval_command $path $parent $node $valcmd values
                }

		ComboBox $widget -borderwidth 1 -font $font \
                    -exportselection 0 -hottrack 1 -textvariable $var \
                    -values $values -editable $editable \
                    -postcommand   [_map_command $path $parent $node $postcmd] \
                    -modifycommand [_map_command $path $parent $node $modcmd]

                set data(valuespath) $widget
	    }
	} else {
            if {!$combobox} {
                set widget $path.edit.e
                set entry  $widget
                Entry $entry -bd 1 -font $font -textvariable $var -width 1 \
                    -editable $editable
            } else {
                set widget  $path.edit.combo
		set entry   $widget.e
                set modcmd  [Widget::getoption $path.$node -modifycommand]
                set postcmd [Widget::getoption $path.$node -postcommand]

                if {[string length $valcmd]} {
                    _eval_command $path $parent $node $valcmd values
                }

		ComboBox $widget -borderwidth 1 -font $font \
                    -exportselection 0 -hottrack 1 -textvariable $var \
                    -values $values -editable $editable \
                    -modifycommand $modcmd -postcommand $postcmd

                set data(valuespath) $widget
            }

            set data(browsepath) $path.edit.b

            set args    [_option $path $parent $node -browseargs]
            set command [Widget::getoption $path.$node -browsecommand]
            lappend args -command [_map_command $path $parent $node $command]
            set args [linsert $args 0 -text ...]

            if {[BWidget::using ttk]} {
                eval [list ttk::button $path.edit.b] $args
            } else {
                set args [linsert $args 0 -relief link]
                eval [list Button $path.edit.b] $args

                if {[string length [$path.edit.b cget -image]]} {
                    $path.edit.b configure \
                        -height [expr {[winfo reqheight $entry] - 4}]
                }
            }
            pack $path.edit.b -side right
	}

        pack $widget -side left -expand 1 -fill x
        bind $entry <Escape> "$path edit cancel; break"
        bind $entry <Return> "$path edit finish; break"
    } else {
	## The user has given us a window to use for editing.  Walk
	## through the immediate children and see if we can find an
	## entry widget to focus on.

        place $window -in $path.edit -x 0 -y 0 -relwidth 1.0 -relheight 1.0

        set widget $window
	set entry  $window
	foreach child [winfo children $window] {
	    if {[string equal [winfo class $child] "Entry"]} {
                set entry $child
                break
            }
	}
    }

    upvar #0 $var value
    set data(value)      $value
    set data(values)     $values
    set data(editing)    $node
    set data(editable)   $editable
    set data(editpath)   $path.edit
    set data(entrypath)  $entry
    set data(editwindow) $window

    set cell $nodes($parent,$node),1
    $table window configure $cell -window $data(editpath) -sticky news -padx 2

    if {[string equal [winfo class $entry] "Entry"] && $editable} {
	after idle [list Properties::_select_entry_contents $path $entry]
    }

    update idletasks

    if {$focus eq ""} { set focus $entry }
    focus -force $focus

    set cmd [_option $path $parent $node -editstartcommand]
    if {![_eval_command $path $parent $node $cmd]} { edit $path cancel; return }

    event generate $path <<PropertiesEditStart>>

    ## If we're displaying a combobox with non-editable values,
    ## go ahead and post the combobox.
    if {$combobox && !$editable} { $widget post }
}


proc Properties::_select_node { path {item ""} } {
    Widget::getVariable $path data

    if {![string length $item]} {
    	set item [lindex [$path.c gettags current] 0]
    }

    set state [Widget::cgetOption -state normal $path.$item $path]
    if {[string equal $state "disabled"]
        || ![Widget::getoption $path.$item -selectable]} { return }

    set bg [Widget::cget $path -selectbackground]
    set fg [Widget::cget $path -selectforeground]

    if {[string length $data(selected)]} {
        $path.c itemconfigure l:$data(selected) -fill #000000
    }
    $path.c delete sel

    set i [$path.c find withtag l:$item]
    if {![string length $i]} { return }

    set data(selected) $item

    $path.c create rect [$path.c bbox $i] -fill $bg -width 0 \
    	-tags [list sel $item]
    $path.c itemconfigure l:$item -fill $fg
    $path.c raise l:$item
}


proc Properties::_toggle_cross { path } {
    set item  [lindex [$path.c gettags current] 0]
    set state [Widget::cgetOption -state normal $path.$item $path]

    if {[string equal $state "disabled"]
        || ![Widget::getoption $path.$item -selectable]} { return }

    _select_node $path $item
    $path toggle $item
}


## level 1 = full redraw
## level 2 = redraw tables only
proc Properties::_redraw_idle { path {level 1} } {
    Widget::getVariable $path data

    if {$data(redrawlevel) > 0} { return }

    set data(redrawlevel) $level
    after idle [list Properties::redraw $path]
}


proc Properties::_redraw_nodes { path } {
    Widget::getVariable $path data
    Widget::getVariable $path events

    set map [_bind_map $path]
    set cmd [list Properties::_handle_event %W %x,%y $map]

    if {[info exists data(editing)]} { Properties::edit $path finish }

    $path.c delete all

    set y 0
    foreach node $data(nodes,root) {
        set item $path.$node

        set open  [Widget::getoption $item -open]
        set state [Widget::getoption $item -state]

        if {[string equal $state "hidden"]} { continue }

        set ipadx [Properties::_get_padding $path $item -ipadx 0]
        set ipady [Properties::_get_padding $path $item -ipady 0]

        ## Give everything a 2 padding to the right so that things
        ## don't get clipped of the screen to the left.
        set x  [expr {2 + [Properties::_get_padding $path $item -padx 0]}]
        incr y [Properties::_get_padding $path $item -pady 0]

        set image [BWidget::Icon tree-plus]
        if {$open} { set image [BWidget::Icon tree-minus] }

        ## Add the cross to open and close this table.
        $path.c create image $x $y -image $image -anchor nw \
            -tags [list $node c:$node c:]
        
        ## Create the label to the right of the cross.
	set bbox [$path.c bbox c:$node]
        set tx   [expr {[lindex $bbox 2] + $ipadx}]
        set ty   [expr {$y - 2}]
        set text [Widget::getoption $item -text]
        set font [Widget::cgetOption -font "" $item $path]
        $path.c create text $tx $ty -text $text -font $font -anchor nw \
            -tags [list $node l:$node l:]

        set help [Widget::getoption $item -helptext]
        if {$help ne ""} {
            DynamicHelp::add $path.c -item l:$node -text $help
        }

	set y [expr {[lindex [$path.c bbox l:$node c:$node] end] + $ipady}]

	if {[Widget::getoption $item -open]} {
            set window [Widget::getoption $item -window]
            if {[string length $window] || [llength $data(nodes,$node)]} {
                if {[string length $window]} {
                    set height [winfo reqheight $window]
                } else {
                    set window $path.t$node

                    if {![winfo exists $window]} {
                        _create_root_node $path root $node
                    }

                    foreach event [array names events] {
                        bind $window $event [linsert $cmd end-1 $event]
                    }

                    _redraw_properties $path $node

                    set height [Widget::getoption $item -height]
                }

                $path.c create window $x $y -window $window \
                    -anchor nw -tags [list $node t:$node node]

                if {[Widget::getoption $path -expand]} {
                    set padx  [Properties::_get_padding $path $item -padx 1]
                    set width [winfo width $path.c]
                    $path.c itemconfigure t:$node -width [expr {$width - $padx}]
                }
                incr y $height
            }
	}
	incr y [Properties::_get_padding $path $item -pady 1]
    }

    if {[string length $data(selected)]} { _select_node $path $data(selected) }
}


proc Properties::_redraw_properties { path {nodelist {}} } {
    Widget::getVariable $path data
    Widget::getVariable $path nodes

    if {![llength $nodelist]} { set nodelist $data(nodes,root) }

    foreach parent $nodelist {
        set t $path.t$parent
        Widget::getVariable $path.$parent tableData

        set open  [Widget::getoption $path.$parent -open]
        set state [Widget::getoption $path.$parent -state]

        if {!$open || [string equal $state "hidden"]
            || ![llength $data(nodes,$parent)]} { continue }

        if {![winfo exists $t]} { _create_root_node $path root $parent }

        set data(realized,$parent) 1

        set row 0
	foreach node $data(nodes,$parent) {
            set state [Widget::getoption $path.$node -state]
	    if {[string equal $state "hidden"]} { continue }
            set text  [Widget::getoption $path.$node -text]
            set value [_get_value $path $node]
            set tableData($row,0) $text
            set tableData($row,1) $value
            set nodes($t,$row) $node
            set nodes($parent,$node) $row

            $t tag cell $node-label $row,0
            $t tag cell $node-value $row,1

            incr row

            _configure_help $path $node
	}

        $t configure -rows $row
        Widget::setoption $path.$parent -height [winfo reqheight $t]
    }
}


proc Properties::_option { path parent node option {default ""} } {
    if {[string equal $parent "root"]} {
        set widgets [list $path.$node $path]
    } else {
        set widgets [list $path.$node $path.$parent $path]
    }

    return [eval [list Widget::cgetOption $option $default] $widgets]
}


proc Properties::_focus_canvas { canvas } {
    set path [winfo parent $canvas]
    Widget::getVariable $path data
    edit $path finish
    focus $canvas
}


proc Properties::_resize { path } {
    Widget::getVariable $path data

    if {[Widget::getoption $path -expand]} {
	update idletasks
	set width [winfo width $path.c]
	foreach item [$path.c find withtag node] {
            set node [lindex [$path.c itemcget $item -tags] 0]
            set padx [Properties::_get_padding $path $path.$node -padx 1]
	    $path.c itemconfigure $item -width [expr {$width - $padx}]
	}
	update idletasks
    }

    $path.c configure -scrollregion [$path.c bbox all]
}


proc Properties::_configure_tables { path args } {
    Widget::getVariable $path data

    foreach parent $data(nodes,root) {
        set table $path.t$parent
        eval [list $table configure] $args
    }
}


proc Properties::_button_1 { table x y } {
    if {[string length [$table border mark $x $y]]} { return }
    set path [winfo parent $table]

    Widget::getVariable $path nodes

    set col [$table index @$x,$y col]
    set row [$table index @$x,$y row]

    if {$col == 0} {
        edit $path finish
    }

    if {$col == 1} {
        edit $path start $nodes($table,$row)
    }

    return -code break
}


proc Properties::_double_button_1 { table x y } {

    set col [lindex [$table border mark $x $y col] 0]
    if {![string length $col]} { return }

    set font [$table cget -font]

    set max 0
    foreach string [$table get 0,0 [$table cget -rows],0] {
        set size [font measure $font $string]
        if {$size > $max} { set max $size }
    }
    incr max 5

    $table width 0 -$max
}


proc Properties::_bind_map { path } {
    return [list %%h %h %%w %w %%x %x %%y %y %%X %X %%Y %Y %%T %W %%W $path]
}


proc Properties::_map_command { path parent node command } {
    set var [Properties::variable $path $node]
    set map [list %W $path %p $parent %n $node %v $var]
    return [string map $map $command]
}


proc Properties::_eval_command { path parent node command {resultVarName ""} } {
    if {![string length $command]} { return 1 }
    if {[string length $resultVarName]} { upvar 1 $resultVarName result }
    set command [_map_command $path $parent $node $command]
    set result [uplevel #0 $command]
    if {![string is boolean -strict $result]} { return 1 }
    return $result
}


proc Properties::_get_value { path node } {
    set value   [Widget::getoption $path.$node -value]
    set varName [Widget::getoption $path.$node -variable]
    if {[string length $varName]} {
        upvar #0 $varName var
        if {![info exists var]} { set var "" }
        set value $var
    }
    return $value
}


proc Properties::_untrace_variable { path node } {
    Widget::getVariable $path vars

    if {[info exists vars($path.$node)]} {
        trace remove variable $vars($path.$node) [list write unset] \
            [list Properties::_handle_variable $path $node]
        unset vars($path.$node)
    }
}


proc Properties::_trace_variable { path node } {
    Widget::getVariable $path data
    Widget::getVariable $path vars

    _untrace_variable $path $node

    set varName [Widget::getoption $path.$node -variable]
    if {![string length $varName]} { return }

    if {[info exists $varName]} {
        Widget::setoption $path.$node -value [set $varName]
    }

    trace add variable $varName [list write unset] \
        [list Properties::_handle_variable $path $node]

    set vars($path.$node) $varName
}


proc Properties::_handle_variable { path node name1 name2 op } {
    Widget::getVariable $path data
    Widget::getVariable $path nodes

    set parent  $data($node)
    set varName [Widget::getoption $path.$node -variable]

    switch -- $op {
        "write" {
            Widget::setoption $path.$node -value [set $varName]

            if {![info exists data(editing)] || $data(editing) != $node} {
                if {[info exists nodes($parent,$node)]} {
                    Widget::getVariable $path.$parent tableData

                    set row $nodes($parent,$node)
                    set tableData($row,1) [set $varName]
                }
            }
        }

        "unset" {
            set $varName [Widget::getoption $path.$node -value]
            _trace_variable $path $node
        }
    }
}


proc Properties::_get_padding { path frame option index } {
    set value [Widget::getOption $option "" $frame $path]
    return [Widget::_get_padding $value $index]
}


proc Properties::_configure_help { path node {force 0} } {
    Widget::getVariable $path help

    if {[info exists help($node)] && !$force} { return }

    set help($node) 1

    Widget::getVariable $path nodes

    set parent  [parent $path $node]
    set table   $path.t$parent
    set row     $nodes($parent,$node)
    set text    [Widget::getoption $path.$node -helptext]
    set column  [Widget::getoption $path -helpcolumn]
    set command [Widget::getoption $path.$node -helpcommand]

    set opt  -cell
    set cell $row,0
    if {$column eq "both"} { set opt -row; set cell $row }
    if {$column eq "value"} { set cell $row,1 }

    switch -- [Widget::getoption $path.$node -helptype] {
        "balloon" {
            DynamicHelp::add $table $opt $cell -text $text -command $command
        }

        "variable" {
            DynamicHelp::add $table $opt $cell -text $text -type variable \
                -command $command \
                -variable [Widget::getoption $path.$node -helpvariable]
        }
    }
}


proc Properties::_display_text_balloon { path table row } {
    Widget::getVariable $path nodes

    set node  $nodes($table,$row)
    set value [_get_value $path $node]

    set font    [$table cget -font]
    set measure [font measure $font $value]

    set width [lindex [$table bbox $row,1] 2]
    if {$measure > $width} { return $value }
}


proc Properties::_select_entry_contents { path entry } {
    if {[winfo exists $entry]} {
        $entry selection range 0 end
    }
}


proc Properties::_realize { path } {
    Widget::getVariable $path data

    if {!$data(realized)} {
        set data(realized) 1
        Properties::redraw $path
    }

    if {[string length $data(selected)]} { _select_node $path $data(selected) }
}


# -----------------------------------------------------------------------------
#  Command Properties::_destroy
# -----------------------------------------------------------------------------
proc Properties::_destroy { path } {
    if {[Widget::exists $path]} {
        Widget::getVariable $path data

        foreach node [array names data] {
            Widget::destroy $path.$node 0
            Properties::_untrace_variable $path $node
        }

        Widget::destroy $path
    }
}

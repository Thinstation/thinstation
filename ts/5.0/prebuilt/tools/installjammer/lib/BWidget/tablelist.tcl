# ---------------------------------------------------------------------------
#  tablelist.tcl
#
#  $Id$
# ---------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - TableList::create
#     - TableList::configure
#     - TableList::cget
#
#   Private Commands:
#     - TableList::_resize
# ---------------------------------------------------------------------------

package require Tk 8.4
package require Tktable

namespace eval TableList {
    Widget::define TableList tablelist Button

    Widget::declare TableList::Column {
        {-name              String      ""         0}
        {-state             Enum        "normal"   0 {disabled normal}}
        {-title             String      ""         0}
        {-width             Int         "0"        0}
        {-column            Int         "-1"       0}
        {-showarrow         Boolean2     ""        0}
        {-formatcommand     String      ""         0}

        {-sortable          Boolean     1          0}
        {-sortargs          String      ""         0}

        {-editstartcommand  String      ""         0}
        {-editfinishcommand String      ""         0}
        {-editcancelcommand String      ""         0}

        {-values            String      ""         0}
        {-editable          Boolean     "1"        0}
        {-editwindow        String      ""         0}
        {-postcommand       String      ""         0}
        {-modifycommand     String      ""         0}
        {-valuescommand     String      ""         0}

        {-browseargs        String      ""         0}
        {-browsebutton      Boolean     "0"        0}
	{-browsecommand     String      ""         0}
    }

    Widget::declare TableList::Item {
        {-row               Int         "-1"       0}
        {-open              Boolean     "0"        0}
        {-data              String      ""         0}
        {-state             Enum        "normal"   0 {disabled normal readonly}}
        {-values            String      {}         0}
    }

    Widget::declare TableList {
        {-rows              Int         "0"        0}
        {-state             Enum        "normal"   0 {disabled normal}}
        {-upimage           String      "::TableList::uparrow"   0}
        {-downimage         String      "::TableList::downarrow" 0}
        {-showarrow         Boolean     1          0}
        {-showtitles        Boolean     1          1}

        {-keycolumn         String      ""         0}
        {-treecolumn        String      "0"        1}

        {-sortargs          String      ""         0}
        {-sortinsert        Boolean     0          0}

        {-browseargs        String      ""         0}
	{-browsecommand     String      ""         0}

        {-editstartcommand  String      ""         0}
        {-editfinishcommand String      ""         0}
        {-editcancelcommand String      ""         0}
    }

    image create photo ::TableList::uparrow \
        -file [file join $::BWIDGET::LIBRARY images uparrow.gif]

    image create photo ::TableList::downarrow \
        -file [file join $::BWIDGET::LIBRARY images downarrow.gif]

    Widget::tkinclude TableList table .t \
        remove {
            -variable -roworigin -cache -state -rows
            -browsecommand -browsecmd -selectioncommand -selcmd
            -command -usecommand -validate -validatecommand -vcmd
        } initialize {
            -background #FFFFFF -sparsearray 0 -rows 1 -relief flat
            -cursor "" -colstretchmode last -anchor w
            -multiline 0 -ellipsis ... -selecttype row -selectmode single
            -bordercursor sb_h_double_arrow -exportselection 0
            -highlightthickness 0 -padx 2 -pady 1
        }

    BWidget::bindMouseWheel TableListTable

    bind TableList <FocusIn> [list after idle [list BWidget::refocus %W %W.t]]
    bind TableList <Destroy> [list TableList::_destroy %W]

    bind TableListTable <1> "TableList::_table_button_1 %W %x %y; break"
    bind TableListTable <Key> [list TableList::_handle_key_press %W %K]
    bind TableListTable <Double-1> [list TableList::_title_double_1 %W %x %y]
    bind TableListTable <Shift-Button-1>   "TableList::_select_row %W %x %y 1"
    bind TableListTable <Control-Button-1> "TableList::_select_row %W %x %y 2"
    bind TableListTable <ButtonRelease-1> [list TableList::selection %W update]

    bind TableListLabel <1> [list TableList::_title_button_1 %W %X %x %y]
    bind TableListLabel <Motion> [list TableList::_title_motion %W %x %y]
    bind TableListLabel <B1-Motion> [list TableList::_title_motion_1 %W %X]
    bind TableListLabel <ButtonRelease-1> [list TableList::_title_release_1 %W]
    bind TableListLabel <Double-1> [list TableList::_title_double_1 %W %x %y]
    bind TableListLabel <Configure> [list TableList::_configure_col %W %w]

    ## Define the X pixel threshold for resize borders.
    variable _threshold 5
}


proc TableList::create { path args } {
    Widget::initArgs TableList $args maps

    frame $path -class TableList \
        -borderwidth 0 -highlightthickness 0 -relief flat -takefocus 0

    Widget::initFromODB TableList $path $maps(TableList)

    Widget::getVariable $path data

    array set data {
        sort            0
        items           {}
        resize          0
        labels          {}
        setting         0
        rowCount        0
        selected        {}
        sortColumn      -1
        sortDirection   -1
        selectionAnchor 0
    }

    set data(keyColumn) [Widget::getoption $path -keycolumn]

    Widget::getVariable $path items
    set items(root)   ""
    set items(root,c) [list]

    set opts [list -state disabled -bordercursor sb_h_double_arrow]
    lappend opts -command [list TableList::_get_set_value $path %r %c %i %s]

    if {[Widget::getoption $path -showtitles]} {
        lappend opts -roworigin -1 -resizeborders none -titlerows 1
    } else {
        lappend opts -roworigin 0 -resizeborders col -titlerows 0
    }

    set table $path.t
    eval [list table $table] $opts $maps(.t)
    set top [winfo toplevel $path.t]
    bindtags $path.t [list $path.t TableListTable Table $top all]

    pack $path.t -expand 1 -fill both

    $table tag configure sel -relief flat

    set data(font)    [$table cget -font]
    set data(colvars) [list path size largest invalidSize titleElided]

    redraw $path

    Widget::create TableList $path

    proc ::$path { cmd args } \
        "return \[TableList::_path_command [list $path] \$cmd \$args\]"

    return $path
}


proc TableList::configure { path args } {
    set res [Widget::configure $path $args]

    set table [gettable $path]

    Widget::getVariable $path data

    set redrawCols 0
    set redrawRows 0

    if {[Widget::hasChanged $path -cols cols]} {
        set redrawCols 1
    }

    if {[Widget::hasChanged $path -rows rows]} {
        set data(rowCount) $rows
        set redrawRows 1
    }

    if {[Widget::hasChanged $path -font font]} {
        set data(font) $font
        set redrawCols 1
        set redrawRows 1
    }

    if {[Widget::hasChanged $path -keycolumn keycol]} {
        set data(keyColumn) [_get_col_index $path $keycol]
    }

    if {[Widget::hasChanged $path -showarrow arrow]} {
        set redrawCols 1
    }

    if {[Widget::hasChanged $path -state state]} {
        TableList::edit $path finish
    }

    if {$redrawRows} { _redraw_rows_idle $path }
    if {$redrawCols} { _redraw_cols_idle $path }

    return $res
}


proc TableList::cget { path option } {
    return [Widget::cget $path $option]
}


proc TableList::itemconfigure { path item args } {
    if {![TableList::exists $path $item]} {
        return -code error "item \"$item\" does not exist"
    }

    set i $path#item#$item
    set res [Widget::configure $i $args]
    set refresh 0

    if {[Widget::hasChanged $i -open open]} {
        TableList::_redraw_rows_idle $path
    }

    if {[Widget::hasChanged $i -row row]} {
        TableList::move $path $item [expr {$row + 1}]
    }

    if {[Widget::hasChanged $i -state state]} {
        if {[TableList::edit $path current] eq $item} {
            TableList::edit $path finish
        }
    }

    if {[Widget::hasChanged $i -values values]} {
        set refresh 1
    }

    if {$refresh} {
        [gettable $path] configure -drawmode [$table cget -drawmode]
    }

    return $res
}


proc TableList::itemcget { path item option } {
    if {![TableList::exists $path $item]} {
        return -code error "item \"$item\" does not exist"
    }
    return [Widget::cget $path#item#$item $option]
}


proc TableList::clear { path } {
    eval [list TableList::delete $path] [TableList::items $path root]
}


proc TableList::column { path command args } {
    Widget::getVariable $path data

    switch -- $command {
        "cget" {
            set idx [_get_col_index $path [lindex $args 0]]
            set col $path#column#$idx
            return [Widget::getoption $col [lindex $args 1]]
        }

        "configure" {
            set idx [_get_col_index $path [lindex $args 0]]
            _columnconfigure $path $idx [lrange $args 1 end]
        }

        "delete" {

        }

        "index" {
            return [_get_col_index $path [lindex $args 0]]
        }

        "insert" {

        }

        "label" {
            return $data([_get_col_index $path [lindex $args 0]],path)
        }

        "move" {
            set col     [lindex $args 0]
            set idx     [_get_col_index $path $col]
            set index   [lindex $args 1]
            set column  $path#column#$idx
            set name    [Widget::getoption $column -name]
            set columns [linsert $data(columns) $index $name]

            if {$index < $idx} { incr idx }
            set columns [lreplace $columns $idx $idx]

            _reorder_cols_idle $path $columns
        }

        "order" {
            if {![llength $args]} { return $data(columns) }
            set neworder [lindex $args 0]
            _reorder_cols_idle $path $neworder
        }
    }
}



proc TableList::curselection { path } {
    return [TableList::selection $path get]
}


proc TableList::delete { path args } {
    Widget::getVariable $path items

    TableList::edit $path finish

    foreach item $args {
        if {![info exists items($item)]} { continue }

        Widget::destroy $path#item#$item 0

        set parent $items($item)
        set index  [TableList::index $path $item]

        set items($parent,c) [lreplace $items($parent,c) $index $index]
    }

    _redraw_rows_idle $path
}


proc TableList::edit { path command args } {
    Widget::getVariable $path data

    if {[info exists data(editing)]
        && ![Widget::exists $path#item#$data(editing)]} { unset data(editing) }

    switch -- $command {
	"start" {
	    eval [list _start_edit $path] $args
	}

	"finish" - "cancel" {
	    if {![info exists data(editing)]} { return }

            set row   $data(editrow)
            set col   $data(editcol)
	    set item  $data(editing)
            set table [TableList::gettable $path]

	    set cmd [_option $path $col -edit${command}command]
            if {![_eval_command $path $item $col $cmd]} { return }

	    destroy $path.edit

            ## The -edit(cancel|finish)command might have cancelled
            ## or finished this operation already.  If they did,
            ## we skip the rest of this.
	    if {![info exists data(editing)]} { return }

            if {[string equal $command "finish"]} {
                set val $data(editvalue)

                set values [Widget::getoption $path#item#$item -values]
                set values [lreplace $values $col $col $val]
                Widget::setoption $path#item#$item -values $values

                ## If this item is the largest in the column, we
                ## invalidate the size of the column.
                if {[string equal $data($col,largest) $item]} {
                    set data($col,invalidSize) 1
                }
            }

            set window $path.label$row,$col
            if {[winfo exists $window]} {
                ## This cell has a tree label and cross.  We need
                ## to update the label and put the label back in.
                $window.l configure -text "[_get_set_value $path $row $col]"
                $table window configure $row,$col -sticky news \
                    -window $window -padx 1 -pady 1
            }

            set vars [list editing editpath entrypath browsepath valuespath]
            foreach var $vars {
                if {[info exists data($var)]} { unset data($var) }
            }

            focus $table
	}

        "reread" {
            if {[info exists data(editing)]} {
            set data(editvalue) $data(value)
        }
        }

	"active" - "current" {
	    if {[info exists data(editing)]} { return $data(editing) }
	}

        "activecell" - "currentcell" {
	    if {[info exists data(editing)]} {
                return $data(editrow),$data(editcol)
            }
        }

        "editvalue" {
	    if {[info exists data(editing)]} {
                if {[llength $args]} {
                    set data(editvalue) [lindex $args 0]
                }
                return $data($command)
            }
        }

        "value"      -
        "values"     -
        "editable"   -
        "editpath"   -
        "entrypath"  -
        "browsepath" -
        "valuespath" {
	    if {[info exists data(editing)]} { return $data($command) }
        }
    }
}


proc TableList::exists { path item } {
    return [expr {$item eq "root" || [Widget::exists $path#item#$item]}]
}


proc TableList::get { path args } {
    set table [gettable $path]

    BWidget::ParseArgs _args $args \
        -switches [list -formatted -selected -visible]

    set switches $_args(SWITCHES)
    switch -- [lindex $_args(_ARGS_) 0] {
        "col" - "column" {
            BWidget::ParseArgs _args $_args(_ARGS_) -options [list -parent]
            set col [_get_col_index $path [lindex $_args(_ARGS_) 1]]

            if {$_args(selected)} {
                Widget::getVariable $path data

                set list [list]
                foreach item $data(selected) {
                    set values [Widget::getoption $path#item#$item -values]
                    if {$_args(formatted)} {
                        set row [Widget::getoption $path#item#$item -row]
                        lappend list [$table get $row,$col]
                    } else {
                        lappend list [lindex $values $col]
                    }
                }
                return $list
            }

            return [$table get 0,$col [$table cget -rows],$col]
        }

        "item" {
            set item [lindex $_args(_ARGS_) 1]
            set row  [Widget::getoption $path#item#$item -row]
            return [eval [list TableList::get $path] $switches row $row]
        }

        "items" {
            set rows [list]
            foreach item [lrange $_args(_ARGS_) 1 end] {
                lappend rows [Widget::getoption $path#item#$item -row]
            }
            return [eval [list TableList::get $path] $switches rows $rows]
        }

        "row" {
            Widget::getVariable $path data

            set list [list]
            set last [$table cget -cols]
            set row  [lindex $_args(_ARGS_) 1]
            set item [lindex $data(items) $row]

            if {$_args(formatted)} {
                return [$table get $row,0 $row,$last]
            } else {
                return [Widget::getoption $path#item#$item -values]
            }
        }

        "rows" {
            Widget::getVariable $path data

            set list [list]
            set last [$table cget -cols]
            foreach row [lrange $_args(_ARGS_) 1 end] {
                set item [lindex $data(items) $row]

                if {$_args(formatted)} {
                    lappend list [$table get $row,0 $row,$last]
                } else {
                    lappend list [Widget::getoption $path#item#$item -values]
                }
            }

            return $list
        }

        "selected" {
            set sel [TableList::selection $path get]
            return [eval [list TableList::get $path] $switches item $sel]
        }

        "value" {
            set item [lindex $_args(_ARGS_) 1]
            set col  [lindex $_args(_ARGS_) 2]

            set val [eval [list TableList::get $path] $switches item $item]
            return  [lindex $val $col]
        }

        default {
            return [eval [list $table get] $_args(_ARGS_)]
        }
    }
}


proc TableList::gettable { path } {
    return $path.t
}


proc TableList::index { path item } {
    Widget::getVariable $path items

    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }

    return [lsearch -exact $items($items($item),c) $item]
}


proc TableList::insert { path index parent item args } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set item [Widget::nextIndex $path $item]

    if {[info exists items($item)]} {
        return -code error "item \"$item\" already exists"
    }

    if {![info exists items($parent)]} {
        return -code error "item \"$item\" does not exist"
    }

    set items($item) $parent

    Widget::init TableList::Item $path#item#$item $args

    if {$index eq "end"} {
        lappend items($parent,c) $item
    } else {
        set items($parent,c) [linsert $items($parent,c) $index $item]
    }

    if {$data(sortColumn) > -1 && [Widget::getoption $path -sortinsert]} {
        _sort_rows_idle   $path
    } else {
        _redraw_rows_idle $path
    }

    _invalidate_cols_idle $path

    return $item
}


proc TableList::items { path parent {first ""} {last ""} } {
    Widget::getVariable $path items

    if {![info exists items($parent)]} {
        return -code error "item \"$parent\" does not exist"
    }

    if {![info exists items($parent,c)]} { return }

    if {![string length $first]} { return $items($parent,c) }
    if {![string length $last]}  { return [lindex $items($parent,c) $first] }
    return [lrange $items($parent,c) $first $last]
}


proc TableList::move { path parent item index } {
    Widget::getVariable $path data

    if {![TableList::exists $path $item]} {
        return -code error "item \"$item\" does not exist"
    }

    set oldindex [Widget::getoption $path#item#$item -row]

    if {$oldindex == 0 && $index == $oldindex} { return }
    if {$oldindex != 0 && $index == [expr {$oldindex + 1}]} { return }

    set data(items) [linsert $data(items) $index $item]

    if {$index < $oldindex} { incr oldindex }
    set data(items) [lreplace $data(items) $oldindex $oldindex]

    _redraw_rows_idle $path
}


proc TableList::parent { path item } {
    Widget::getVariable $path items
    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }
    return $items($item)
}


proc TableList::redraw { path } {
    _redraw_rows $path
    _redraw_cols $path
}


proc TableList::reorder { path parent neworder } {
    Widget::getVariable $path items

    if {![info exists items($parent)]} {
        return -code error "item \"$parent\" does not exist"
    }

    set items($parent,c) $neworder

    _redraw_rows_idle $path
}


proc TableList::see { path args } {
    set table [gettable $path]

    update idletasks

    switch -- [lindex $args 0] {
        "cell" {
            $table see [lindex $args 1]
        }

        "item" {
            set item [lindex $args 1]
            set col  [lindex $args 2]
            if {![string length $col]} { set col 0 }

            if {![TableList::exists $path $item]} {
                return -code error "item \"$item\" does not exist"
            }

            set row [Widget::getoption $path#item#$item -row]
            $table see $row,$col
        }

        default {
            eval [list $table see] $args
        }
    }

    return
}


proc TableList::selection { path command args } {
    if {[Widget::exists $path]} { Widget::getVariable $path data }

    set table [TableList::gettable $path]

    switch -- $command {
        "add" {
            foreach item $args {
                if {![TableList::exists $path $item]} {
                    return -code error "item \"$item\" does not exist"
                }
                set row [Widget::getoption $path#item#$item -row]
                $table selection set $row,0
                lappend data(selected) $item
            }

            event generate $path <<TableListSelect>>

            return $data(selected)
        }

        "clear" {
            if {![llength $args]} { set args all }
            eval [list $table selection clear] $args
            TableList::selection $path update
        }

        "get" {
            return $data(selected)
        }

        "includes" {
            set item [lindex $args 0]
            return [expr {[lsearch -exact $data(selected) $item] > -1}]
        }

        "range" {
            set item1 [lindex $args 0]
            if {![TableList::exists $path $item1]} {
                return -code error "item \"$item1\" does not exist"
            }

            set item2 [lindex $args 1]
            if {![TableList::exists $path $item2]} {
                return -code error "item \"$item2\" does not exist"
            }

            set first [Widget::getoption $path#item#$item1 -row]
            set last  [Widget::getoption $path#item#$item2 -row]

            $table selection clear all
            $table selection set $first,0 $last,0

            TableList::selection $path update
        }

        "remove" {
            foreach item $args {
                if {![TableList::exists $path $item]} {
                    return -code error "item \"$item\" does not exist"
                }
                set row [Widget::getoption $path#item#$item -row]
                $table selection clear $row,0
            }

            TableList::selection $path update
        }

        "set" {
            $table selection clear all
            foreach item $args {
                if {![TableList::exists $path $item]} {
                    return -code error "item \"$item\" does not exist"
                }
                set row [Widget::getoption $path#item#$item -row]
                $table selection set $row,0
            }

            event generate $path <<TableListSelect>>

            set data(selected) $args
        }

        "toggle" {
            foreach item $args {
                if {![TableList::exists $path $item]} {
                    return -code error "item \"$item\" does not exist"
                }
                set row [Widget::getoption $path#item#$item -row]
                if {[lsearch -exact $data(selected) $item] > -1} {
                    $table selection clear $row,0
                } else {
                    $table selection set $row,0
                }
            }

            TableList::selection $path update
        }

        "update" {
            if {[string equal [winfo class $path] "Table"]} {
                set table $path
                set path  [winfo parent $path]
                Widget::getVariable $path data
            }

            set data(selected) [list]
            foreach row [$table tag row sel] {
                lappend data(selected) [lindex $data(items) $row]
            }

            event generate $path <<TableListSelect>>

            return $data(selected)
        }
    }
}


proc TableList::sort { path col args } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    array set _args {
        parent  root
    }
    BWidget::ParseArgs _args $args -options [list -parent] \
        -switches [list -increasing -decreasing -recursive]
    
    set col    [TableList::_get_col_index $path $col]
    set parent $_args(parent)
    set column $path#column#$col

    if {![TableList::exists $path $parent]} {
        return -code error "item \"$parent\" does not exist"
    }

    set sortargs [TableList::_option $path $col -sortargs]

    if {[set idx [lsearch -exact $sortargs "-recursive"]] > -1} {
        set _args(recursive) 1
        set sortargs [lreplace $sortargs $idx $idx]
    }

    set direction 0
    if {!$direction} {
        set direction -1
        if {$col == $data(sortColumn)} {
            if {$data(sortDirection) == 1} {
                set direction -1
            } else {
                set direction 1
            }
        }
    }

    if {[lsearch -exact $_args(SWITCHES) "-increasing"] > -1 } {
        lappend sortargs -increasing
    } elseif {[lsearch -exact $_args(SWITCHES) "-decreasing"] > -1} {
        lappend sortargs -decreasing
    } else {
        if {$direction == -1} {
            lappend sortargs -increasing
        } else {
            lappend sortargs -decreasing
        }
    }

    foreach item $items($parent,c) {
        set value [lindex [Widget::getoption $path#item#$item -values] $col]
        lappend sort($value) $item
        if {[info exists items($item,c)]} { lappend parents $item }
    }

    set items($parent,c) [list]
    foreach value [eval lsort $sortargs [list [array names sort]]] {
        eval lappend items($parent,c) $sort($value)
    }

    if {$_args(recursive) && [info exists parents]} {
        foreach parent $parents {
            TableList::sort $path $col -parent $parent \
                -recursive [lindex $sortargs end]
        }
    }

    set data(sortColumn)    $col
    set data(sortDirection) $direction

    _redraw_cols_idle $path
    _redraw_rows_idle $path
}


proc TableList::toggle { path item } {
    if {![TableList::exists $path $item]} {
        return -code error "item \"$item\" does not exist"
    }

    if {[Widget::getoption $path#item#$item -open]} {
        TableList::itemconfigure $path $item -open 0
    } else {
        TableList::itemconfigure $path $item -open 1
    }
}


proc TableList::visible { path item } {
    if {![TableList::exists $path $item]} {
        return -code error "item \"$item\" does not exist"
    }

    return [expr {[Widget::getoption $path#item#$item -row] > -1}]
}


proc TableList::_path_command { path cmd larg } {
    if {[string length [info commands ::TableList::$cmd]]} {
        return [eval [linsert $larg 0 TableList::$cmd $path]]
    } else {
        set table [TableList::gettable $path]
        if {$cmd eq "set"} {
            $table configure -state normal
            set result [eval [linsert $larg 0 $table $cmd]]
            $table configure -state disabled
        } else {
            set result [eval [linsert $larg 0 $table $cmd]]
        }
        
        return $result
    }
}


proc TableList::_redraw_item { path item {level -1} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set col [_get_col_index $path [Widget::getoption $path -treecolumn]]
    if {$col < 0} { return }

    set parent      $items($item)
    set hasChildren [info exists items($item,c)]
    if {$parent eq "root" && !$hasChildren} { return }

    if {$level < 0} {
        set level  0
        while {$parent ne "root"} {
            incr level
            set parent $items($parent)
        }
    }

    set row    $data(rowCount)
    set table  [TableList::gettable $path]
    set window $path.label$row,$col
    set label  $window

    if {![winfo exists $window]} {
        set bg [Widget::cget $path -bg]

        if {$hasChildren} {
            frame $window -bg $bg

            button $window.b -bg $bg -bd 1 -relief flat \
                -command [list $path toggle $item]
            pack $window.b -side left -padx [list [expr {$level * 20}] 0]

            set label $window.l
        }

        Label $label -bg $bg -elide 1 -anchor nw \
            -font $data(font) -borderwidth 0 \
            -padx 0 -pady 0 -highlightthickness 0
        bind $label <1> \
            [list TableList::_handle_tree_label_click $path $row $col]

        if {$hasChildren} {
            pack $label -side left -expand 1 -fill x
        } else {
            $label configure -padx [expr {$level * 20}]
        }
    }

    if {[winfo exists $window.b]} {
        set image [BWidget::Icon tree-plus]
        if {[Widget::getoption $path#item#$item -open]} {
            set image [BWidget::Icon tree-minus]
        }
        $window.b configure -image $image
        set label $window.l
    }

    $label configure -text "[_get_set_value $path $row $col]"

    $table window configure $row,$col -sticky news \
        -window $window -padx 1 -pady 1
    lappend data(labels) $row,$col

    _redraw_cols_idle $path
}


proc TableList::_redraw_rows_idle { path } {
    Widget::getVariable $path data

    if {![info exists data(redrawRows)]} {
        after idle [list TableList::_redraw_rows $path]
        set data(redrawRows) 1
    }
}


proc TableList::_redraw_rows { path {parent root} {level 0} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    if {$parent eq "root"} {
        set data(items)    [list]
        set data(rowCount) -1

        set table   [TableList::gettable $path]
        if {[llength $data(labels)]} {
            eval [list $table window delete] $data(labels)
        }
    } else {
        _redraw_item $path $parent $level

        if {![Widget::getoption $path#item#$parent -open]} { return }

        incr level
    }

    foreach item $items($parent,c) {
        lappend data(items) $item
        Widget::setoption $path#item#$item -row [incr data(rowCount)]
        TableList::_redraw_rows $path $item $level
    }

    if {$parent eq "root"} {
        set table [TableList::gettable $path]

        incr data(rowCount)
        set rowcount $data(rowCount)
        if {[Widget::getoption $path -showtitles]} { incr rowcount }

        $table configure -rows $rowcount -state disabled

        Widget::setoption $path -rows $data(rowCount)

        set rows [list]
        for {set i 1} {$i < [$table cget -rows]} {incr i 2} {
            lappend rows $i
        }
        eval [list $table tag row alt] $rows

        if {[llength $data(selected)]} {
            set selected [list]
            foreach item $data(selected) {
                if {[Widget::exists $path#item#$item]} {
                    lappend selected $item
                }
            }
            eval [list TableList::selection $path set] $selected
        }

        unset -nocomplain data(redrawRows)
    }
}


proc TableList::_sort_rows_idle { path } {
    Widget::getVariable $path data

    if {![info exists data(sortRows)]} {
        after idle [list TableList::_sort_rows $path]
        set data(sortRows) 1
    }
}


proc TableList::_sort_rows { path } {
    Widget::getVariable $path data

    TableList::sort $path $data(sortColumn) $data(sortDirection)

    unset -nocomplain data(sortRows)
}


proc TableList::_columnconfigure { path col options } {
    Widget::getVariable $path data

    set column $path#column#$col

    set oldcol  [Widget::getoption $column -column]
    set oldname [Widget::getoption $column -name]

    set res [Widget::configure $column $options]

    set table [gettable $path]

    set redrawCol 0

    if {[Widget::hasChanged $column -name name]} {
        set idx [lsearch -exact $data(columns) $oldname]
        set data(columns) [lreplace $data(columns) $idx $idx $name]
    }

    if {[Widget::hasChanged $column -state state] && $state eq "disabled"} {
        if {[info exists data(editing)] && $col == $data(editcol)} {
            TableList::edit $path finish
        }
    }

    if {[Widget::hasChanged $column -column newcol]} {
        Widget::setoption $column -column $oldcol
        TableList::column $path move $col [expr {$newcol + 1}]
    }

    if {[Widget::hasChanged $column -title title]} {
        set redrawCol 1
    }

    if {[Widget::hasChanged $column -width width]} {
        set redrawCol 1
        $table width $col $width
    }

    if {[Widget::hasChanged $column -showarrow arrow]} {
        set redrawCol 1
    }

    if {[Widget::hasChanged $column -formatcommand cmd]} {
        ## Force the table widget to redraw.
        $table configure -state normal -state disabled
    }

    if {$redrawCol} { _redraw_col $path $col }

    return $res
}


proc TableList::_redraw_cols_idle { path } {
    Widget::getVariable $path data

    if {![info exists data(redrawCols)]} {
        after idle [list TableList::_redraw_cols $path]
        set data(redrawCols) 1
    }
}


proc TableList::_redraw_cols { path } {
    Widget::getVariable $path data

    set cols [[gettable $path] cget -cols]
    for {set i 0} {$i < $cols} {incr i} {
        _redraw_col $path $i
    }

    unset -nocomplain data(redrawCols)
}


proc TableList::_redraw_col { path col } {
    Widget::getVariable $path data

    set table  [TableList::gettable $path]
    set column $path#column#$col

    if {![Widget::exists $column]} {
        ## This is a new column.
        lappend data(columns) column$col

        set data($col,path)        $path.column$col
        set data($col,size)        0
        set data($col,largest)     ""
        set data($col,invalidSize) 1
        set data($col,titleElided) 0

        set data($data($col,path),col) $col

        set opts [list -name column$col -column $col -width [$table width $col]]
        Widget::init TableList::Column $column $opts
    }

    set label $data($col,path)

    if {[Widget::getoption $path -showtitles]} {
        if {![winfo exists $label]} {
            set top [winfo toplevel $path]
            label $label -relief raised -borderwidth 2 -compound right -anchor w
            bindtags $label [list $label TableListLabel $top all]
            $table window configure -1,$col -window $label -sticky news \
                -padx 0 -pady 0
            $table tag col column$col $col
        }

        set title [Widget::getoption $column -title]

        $label configure -font $data(font)

        if {$col == $data(sortColumn) && [_option $path $col -showarrow]} {
            if {$data(sortDirection) == -1} {
                set image [Widget::getoption $path -upimage]
            } else {
                set image [Widget::getoption $path -downimage]
            }
            $label configure -image $image -text "$title  "
        } else {
            $label configure -image "" -text $title
        }

        _configure_col $label [winfo width $label]
    }
}


proc TableList::_reorder_cols_idle { path columns } {
    Widget::getVariable $path data

    if {![info exists data(reorderCols)]} {
        after idle [list TableList::_reorder_cols $path $columns]
        set data(reorderCols) 1
    }
}


proc TableList::_reorder_cols { path columns } {
    Widget::getVariable $path data

    set newidx 0
    foreach column $columns {
        set oldidx [lsearch -exact $data(columns) $column]

        foreach var $data(colvars) {
            set new($newidx,$var) $data($oldidx,$var)
            unset data($oldidx,$var)
        }

        incr newidx
    }

    array set data [array get new]

    set data(columns) $columns

    set col    0
    set table  [gettable $path]
    set widths [list]
    foreach column $data(columns) {
        Widget::setoption $path#column#$col -column $col
        lappend widths $col [Widget::getoption $path#column#$col -width]
        if {[Widget::getoption $path -showtitles]} {
            $table window configure -1,$col -window $data($col,path) \
                -sticky news -padx 0 -pady 0
        }
        incr col
    }

    eval [list $table width] $widths

    _redraw_cols $path

    unset -nocomplain data(reorderCols)
}


proc TableList::_invalidate_cols_idle { path } {
    Widget::getVariable $path data
    if {![info exists data(invalidCols)]} {
        set data(invalidCols) 1
        after idle [list TableList::_invalidate_cols $path]
    }
}


proc TableList::_invalidate_cols { path } {
    Widget::getVariable $path data

    set table [gettable $path]

    for {set col 0} {$col < [$table cget -cols]} {incr col} {
        set data($col,invalidSize) 1
    }

    unset -nocomplain data(invalidCols)
}


proc TableList::_border_column { widget col x y } {
    set n $::TableList::_threshold
    set w [winfo width $widget]

    if {$col > 0 && $x <= $n}   { return [incr col -1] }
    if {$x >= [expr {$w - $n}]} { return $col }
    return -1
}


proc TableList::_title_motion { widget x y } {
    set path [winfo parent $widget]
    Widget::getVariable $path data

    set col $data($widget,col)
    if {[_border_column $widget $col $x $y] > -1} {
        $widget configure -cursor [Widget::cget $path -bordercursor]
    } else {
        $widget configure -cursor [Widget::cget $path -cursor]
    }
}


proc TableList::_title_button_1 { widget X x y } {
    set path  [winfo parent $widget]
    Widget::getVariable $path data

    set col    $data($widget,col)
    set table  [gettable $path]
    set border [_border_column $widget $col $x $y]

    if {$border > -1} {
        set data(resize)      1
        set data(resizeX)     $X
        set data(resizeCol)   $border
        set data(resizeWidth) [winfo width $data($border,path)]
    } else {
        set data(resize) 0
        if {[Widget::getoption $path#column#$col -sortable]} {
            set data(sort) 1
            TableList::edit $path cancel
            $widget configure -relief sunken
        }
    }
}


proc TableList::_title_motion_1 { widget X } {
    set path  [winfo parent $widget]
    Widget::getVariable $path data

    if {$data(resize)} {
        set width [expr {$data(resizeWidth) + ($X - $data(resizeX))}]
        if {$width > 0} { [gettable $path] width $data(resizeCol) -$width }
    }
}


proc TableList::_title_release_1 { widget } {
    set path [winfo parent $widget]
    Widget::getVariable $path data

    set table [TableList::gettable $path]

    if {$data(sort)} {
        set col $data($widget,col)
        set column $path#column#$col
        TableList::sort $path [Widget::getoption $column -column]
        $widget configure -relief raised
    }

    set data(sort)   0
    set data(resize) 0

    focus $table
}


proc TableList::_title_double_1 { widget x y } {
    set path [winfo parent $widget]
    Widget::getVariable $path data

    set table [gettable $path]

    if {$widget eq $table} {
        set col [lindex [$widget border mark $x $y col] 0]
        if {![string length $col]} { return }
    } else {
        set col $data($widget,col)
        if {[set col [_border_column $widget $col $x $y]] < 0} { return }
    }

    ## They double-clicked on a column resize border.  We want to
    ## shrink or expand the column width to fit the largest string
    ## in the column.

    if {$data($col,invalidSize)} {
        _configure_col_size $path $col
    }

    set width [expr {$data($col,size) + 8}]

    $table width $col -$width

    if {$widget ne $table} {
        _configure_col $widget $width

        update idletasks

        ## Adjust the cursor.
        set X [winfo pointerx $path]
        set Y [winfo pointery $path]
        set w [winfo containing $X $Y]
        set x [expr {$X - [winfo rootx $w]}]
        set y [expr {$Y - [winfo rooty $w]}]

        _title_motion $w $x $y
    }

    focus $table
}


proc TableList::_configure_col { label width } {
    set path  [winfo parent $label]
    Widget::getVariable $path data

    set col    $data($label,col)
    set column $path#column#$col

    set table [gettable $path]
    set font  [$table cget -font]
    set title [Widget::getoption $column -title]
    set ellipsis [$table cget -ellipsis]

    set sorted 0
    if {$col == $data(sortColumn) && [_option $path $col -showarrow]} {
        set sorted 1
        incr width -[image width [$label cget -image]]
        incr width -[font measure $font "  "]
    }

    set text   $title
    set elided 0
    while {[font measure $font $title] > $width} {
        set text   [string range $text 0 end-1]
        set title  $text$ellipsis
        set elided 1
        if {![string length $text]} { break }
    }

    set data($col,titleElided) $elided

    if {!$elided && $sorted} { append title "  " }

    $label configure -text $title

    Widget::setoption $column -width [$table width $col]
}


proc TableList::_get_set_value { path row col {which -1} {value ""} } {
    if {$row < 0} { return }

    Widget::getVariable $path data
    set item [lindex $data(items) $row]

    if {![Widget::exists $path#item#$item]} { return }

    if {$which <= 0} {
        if {![string length $item]} { return }
        set value [lindex [Widget::getoption $path#item#$item -values] $col]

        if {$which == 0} {
            set cmd [Widget::getoption $path#column#$col -formatcommand]
            if {[string length $cmd]} { set value [eval $cmd [list $value]] }
        }

        return $value
    }

    set values [Widget::getoption $path#item#$item -values]
    set values [lreplace $values $col $col $value]
    Widget::setoption $path#item#$item -values $values

    return $value
}


proc TableList::_configure_col_size { path {col -1} {string ""} } {
    Widget::getVariable $path data

    if {[string length $string]} {
        set size [font measure $data(font) $string]
        if {$size > $data($col,size)} { set data($col,size) $size }
        return
    }

    set table [gettable $path]
    set rows  [$table cget -rows]
    set cols  [$table cget -cols]

    if {$col < 0} {
        for {set i 0} {$i < $cols} {incr i} { lappend cols $i }
    } else {
        set cols $col
    }

    set treecol [_get_col_index $path [Widget::getoption $path -treecolumn]]

    foreach col $cols {
        set data($col,size)        0
        set data($col,invalidSize) 0
        set row 0
        foreach item $data(items) {
            set size [font measure $data(font) [$table get $row,$col]]
            if {$col == $treecol && [winfo exists $path.label$row,$col]} {
                incr size [winfo width $path.label$row,$col.b]
            }
            if {$size > $data($col,size)} {
                set data($col,size)    $size
                set data($col,largest) $item
            }
            incr row
        }
    }
}


proc TableList::_table_button_1 { table x y } {
    set path [winfo parent $table]
    Widget::getVariable $path data

    set row  [$table index @$x,$y row]
    set col  [$table index @$x,$y col]
    set last [$table index end row]
    set cell $row,$col

    set bbox [$table bbox $cell]
    if {![llength $bbox]} { return }
    foreach [list bx by bw bh] $bbox { break }

    TableList::edit $path finish
    TableList::selection $path clear

    if {$row == $last && $y > [expr {$by + $bh}]} { return -code break }

    set item [lindex $data(items) $row]
    set data(selectionAnchor) $row
    TableList::selection $path set $item
    if {$item ne "" && ![info exists data(editing)]} {
        TableList::edit $path start $item $col
    }
}


proc TableList::_start_edit { path item col } {
    Widget::getVariable $path data

    if {[TableList::_is_disabled $path $item $col]} { return }

    if {[info exists data(editing)]} { TableList::edit $path finish }

    update idletasks

    foreach var [list editpath entrypath browsepath valuespath] {
        set data($var) ""
    }

    set col [_get_col_index $path $col]

    set column $path#column#$col

    set font     $data(font)
    set window   [Widget::getoption $column -editwindow]
    set values   [Widget::getoption $column -values]
    set valcmd   [Widget::getoption $column -valuescommand]
    set editable [Widget::getoption $column -editable]

    set combobox 0
    if {[string length $values] || [string length $valcmd]} { set combobox 1 }

    frame $path.edit

    set var [Widget::widgetVar $path data(editvalue)]

    if {![string length $window]} {
	if {![Widget::getoption $column -browsebutton]} {
            if {!$combobox} {
		set widget $path.edit.e
                set entry  $widget
		Entry $entry -bd 1 -font $font -textvariable $var \
                    -editable $editable
	    } else {
                set widget  $path.edit.cb
		set entry   $widget.e
                set modcmd  [Widget::getoption $column -modifycommand]
                set postcmd [Widget::getoption $column -postcommand]

                if {[string length $valcmd]} {
                    set values [_eval_command $path $item $column $valcmd]
                }

		ComboBox $widget -borderwidth 1 -font $font \
                    -hottrack 1 -exportselection 0 -textvariable $var \
                    -values $values -editable $editable \
                    -postcommand [_map_command $path $item $column $postcmd] \
                    -modifycommand [_map_command $path $item $column $modcmd]

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
                set modcmd  [Widget::getoption $column -modifycommand]
                set postcmd [Widget::getoption $column -postcommand]

                if {[string length $valcmd]} {
                    set values [_eval_command $path $item $column $valcmd]
                }

		ComboBox $widget -borderwidth 1 -font $font \
                    -exportselection 0 -hottrack 1 -textvariable $var \
                    -values $values -editable $editable \
                    -modifycommand $modcmd -postcommand $postcmd

                set data(valuespath) $widget
            }

            set data(browsepath) $path.edit.b

            set args    [_option $path $col -browseargs]
            set command [_option $path $col -browsecommand]
            lappend args -command [_map_command $path $item $col $command]
            set args [linsert $args 0 -text ...]

            if {[BWidget::using ttk]} {
                eval [list ttk::button $data(browsepath)] $args
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

    set row   [Widget::getoption $path#item#$item -row]
    set cell  $row,$col
    set table [TableList::gettable $path]

    set data(value)     [_get_set_value $path $row $col]
    set data(values)    $values
    set data(editing)   $item
    set data(editcol)   $col
    set data(editrow)   $row
    set data(editable)  $editable
    set data(editpath)  $path.edit
    set data(entrypath) $entry
    set data(editvalue) $data(value)

    $table see $cell

    $table window configure $cell -window $data(editpath) -sticky news -padx 2

    set class [winfo class $entry]
    if {$editable && ($class eq "Entry" || $class eq "Spinbox")} {
        bind $entry <Shift-Tab> [list TableList::_handle_tab_key_press $path -1]
        bind $entry <Tab> [list TableList::_handle_tab_key_press $path 1]
	$entry selection range 0 end
    }

    focus -force $entry

    set cmd [_option $path $col -editstartcommand]
    if {![_eval_command $path $item $col $cmd]} { edit $path cancel; return }

    ## If we're displaying a combobox with non-editable values,
    ## go ahead and post the combobox.
    if {$combobox && !$editable} {
        set listbox [$widget getlistbox]
        bind $listbox <Shift-Tab> \
            [list TableList::_handle_tab_key_press $path -1 1]
        bind $listbox <Tab> [list TableList::_handle_tab_key_press $path 1 1]
        $widget post
    }
}


proc TableList::_map_command { path item col command } {
    set row [Widget::getoption $path#item#$item -row]
    set map [list %W $path %i $item %r $row %c $col %C $row,$col]
    return  [string map $map $command]
}


proc TableList::_eval_command { path item col command } {
    if {![string length $command]} { return 1 }
    set command [_map_command $path $item $col $command]
    return [uplevel #0 $command]
}


proc TableList::_option { path col option {default ""} } {
    Widget::getVariable $path data
    set widgets [list $path#column#$col $path]
    return [eval [list Widget::getOption $option $default] $widgets]
}


proc TableList::_get_col_index { path col } {
    if {[string is integer -strict $col]} {
        set index $col
    } elseif {[string equal $col "end"]} {
        set index [Widget::getoption $path -cols]
    } else {
        Widget::getVariable $path data
        set index [lsearch -exact $data(columns) $col]
        if {$index < 0} { return -code error "column \"$col\" does not exist" }
    }

    return $index
}


proc TableList::_handle_key_press { table K } {
    set path [winfo parent $table]
    Widget::getVariable $path data

    if {$data(keyColumn) < 0} { return }

    if {[info exists data(findAfterId)]} { after cancel $data(findAfterId) }

    set var [Widget::widgetVar $path data(keyFind)]
    set data(findAfterId) [after 1000 [list unset -nocomplain $var]]

    if {[string length $K] == 1} {
        append data(keyFind) $K
        set list [TableList::get $path col $data(keyColumn)]
        set row  [lsearch -glob $list $data(keyFind)*]
        if {$row < 0} {
            set data(keyFind) $K
            set row  [lsearch -glob $list $data(keyFind)*]
        } else {
            TableList::selection $path set [lindex $data(items) $row]
            $table see $row,$data(keyColumn)
        }
    }
}


proc TableList::_handle_tab_key_press { path dir {unpost 0} } {
    Widget::getVariable $path data

    set table [TableList::gettable $path]
    set item  $data(editing)

    set col  [expr {$data(editcol) + $dir}]
    set row  [Widget::getoption $path#item#$item -row]
    set cols [Widget::cget $path -cols]
    set rows [Widget::getoption $path -rows]

    if {$col < 0 || $col == $cols} {
        ## End of the line.
        while {1} {
            if {$col < 0} {
                set col [expr {$cols - 1}]
                incr row $dir
                continue
            }

            if {[expr {$col + 1}] > $cols} {
                set col 0
                incr row $dir
                continue
            }

            if {$row < 0} {
                set row [expr {$rows - 1}]
                continue
            }

            if {[expr {$row + 1}] > $rows} {
                set row 0
                continue
            }

            if {[Widget::getoption $path#column#$col -state] eq "disabled"} {
                incr col $dir
                continue
            }

            set item [lindex $data(items) $row]

            if {[Widget::getoption $path#item#$item -state] eq "disabled"} {
                incr row $dir
                continue
            }

            break
        }

    } else {
        set item $data(editing)
    }

    if {$unpost} {
        $data(valuespath) unpost
    }

    TableList::edit $path finish

    if {![info exists data(editing)]} {
        TableList::edit $path start $item $col
    }

    return -code break
}


proc TableList::_is_disabled { path item col } {
    return [expr {[Widget::getoption $path -state] eq "disabled"
        || [Widget::getoption $path#column#$col -state] eq "disabled"
        || [Widget::getoption $path#item#$item -state] eq "disabled"}]
}


proc TableList::_handle_tree_label_click { path row col } {
    Widget::getVariable $path data

    set item [lindex $data(items) $row]
    set column $path#column#$col
    set window $path.label$row,$col

    ## Clicking the label in a disabled state toggles it.
    if {[TableList::_is_disabled $path $item $col]} {
        TableList::toggle $path $item
    } else {
        TableList::edit $path start $item $col
    }
}


proc TableList::_select_row { table x y which } {
    set path [winfo parent $table]
    Widget::getVariable $path data

    set row [$table index @$x,$y row]

    TableList::edit $path finish

    if {$which == 1} {
        ## Shift click
        set anchor $data(selectionAnchor)
        TableList::selection $path range \
            [lindex $data(items) $anchor] [lindex $data(items) $row]
    } elseif {$which == 2} {
        ## Control click
        TableList::selection $path toggle [lindex $data(items) $row]
    }
}


proc TableList::_destroy { path } {
    variable ::Widget::_class

    Widget::destroy $path

    foreach widget [array names _class $path*] {
        Widget::destroy $widget 0
    }
}

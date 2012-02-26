# ----------------------------------------------------------------------------
#  dynhelp.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: dynhelp.tcl,v 1.13 2003/10/20 21:23:52 damonc Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#     - DynamicHelp::configure
#     - DynamicHelp::include
#     - DynamicHelp::sethelp
#     - DynamicHelp::register
#     - DynamicHelp::_motion_balloon
#     - DynamicHelp::_motion_info
#     - DynamicHelp::_leave_info
#     - DynamicHelp::_menu_info
#     - DynamicHelp::_show_help
#     - DynamicHelp::_init
# ----------------------------------------------------------------------------

namespace eval DynamicHelp {
    Widget::define DynamicHelp dynhelp -classonly

    Widget::declare DynamicHelp {
        {-foreground     Color      "#000000"       0}
        {-topbackground  Color      "#000000"       0}
        {-background     Color      "#FFFFC0"       0}
        {-borderwidth    Int        1               0}
        {-justify        TkResource left            0 label}
        {-font           String     "TkTooltipFont" 0}
        {-delay          Int        600             0 "%d >= 100 & %d <= 2000"}
	{-state          Enum       "normal"        0 {normal disabled}}
        {-padx           Int        1               0}
        {-pady           Int        1               0}

        {-bd             Synonym    -borderwidth}
        {-bg             Synonym    -background}
        {-fg             Synonym    -foreground}
        {-topbg          Synonym    -topbackground}
    }

    Widget::declare DynamicHelp::Node {
        {-row            Int             ""         0}
        {-col            Int             ""         0}
        {-cell           String          ""         0}

        {-tag            String          ""         0}
        {-type           String          "balloon"  0}
        {-text           String          ""         0}
        {-item           String          ""         0}
        {-index          Int             "-1"       0}
        {-command        String          ""         0}
        {-variable       String          ""         0}
        {-destroyballoon Enum            "leave"    0 {leave motion}}
    }

    variable _saved
    variable _widgets
    variable _registered

    variable _top     ".#Bwidget#helpBalloon"
    variable _id      ""
    variable _delay   600
    variable _current_balloon  ""
    variable _current_variable ""

    Widget::init DynamicHelp $_top [list]

    bind BwHelpBalloon <Enter>   {DynamicHelp::_motion_balloon enter  %W %X %Y}
    bind BwHelpBalloon <Motion>  {DynamicHelp::_motion_balloon motion %W %X %Y}
    bind BwHelpBalloon <Leave>   {DynamicHelp::_motion_balloon leave  %W %X %Y}
    bind BwHelpBalloon <Button>  {DynamicHelp::_motion_balloon button %W %X %Y}

    bind BwHelpVariable <Enter>  {DynamicHelp::_motion_info %W}
    bind BwHelpVariable <Motion> {DynamicHelp::_motion_info %W}
    bind BwHelpVariable <Leave>  {DynamicHelp::_leave_info  %W}

    bind BwHelpMenu <Unmap>        {DynamicHelp::_menu_info unmap  %W}
    bind BwHelpMenu <<MenuSelect>> {DynamicHelp::_menu_info select %W}

    bind BwHelpTableBalloon <Leave>  { DynamicHelp::_table_leave balloon %W }
    bind BwHelpTableBalloon <Motion> {
        DynamicHelp::_table_motion balloon %W %X %Y %x %y
    }

    bind BwHelpTableVariable <Leave>  { DynamicHelp::_table_leave variable %W }
    bind BwHelpTableVariable <Motion> {
        DynamicHelp::_table_motion variable %W %X %Y %x %y
    }

    bind BwHelpDestroy <Destroy> [list DynamicHelp::_unset_help %W]
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::configure
# ----------------------------------------------------------------------------
proc DynamicHelp::configure { args } {
    variable _top
    variable _delay

    set res [Widget::configure $_top $args]
    if { [Widget::hasChanged $_top -delay val] } {
        set _delay $val
    }

    return $res
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::include
# ----------------------------------------------------------------------------
proc DynamicHelp::include { class type } {
    set helpoptions [list \
        [list -helptext    String    ""    0] \
        [list -helpvar     String    ""    0] \
        [list -helpcommand String    ""    0] \
        [list -helptype    Enum      $type 0 [list balloon variable]] \
    ]
    Widget::declare $class $helpoptions
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::sethelp
# ----------------------------------------------------------------------------
proc DynamicHelp::sethelp { path subpath {force 0} } {
    set vars [list -helptype -helptext -helpvar -helpcommand]
    if {$force || [eval [list Widget::anyChangedX $path] $vars]} {
	set type [Widget::cget $path -helptype]
        set txt  [Widget::cget $path -helptext]
        set cmd  [Widget::cget $path -helpcommand]

        switch $type {
            "balloon" {
                add $subpath -text $txt -command $cmd
            }

            "variable" {
                set var [Widget::cget $path -helpvar]
                add $subpath -text $txt -type $type -command $cmd -variable $var
            }

            default {
                return [register $subpath $type]
            }
        }
    }
}

# ----------------------------------------------------------------------------
#  Command DynamicHelp::register ( DEPRECATED -- USE DynamicHelp::add )
#
#  DynamicHelp::register path balloon  ?itemOrTag? text
#  DynamicHelp::register path variable ?itemOrTag? text varName
#  DynamicHelp::register path menu varName
#  DynamicHelp::register path menuentry index text
# ----------------------------------------------------------------------------
proc DynamicHelp::register { path type args } {
    variable _registered

    set len [llength $args]
    if {$type == "balloon"  && $len > 1} { set type canvasBalloon  }
    if {$type == "variable" && $len > 2} { set type canvasVariable }

    if { ![winfo exists $path] } {
        _unset_help $path
        return 0
    }

    switch $type {
        "balloon" {
            set data(-text) [lindex $args 0]
        }

        "canvasBalloon" {
            set data(-item) [lindex $args 0]
            set data(-text) [lindex $args 1]
        }

        "variable" {
            set data(-type)     variable
            set data(-variable) [lindex $args 0]
            set data(-text)     [lindex $args 1]
        }

        "canvasVariable" {
            set data(-type)     variable
            set data(-item)     [lindex $args 0]
            set data(-variable) [lindex $args 1]
            set data(-text)     [lindex $args 2]
        }

        "menu" {
            set data(-type)     menu
            set data(-variable) [lindex $args 0]
        }

        "menuentry" {
            set data(-type)  menu
            set data(-index) [lindex $args 0]
            set data(-text)  [lindex $args 1]
        }

        default {
            _unset_help $path
	    return 0
        }
    }

    foreach option [list -text -variable -index] {
        if {[info exists data($option)] && [string equal $data($option) ""]} {
            _unset_help $path
            return 0
        }
    }

    eval [list DynamicHelp::add $path] [array get data]

    return 1
}


proc DynamicHelp::add { path args } {
    variable _registered

    set node #DynamicHelp#$path
    Widget::init DynamicHelp::Node $node $args

    if {[winfo exists $path] && [string equal [winfo class $path] "Menu"]} {
        Widget::configure $node [list -type menu]
    }

    set name     $path
    set tag      [Widget::getoption $node -tag]
    set item     [Widget::getoption $node -item]
    set type     [Widget::getoption $node -type]
    set text     [Widget::getoption $node -text]
    set variable [Widget::getoption $node -variable]

    set row      [Widget::getoption $node -row]
    set col      [Widget::getoption $node -col]
    set cell     [Widget::getoption $node -cell]

    switch -- $type {
        "balloon" {
            if {[string length $item]} {
                _add_canvas_balloon $path $text $item
                set name $path,$item
            } elseif {[string length $tag]} {
                _add_text_balloon $path $text $tag
                set name $path,$tag
            } elseif {[string length $cell]} {
                _add_table_balloon $path $text $cell
                set name $path,$cell
            } elseif {[string length $row]} {
                _add_table_balloon $path $text row,$row
                set name $path,row,$row
            } elseif {[string length $col]} {
                _add_table_balloon $path $text col,$col
                set name $path,col,$col
            } else {
                _add_balloon $path $text
            }

            if {[string length $variable]} {
		set _registered($tag,balloonVar) $variable
	    }
        }

        "variable" {
            set var $variable
            if {[string length $item]} {
                _add_canvas_variable $path $text $var $item
                set name $path,$item
            } elseif {[string length $tag]} {
                _add_text_variable $path $text $var $tag
                set name $path,$tag
            } elseif {[string length $cell]} {
                _add_table_variable $path $text $var $cell
                set name $path,$cell
            } elseif {[string length $row]} {
                _add_table_variable $path $text $var row,$row
                set name $path,row,$row
            } elseif {[string length $col]} {
                _add_table_variable $path $text $var col,$col
                set name $path,col,$col
            } else {
                _add_variable $path $text $var
            }
        }

        "menu" {
            set index [Widget::getoption $node -index]

            if {$index != -1} {
                set cpath [BWidget::clonename $path]
                if { [winfo exists $cpath] } { set path $cpath }
                if {![info exists _registered($path)]} { return 0 }
                _add_menuentry $path $text $index
                set name $path,$index
            } else {
                _add_menu $path $variable
            }
        }

        default {
            return 0
        }
    }

    set command [Widget::getoption $node -command]
    if {[string length $command]} { set _registered($name,command) $command }

    return 1
}


proc DynamicHelp::delete { path } {
    _unset_help $path
}


proc DynamicHelp::itemcget { path option } {
    set item #DynamicHelp#$path
    if {![Widget::exists $item]} {
        return -code error "no dynamic help found for $path"
    }
    return [Widget::getoption $item $option]
}


proc DynamicHelp::itemconfigure { path args } {
    set item #DynamicHelp#$path
    if {![Widget::exists $item]} {
        return -code error "no dynamic help found for $path"
    }
    return [Widget::configure $item $args]
}


proc DynamicHelp::_add_bind_tag { path args } {
    set evt [bindtags $path]
    set found 0
    foreach tag $args {
        if {[lsearch -exact $evt $tag] < 0} {
            set found 1
            lappend evt $tag
        }
    }
    if {$found} { bindtags $path $evt }
    return $found
}


proc DynamicHelp::_add_balloon { path text } {
    variable _registered
    set _registered($path,balloon) $text
    _add_bind_tag $path BwHelpBalloon BwHelpDestroy
}


proc DynamicHelp::_add_canvas_balloon { path text tagOrItem } {
    set DynamicHelp::_registered($path,$tagOrItem,balloon) $text

    if {[DynamicHelp::_add_bind_tag $path BwHelpBalloon BwHelpDestroy]} {
        ## This canvas doesn't have the bindings yet.

        $path bind BwHelpBalloon <Enter> \
            [list DynamicHelp::_motion_balloon enter  %W %X %Y canvas]
        $path bind BwHelpBalloon <Motion> \
            [list DynamicHelp::_motion_balloon motion %W %X %Y canvas]
        $path bind BwHelpBalloon <Leave> \
            [list DynamicHelp::_motion_balloon leave  %W %X %Y canvas]
        $path bind BwHelpBalloon <Button> \
            [list DynamicHelp::_motion_balloon button %W %X %Y canvas]
    }

    $path addtag BwHelpBalloon withtag $tagOrItem
}


proc DynamicHelp::_add_text_balloon { path text tag } {
    set DynamicHelp::_registered($path,$tag,balloon) $text

    _add_bind_tag $path BwHelpDestroy

    $path tag bind $tag <Enter> \
        [list DynamicHelp::_motion_balloon enter  %W %X %Y text $tag]
    $path tag bind $tag <Motion> \
        [list DynamicHelp::_motion_balloon motion %W %X %Y text $tag]
    $path tag bind $tag <Leave> \
        [list DynamicHelp::_motion_balloon leave  %W %X %Y text $tag]
    $path tag bind $tag <Button> \
        [list DynamicHelp::_motion_balloon button %W %X %Y text $tag]
}


proc DynamicHelp::_add_table_balloon { path text cell } {
    set DynamicHelp::_registered($path,$cell,balloon) $text
    _add_bind_tag $path BwHelpTableBalloon BwHelpDestroy
}


proc DynamicHelp::_add_variable { path text varName } {
    set DynamicHelp::_registered($path,variable) [list $varName $text]
    _add_bind_tag $path BwHelpVariable BwHelpDestroy
}


proc DynamicHelp::_add_canvas_variable { path text varName tagOrItem } {
    set DynamicHelp::_registered($path,$tagOrItem,variable) \
        [list $varName $text]

    if {[DynamicHelp::_add_bind_tag $path BwHelpVariable BwHelpDestroy]} {
        ## This canvas doesn't have the bindings yet.

        $path bind BwHelpVariable <Enter> \
            [list DynamicHelp::_motion_info %W canvas]
        $path bind BwHelpVariable <Motion> \
            [list DynamicHelp::_motion_info %W canvas]
        $path bind BwHelpVariable <Leave> \
            [list DynamicHelp::_leave_info  %W canvas]
    }

    $path addtag BwHelpVariable withtag $tagOrItem
}


proc DynamicHelp::_add_text_variable { path text varName tag } {
    set DynamicHelp::_registered($path,$tag,variable) [list $varName $text]

    _add_bind_tag $path BwHelpDestroy

    $path tag bind $tag <Enter>  [list DynamicHelp::_motion_info %W text $tag]
    $path tag bind $tag <Motion> [list DynamicHelp::_motion_info %W text $tag]
    $path tag bind $tag <Leave>  [list DynamicHelp::_leave_info  %W text $tag]
}


proc DynamicHelp::_add_table_variable { path text varName cell } {
    set DynamicHelp::_registered($path,$cell,variable) [list $varName $text]
    _add_bind_tag $path BwHelpTableVariable BwHelpDestroy
}


proc DynamicHelp::_add_menu { path varName } {
    set cpath [BWidget::clonename $path]
    if {[winfo exists $cpath]} { set path $cpath }

    set DynamicHelp::_registered($path) [list $varName]
    _add_bind_tag $path BwHelpMenu BwHelpDestroy
}


proc DynamicHelp::_add_menuentry { path text index } {
    variable _registered

    set idx  [lsearch $_registered($path) [list $index *]]
    set list [list $index $text]
    if { $idx == -1 } {
	lappend _registered($path) $list
    } else {
	set _registered($path) \
	    [lreplace $_registered($path) $idx $idx $list]
    }
}


proc DynamicHelp::_table_motion { type table X Y x y } {
    variable _registered

    set row  [$table index @$x,$y row]
    set col  [$table index @$x,$y col]
    set cell $row,$col
    set path $table

    if {[info exists _registered($table,$cell,$type)]} {
        set path $table,$cell
    } elseif {[info exists _registered($table,row,$row,$type)]} {
        set path $table,row,$row
    } elseif {[info exists _registered($table,col,$col,$type)]} {
        set path $table,col,$col
    }

    if {[string equal $type "balloon"]} {
        variable _id
        variable _top
        variable _delay
        variable _current_balloon

        set event [Widget::getoption #DynamicHelp#$table -destroyballoon]
        if {[string equal $event "motion"]} { _destroy_balloon $_top }

        if {![string equal $_current_balloon $path]} {
            _destroy_balloon $_top
            set _current_balloon $path
        }

        if {[string length $_id]} {
            after cancel $_id
            set _id ""
        }

        if {![winfo exists $_top]} {
            set cmd [list DynamicHelp::_show_help $path $table $X $Y $row $col]
            set _id [after $_delay $cmd]
        }
    } else {
        variable _saved
        variable _current_variable

        set curr $_current_variable

        if {![string equal $_current_variable $path]} {
            _table_leave variable $table

            if {[info exists _registered($path,variable)]} {
                set varName [lindex $_registered($path,variable) 0]
                if {![info exists _saved]} {
                    set _saved [BWidget::getglobal $varName]
                }
                set string [lindex $_registered($path,variable) 1]
                if {[info exists _registered($path,command)]} {
                    set string [eval $_registered($path,command)]
                }
                BWidget::setglobal $varName $string
                set _current_variable $path
            }
        }
    }
}


proc DynamicHelp::_table_leave { type table } {
    switch -- $type {
        "balloon" {
            variable _id
            variable _top
            variable _current_balloon ""
            after cancel $_id
            _destroy_balloon $_top
        }

        "variable" {
            variable _saved
            variable _registered
            variable _current_variable
            set curr $_current_variable

            set _current_variable ""

            if {[info exists _registered($curr,variable)]} {
                set varName [lindex $_registered($curr,variable) 0]
                BWidget::setglobal $varName $_saved
            }
        }
    }
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::_motion_balloon
# ----------------------------------------------------------------------------
proc DynamicHelp::_motion_balloon { type path x y {class ""} {tag ""} } {
    variable _id
    variable _top
    variable _delay
    variable _current_balloon

    set event [Widget::getoption #DynamicHelp#$path -destroyballoon]

    set w $path
    if {[string equal $class "canvas"]} {
        set path [_get_canvas_path $path balloon]
    } elseif {[string equal $class "text"]} {
        set path $path,$tag
    }

    if {![string equal $_current_balloon $path]
        && [string equal $type "enter"]} {
        set _current_balloon $path
        set type "motion"
        _destroy_balloon $_top
    }

    if {[string equal $_current_balloon $path]} {
        if {[string length $_id]} {
            after cancel $_id
            set _id ""
        }

        if {[string equal $type "motion"]} {
            if {![winfo exists $_top]} {
                set cmd [list DynamicHelp::_show_help $path $w $x $y]
                set _id [after $_delay $cmd]
            } elseif {[string equal $event "motion"]} {
                ## The user has opted to destroy the balloon
                ## any time there is mouse motion.  We still
                ## keep the current_balloon set though so that
                ## if the mouse stops again within the same
                ## widget, we'll display the balloon again.
                _destroy_balloon $_top
            }
        } else {
            _destroy_balloon $_top
            set _current_balloon ""
        }
    }
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::_motion_info
# ----------------------------------------------------------------------------
proc DynamicHelp::_motion_info { path {class ""} {tag ""} } {
    variable _saved
    variable _registered
    variable _current_variable

    if {[string equal $class "canvas"]} {
        set path [_get_canvas_path $path balloon]
    } elseif {[string equal $class "text"]} {
        set path $path,$tag
    }

    if { $_current_variable != $path
        && [info exists _registered($path,variable)] } {

        set varName [lindex $_registered($path,variable) 0]
        if {![info exists _saved]} { set _saved [BWidget::getglobal $varName] }
        set string [lindex $_registered($path,variable) 1]
        if {[info exists _registered($path,command)]} {
            set string [eval $_registered($path,command)]
        }
        BWidget::setglobal $varName $string
        set _current_variable $path
    }
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::_leave_info
# ----------------------------------------------------------------------------
proc DynamicHelp::_leave_info { path {class ""} {tag ""} } {
    variable _saved
    variable _registered
    variable _current_variable

    if {[string equal $class "canvas"]} {
        set path [_get_canvas_path $path balloon]
    } elseif {[string equal $class "text"]} {
        set path $path,$tag
    }

    if { [info exists _registered($path,variable)] } {
        set varName [lindex $_registered($path,variable) 0]
        BWidget::setglobal $varName $_saved
    }
    unset _saved
    set _current_variable ""
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::_menu_info
#    Version of R1v1 restored, due to lack of [winfo ismapped] and <Unmap>
#    under windows for menu.
# ----------------------------------------------------------------------------
proc DynamicHelp::_menu_info { event path } {
    variable _registered

    if { [info exists _registered($path)] } {
        set index   [$path index active]
        set varName [lindex $_registered($path) 0]
        if { ![string equal $index "none"] &&
             [set idx [lsearch $_registered($path) [list $index *]]] != -1 } {
	    set string [lindex [lindex $_registered($path) $idx] 1]
	    if {[info exists _registered($path,$index,command)]} {
		set string [eval $_registered($path,$index,command)]
	    }
            BWidget::setglobal $varName $string
        } else {
            BWidget::setglobal $varName ""
        }
    }
}


# ----------------------------------------------------------------------------
#  Command DynamicHelp::_show_help
# ----------------------------------------------------------------------------
proc DynamicHelp::_show_help { path w x y {row -1} {col -1} } {
    variable _top
    variable _registered
    variable _id
    variable _delay

    if {[string equal [Widget::getoption $_top -state] "disabled"]} { return }

    if {[info exists _registered($path,balloon)]} {
        _destroy_balloon $_top 1

        set string $_registered($path,balloon)

	if {[info exists _registered($path,balloonVar)]} {
	    upvar #0 $_registered($path,balloonVar) var
	    if {[info exists var]} { set string $var }
	}

        if {[info exists _registered($path,command)]} {
            set map [list %W $w %X $x %Y $y %c $col %r $row %C $row,$col]
            set string [eval [string map $map $_registered($path,command)]]
        }

        if {![string length $string]} { return }

        toplevel $_top -relief flat \
            -bg [Widget::getoption $_top -topbackground] \
            -bd [Widget::getoption $_top -borderwidth] \
            -screen [winfo screen $w]

        wm withdraw $_top
        if {[BWidget::using aqua]} {
            ::tk::unsupported::MacWindowStyle style $_top help none
        } else {
            wm overrideredirect $_top 1
        }

	catch { wm attributes $_top -topmost 1 }

        label $_top.label -text $string \
            -relief flat -bd 0 -highlightthickness 0 \
	    -padx       [Widget::getoption $_top -padx] \
	    -pady       [Widget::getoption $_top -pady] \
            -foreground [Widget::getoption $_top -foreground] \
            -background [Widget::getoption $_top -background] \
            -font       [Widget::getoption $_top -font] \
            -justify    [Widget::getoption $_top -justify] \
            -wraplength 400


        pack $_top.label -side left
        update idletasks

	if {![winfo exists $_top]} { return }

        set  scrwidth  [winfo vrootwidth  .]
        set  scrheight [winfo vrootheight .]
        set  width     [winfo reqwidth  $_top]
        set  height    [winfo reqheight $_top]
        incr y 12
        incr x 8

        if { $x+$width > $scrwidth } {
            set x [expr {$scrwidth - $width}]
        }
        if { $y+$height > $scrheight } {
            set y [expr {$y - 12 - $height}]
        }

        wm geometry  $_top "+$x+$y"
        update idletasks

	if {![winfo exists $_top]} { return }
        wm deiconify $_top
        raise $_top
    }
}

# ----------------------------------------------------------------------------
#  Command DynamicHelp::_unset_help
# ----------------------------------------------------------------------------
proc DynamicHelp::_unset_help { path } {
    variable _widgets
    variable _registered

    if {[info exists _registered($path)]} { unset _registered($path) }
    if {[winfo exists $path]} {
	set cpath [BWidget::clonename $path]
	if {[info exists _registered($cpath)]} { unset _registered($cpath) }

        set tags [list BwHelpBalloon BwHelpVariable BwHelpMenu BwHelpDestroy]
        bindtags $path [eval [list BWidget::lremove [bindtags $path]] $tags]
    }

    array unset _widgets    $path,*
    array unset _registered $path,*

    Widget::destroy #DynamicHelp#$path
}

# ----------------------------------------------------------------------------
#  Command DynamicHelp::_get_canvas_path
# ----------------------------------------------------------------------------
proc DynamicHelp::_get_canvas_path { path type {item ""} } {
    variable _registered

    if {$item == ""} { set item [$path find withtag current] }

    ## Check the tags related to this item for the one that
    ## represents our text.  If we have text specific to this
    ## item or for 'all' items, they override any other tags.
    eval [list lappend tags $item all] [$path itemcget $item -tags]
    foreach tag $tags {
	set check $path,$tag
	if {![info exists _registered($check,$type)]} { continue }
	return $check
    }
}


proc DynamicHelp::_destroy_balloon { top {force 0} } {
    if {[winfo exists $top]} {
	if {!$force && [BWidget::using aqua]} {
	    BWidget::FadeWindowOut $top 1
	} else {
	    destroy $top
        }
    }
}

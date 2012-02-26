# ----------------------------------------------------------------------------
#  panedw.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - PanedWindow::create
#     - PanedWindow::configure
#     - PanedWindow::cget
#     - PanedWindow::add
#     - PanedWindow::getframe
#
#   Private Commands:
#     - PanedWindow::_destroy
#     - PanedWindow::_redraw
#     - PanedWindow::_resize
#     - PanedWindow::_sash_move
#     - PanedWindow::_sash_move_begin
#     - PanedWindow::_sash_move_end
# ----------------------------------------------------------------------------

namespace eval PanedWindow {
    Widget::define PanedWindow panedw

    namespace eval Pane {
        Widget::declare PanedWindow::Pane {
            {-after   String   ""       1}
            {-before  String   ""       0}
            {-minsize Int      0        0 "%d >= 0"}
            {-width   Int      0        0 "%d >= 0"}
            {-height  Int      0        0 "%d >= 0"}
            {-weight  Int      0        0 "%d >= 0"}
            {-padx    Int      0        0}
            {-pady    Int      0        0}
            {-hide    Boolean  0        0}
            {-sticky  String   "nesw"   0}
            {-stretch Enum     "always" 0 {always first last middle never}}
        }
    }

    Widget::tkinclude PanedWindow frame :cmd \
        include {
            -relief -bd -borderwidth -bg -background -cursor -width -height
        }

    Widget::declare PanedWindow {
        {-side         Enum       top      1 {top left bottom right}}
        {-activator    Enum       "line"   1 {line button}}
	{-weights      Enum       "extra"  1 {extra available}}
        {-opaqueresize Boolean    "0"      0}

        {-sashpad      Int        4        1 "%d >= 0"}
        {-sashcursor   String     ""       0}
        {-sashwidth    Int        4        0}
        {-sashrelief   Enum       "raised" 0
                                  {flat groove raised ridge solid sunken}}

        {-handlepad    Int        "6"      0 "%d >= 0"}
        {-handlesize   Int        "10"     0 "%d >= 0"}
        {-showhandle   Boolean    "0"      0}
        {-handlemove   Boolean    "0"      0}

        {-pad          Synonym    -sashpad}
    }

    bind PanedWindow <Destroy>   [list PanedWindow::_destroy %W]
    bind PanedWindow <Configure> [list PanedWindow::_resize %W %w %h]
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::create
# ----------------------------------------------------------------------------
proc PanedWindow::create { path args } {
    Widget::initArgs PanedWindow $args maps

    eval [list frame $path -class PanedWindow] $maps(:cmd)

    Widget::initFromODB PanedWindow $path $maps(PanedWindow)

    Widget::getVariable $path data

    array set data {
        npanes          0
        curpanes        0
        realized        0
        resizing        0
        horizontal      0
        lastpane        ""
        firstpane       ""
        panes           {}
        frames          {}
        sashes          {}
        handles         {}
        allwidgets      {}
        curwidgets      {}
    }
    
    set side [Widget::getoption $path -side]
    if {[string equal $side "top"] || [string equal $side "bottom"]} {
        set data(horizontal) 1
    }

    if {[string equal [Widget::getoption $path -activator] "button"]} {
        Widget::configure $path [list -showhandle 1]
    }

    return [Widget::create PanedWindow $path]
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::configure
# ----------------------------------------------------------------------------
proc PanedWindow::configure { path args } {
    Widget::getVariable $path data

    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -background bg] && $data(npanes) > 0 } {
        $path:cmd configure -background $bg
        foreach widget $data(allwidgets) {
            $widget configure -background $bg
        }
    }

    return $res
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::cget
# ----------------------------------------------------------------------------
proc PanedWindow::cget { path option } {
    return [Widget::cget $path $option]
}


proc PanedWindow::itemconfigure { path pane args } {
    Widget::getVariable $path data
    set frame [lindex $data(frames) [index $path $pane]]

    set res [Widget::configure $frame $args]

    set resize 0
    if {[Widget::hasChanged $frame -hide hide]} {
        set resize 1
        _redraw $path
    }

    $frame configure \
        -width  [Widget::getoption $frame -width] \
        -height [Widget::getoption $frame -height]

    if {$resize || [Widget::anyChangedX $frame -stretch -width -height]} {
        _resize $path
    }

    return $res
}


## Compatibility proc for Tcl 8.4's panedwindow.
proc PanedWindow::paneconfigure { path pane args } {
    return [eval [list PanedWindow::itemconfigure $path $pane] $args]
}


proc PanedWindow::itemcget { path pane option } {
    Widget::getVariable $path data
    set frame [lindex $data(frames) [index $path $pane]]
    return [Widget::cget $frame $option]
}


## Compatibility proc for Tcl 8.4's panedwindow.
proc PanedWindow::panecget { path pane option } {
    return [PanedWindow::itemcget $path $pane $option]
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::add
# ----------------------------------------------------------------------------
proc PanedWindow::add { path args } {
    Widget::getVariable $path data

    set num    $data(npanes)
    set pane   $path.f$num
    set user   $pane.frame
    set create 1

    ## It's optional that the user can pass us a widget instead of
    ## creating a new frame.  See if we were passed an existing
    ## widget as our first argument.
    if {[llength $args] && [winfo exists [lindex $args 0]]} {
        set user   [lindex $args 0]
        set args   [lrange $args 1 end]
        set create 0
    }

    Widget::init PanedWindow::Pane $pane $args

    set index  end
    set after  [Widget::getoption $pane -after]
    set before [Widget::getoption $pane -before]

    if {[string length $after]} {
        set idx [lsearch -exact $data(panes) $after]
        if {$idx > 0} { set index [expr {$idx + 1}] }
    }

    if {[string length $before]} {
        set idx [lsearch -exact $data(panes) $before]
        if {$idx > 0} { set index $idx }
    }

    set data(panes)  [linsert $data(panes)  $index $user]
    set data(frames) [linsert $data(frames) $index $pane]

    set bg      [Widget::cget $path -background]
    set sashw   [Widget::getoption $path -sashwidth]
    set sashc   [Widget::getoption $path -sashcursor]
    set sashr   [Widget::getoption $path -sashrelief]
    set handlew [Widget::getoption $path -handlesize]

    if { $num > 0 } {
        set sep $path.sash$num
        set but $path.handle$num
        frame $sep -bd 1 -highlightthickness 0 \
            -bg $bg -width $sashw -height $sashw -relief $sashr
        frame $but -bd 1 -relief raised -highlightthickness 0 \
            -bg $bg -width $handlew -height $handlew

        lappend data(sashes)     $sep
        lappend data(handles)    $but
        lappend data(allwidgets) $sep $but

        set cursor [Widget::getoption $path -sashcursor]
        if {[string equal $cursor ""]} {
            if {$data(horizontal)} {
                set cursor sb_h_double_arrow 
            } else {
                set cursor sb_v_double_arrow 
            }
        }

        ## If they only want to move with the handle, don't bind the sash.
        if {![Widget::getoption $path -handlemove]} {
            $sep configure -cursor $cursor 
            bind $sep <B1-Motion>       [list $path _sash_move %X %Y]
            bind $sep <ButtonRelease-1> [list $path _sash_move_end %X %Y]
            bind $sep <ButtonPress-1>   [list $path _sash_move_begin %W %X %Y]
        }

        ## Bind the handle for movement.
        $but configure -cursor $cursor 
        bind $but <B1-Motion>       [list $path _sash_move %X %Y]
        bind $but <ButtonRelease-1> [list $path _sash_move_end %X %Y]
        bind $but <ButtonPress-1>   [list $path _sash_move_begin %W %X %Y]
    }

    frame $pane -bd 0 -relief flat -highlightthickness 0 -bg $bg \
        -width  [Widget::getoption $pane -width] \
        -height [Widget::getoption $pane -height]
    lappend data(allwidgets) $pane

    if {$create} {
        frame $user -bd 0 -relief flat -highlightthickness 0 -bg $bg
        lappend data(allwidgets) $user
    }
    place $user -in $pane -x 0 -y 0 -relwidth 1 -relheight 1
    raise $user

    incr data(npanes)

    _redraw $path
    _resize $path

    return $user
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::getframe
# ----------------------------------------------------------------------------
proc PanedWindow::getframe { path index } {
    Widget::getVariable $path data
    return [lindex $data(panes) $index]
}


proc PanedWindow::index { path pane } {
    Widget::getVariable $path data

    set n   [expr {[llength $data(panes)] - 1}]
    set idx $pane
    if {[string is integer -strict $pane]} {
        if {$pane < 0}  { set idx 0  }
        if {$pane > $n} { set idx $n }
    } elseif {[string equal $pane "end"]} {
        set idx $n
    } else {
        set idx [lsearch -exact $data(panes) $pane]
    }

    return $idx
}


proc PanedWindow::panes { path {first ""} {last ""} } {
    Widget::getVariable $path data
    if {![string length $first]} { return $data(panes) }
    if {![string length $last]}  { return [lindex $data(panes) $first] }
    return [lrange $data(panes) $first $last]
}


proc PanedWindow::delete { path args } {
    Widget::getVariable $path data

    foreach pane $args {
        set idx [lsearch -exact $data(panes) $pane]
        if {$idx < 0} { continue }
        set frame  [lindex $data(frames)  $idx]

        if {$idx == [expr {[llength $data(panes)] - 1}]} {
            set sash   [lindex $data(sashes)  end]
            set handle [lindex $data(handles) end]
        } else {
            set sash   [lindex $data(sashes)  $idx]
            set handle [lindex $data(handles) $idx]
        }

        set created [expr [lsearch -exact $data(allwidgets) $pane] > -1]

        set data(panes)   [lreplace $data(panes)  $idx $idx]
        set data(frames)  [lreplace $data(frames) $idx $idx]

        set data(sashes)     [BWidget::lremove $data(sashes)  $sash]
        set data(handles)    [BWidget::lremove $data(handles) $handle]
        set data(allwidgets) [BWidget::lremove $data(allwidgets) \
                                $frame $sash $pane $handle]

        destroy $frame $sash $handle

        ## If we created this frame, we need to destroy it.
        ## Otherwise, the user created it, and we don't want to mess with it.
        if {$created} { destroy $pane }
    }

    _redraw $path
    _resize $path
}


## Compatibility proc for Tcl 8.4's panedwindow.
proc PanedWindow::forget { path pane } {
    return [PanedWindow::delete $path $pane]
}


proc PanedWindow::identify { path x y } {
    Widget::getVariable $path data

    set idx    -1
    set widget [winfo containing $x $y]

    if {[Widget::getoption $path -showhandle]} {
        set idx  [lsearch -exact $data(handles) $widget]
        set word handle
    }

    if {$idx < 0} {
        set idx  [lsearch -exact $data(sashes) $widget]
        set word sash
    }

    if {$idx > -1} { return [list $idx $word] }
}


proc PanedWindow::_sash_temp_name { path } {
    set top [winfo toplevel $path]
    if {[string equal $top "."]} {
        return .#BWidget#sash
    } else {
        return $top.#BWidget#sash
    }
}
    

# ----------------------------------------------------------------------------
#  Command PanedWindow::_sash_move_begin
# ----------------------------------------------------------------------------
proc PanedWindow::_sash_move_begin { path w x y } {
    Widget::getVariable $path data

    set data(x)      $x
    set data(y)      $y
    set data(startX) $x
    set data(startY) $y
    set data(endX)   $x
    set data(endY)   $y
    set data(sash)   [lsearch -exact $data(curwidgets) $w]

    if {![Widget::getoption $path -opaqueresize]} {
        ## If we're not doing an opaque resize, we need to draw
        ## a temporary sash that we can move around.
        set bg   [Widget::cget $path -background]
        set sash [lindex $data(curwidgets) $data(sash)]
        set geom [split [winfo geometry $sash] x+-]
        foreach [list w h x y] $geom { break }

        set sashw [Widget::getoption $path -sashwidth]
        set sashr [Widget::getoption $path -sashrelief]

        set sep [_sash_temp_name $path]
        frame $sep -bd 1 -highlightthickness 0 \
            -bg $bg -width $sashw -height $sashw -relief $sashr

        place $sep -in $path -x $x -y $y -width $w -height $h
    }
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::_sash_move
# ----------------------------------------------------------------------------
proc PanedWindow::_sash_move { path x y } {
    Widget::getVariable $path data

    set cx $data(x)
    set cy $data(y)

    set data(x) $x
    set data(y) $y

    set column $data(sash)

    if {$data(horizontal)} {
        set change [expr {$x - $cx}]
    } else {
        set change [expr {$y - $cy}]
    }

    if {$change == 0} { return }

    if {$change < 0} {
        set lose [lindex $data(curwidgets) [expr {$column - 1}]]
        set gain [lindex $data(curwidgets) [expr {$column + 1}]]
        incr column -1
        set adjust 5
    } else {
        set lose [lindex $data(curwidgets) [expr {$column + 1}]]
        set gain [lindex $data(curwidgets) [expr {$column - 1}]]
        incr column 1
        set adjust -5
    }

    if {$data(horizontal)} {
        set box [grid bbox $path $column 0]
    } else {
        set box [grid bbox $path 0 $column]
    }

    if {![Widget::getoption $path -opaqueresize]} {
        set sep [_sash_temp_name $path]
        if {$data(horizontal)} {
            set opt -x
            set min [expr {[lindex $box 0] + $adjust}]
            set max [expr {$min + [lindex $box 2] - 5}]
        } else {
            set opt -y
            set min [expr {[lindex $box 1] + $adjust}]
            set max [expr {$min + [lindex $box 3] - 5}]
        }

        set new [expr {[lindex [place configure $sep $opt] end] + $change}]

        if {$change < 0 && $new <= $min} { return }
        if {$change > 0 && $new >= $max} { return }
        place $sep $opt $new
    } else {
        set change [expr {abs($change)}]
        set min [Widget::getoption $lose -minsize]
        if {$data(horizontal)} {
            set opt  -width
            set size [lindex $box 2]
        } else {
            set opt  -height
            set size [lindex $box 3]
        }

        if {$size - $change <= $min} { return }

        set losex [expr {[$lose cget $opt] - $change}]
        set gainx [expr {[$gain cget $opt] + $change}]
        $lose configure $opt $losex
        $gain configure $opt $gainx

        Widget::setoption $lose $opt $losex
        Widget::setoption $gain $opt $gainx
    }

    set data(endX) $x
    set data(endY) $y
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::_sash_move_end
# ----------------------------------------------------------------------------
proc PanedWindow::_sash_move_end { path x y } {
    Widget::getVariable $path data

    if {[Widget::getoption $path -opaqueresize]} { return }

    set sep [_sash_temp_name $path]

    if {$data(horizontal)} {
        set opt    -width
        set change [expr {$data(endX) - $data(startX)}]
    } else {
        set opt    -height
        set change [expr {$data(endY) - $data(startY)}]
    }

    if {$change < 0} {
        set lose [lindex $data(curwidgets) [expr {$data(sash) - 1}]]
        set gain [lindex $data(curwidgets) [expr {$data(sash) + 1}]]
    } else {
        set lose [lindex $data(curwidgets) [expr {$data(sash) + 1}]]
        set gain [lindex $data(curwidgets) [expr {$data(sash) - 1}]]
    }

    if {[set min [Widget::getoption $lose -minsize]] < 1} { set min 1 }

    set losex [expr {[$lose cget $opt] - abs($change)}]
    if {$losex < $min} { set losex $min }
    set gainx [expr {[$gain cget $opt] + ([$lose cget $opt] - $losex)}]

    $lose configure $opt $losex
    $gain configure $opt $gainx

    Widget::setoption $lose $opt $losex
    Widget::setoption $gain $opt $gainx

    destroy $sep
}


proc PanedWindow::_resize { path {w ""} {h ""} } {
    Widget::getVariable $path data

    if {$data(resizing)} { return }

    if {$data(curpanes) < 1} { return }

    set data(resizing) 1

    set npanes $data(curpanes)

    if {[string equal $w ""]} { set w [winfo width  $path] }
    if {[string equal $h ""]} { set h [winfo height $path] }

    if {$data(horizontal)} {
        set opt   -width
	set total $w
    } else {
        set opt   -height
	set total $h
    }

    set sashp [Widget::getoption $path -sashpad]
    set sashw [Widget::getoption $path -sashwidth]
    set sashw [expr {$sashw + (2 * $sashp)}]
    set total [expr {$total - (($npanes - 1) * $sashw)}]
    
    set panes        [list]
    set sizes        [list]
    set panesize     0
    set stretchpanes 0
    foreach frame $data(frames) {
        if {[Widget::getoption $frame -hide]} { continue }
        set stretch   [Widget::getoption $frame -stretch]
        set framesize [Widget::getoption $frame $opt].0

        if {[string equal $stretch "never"]
            || ([string equal $stretch "last"]
                && ![string equal $frame $data(lastpane)])
            || ([string equal $stretch "first"]
                && ![string equal $frame $data(firstpane)])
            || ([string equal $stretch "middle"]
                && ([string equal $frame $data(firstpane)]
                    || [string equal $frame $data(lastpane)]))} {
            set total [expr {$total - $framesize}]
            continue
        }
        lappend panes $frame
        lappend sizes $framesize
        set panesize [expr {$panesize + $framesize}]
        incr stretchpanes
    }

    foreach pane $panes size $sizes {
        if {$panesize > 0} {
            set newsize [expr {($size / $panesize) * $total}]
        } else {
            set newsize [expr {$total / $stretchpanes}]
        }
        $pane configure $opt $newsize
    }

    update idletasks
    set data(resizing) 0
}


proc PanedWindow::_redraw { path } {
    Widget::getVariable $path data

    set data(curpanes)   0
    set data(curwidgets) [list]

    set handle     [Widget::getoption $path -showhandle]
    set sashpad    [Widget::getoption $path -sashpad]
    set handlepad  [Widget::getoption $path -handlepad]

    set sashPadX   0
    set sashPadY   0
    set handlePadX 0
    set handlePadY 0

    set side [Widget::getoption $path -side]
    if {$data(horizontal)} {
        set where        column
        set sashPadX     $sashpad
        set sashSticky   ns
        set handlePadY   $handlepad
        set handleSticky s
        if {[string equal $side "top"]} { set handleSticky n }
        grid rowconfigure $path 0 -weight 1
    } else {
        set where        row
        set sashPadY     $sashpad
        set sashSticky   ew
        set handlePadX   $handlepad
        set handleSticky e
        if {[string equal $side "left"]} { set handleSticky w }
        grid columnconfigure $path 0 -weight 1
    }

    ## Before we redraw the grid, we need to walk through and
    ## make sure all the configuration options are clean.
    set i -1
    foreach widget $data(curwidgets) {
        grid remove $widget
        grid ${where}configure $path [incr i] -weight 0
    }

    set c -1
    foreach pane $data(frames) sash $data(sashes) {
        if {[Widget::getoption $pane -hide]} { continue }

        if {$data(horizontal)} {
            set row 0; set col [incr c]
        } else {
            set row [incr c]; set col 0
        }

        if {!$data(curpanes)} { set data(firstpane) $pane }
        set data(lastpane) $pane
        incr data(curpanes)

        lappend data(curwidgets) $pane

        ## Grid the pane into place.
        set padx   [Widget::getoption $pane -padx]
        set pady   [Widget::getoption $pane -pady]
        set sticky [Widget::getoption $pane -sticky]
        set weight [Widget::getoption $pane -weight]
        grid $pane -in $path -row $row -column $col \
            -sticky $sticky -padx $padx -pady $pady
        grid ${where}configure $path $c -weight $weight

        if {[string length $sash]} {
            if {$data(horizontal)} {
                set row 0; set col [incr c]
            } else {
                set row [incr c]; set col 0
            }

            lappend data(curwidgets) $sash

            ## Grid the sash into place
            grid $sash -in $path -row $row -column $col \
                -sticky $sashSticky -padx $sashPadX -pady $sashPadY

            set x [lsearch -exact $data(sashes) $sash]
            set button [lindex $data(handles) $x]
            if {$handle} {
                grid $button -in $path -row $row -column $col \
                    -sticky $handleSticky -padx $handlePadX -pady $handlePadY
            } else {
                grid remove $button
            }
        }
    }
}


# ----------------------------------------------------------------------------
#  Command PanedWindow::_destroy
# ----------------------------------------------------------------------------
proc PanedWindow::_destroy { path } {
    Widget::getVariable $path data

    for {set i 0} {$i < $data(npanes)} {incr i} {
        Widget::destroy $path.f$i 0
    }

    Widget::destroy $path
}

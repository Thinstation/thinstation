# ----------------------------------------------------------------------------
#  drawerpanel.tcl
#	Create Drawer Panel widget.
#  $Id$
# ----------------------------------------------------------------------------
#  Index of commands:
#     - DrawerPanel::cget
#     - DrawerPanel::configure
#     - DrawerPanel::create
#     - DrawerPanel::getframe
#     - DrawerPanel::insert
# ----------------------------------------------------------------------------

namespace eval DrawerPanel {
    Widget::define DrawerPanel drawerpanel IconLibrary

    Widget::declare DrawerPanel::Drawer {
	{-panelbackground        String       ""              0}
	{-panelforeground        String       ""              0}
	{-panelbackground2       String       ""              0}
	{-panelactiveforeground  String       ""              0}
        {-panelheight            Int          ""              0 "%d > 0"}
        {-animatespeed           Int          ""              0 "%d > -1"}
        {-gradientoffset         Int          ""              0 "%d > -1"}

	{-drawerbackground       String       ""              0}
	{-drawerwidth		 Int	      ""              0 "%d > -1"}
	{-drawerheight	         Int	      ""              0 "%d > -1"}

	{-font		         String       ""              0}
	{-text		         String       ""              0}
        {-bevel                  Boolean2     ""              0}
        {-pady                   Padding      ""              0}
        {-padx                   Padding      ""              0}
        {-ipadx                  Padding      ""              0}

        {-open                   Boolean      1               0}
    }

    Widget::tkinclude DrawerPanel frame :cmd \
        include {
            -background -bg -borderwidth -bd -relief
        }

    Widget::tkinclude DrawerPanel canvas .c \
        include {
            -background -bg -width -height
            -xscrollcommand -yscrollcommand -xscrollincrement -yscrollincrement
        } initialize {
            -width 200
        }

    Widget::declare DrawerPanel {
	{-font		         String       "TkTextFont"      0}
	{-panelbackground        String       "#FFFFFF"         0}
	{-panelforeground        String       "#000000"         0}
	{-panelbackground2       String       "#9898b534ffff"   0}
	{-panelactiveforeground  Color        "SystemHighlight" 0}
        {-panelheight            Int          20                0 "%d > 0"}
        {-gradientoffset         Int          75                0}
        {-animatespeed           Int          20                0}

	{-drawerbackground       String       "#9898b534ffff"   0}
	{-drawerwidth		 Int	      150               0 "%d > -1"}
	{-drawerheight	         Int	      100               0 "%d > -1"}

        {-bevel                  Boolean      1                 0}
        {-expand                 Boolean      0                 0}
        {-pady                   Padding      8                 0}
        {-padx                   Padding      10                0}
        {-ipadx                  Padding      10                0}
    }

    bind DrawerPanel <Configure> [list DrawerPanel::_configure %W %w %h]
}


proc DrawerPanel::create { path args } {
    BWidget::LoadBWidgetIconLibrary

    frame $path -class DrawerPanel
    if {[info tclversion] >= 8.4} { $path configure -padx 0 -pady 0 }

    Widget::init DrawerPanel $path $args

    Widget::getVariable $path data

    set data(Y)       0
    set data(image)   0
    set data(redraw)  0
    set data(frames)  [list]
    set data(drawers) [list]

    set data(width)   [Widget::getoption $path -drawerwidth]

    grid rowconfigure    $path 0 -weight 1
    grid columnconfigure $path 0 -weight 1

    canvas $path.c -borderwidth 0 -highlightthickness 0
    grid $path.c -row 0 -column 0 -sticky news

    $path.c bind link <1>     [list DrawerPanel::toggle $path]
    $path.c bind link <Enter> [list DrawerPanel::_highlight_drawer $path enter]
    $path.c bind link <Leave> [list DrawerPanel::_highlight_drawer $path leave]

    return [Widget::create DrawerPanel $path]
}


proc DrawerPanel::cget { path option } {
    return [Widget::cget $path $option]
}


proc DrawerPanel::configure { path args } {
    Widget::getVariable $path data

    set res [Widget::configure $path $args]

    set redraw [Widget::anyChangedX $path -padx -pady -ipadx -font \
        -background -drawerbackground -drawerheight -panelforeground -expand]

    set redrawImages [Widget::anyChangedX $path -panelheight -panelbackground \
        -panelbackground2 -gradientoffset -bevel -drawerwidth]

    if {$redraw || $redrawImages} { _redraw_idle $path $redrawImages }

    return $res
}


proc DrawerPanel::itemcget { path drawer option } {
    return [Widget::cget [getframe $path $drawer] $option]
}


proc DrawerPanel::itemconfigure { path drawer args } {
    Widget::getVariable $path data

    set frame [getframe $path $drawer]

    set res [Widget::configure $frame $args]

    if {[Widget::hasChanged $frame -drawerbackground bg]} {
        $frame configure -background $bg
    }

    if {[Widget::hasChanged $frame -panelforeground fg]} {
        $path.c itemconfigure $drawer-text -fill $fg
    }

    if {[Widget::hasChanged $frame -font font]} {
        set font [Widget::getOption -font "" $frame $path]
        $path.c itemconfigure $drawer-text -font $font
    }

    if {[Widget::hasChanged $frame -text text]} {
        $path.c itemconfigure $drawer-text -text $text
    }

    if {[Widget::hasChanged $frame -open open]} {
        if {$open} {
            DrawerPanel::open  $path $drawer
        } else {
            DrawerPanel::close $path $drawer
        }
    }

    set redraw [Widget::anyChangedX $frame -padx -pady -ipadx -drawerheight]

    set redrawImages [Widget::anyChangedX $frame -panelbackground \
        -panelbackground2 -gradientoffset -panelheight -bevel -drawerwidth]

    if {$redraw || $redrawImages} { _redraw_idle $path $redrawImages }

    return $res
}


proc DrawerPanel::getcanvas { path } {
    return $path.c
}


proc DrawerPanel::open { path drawer } {
    Widget::getVariable $path data

    set frame [getframe $path $drawer]

    Widget::setoption $frame -open 1

    set index  [expr [lsearch -exact $data(drawers) $drawer] + 1]
    set length [llength $data(drawers)]
    set height [Widget::getOption -drawerheight "" $frame $path]
    set amount [Widget::getOption -animatespeed "" $frame $path]

    $path.c itemconfigure $drawer-image \
        -image [BWidget::Icon nav2uparrow16]

    $path.c itemconfigure $frame -window $frame

    DrawerPanel::_animate_drawer $path $frame $index $length 0 $height $amount

    return
}


proc DrawerPanel::close { path drawer } {
    Widget::getVariable $path data

    set frame [getframe $path $drawer]

    Widget::setoption $frame -open 0

    set index  [expr [lsearch -exact $data(drawers) $drawer] + 1]
    set length [llength $data(drawers)]
    set height [Widget::getOption -drawerheight "" $frame $path]
    set amount [Widget::getOption -animatespeed "" $frame $path]
    set amount -$amount

    $path.c itemconfigure $drawer-image \
        -image [BWidget::Icon nav2downarrow16]

    DrawerPanel::_animate_drawer $path $frame $index $length $height 0 $amount

    return
}


proc DrawerPanel::toggle { path {drawer ""} } {
    if {![string length $drawer]} {
        set drawer [_get_drawer_from_item $path current]
        if {![DrawerPanel::exists $path $drawer]} { return }
    }

    set frame [getframe $path $drawer]

    if {[Widget::getoption $frame -open]} {
        DrawerPanel::close $path $drawer
    } else {
        DrawerPanel::open $path $drawer
    }

    return
}


proc DrawerPanel::exists { path drawer } {
    return [expr [DrawerPanel::index $path $drawer] > -1]
}


proc DrawerPanel::getframe { path drawer } {
    if {![DrawerPanel::exists $path $drawer]} {
        return -code error "drawer \"$drawer\" does not exist"
    }
    return $path.f$drawer
}


proc DrawerPanel::index { path drawer } {
    Widget::getVariable $path data
    return [lsearch -exact $data(drawers) $drawer]
}


proc DrawerPanel::drawers { path {first ""} {last ""} } {
    Widget::getVariable $path data
    if {![string length $first]} { return $data(drawers) }
    if {![string length $last]}  { return [lindex $data(drawers) $first] }
    return [lrange $data(drawers) $first $last]
}


proc DrawerPanel::order { path {order ""} } {
    Widget::getVariable $path data

    if {![string length $order]} { return $data(drawers) }

    set data(drawers) $order
    set data(frames)  [list]
    foreach drawer $data(drawers) {
        lappend data(frames) [getframe $path $drawer]
    }

    _redraw_idle $path
}


proc DrawerPanel::insert { path index drawer args } {
    Widget::getVariable $path data

    set drawer [Widget::nextIndex $path $drawer]

    if {[DrawerPanel::exists $path $drawer]} {
        return -code error "drawer \"$drawer\" already exists"
    }

    set frame $path.f$drawer
    Widget::init DrawerPanel::Drawer $frame $args

    set bg     [Widget::getOption -drawerbackground "" $frame $path]
    set width  [Widget::getOption -drawerwidth  "" $frame $path]
    set height [Widget::getOption -drawerheight "" $frame $path]

    frame $frame -width $width -height $height -background $bg
    pack propagate $frame 0
    grid propagate $frame 0

    set data(frames)  [linsert $data(frames)  $index $frame]
    set data(drawers) [linsert $data(drawers) $index $drawer]

    if {[string equal $index "end"]} {
        _draw_drawer $path $drawer
        _resize $path
    } else {
        _redraw_idle $path
    }

    return $frame
}


proc DrawerPanel::delete { path drawer } {
    Widget::getVariable $path data

    set frame [getframe $path $drawer]
    set index [index $path $drawer]

    set data(frames)  [lreplace $data(frames)  $index $index]
    set data(drawers) [lreplace $data(drawers) $index $index]

    destroy $frame

    _redraw_idle $path
}


proc DrawerPanel::xview { path args } {
    return [eval [list $path.c xview] $args]
}


proc DrawerPanel::yview { path args } {
    return [eval [list $path.c yview] $args]
}


proc DrawerPanel::_get_drawer_from_item { path item } {
    return [lindex [$path.c itemcget $item -tags] 1]
}


proc DrawerPanel::_highlight_drawer { path type } {
    set drawer [_get_drawer_from_item $path current]
    set frame  [getframe $path $drawer]

    switch -- $type {
        "leave" {
            set fill [Widget::getOption -panelforeground "" $frame $path]
        }
        "enter" {
            set fill [Widget::getOption -panelactiveforeground "" $frame $path]
        }
    }

    $path.c itemconfigure $drawer-text -fill $fill
}


proc DrawerPanel::_animate_drawer { path frame index length height max amt } {
    ## We use the value of max to determine if we're
    ## opening or closing this drawer.
    ## max == 0 == closing
    ## max >  0 == opening

    if {$height == $max} {
        if {!$max} { $path.c itemconfigure $frame -window "" }
        _resize $path
        return
    }

    incr height $amt

    set animate 1
    if {!$amt} {
        set amt     [expr {$max - $height}]
        set height  $max
        set animate 0
    } elseif {$amt > 0 && $height > $max} {
        set amt    [expr {$max - $height + $amt}]
        set height $max
    } elseif {$amt < 0 && $height < $max} {
        set amt    [expr {$max - $height + $amt}]
        set height $max
    }

    $frame configure -height $height
    if {!$max && !$animate} { $path.c itemconfigure $frame -window "" }

    _move_drawers $path $index $length $amt

    update idletasks

    if {$animate} {
        after 10 [lreplace [info level 0] 5 5 $height]
    } else {
        _resize $path
    }
}


proc DrawerPanel::_move_drawers { path start length amt } {
    for {set i $start} {$i < $length} {incr i} {
        $path.c move idx$i 0 $amt
    }
}


proc DrawerPanel::_get_drawer_colors { path drawer } {
    Widget::getVariable $path data

    set frame  [getframe $path $drawer]
    set width  [Widget::getOption -drawerwidth      "" $frame $path]
    set offset [Widget::getOption -gradientoffset   "" $frame $path]
    set color1 [Widget::getOption -panelbackground  "" $frame $path]
    set color2 [Widget::getOption -panelbackground2 "" $frame $path]
    set color1 [BWidget::color2hex $path $color1]
    set color2 [BWidget::color2hex $path $color2]
    if {[Widget::getoption $path -expand]} { set width $data(width) }

    return [BWidget::getGradientColors $color1 $color2 $width $offset]
}


proc DrawerPanel::_get_drawer_image { path drawer {force 0} } {
    Widget::getVariable $path data

    set frame  [getframe $path $drawer]
    set padx   [DrawerPanel::_get_padding $path $frame -padx 0]
    set padx2  [DrawerPanel::_get_padding $path $frame -padx 1]
    set bevel  [Widget::getOption -bevel            "" $frame $path]
    set width  [Widget::getOption -drawerwidth      "" $frame $path]
    set height [Widget::getOption -panelheight      "" $frame $path]
    set offset [Widget::getOption -gradientoffset   "" $frame $path]
    set color1 [Widget::getOption -panelbackground  "" $frame $path]
    set color2 [Widget::getOption -panelbackground2 "" $frame $path]
    set color1 [BWidget::color2hex $path $color1]
    set color2 [BWidget::color2hex $path $color2]
    set colors [_get_drawer_colors $path $drawer]

    if {[Widget::getoption $path -expand]} { set width $data(width) }

    set width [expr {$width - $padx - $padx2}]

    set key $path:$color1:$color2:$offset:$width:$height:$bevel
    if {!$force && [info exists data(image,$key)]} { return $data(image,$key) }

    set data(image,$key) \
        [image create photo DrawerPanel::$path[incr data(image)]]
    _redraw_image $path $data(image,$key) $colors $width $height $bevel

    return $data(image,$key)
}


proc DrawerPanel::_bevel_image { path image width } {
    set bg [BWidget::color2hex $path [Widget::cget $path -background]]

    $image put $bg -to 0 0
    $image put $bg -to 0 1
    $image put $bg -to 1 0
    $image put $bg -to [expr {$width - 2}] 0
    $image put $bg -to [expr {$width - 1}] 0
    $image put $bg -to [expr {$width - 1}] 1
}


proc DrawerPanel::_redraw_image { path image colors width height {bevel 0} } {
    for {set i 0} {$i < $height} {incr i} {
        lappend imagedata $colors
    }

    $image blank
    $image configure -height $height -width $width
    $image put $imagedata

    if {$bevel} { _bevel_image $path $image $width }
}


proc DrawerPanel::_draw_drawer { path drawer {Y ""} } {
    Widget::getVariable $path data

    if {![string length $Y]} { set Y $data(Y) }

    set c [getcanvas $path]

    set frame   [getframe $path $drawer]
    set image   [_get_drawer_image $path $drawer]
    set index   [lsearch -exact $data(drawers) $drawer]
    set width   [Widget::cgetOption -drawerwidth  "" $frame $path]
    set height  [Widget::cgetOption -drawerheight "" $frame $path]
    set pheight [Widget::getOption  -panelheight  "" $frame $path]
    set padx    [DrawerPanel::_get_padding $path $frame -padx 0]
    set padx2   [DrawerPanel::_get_padding $path $frame -padx 1]
    set ipadx   [DrawerPanel::_get_padding $path $frame -ipadx 0]
    set ipadx2  [DrawerPanel::_get_padding $path $frame -ipadx 1]

    if {[Widget::getoption $path -expand]} { set width $data(width) }

    set data($drawer,Y) $Y

    incr Y [DrawerPanel::_get_padding $path $frame -pady 0]
    $path.c create image $padx $Y -anchor nw -image $image \
        -tags [list idx$index $drawer $drawer-panel link]

    $path.c create text \
        [expr {$padx + $ipadx}] [expr {$Y + ($pheight / 2)}] \
        -text [Widget::getoption $frame -text] \
        -font [Widget::getOption -font "" $frame $path] \
        -fill [Widget::getOption -panelforeground "" $frame $path] \
        -anchor w -tags [list idx$index $drawer $drawer-text link]

    set image nav2downarrow16
    if {[Widget::getoption $frame -open]} { set image nav2uparrow16 }

    $path.c create image \
        [expr {$width - $padx - $padx2 - $ipadx2}] \
        [expr {$Y + ($pheight / 2)}] \
        -image [BWidget::Icon $image] -anchor w \
        -tags [list idx$index $drawer $drawer-image link]

    incr Y $pheight

    $path.c create window $padx $Y -anchor nw \
        -tags [list idx$index $drawer $drawer-frame $frame]
    $frame configure -height $height -width [expr {$width - $padx - $padx2}]

    if {[Widget::getoption $frame -open]} {
        $path.c itemconfigure $drawer-frame -window $frame
        incr Y [Widget::getOption -drawerheight "" $frame $path]
    }

    incr Y [DrawerPanel::_get_padding $path $frame -pady 1]

    set data(Y) $Y
}


proc DrawerPanel::_get_padding { path frame option index } {
    set value [Widget::getOption $option "" $frame $path]
    return [Widget::_get_padding $value $index]
}


proc DrawerPanel::_resize { path } {
    set bbox [$path.c bbox all]
    if {![llength $bbox]} { return }
    set bbox [lreplace $bbox 0 1 0 0]
    $path.c configure -scrollregion $bbox
}


proc DrawerPanel::_redraw_idle { path {redrawImages 0} } {
    Widget::getVariable $path data

    if {!$data(redraw)} {
        after idle [list DrawerPanel::_redraw $path $redrawImages]
        set data(redraw) 1
    }
}


proc DrawerPanel::_redraw { path {redrawImages 0} } {
    Widget::getVariable $path data

    $path.c delete all

    if {$redrawImages} {
        ## Destroy all of the panel images.
        foreach image [array names data image,*] {
            image delete $data($image)
            unset data($image)
        }
    }

    set Y 0
    foreach drawer $data(drawers) {
        set Y [_draw_drawer $path $drawer $Y]
    }

    _resize $path

    set data(redraw) 0

    return
}


proc DrawerPanel::_configure { path width height } {
    Widget::getVariable $path data

    if {$width == $data(width)} { return }

    set data(width) $width

    if {[Widget::getoption $path -expand]} {
        ## Redraw all the drawers.
        _redraw $path 1
    }
}

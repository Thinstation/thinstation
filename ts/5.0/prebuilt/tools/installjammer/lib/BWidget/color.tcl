# Black Brown "Olive Green" "Dark Green" "Dark Teal" "Dark Blue" Indigo Gray80
# "Dark Red" Orange "Dark Yellow" Green Teal Blue "Blue Gray" Gray50
# Red "Light Orange" Lime "Sea Green" Aqua "Light Blue" Violet Gray40
# Pink Gold Yellow "Bright Green" Turquoise "Sky Blue" Plum Gray25
# Rose Tan "Light Yellow" "Light Green" "Light Turquoise" "Pale Blue" Lavender White

# "Olive Green" "Dark Teal" Indigo "Dark Yellow" Teal "Blue Gray"
# "Light Orange" Lime Aqua "Bright Green" Rose "Light Turquoise" "Pale Blue"

namespace eval SelectColor {
    Widget::define SelectColor color Dialog IconLibrary

    Widget::declare SelectColor {
        {-title          String     "Select a Color" 0}
        {-parent         String     ""        0}
        {-color          Color      "SystemButtonFace"  0}
	{-type           Enum       "dialog"  1 {dialog popup}}
	{-placement      String     "center"  1}
        {-highlightcolor Color      "SystemHighlight"   0}
        {-paletteimage   String     ""        0}
    }

    BWidget::LoadBWidgetIconLibrary

    set image [BWidget::Icon actcolorize16]
    Widget::declare SelectColor [list [list -paletteimage String $image 0]]

    variable _baseColors {
        \#0000ff \#00ff00 \#00ffff \#ff0000 \#ff00ff \#ffff00
        \#000099 \#009900 \#009999 \#990000 \#990099 \#999900
        \#000000 \#333333 \#666666 \#999999 \#cccccc \#ffffff
    }

    variable _userColors {
        \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff
        \#ffffff \#ffffff \#ffffff \#ffffff \#ffffff
    }

    variable _selectype
    variable _selection
    variable _wcolor
    variable _image
    variable _hsv
}

proc SelectColor::create { path args } {
    BWidget::LoadBWidgetIconLibrary

    Widget::init SelectColor $path $args

    set type [Widget::cget $path -type]

    switch -- [Widget::cget $path -type] {
	"dialog" {
	    return [eval [list SelectColor::dialog $path] $args]
	}

	"popup" {
	    set list      [list at center left right above below]
	    set placement [Widget::cget $path -placement]
	    set where     [lindex $placement 0]

	    if {[lsearch $list $where] < 0} {
		return -code error \
		    [BWidget::badOptionString placement $placement $list]
	    }

	    ## If they specified a parent and didn't pass a second argument
	    ## in the placement, set the placement relative to the parent.
	    set parent [Widget::cget $path -parent]
	    if {[string length $parent]} {
		if {[llength $placement] == 1} { lappend placement $parent }
	    }
	    return [eval [list SelectColor::menu $path $placement] $args]
	}
    }
}

proc SelectColor::menu {path placement args} {
    variable _baseColors
    variable _userColors
    variable _wcolor
    variable _selectype
    variable _selection

    Widget::init SelectColor $path $args

    set top    [toplevel $path]
    set parent [winfo toplevel [winfo parent $top]]
    wm withdraw  $top
    wm transient $top $parent
    wm overrideredirec $top 1
    catch { wm attributes $top -topmost 1 }

    set c [canvas $top.c -highlightthickness 0 -width 115 -height 98]
    pack $c -expand 1 -fill both
    bind $c <FocusOut> [list set SelectColor::_selection ""]

    set i [$c create rect 0 0 114 96 -width 0]
    $c bind $i <ButtonPress-1> [list set SelectColor::_selection ""]

    set x      6
    set y      6
    set col    0
    set row    0
    set size   11
    set space  18
    set colors [concat $_baseColors $_userColors]
    foreach color $colors {
        set i [$c create rect $x $y [expr {$x + $size}] [expr {$y + $size}] \
            -fill $color -width 1 -tags [list color $color] -outline #B8B8B8]
        $c bind $i <Enter> [list SelectColor::_highlight_color $path $i]
        $c bind $i <Leave> [list SelectColor::_highlight_color $path ""]
        $c bind $i <ButtonRelease-1> \
            [list SelectColor::_select_color $path $color]

        incr x $space

        if {[incr col] == 6} {
            set x   6
            set col 0
            incr row
            incr y $space
        }
    }

    set image [Widget::getoption $path -paletteimage]

    set i [$c create image $x $y -anchor nw -image $image]
    $c bind $i <Enter> [list SelectColor::_highlight_color $path $i]
    $c bind $i <Leave> [list SelectColor::_highlight_color $path ""]
    $c bind $i <ButtonRelease-1> [list set SelectColor::_selection custom]

    eval [list BWidget::place $top 0 0] $placement

    wm deiconify $top
    raise $top
    if {$::tcl_platform(platform) == "unix"} {
	tkwait visibility $top
	update
    }

    BWidget::SetFocusGrab $top $c

    tkwait variable SelectColor::_selection
    BWidget::RestoreFocusGrab $top $c destroy
    Widget::destroy $top
    if {[string equal $_selection "custom"]} {
        if {[BWidget::using ttk]} {
            array set opts {
                -parent -parent
                -title  -title
                -color  -initialcolor
            }

            set native 1
            set nativecmd [list tk_chooseColor -parent $parent]
            foreach {key val} $args {
                if {![info exists opts($key)]} {
                    set native 0
                    break
                }
                lappend nativecmd $opts($key) $val
            }

            if {$native} {
                return [eval $nativecmd]
            }
        }

        return [eval [list dialog $path] $args]
    } else {
        return $_selection
    }
}


proc SelectColor::dialog {path args} {
    variable top
    variable _hsv
    variable _image
    variable _widget
    variable _baseColors
    variable _userColors
    variable _base_selection
    variable _user_selection
    variable _user_next_index

    set widg $path:SelectColor

    Widget::init SelectColor $widg $args
    set top   [Dialog::create $path \
                   -title  [Widget::cget $path:SelectColor -title]  \
                   -parent [Widget::cget $path:SelectColor -parent] \
                   -separator 1 -default 0 -cancel 1 -anchor e]
    wm resizable $top 0 0
    set dlgf  [$top getframe]  
    set fg    [frame $dlgf.fg]
    set desc  [list \
               base _baseColors "Basic colors" \
               user _userColors "Custom colors"]

    foreach {type varcol defTitle} $desc {
        set col   0
        set lin   0
        set count 0
        set title [lindex [BWidget::getname "${type}Colors"] 0]
        if {![string length $title]} {
            set title $defTitle
        }
        set titf [LabelFrame $fg.$type -text $title -side top -anchor w]
        set subf [$titf getframe]
        foreach color [set $varcol] {
            set fround [frame $fg.round$type$count \
                            -highlightthickness 1 \
                            -relief sunken -borderwidth 2]
            set fcolor [frame $fg.color$type$count -width 18 -height 14 \
                            -highlightthickness 0 \
                            -relief flat -borderwidth 0 -background $color]
            pack $fcolor -in $fround
            grid $fround -in $subf -row $lin -column $col -padx 1 -pady 1

            set script [list SelectColor::_select_rgb $count $type]
            bind $fround <ButtonPress-1> $script
            bind $fcolor <ButtonPress-1> $script

            set script [list SelectColor::_select_rgb $count $type 1]
	    bind $fround <Double-1> $script
	    bind $fcolor <Double-1> $script

            incr count
            if {[incr col] == 6} {
                incr lin
                set  col 0
            }
        }
        pack $titf -anchor w -pady 2
    }

    frame $fg.border
    pack  $fg.border -anchor e

    label $fg.border.newL -text "New"
    pack  $fg.border.newL

    set color [Widget::getoption $widg -color]

    frame $fg.color -width 50 -height 25 -bd 1 -relief sunken
    pack $fg.color -in $fg.border

    frame $fg.old -width 50 -height 25 -bd 1 -relief sunken -background $color
    pack  $fg.old -in $fg.border

    label $fg.border.oldL -text "Current"
    pack  $fg.border.oldL

    set fd  [frame $dlgf.fd]
    set c1  [canvas $fd.c1 -width 200 -height 200 \
        -bd 2 -relief sunken -highlightthickness 0]
    set c2  [canvas $fd.c2 -width 15  -height 200 \
        -bd 2 -relief sunken -highlightthickness 0]

    for {set val 0} {$val < 40} {incr val} {
        set tags [list val[expr {39 - $val}]]
        $c2 create rectangle 0 [expr {5*$val}] 15 [expr {5*$val+5}] -tags $tags
    }
    $c2 create polygon 0 0 10 5 0 10 -fill #000000 -outline #FFFFFF -tags target

    grid $c1 -row 0 -column 0 -padx 10
    grid $c2 -row 0 -column 1 -padx 10

    pack $fg $fd -side left -anchor n -fill y

    bind $c1 <ButtonPress-1> [list SelectColor::_select_hue_sat %x %y]
    bind $c1 <B1-Motion>     [list SelectColor::_select_hue_sat %x %y]

    bind $c2 <ButtonPress-1> [list SelectColor::_select_value %x %y]
    bind $c2 <B1-Motion>     [list SelectColor::_select_value %x %y]

    if {![info exists _image] || [catch {image type $_image}]} {
        set _image [image create photo -width 200 -height 200]
        for {set x 0} {$x < 200} {incr x 4} {
            for {set y 0} {$y < 200} {incr y 4} {
                set hue [expr {$x / 196.0}]
                set sat [expr {(196 - $y) / 196.0}]
                set val "0.85"
                set hex [rgb2hex [hsvToRgb $hue $sat $val]]
                $_image put $hex -to $x $y [expr {$x+4}] [expr {$y+4}]
            }
        }
    }
    $c1 create image  0 0 -anchor nw -image $_image
    $c1 create bitmap 0 0 \
        -bitmap @[file join $::BWIDGET::LIBRARY "images" "target.xbm"] \
        -anchor nw -tags target

    if 0 {
        set f [frame $fd.info]
        grid $f -row 1 -column 0 -columnspan 2 -sticky se -padx 10 -pady 5

        label $f.hueL -text "Hue:"
        grid  $f.hueL -row 0 -column 0
        entry $f.hue  -textvariable SelectColor::data(hue) -width 5 \
            -state readonly
        grid  $f.hue  -row 0 -column 1

        label $f.satL -text "Sat:"
        grid  $f.satL -row 1 -column 0
        entry $f.sat  -textvariable SelectColor::data(sat) -width 5 \
            -state readonly
        grid  $f.sat  -row 1 -column 1

        label $f.lumL -text "Lum:"
        grid  $f.lumL -row 2 -column 0
        entry $f.lum  -textvariable SelectColor::data(lum) -width 5 \
            -state readonly
        grid  $f.lum  -row 2 -column 1

        label $f.redL -text "Red:"
        grid  $f.redL -row 0 -column 2
        entry $f.red  -textvariable SelectColor::data(red) -width 5 \
            -state readonly
        grid  $f.red  -row 0 -column 3

        label $f.greenL -text "Green:"
        grid  $f.greenL -row 1 -column 2
        entry $f.green  -textvariable SelectColor::data(green) \
            -width 5 -state readonly
        grid  $f.green  -row 1 -column 3

        label $f.blueL -text "Blue:"
        grid  $f.blueL -row 2 -column 2
        entry $f.blue  -textvariable SelectColor::data(blue) \
            -width 5 -state readonly
        grid  $f.blue  -row 2 -column 3
    }

    Button $fd.addCustom -text "Add to Custom Colors" -underline 0 \
        -command [list SelectColor::_add_custom_color $path]

    grid $fd.addCustom -row 2 -column 0 -columnspan 2 -sticky ew \
        -padx 10 -pady 5

    set _base_selection  -1
    set _user_selection  -1
    set _user_next_index -1

    set _widget(fcolor) $fg
    set _widget(chs)    $c1
    set _widget(cv)     $c2
    set color           [Widget::cget $path:SelectColor -color]
    set rgb             [winfo rgb $path $color]
    set _hsv            [eval rgbToHsv $rgb]

    _set_rgb     [rgb2hex $rgb]
    _set_hue_sat [lindex $_hsv 0] [lindex $_hsv 1]
    _set_value   [lindex $_hsv 2]

    $top add -name ok -width 12
    $top add -name cancel -width 12
    set res [$top draw]
    if {$res == 0} {
        set color [$fg.color cget -background]
    } else {
        set color ""
    }
    destroy $top
    return $color
}

proc SelectColor::setcolor { idx color } {
    variable _userColors
    set _userColors [lreplace $_userColors $idx $idx $color]
}


proc SelectColor::_select_color { path color } {
    variable _selection
    set _selection [rgb2hex [winfo rgb $path $color]]
}


proc SelectColor::_add_custom_color { path } {
    variable _widget
    variable _baseColors
    variable _userColors
    variable _user_selection
    variable _user_next_index

    set frame $_widget(fcolor)

    set bg  [$frame.color cget -bg]
    set idx $_user_selection
    if {$idx < 0} { set idx [incr _user_next_index] }

    if {![winfo exists $frame.coloruser$idx]} {
        set idx 0
        set _user_next_index 0
    }

    $frame.coloruser$idx configure -background $bg
    set _userColors [lreplace $_userColors $idx $idx $bg]
}

proc SelectColor::_select_rgb { count type {double 0} } {
    variable top
    variable _hsv
    variable _widget
    variable _selection
    variable _baseColors
    variable _userColors
    variable _base_selection
    variable _user_selection

    upvar 0 _${type}_selection _selection

    set frame $_widget(fcolor)
    if {$_selection >= 0} {
        $frame.round$type$_selection configure -background [$frame cget -bg]
    }
    $frame.round$type$count configure -background #000000

    set _selection $count
    set bg   [$frame.color$type$count cget -background]

    set _hsv [eval rgbToHsv [winfo rgb $frame.color$type$count $bg]]
    _set_hue_sat [lindex $_hsv 0] [lindex $_hsv 1]
    _set_value   [lindex $_hsv 2]
    $frame.color configure -background $bg

    if {$double} { $top invoke 0 }
}


proc SelectColor::_set_rgb {rgb} {
    variable data
    variable _widget

    set frame $_widget(fcolor)
    $frame.color configure -background $rgb

    BWidget::lassign [winfo rgb $frame $rgb] data(red) data(green) data(blue)
}


proc SelectColor::_select_hue_sat {x y} {
    variable _widget
    variable _hsv

    if {$x < 0} {
        set x 0
    } elseif {$x > 200} {
        set x 200
    }
    if {$y < 0 } {
        set y 0
    } elseif {$y > 200} {
        set y 200
    }
    set hue  [expr {$x/200.0}]
    set sat  [expr {(200-$y)/200.0}]
    set _hsv [lreplace $_hsv 0 1 $hue $sat]
    $_widget(chs) coords target [expr {$x-9}] [expr {$y-9}]
    _draw_values $hue $sat
    _set_rgb [rgb2hex [eval hsvToRgb $_hsv]]
    _set_hue_sat [lindex $_hsv 0] [lindex $_hsv 1]
}


proc SelectColor::_set_hue_sat {hue sat} {
    variable data
    variable _widget

    set data(hue) $hue
    set data(sat) $sat

    set x [expr {$hue*200-9}]
    set y [expr {(1-$sat)*200-9}]
    $_widget(chs) coords target $x $y
    _draw_values $hue $sat
}



proc SelectColor::_select_value {x y} {
    variable _widget
    variable _hsv

    if {$y < 0} {
        set y 0
    } elseif {$y > 200} {
        set y 200
    }
    $_widget(cv) coords target 0 [expr {$y-5}] 10 $y 0 [expr {$y+5}]
    set _hsv [lreplace $_hsv 2 2 [expr {(200-$y)/200.0}]]
    _set_rgb [rgb2hex [eval hsvToRgb $_hsv]]
    _set_value   [lindex $_hsv 2]
}


proc SelectColor::_draw_values {hue sat} {
    variable _widget

    for {set val 0} {$val < 40} {incr val} {
        set l   [hsvToRgb $hue $sat [expr {$val/39.0}]]
        set col [rgb2hex $l]
        $_widget(cv) itemconfigure val$val -fill $col -outline $col
    }
}


proc SelectColor::_set_value {value} {
    variable data
    variable _widget

    set data(lum) $value

    set y [expr {int((1-$value)*200)}]
    $_widget(cv) coords target 0 [expr {$y-5}] 10 $y 0 [expr {$y+5}]
}


proc SelectColor::_highlight_color { path item } {
    set c $path.c

    if {[string equal $item ""]} {
        $c delete hottrack
        return
    }

    set select [Widget::getoption $path -highlightcolor]
    BWidget::lassign [BWidget::get3dcolor $c $select] dark light

    set x 2
    if {[string equal [$c type $item] "image"]} { set x 0 }

    foreach [list x0 y0 x1 y1] [$c bbox $item] {break}
    set coords [list [expr {$x0 - 2}] [expr {$y0 - 2}] \
        [expr {$x1 + $x}] [expr {$y1 + $x}]]

    BWidget::DrawCanvasBorder $c rounded $select $coords \
        -outline $dark -fill $light -tags hottrack
    $c lower hottrack
}


proc SelectColor::rgb2hex { rgb } {
    return [eval format "\#%04x%04x%04x" $rgb]
}


# --
#  Taken from tk8.0/demos/tcolor.tcl
# --
# The procedure below converts an HSB value to RGB.  It takes hue, saturation,
# and value components (floating-point, 0-1.0) as arguments, and returns a
# list containing RGB components (integers, 0-65535) as result.  The code
# here is a copy of the code on page 616 of "Fundamentals of Interactive
# Computer Graphics" by Foley and Van Dam.

proc SelectColor::hsvToRgb {hue sat val} {
    set v [expr {round(65535.0*$val)}]
    if {$sat == 0} {
	return [list $v $v $v]
    } else {
	set hue [expr {$hue*6.0}]
	if {$hue >= 6.0} {
	    set hue 0.0
	}
	set i [expr {int($hue)}]
	set f [expr {$hue-$i}]
	set p [expr {round(65535.0*$val*(1 - $sat))}]
        set q [expr {round(65535.0*$val*(1 - ($sat*$f)))}]
        set t [expr {round(65535.0*$val*(1 - ($sat*(1 - $f))))}]
        switch $i {
	    0 {return [list $v $t $p]}
	    1 {return [list $q $v $p]}
	    2 {return [list $p $v $t]}
	    3 {return [list $p $q $v]}
	    4 {return [list $t $p $v]}
            5 {return [list $v $p $q]}
        }
    }
}


# --
#  Taken from tk8.0/demos/tcolor.tcl
# --
# The procedure below converts an RGB value to HSB.  It takes red, green,
# and blue components (0-65535) as arguments, and returns a list containing
# HSB components (floating-point, 0-1) as result.  The code here is a copy
# of the code on page 615 of "Fundamentals of Interactive Computer Graphics"
# by Foley and Van Dam.

proc SelectColor::rgbToHsv {red green blue} {
    if {$red > $green} {
	set max $red.0
	set min $green.0
    } else {
	set max $green.0
	set min $red.0
    }
    if {$blue > $max} {
	set max $blue.0
    } else {
	if {$blue < $min} {
	    set min $blue.0
	}
    }
    set range [expr {$max-$min}]
    if {$max == 0} {
	set sat 0
    } else {
	set sat [expr {($max-$min)/$max}]
    }
    if {$sat == 0} {
	set hue 0
    } else {
	set rc [expr {($max - $red)/$range}]
	set gc [expr {($max - $green)/$range}]
	set bc [expr {($max - $blue)/$range}]
	if {$red == $max} {
	    set hue [expr {.166667*($bc - $gc)}]
	} else {
	    if {$green == $max} {
		set hue [expr {.166667*(2 + $rc - $bc)}]
	    } else {
		set hue [expr {.166667*(4 + $gc - $rc)}]
	    }
	}
	if {$hue < 0.0} {
	    set hue [expr {$hue + 1.0}]
	}
    }
    return [list $hue $sat [expr {$max/65535}]]
}


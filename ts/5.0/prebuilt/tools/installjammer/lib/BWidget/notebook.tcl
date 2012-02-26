# ---------------------------------------------------------------------------
#  notebook.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: notebook.tcl,v 1.20 2003/11/26 18:42:24 hobbs Exp $
# ---------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - NoteBook::bindtabs
#     - NoteBook::cget
#     - NoteBook::compute_size
#     - NoteBook::configure
#     - NoteBook::create
#     - NoteBook::delete
#     - NoteBook::index
#     - NoteBook::insert
#     - NoteBook::itemcget
#     - NoteBook::itemconfigure
#     - NoteBook::getframe
#     - NoteBook::raise
#     - NoteBook::see
#     - NoteBook::page
#     - NoteBook::pages
#
#   Private Commands:
#     - NoteBook::_compute_width
#     - NoteBook::_draw_area
#     - NoteBook::_draw_arrows
#     - NoteBook::_draw_page
#     - NoteBook::_get_x_page
#     - NoteBook::_highlight
#     - NoteBook::_itemconfigure
#     - NoteBook::_redraw
#     - NoteBook::_resize
#     - NoteBook::_select
#     - NoteBook::_test_page
#     - NoteBook::_xview
# ---------------------------------------------------------------------------

namespace eval NoteBook {
    Widget::define NoteBook notebook ArrowButton DynamicHelp

    namespace eval Page {
        Widget::declare NoteBook::Page {
            {-anchor             Enum       "w"      0
                {center e n ne nw s se sw s w}}
            {-ipadx              Padding    "8 4"    0 "%d > -1"}
            {-ipady              Int        "2 6"    0 "%d > -1"}
            {-imagepad           Int        "2"      0 "%d > -1"}
            {-container          Boolean    "0"      1}
            {-state              Enum       "normal" 0 {normal disabled}}
            {-createcmd          String     ""       0}
            {-raisecmd           String     ""       0}
            {-leavecmd           String     ""       0}
            {-image              String     ""       0}
            {-text               String     ""       0}
            {-drawtab            Boolean    "1"      0}
            {-foreground         String     ""       0}
            {-background         String     ""       0}
            {-activeforeground   String     ""       0}
            {-activebackground   String     ""       0}
            {-disabledforeground String     ""       0}
        }
    }

    DynamicHelp::include NoteBook::Page balloon

    Widget::bwinclude NoteBook ArrowButton .c.fg \
	    include {-foreground -background -activeforeground \
		-activebackground -disabledforeground -repeatinterval \
		-repeatdelay -borderwidth} \
	    initialize {-borderwidth 1}

    Widget::bwinclude NoteBook ArrowButton .c.fd \
	    include {-foreground -background -activeforeground \
		-activebackground -disabledforeground -repeatinterval \
		-repeatdelay -borderwidth} \
	    initialize {-borderwidth 1}

    if {[BWidget::using ttk]} {
        Widget::tkinclude NoteBook ttk::frame :cmd \
            remove { -class -background -width -height }
    } else {
        Widget::tkinclude NoteBook frame :cmd \
            remove { -class -colormap -visual -background -width -height }
    }

    Widget::declare NoteBook {
        {-background		Color      "SystemButtonFace"       0}
	{-foreground		Color      "SystemButtonText"       0}
        {-activebackground	Color      "SystemButtonFace"       0}
        {-activeforeground	Color      "SystemButtonText"       0}
        {-disabledforeground	Color      "SystemDisabledText"     0}
        {-font			String     "TkTextFont"             0}
        {-side			Enum       top      0 {top bottom}}
        {-homogeneous		Boolean    0        0}
 	{-internalborderwidth	Int        10       0 "%d >= 0"}
        {-width			Int        0        0 "%d >= 0"}
        {-height		Int        0        0 "%d >= 0"}
        {-state                 Enum       "normal" 0 {normal disabled}}
        {-repeatdelay           BwResource ""       0 ArrowButton}
        {-repeatinterval        BwResource ""       0 ArrowButton}
	{-arcradius             Int        2        0 "%d >= 0 && %d <= 8"}
	{-tabbevelsize          Int        0        0 "%d >= 0 && %d <= 8"}

        {-fg                    Synonym    -foreground}
        {-bg                    Synonym    -background}
        {-bd                    Synonym    -borderwidth}
        {-ibd                   Synonym    -internalborderwidth}
    }

    Widget::addmap NoteBook "" .c { -background {} }

    variable _warrow 12

    bind NoteBook <Configure> [list NoteBook::_resize  %W]
    bind NoteBook <Destroy>   [list NoteBook::_destroy %W]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::create
# ---------------------------------------------------------------------------
proc NoteBook::create { path args } {
    Widget::initArgs NoteBook $args maps

    if {[BWidget::using ttk]} {
        eval [list ttk::frame $path -class NoteBook] $maps(:cmd)
    } else {
        eval [list frame $path -class NoteBook] $maps(:cmd)
    }

    Widget::initFromODB NoteBook $path $maps(NoteBook)

    Widget::getVariable $path data

    array set data {
        cpt      0
        base     0
        pages    {}
        wpage    0
        select   ""
        realized 0
    }

    _compute_height $path

    ## Create the canvas.
    eval [list canvas $path.c] $maps(.c) -highlightthickness 0
    pack $path.c -expand yes -fill both

    # Removing the Canvas global bindings from our canvas as
    # application specific bindings on that tag may interfere with its
    # operation here. [SF item #459033]
    bindtags $path.c [BWidget::lremove [bindtags $path.c] Canvas]

    ## Create the arrow buttons.
    eval [list ArrowButton::create $path.c.fg] $maps(.c.fg) \
	    [list -highlightthickness 0 -type button -dir left \
	    -armcommand [list NoteBook::_xview $path -1]]

    eval [list ArrowButton::create $path.c.fd] $maps(.c.fd) \
	    [list -highlightthickness 0 -type button -dir right \
	    -armcommand [list NoteBook::_xview $path 1]]

    Widget::create NoteBook $path

    set bg [$path.c cget -background]
    foreach {data(dbg) data(lbg)} [BWidget::get3dcolor $path $bg] {break}

    return $path
}


# ---------------------------------------------------------------------------
#  Command NoteBook::configure
# ---------------------------------------------------------------------------
proc NoteBook::configure { path args } {
    Widget::getVariable $path data

    set res    [Widget::configure $path $args]
    set redraw 0

    set opts [list -font -homogeneous]
    BWidget::lassign [eval [list Widget::hasChangedX $path] $opts] cf ch
    if {$cf || $ch} {
        if {$cf} {
            _compute_height $path
        }
        _compute_width $path
        set redraw 1
    }

    set chbg  [Widget::hasChanged $path -background bg]
    set chibd [Widget::hasChanged $path -internalborderwidth ibd]
    if {$chibd || $chbg} {
        foreach page $data(pages) {
            $path.f$page configure -borderwidth $ibd -background $bg
        }
    }

    if {$chbg} {
        set col [BWidget::get3dcolor $path $bg]
        set data(dbg)  [lindex $col 0]
        set data(lbg)  [lindex $col 1]
        set redraw 1
    }

    set wc [Widget::hasChanged $path -width  w]
    set hc [Widget::hasChanged $path -height h]
    if {$wc || $hc} {
        $path.c configure \
            -width  [expr {$w + 4}] \
            -height [expr {$h + $data(hpage) + 4}]
    }

    if {[Widget::hasChanged $path -state state]} {
        set redraw 1
        foreach page $data(pages) {
            _itemconfigure $path $page [list -state $state]
        }
    }

    set list [list -foreground -borderwidth -arcradius -tabbevelsize -side]
    if {[eval [list Widget::anyChangedX $path] $list]} { set redraw 1 }

    if {$redraw} {
        _redraw $path
    }

    return $res
}


# ---------------------------------------------------------------------------
#  Command NoteBook::cget
# ---------------------------------------------------------------------------
proc NoteBook::cget { path option } {
    return [Widget::cget $path $option]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::compute_size
# ---------------------------------------------------------------------------
proc NoteBook::compute_size { path } {
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
    # Sven... well ok so this is called twice in some cases...
    NoteBook::_redraw $path
    # Sven end
}


# ---------------------------------------------------------------------------
#  Command NoteBook::insert
# ---------------------------------------------------------------------------
proc NoteBook::insert { path index page args } {
    Widget::getVariable $path data

    set page [Widget::nextIndex $path $page]

    if {[exists $path $page]} {
        return -code error "page \"$page\" already exists"
    }

    set f $path.f$page
    Widget::init NoteBook::Page $f $args

    set data(pages) [linsert $data(pages) $index $page]
    # If the page doesn't exist, create it; if it does reset its bg and ibd
    if { ![winfo exists $f] } {
        frame $f \
	    -relief      flat \
            -container   [Widget::cget $f -container] \
	    -background  [$path.c cget -background] \
	    -borderwidth [Widget::cget $path -internalborderwidth]
        set data($page,realized) 0
    } else {
	$f configure \
	    -background  [$path.c cget -background] \
	    -borderwidth [Widget::cget $path -internalborderwidth]
    }
    _compute_height $path
    _compute_width  $path
    _draw_page $path $page 1
    _set_help  $path $page
    _redraw $path

    return $f
}


# ---------------------------------------------------------------------------
#  Command NoteBook::delete
# ---------------------------------------------------------------------------
proc NoteBook::delete { path page {destroyframe 1} } {
    Widget::getVariable $path data

    set pos [_test_page $path $page]
    set data(pages) [lreplace $data(pages) $pos $pos]
    _compute_width $path
    $path.c delete p:$page
    if { $data(select) == $page } {
        set data(select) ""
    }
    if { $pos < $data(base) } {
        incr data(base) -1
    }
    if { $destroyframe } {
        destroy $path.f$page
    }
    _redraw $path
}


proc NoteBook::exists { path page } {
    return [expr [index $path $page] != -1]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::itemconfigure
# ---------------------------------------------------------------------------
proc NoteBook::itemconfigure { path page args } {
    _test_page $path $page

    set res [_itemconfigure $path $page $args]

    _set_help $path $page

    _redraw $path

    return $res
}


# ---------------------------------------------------------------------------
#  Command NoteBook::itemcget
# ---------------------------------------------------------------------------
proc NoteBook::itemcget { path page option } {
    _test_page $path $page
    return [Widget::cget $path.f$page $option]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::bindtabs
# ---------------------------------------------------------------------------
proc NoteBook::bindtabs { path event script } {
    if { $script != "" } {
	append script " \[NoteBook::_get_page_name [list $path] current 2\]"
        $path.c bind "page" $event $script
    } else {
        $path.c bind "page" $event {}
    }
}


# ---------------------------------------------------------------------------
#  Command NoteBook::move
# ---------------------------------------------------------------------------
proc NoteBook::move { path page index } {
    Widget::getVariable $path data

    set pos [_test_page $path $page]
    set data(pages) [linsert [lreplace $data(pages) $pos $pos] $index $page]
    _redraw $path
}


# ---------------------------------------------------------------------------
#  Command NoteBook::raise
# ---------------------------------------------------------------------------
proc NoteBook::raise { path {page ""} } {
    Widget::getVariable $path data

    if { $page != "" } {
        _test_page $path $page
        _select $path $page
    }
    return $data(select)
}


proc NoteBook::clear { path } {
    Widget::getVariable $path data

    set data(select) ""
    _redraw $path
}


# ---------------------------------------------------------------------------
#  Command NoteBook::see
# ---------------------------------------------------------------------------
proc NoteBook::see { path page } {
    Widget::getVariable $path data

    set pos [_test_page $path $page]
    if { $pos < $data(base) } {
        set data(base) $pos
        _redraw $path
    } else {
        set w     [expr {[winfo width $path]-1}]
        set fpage [expr {[_get_x_page $path $pos] + $data($page,width) + 6}]
        set idx   $data(base)
        while { $idx < $pos && $fpage > $w } {
            set fpage [expr {$fpage - $data([lindex $data(pages) $idx],width)}]
            incr idx
        }
        if { $idx != $data(base) } {
            set data(base) $idx
            _redraw $path
        }
    }
}


# ---------------------------------------------------------------------------
#  Command NoteBook::page
# ---------------------------------------------------------------------------
proc NoteBook::page { path first {last ""} } {
    Widget::getVariable $path data

    if { $last == "" } {
        return [lindex $data(pages) $first]
    } else {
        return [lrange $data(pages) $first $last]
    }
}


# ---------------------------------------------------------------------------
#  Command NoteBook::pages
# ---------------------------------------------------------------------------
proc NoteBook::pages { path {first ""} {last ""}} {
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


# ---------------------------------------------------------------------------
#  Command NoteBook::index
# ---------------------------------------------------------------------------
proc NoteBook::index { path page } {
    Widget::getVariable $path data
    return [lsearch -exact $data(pages) $page]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::getframe
# ---------------------------------------------------------------------------
proc NoteBook::getframe { path page } {
    return $path.f$page
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_test_page
# ---------------------------------------------------------------------------
proc NoteBook::_test_page { path page } {
    Widget::getVariable $path data

    if { [set pos [lsearch -exact $data(pages) $page]] == -1 } {
        return -code error "page \"$page\" does not exists"
    }
    return $pos
}

proc NoteBook::_getoption { path page option } {
    set value [Widget::cget $path.f$page $option]
    if {![string length $value]} {
        set value [Widget::cget $path $option]
    }
    return $value
}

# ---------------------------------------------------------------------------
#  Command NoteBook::_itemconfigure
# ---------------------------------------------------------------------------
proc NoteBook::_itemconfigure { path page lres } {
    Widget::getVariable $path data

    set res [Widget::configure $path.f$page $lres]
    if {[Widget::hasChanged $path.f$page -text text]} {
        _compute_width $path
    } elseif {[Widget::hasChanged $path.f$page -image image]} {
        _compute_height $path
        _compute_width  $path
    }

    if {[Widget::hasChanged $path.f$page -anchor anchor]} {
        _draw_page $path $page 0
    }

    if {[Widget::getoption $path.f$page -drawtab]
        && [Widget::hasChanged $path.f$page -state state]
        && [string equal $state "disabled"]
        && [string equal $data(select) $page]} {
        set data(select) ""
    }

    return $res
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_compute_width
# ---------------------------------------------------------------------------
proc NoteBook::_compute_width { path } {
    Widget::getVariable $path data

    set wmax 0
    set wtot 0
    set hmax $data(hpage)
    set font [Widget::cget $path -font]
    if {![info exists data(textid)]} {
        set data(textid) [$path.c create text 0 -100 -font $font -anchor nw]
    }
    set id $data(textid)
    $path.c itemconfigure $id -font $font
    foreach page $data(pages) {
        set frame $path.f$page
        set data($page,width) 0
        if {![Widget::getoption $frame -drawtab]} { continue }
        $path.c itemconfigure $id -text [Widget::getoption $frame -text]

	# Get the bbox for this text to determine its width, then substract
	# 6 from the width to account for canvas bbox oddness w.r.t. widths of
	# simple text.
	foreach {x1 y1 x2 y2} [$path.c bbox $id] break

        set data($page,textwidth)  [expr {$x2 - $x1 - 2}]
        set data($page,itemwidth)  $data($page,textwidth)
        set data($page,itemheight) [expr {$y2 - $y1 - 2}]

	set x2 [expr {$x2 - 6}]
        set wtext [expr {$x2 - $x1 + 20}]
        if { [set img [Widget::cget $path.f$page -image]] != "" } {
            set imgw [image width  $img]
            set imgh [image height $img]
            incr data($page,itemwidth) $imgw
            incr data($page,itemwidth) [Widget::getoption $frame -imagepad]
            set wtext [expr {$wtext + $imgw + 4}]
            set himg  [expr {$imgh + 6}]
            if { $himg > $hmax } {
                set hmax $himg
            }

            if {$imgh > $data($page,itemheight)} {
                set data($page,itemheight) $imgh
            }
        }
        set  wmax  [expr {$wtext > $wmax ? $wtext : $wmax}]
        incr wtot  $wtext
        set  data($page,width) $wtext
    }

    if {[Widget::cget $path -homogeneous]} {
        foreach page $data(pages) {
            if {![Widget::cget $path.f$page -drawtab]} { continue }
            set data($page,width) $wmax
        }
        set wtot [expr {$wmax * [llength $data(pages)]}]
    }

    set data(hpage) $hmax
    set data(wpage) $wtot
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_compute_height
# ---------------------------------------------------------------------------
proc NoteBook::_compute_height { path } {
    Widget::getVariable $path data

    set font    [Widget::cget $path -font]
    set metrics [font metrics $font -linespace]
    set imgh    0
    set padh    0
    set lines   1
    foreach page $data(pages) {
        set frame $path.f$page
        set img   [Widget::cget $frame -image]
        set text  [Widget::cget $frame -text]
        set len   [llength [split $text \n]]
        set pady0 [Widget::_get_padding $frame -ipady 0]
        set pady1 [Widget::_get_padding $frame -ipady 1]
        set padding [expr {$pady0 + $pady1}]
        if {$len > $lines} { set lines $len}
        if {[string length $img]} {
            set h [image height $img]
            if {$h > $imgh} { set imgh $h }
        }

        if {$padding > $padh} { set padh $padding }
    }
    set height [expr {$metrics * $lines}]
    if {$imgh > $height} { set height $imgh }
    set data(hpage) [expr {$height + $padh}]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_get_x_page
# ---------------------------------------------------------------------------
proc NoteBook::_get_x_page { path pos } {
    Widget::getVariable $path data

    set base $data(base)
    # notebook tabs start flush with the left side of the notebook
    set x 0
    if { $pos < $base } {
        foreach page [lrange $data(pages) $pos [expr {$base-1}]] {
            if {![Widget::cget $path.f$page -drawtab]} { continue }
            incr x [expr {-$data($page,width)}]
        }
    } elseif { $pos > $base } {
        foreach page [lrange $data(pages) $base [expr {$pos-1}]] {
            if {![Widget::cget $path.f$page -drawtab]} { continue }
            incr x $data($page,width)
        }
    }
    return $x
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_xview
# ---------------------------------------------------------------------------
proc NoteBook::_xview { path inc } {
    Widget::getVariable $path data

    if { $inc == -1 } {
        set base [expr {$data(base)-1}]
        set dx $data([lindex $data(pages) $base],width)
    } else {
        set dx [expr {-$data([lindex $data(pages) $data(base)],width)}]
        set base [expr {$data(base)+1}]
    }

    if { $base >= 0 && $base < [llength $data(pages)] } {
        set data(base) $base
        $path.c move page $dx 0
        _draw_area   $path
        _draw_arrows $path
    }
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_highlight
# ---------------------------------------------------------------------------
proc NoteBook::_highlight { type path page } {
    Widget::getVariable $path data

    if { [string equal [Widget::cget $path.f$page -state] "disabled"] } {
        return
    }

    switch -- $type {
        on {
            $path.c itemconfigure "$page:poly" \
		    -fill [_getoption $path $page -activebackground]
            $path.c itemconfigure "$page:text" \
		    -fill [_getoption $path $page -activeforeground]
        }
        off {
            $path.c itemconfigure "$page:poly" \
		    -fill [_getoption $path $page -background]
            $path.c itemconfigure "$page:text" \
		    -fill [_getoption $path $page -foreground]
        }
    }
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_select
# ---------------------------------------------------------------------------
proc NoteBook::_select { path page } {
    Widget::getVariable $path data

    set draw  [Widget::cget $path.f$page -drawtab]
    set state [Widget::cget $path.f$page -state]

    ## If we want to draw the tab for this page and the state is
    ## not normal, we can't select it.  Pages with no tab can
    ## still be raised by the code even in a disabled state
    ## because they are often used to display a page of data
    ## while the rest of the notebook is disabled.
    if {$draw && ![string equal $state "normal"] } { return }

    set oldsel $data(select)

    if {[string equal $page $oldsel]} { return }

    if { ![string equal $oldsel ""] } {
	set cmd [Widget::cget $path.f$oldsel -leavecmd]
	if { ![string equal $cmd ""] } {
	    set code [catch {uplevel \#0 $cmd} res]
	    if { $code == 1 || $res == 0 } {
		return -code $code $res
	    }
	}
	set data(select) ""
	_draw_page $path $oldsel 0
    }

    set data(select) $page
    if { ![string equal $page ""] } {
	if { !$data($page,realized) } {
	    set data($page,realized) 1
	    set cmd [Widget::cget $path.f$page -createcmd]
	    if { ![string equal $cmd ""] } {
		uplevel \#0 $cmd
	    }
	}
	set cmd [Widget::cget $path.f$page -raisecmd]
	if { ![string equal $cmd ""] } {
	    uplevel \#0 $cmd
	}
	_draw_page $path $page 0
    }

    _draw_area $path
}


# -----------------------------------------------------------------------------
#  Command NoteBook::_redraw
# -----------------------------------------------------------------------------
proc NoteBook::_redraw { path } {
    Widget::getVariable $path data

    if { !$data(realized) } { return }

    _compute_height $path

    foreach page $data(pages) {
        _draw_page $path $page 0
    }
    _draw_area   $path
    _draw_arrows $path
}


# ----------------------------------------------------------------------------
#  Command NoteBook::_draw_page
# ----------------------------------------------------------------------------
proc NoteBook::_draw_page { path page create } {
    Widget::getVariable $path data

    set frame $path.f$page

    if {![Widget::cget $frame -drawtab]} { return }

    # --- calcul des coordonnees et des couleurs de l'onglet ------------------
    set pos [lsearch -exact $data(pages) $page]
    set bg  [_getoption $path $page -background]

    # lookup the tab colors
    set fgt   $data(lbg)
    set fgb   $data(dbg)

    set h   $data(hpage)
    set xd  [_get_x_page $path $pos]
    set xf  [expr {$xd + $data($page,width)}]

    foreach {textx texty textanchor imagex imagey imageanchor} \
        [_get_tab_positions $path $page] {break}

    # Coordinates of the tab corners are:
    #     c3        c4
    #
    # c2                c5
    #
    # c1                c6
    #
    # where
    # c1 = $xd,	  $h
    # c2 = $xd+$xBevel,	           $arcRadius+2
    # c3 = $xd+$xBevel+$arcRadius, $arcRadius
    # c4 = $xf+1-$xBevel,          $arcRadius
    # c5 = $xf+$arcRadius-$xBevel, $arcRadius+2
    # c6 = $xf+$arcRadius,         $h

    set top       2
    set xBevel    [Widget::getoption $path -tabbevelsize]
    set arcRadius [Widget::getoption $path -arcradius]

    # Precompute some coord values that we use a lot
    set topPlusRadius	[expr {$top + $arcRadius}]
    set rightPlusRadius	[expr {$xf + $arcRadius}]
    set leftPlusRadius	[expr {$xd + $arcRadius}]

    # Sven
    set tabsOnBottom [string equal [Widget::getoption $path -side] "bottom"]

    set h1 [expr {[winfo height $path]}]
    set bd [Widget::cget $path -borderwidth]
    if {$bd < 1} { set bd 1 }

    if { $tabsOnBottom } {
	set top [expr {$top * -1}]
	set topPlusRadius [expr {$topPlusRadius * -1}]
	# Hrm... the canvas has an issue with drawing diagonal segments
	# of lines from the bottom to the top, so we have to draw this line
	# backwards (ie, lt is actually the bottom, drawn from right to left)
        set lt  [list \
		$rightPlusRadius			[expr {$h1-$h-1}] \
		[expr {$rightPlusRadius - $xBevel}]	[expr {$h1 + $topPlusRadius}] \
		[expr {$xf - $xBevel}]			[expr {$h1 + $top}] \
		[expr {$leftPlusRadius + $xBevel}]	[expr {$h1 + $top}] \
		]
        set lb  [list \
		[expr {$leftPlusRadius + $xBevel}]	[expr {$h1 + $top}] \
		[expr {$xd + $xBevel}]			[expr {$h1 + $topPlusRadius}] \
		$xd					[expr {$h1-$h-1}] \
		]
	# Because we have to do this funky reverse order thing, we have to
	# swap the top/bottom colors too.
	set tmp $fgt
	set fgt $fgb
	set fgb $tmp
    } else {
	set lt [list \
		$xd					$h \
		[expr {$xd + $xBevel}]			$topPlusRadius \
		[expr {$leftPlusRadius + $xBevel}]	$top \
		[expr {$xf + 1 - $xBevel}]		$top \
		]
	set lb [list \
		[expr {$xf + 1 - $xBevel}] 		[expr {$top + 1}] \
		[expr {$rightPlusRadius - $xBevel}]	$topPlusRadius \
		$rightPlusRadius			$h \
		]
    }

    set img [Widget::cget $path.f$page -image]

    if {[string equal $data(select) $page]} {
        set bd    [Widget::cget $path -borderwidth]
	if {$bd < 1} { set bd 1 }
        set fg    [_getoption $path $page -foreground]
    } else {
        set bd    1
        if { [Widget::cget $path.f$page -state] == "normal" } {
            set fg [_getoption $path $page -foreground]
        } else {
            set fg [_getoption $path $page -disabledforeground]
        }
    }

    # --- creation ou modification de l'onglet --------------------------------
    # Sven
    if { $create } {
	# Create the tab region
        eval [list $path.c create polygon] [concat $lt $lb] [list \
		-tags		[list page p:$page $page:poly] \
		-outline	$bg \
		-fill		$bg \
		]
        eval [list $path.c create line] $lt [list \
            -tags [list page p:$page $page:top top] -fill $fgt -width $bd]
        eval [list $path.c create line] $lb [list \
            -tags [list page p:$page $page:bot bot] -fill $fgb -width $bd]
        $path.c create text $textx $texty 			\
		-text	[Widget::cget $path.f$page -text]	\
		-font	[Widget::cget $path -font]		\
		-fill	$fg					\
		-anchor	$textanchor					\
		-tags	[list page p:$page $page:text]

        $path.c bind p:$page <ButtonPress-1> \
		[list NoteBook::_select $path $page]
        $path.c bind p:$page <Enter> \
		[list NoteBook::_highlight on  $path $page]
        $path.c bind p:$page <Leave> \
		[list NoteBook::_highlight off $path $page]
    } else {
        $path.c coords "$page:text" $textx $texty

        $path.c itemconfigure "$page:text" \
            -text [Widget::cget $path.f$page -text] \
            -font [Widget::cget $path -font] \
            -fill $fg -anchor $textanchor
    }
    eval [list $path.c coords "$page:poly"] [concat $lt $lb]
    eval [list $path.c coords "$page:top"]  $lt
    eval [list $path.c coords "$page:bot"]  $lb
    $path.c itemconfigure "$page:poly" -fill $bg  -outline $bg
    $path.c itemconfigure "$page:top"  -fill $fgt -width $bd
    $path.c itemconfigure "$page:bot"  -fill $fgb -width $bd
    
    # Sven end

    if {[string length $img]} {
        # Sven
	set id [$path.c find withtag $page:img]
        if {![string length $id]} {
	    set id [$path.c create image $imagex $imagey \
		    -anchor $imageanchor    \
		    -tags   [list page p:$page $page:img]]
        }
        $path.c coords $id $imagex $imagey
        $path.c itemconfigure $id -image $img -anchor $imageanchor
        # Sven end
    } else {
        $path.c delete $page:img
    }

    if {[string equal $data(select) $page]} {
        $path.c raise p:$page
    } elseif { $pos == 0 } {
        if { $data(select) == "" } {
            $path.c raise p:$page
        } else {
            $path.c lower p:$page p:$data(select)
        }
    } else {
        set pred [lindex $data(pages) [expr {$pos-1}]]
        if { $data(select) != $pred || $pos == 1 } {
            $path.c lower p:$page p:$pred
        } else {
            $path.c lower p:$page p:[lindex $data(pages) [expr {$pos-2}]]
        }
    }
}


# -----------------------------------------------------------------------------
#  Command NoteBook::_draw_arrows
# -----------------------------------------------------------------------------
proc NoteBook::_draw_arrows { path } {
    variable _warrow
    Widget::getVariable $path data

    set w       [expr {[winfo width $path]-1}]
    set h       [expr {$data(hpage)-1}]
    set nbpages [llength $data(pages)]
    set xl      0
    set xr      [expr {$w-$_warrow+1}]
    # Sven
    set side [Widget::cget $path -side]
    if { [string equal $side "bottom"] } {
        set h1 [expr {[winfo height $path]-1}]
        set bd [Widget::cget $path -borderwidth]
	if {$bd < 1} { set bd 1 }
        set y0 [expr {$h1 - $data(hpage) + $bd}]
    } else {
        set y0 1
    }
    # Sven end (all y positions where replaced with $y0 later)

    if { $data(base) > 0 } {
        # Sven 
        if { ![llength [$path.c find withtag "leftarrow"]] } {
            $path.c create window $xl $y0 \
                -width  $_warrow            \
                -height $h                  \
                -anchor nw                  \
                -window $path.c.fg            \
                -tags   "leftarrow"
        } else {
            $path.c coords "leftarrow" $xl $y0
            $path.c itemconfigure "leftarrow" -width $_warrow -height $h
        }
        # Sven end
    } else {
        $path.c delete "leftarrow"
    }

    if { $data(base) < $nbpages-1 &&
         $data(wpage) + [_get_x_page $path 0] + 6 > $w } {
        # Sven
        if { ![llength [$path.c find withtag "rightarrow"]] } {
            $path.c create window $xr $y0 \
                -width  $_warrow            \
                -height $h                  \
                -window $path.c.fd            \
                -anchor nw                  \
                -tags   "rightarrow"
        } else {
            $path.c coords "rightarrow" $xr $y0
            $path.c itemconfigure "rightarrow" -width $_warrow -height $h
        }
        # Sven end
    } else {
        $path.c delete "rightarrow"
    }
}


# -----------------------------------------------------------------------------
#  Command NoteBook::_draw_area
# -----------------------------------------------------------------------------
proc NoteBook::_draw_area { path } {
    Widget::getVariable $path data

    set w   [expr {[winfo width  $path] - 1}]
    set h   [expr {[winfo height $path] - 1}]
    set bd  [Widget::cget $path -borderwidth]
    if {$bd < 1} { set bd 1 }
    set x0  [expr {$bd - 1}]

    set arcRadius [Widget::cget $path -arcradius]

    set side [Widget::cget $path -side]

    if {[string equal $side "bottom"]} {
        set y0 0
        set y1 [expr {$h - $data(hpage)}]
        set yo $y1
    } else {
        set y0 $data(hpage)
        set y1 $h
        set yo [expr {$h-$y0}]
    }

    set dbg $data(dbg)
    set sel $data(select)

    if {$sel == ""} {
        set xd  [expr {$w/2}]
        set xf  $xd
        set lbg $data(dbg)
    } else {
        set xd [_get_x_page $path [lsearch -exact $data(pages) $sel]]
        set xf [expr {$xd + $data($sel,width) + $arcRadius + 1}]
        set lbg $data(lbg)
    }

    if { [llength [$path.c find withtag rect]] == 0} {
        $path.c create line $xd $y0 $x0 $y0 $x0 $y1 \
            -tags "rect toprect1" 
        $path.c create line $w $y0 $xf $y0 \
            -tags "rect toprect2"
        $path.c create line 1 $h $w $h $w $y0 \
            -tags "rect botrect"
    }

    if {[string equal $side "bottom"]} {
        $path.c coords "toprect1" $w $y0 $x0 $y0 $x0 $y1
        $path.c coords "toprect2" $x0 $y1 $xd $y1
        $path.c coords "botrect"  $xf $y1 $w $y1 $w $y0
        $path.c itemconfigure "toprect1" -fill $lbg -width $bd
        $path.c itemconfigure "toprect2" -fill $dbg -width $bd
        $path.c itemconfigure "botrect" -fill $dbg -width $bd
    } else {
        $path.c coords "toprect1" $xd $y0 $x0 $y0 $x0 $y1
        $path.c coords "toprect2" $w $y0 $xf $y0
        $path.c coords "botrect"  $x0 $h $w $h $w $y0
        $path.c itemconfigure "toprect1" -fill $lbg -width $bd
        $path.c itemconfigure "toprect2" -fill $lbg -width $bd
        $path.c itemconfigure "botrect" -fill $dbg -width $bd
    }

    $path.c raise "rect"

    if { $sel != "" } {
        if { [llength [$path.c find withtag "window"]] == 0 } {
            $path.c create window 2 [expr {$y0+1}] \
                -width  [expr {$w-3}]           \
                -height [expr {$yo-3}]          \
                -anchor nw                      \
                -tags   "window"                \
                -window $path.f$sel
        }
        $path.c coords "window" 2 [expr {$y0+1}]
        $path.c itemconfigure "window"    \
            -width  [expr {$w-3}]           \
            -height [expr {$yo-3}]          \
            -window $path.f$sel
    } else {
        $path.c delete "window"
    }
}


# -----------------------------------------------------------------------------
#  Command NoteBook::_resize
# -----------------------------------------------------------------------------
proc NoteBook::_resize { path } {
    Widget::getVariable $path data

    if {!$data(realized)} {
	if { [set width  [Widget::cget $path -width]]  == 0 ||
	     [set height [Widget::cget $path -height]] == 0 } {
	    compute_size $path
	}
	set data(realized) 1
    }

    NoteBook::_redraw $path
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
proc NoteBook::_set_help { path page } {
    Widget::getVariable $path help

    set item $path.f$page
    set change [Widget::anyChangedX $item -helptype -helptext -helpvar]
    set text   [Widget::getoption $item -helptext]

    ## If we've never set help for this item before, and text is not blank,
    ## we need to setup help.  We also need to reset help if any of the
    ## options have changed.
    if { (![info exists help($page)] && $text != "") || $change } {
	set help($page) 1
	set type [Widget::getoption $item -helptype]
        switch $type {
            balloon {
		DynamicHelp::register $path.c balloon p:$page $text
            }
            variable {
		set var [Widget::getoption $item -helpvar]
		DynamicHelp::register $path.c variable p:$page $var $text
            }
        }
    }
}


proc NoteBook::_get_page_name { path {item current} {tagindex end-1} } {
    return [string range [lindex [$path.c gettags $item] $tagindex] 2 end]
}


proc NoteBook::_get_tab_positions { path page } {
    Widget::getVariable $path data

    set frame $path.f$page

    set image     [Widget::getoption $frame -image]
    set anchor    [Widget::getoption $frame -anchor]
    set haveimage [string length $image]

    set top     2
    set pady    [Widget::_get_padding $frame -ipady 0]
    set padx    [Widget::_get_padding $frame -ipadx 0]
    set imgpad  [Widget::_get_padding $frame -imagepad 0]
    set pos     [lsearch -exact $data(pages) $page]
    set offset  [_get_x_page $path $pos]
    set width   $data($page,width)
    set height  $data(hpage)
    set cheight [winfo height $path]

    set textx  [expr {($width / 2) + $offset}]
    set texty  [expr {($height / 2) + $pady}]
    set texta  $anchor
    set imagex $textx
    set imagey $texty
    set imagea $texta

    if {$haveimage} { set iwidth [image width $image] }

    if {[string match "n*" $anchor]} {
        set texty  [expr {$top + $pady + ($data($page,itemheight) / 2)}]
        set imagey $texty
    } elseif {[string match "s*" $anchor]} {
        set texty  [expr {$height - ($data($page,itemheight) / 2) - $pady}]
        incr texty $top
        set imagey $texty
    }

    if {[string match "*e" $anchor]} {
        set texta  e
        set imagea e

        set pad   [Widget::_get_padding $frame -ipadx 1]
        set textx [expr {$width - $pad}]
        if {$haveimage} {
            set imagex [expr {$textx - $data($page,textwidth) - $imgpad}]
        }
    } elseif {[string match "*w" $anchor]} {
        set texta  w
        set imagea w

        set textx [expr {$offset + $padx}]
        if {$haveimage} {
            set imagex $textx
            incr textx [expr {$iwidth + $imgpad}]
        }
    } elseif {$haveimage} {
        set x [expr {($width - $data($page,textwidth) - $iwidth) / 2}]
        set textx  [expr {$x + $iwidth + $imgpad}]
        set imagex $x
        set texta  w
        set imagea w
    }

    if {[string equal [Widget::getoption $path -side] "bottom"]} {
	incr texty  [expr {$cheight - $height}]
        incr imagey [expr {$cheight - $height}]
    }

    if {[string equal $data(select) $page]} {
	# The selected page's text is raised higher than the others
        incr texty  -2
        incr imagey -2
    }

    return [list $textx $texty $texta $imagex $imagey $imagea]
}


# ---------------------------------------------------------------------------
#  Command NoteBook::_destroy
# ---------------------------------------------------------------------------
proc NoteBook::_destroy { path } {
    Widget::getVariable $path data

    foreach page $data(pages) {
        Widget::destroy $path.f$page 0
    }

    Widget::destroy $path
}

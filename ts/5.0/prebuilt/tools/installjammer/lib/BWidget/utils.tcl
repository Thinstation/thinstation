# ----------------------------------------------------------------------------
#  utils.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: utils.tcl,v 1.11 2004/01/06 07:22:39 damonc Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#     - BWidget::globalexists
#     - BWidget::setglobal
#     - BWidget::getglobal
#     - BWidget::traceglobal
#     - BWidget::assert
#     - BWidget::clonename
#     - BWidget::get3dcolor
#     - BWidget::XLFDfont
#     - BWidget::place
#     - BWidget::grab
#     - BWidget::focus
# ----------------------------------------------------------------------------

namespace eval BWidget {
    variable _gstack [list]
    variable _fstack [list]
}


proc BWidget::use { args } {
    variable includes

    if {![llength $args]} {
        ## Setup some default packages.
        BWidget::use aqua [expr {$::tcl_version >= 8.4
                            && [string equal [tk windowingsystem] "aqua"]}]
        return
    }

    set package [lindex $args 0]
    set value   [lindex $args 1]
    set force   [string equal [lindex $args 2] "-force"]
    if {![string length $value]} { set value 1 }

    if {$value && ($force || ![info exists includes($package)])} {
        ## Each package supported to enhance BWidgets is setup here.
        switch -- $package {
            "aqua" {

            }

            "png" {
                if {[catch { package require img::png } err]} {
                    if {[catch { package require tkpng } err]} {
                        return -code error "Could not find img::png or tkpng\
                            package to support PNG data"
                    } else {
                        set ::BWidget::imageFormat png
                    }
                } else {
                    set ::BWidget::imageFormat PNG
                }

                if {![info exists ::BWidget::iconLibraryFile]} {
                    set ::BWidget::iconLibraryFile \
                        [file join $::BWidget::imageDir BWidget.png.tkico]
                }
            }

            "ttk" {
                Widget::theme 1

                variable ::BWidget::colors

                foreach {opt val} [style configure .] {
                    switch -- $opt {
                        "-background" {
                            set colors(SystemButtonFace) $val
                        }

                        "-foreground" {
                            set colors(SystemWindowText) $val
                        }

                        "-selectbackground" {
                            set colors(SystemHighlight) $val
                        }

                        "-selectforeground" {
                            set colors(SystemHighlightText) $val
                        }

                        "-troughcolor" {
                            set colors(SystemScrollbar) $val
                        }
                    }
                }
            }
        }
    }

    set includes($package) $value
    return $value
}


proc BWidget::using { package } {
    if {[info exists ::BWidget::includes($package)]} {
        return $::BWidget::includes($package)
    }
    return 0
}


# ----------------------------------------------------------------------------
#  Command BWidget::globalexists
# ----------------------------------------------------------------------------
proc BWidget::globalexists { varName } {
    return [uplevel \#0 [list info exists $varName]]
}


# ----------------------------------------------------------------------------
#  Command BWidget::setglobal
# ----------------------------------------------------------------------------
proc BWidget::setglobal { varName value } {
    return [uplevel \#0 [list set $varName $value]]
}


# ----------------------------------------------------------------------------
#  Command BWidget::getglobal
# ----------------------------------------------------------------------------
proc BWidget::getglobal { varName } {
    return [uplevel \#0 [list set $varName]]
}


# ----------------------------------------------------------------------------
#  Command BWidget::traceglobal
# ----------------------------------------------------------------------------
proc BWidget::traceglobal { cmd varName args } {
    return [uplevel \#0 [list trace $cmd $varName] $args]
}



# ----------------------------------------------------------------------------
#  Command BWidget::lreorder
# ----------------------------------------------------------------------------
proc BWidget::lreorder { list neworder } {
    set pos     0
    set newlist {}
    foreach e $neworder {
        if { [lsearch -exact $list $e] != -1 } {
            lappend newlist $e
            set tabelt($e)  1
        }
    }
    set len [llength $newlist]
    if { !$len } {
        return $list
    }
    if { $len == [llength $list] } {
        return $newlist
    }
    set pos 0
    foreach e $list {
        if { ![info exists tabelt($e)] } {
            set newlist [linsert $newlist $pos $e]
        }
        incr pos
    }
    return $newlist
}


proc BWidget::lremove { list args } {
    foreach elem $args {
        set x [lsearch -exact $list $elem]     
        if {$x > -1} { set list [lreplace $list $x $x] }
    }
    return $list
}


proc BWidget::lassign { list args } {
    foreach elem $list varName $args {
        if {[string equal $varName ""]} { break }
        uplevel 1 [list set $varName $elem]
    }
}


# ----------------------------------------------------------------------------
#  Command BWidget::assert
# ----------------------------------------------------------------------------
proc BWidget::assert { exp {msg ""}} {
    set res [uplevel 1 expr $exp]
    if { !$res} {
        if { $msg == "" } {
            return -code error "Assertion failed: {$exp}"
        } else {
            return -code error $msg
        }
    }
}


# ----------------------------------------------------------------------------
#  Command BWidget::clonename
# ----------------------------------------------------------------------------
proc BWidget::clonename { menu } {
    set path     ""
    set menupath ""
    set found    0
    foreach widget [lrange [split $menu "."] 1 end] {
        if { $found || [winfo class "$path.$widget"] == "Menu" } {
            set found 1
            append menupath "#" $widget
            append path "." $menupath
        } else {
            append menupath "#" $widget
            append path "." $widget
        }
    }
    return $path
}


# ----------------------------------------------------------------------------
#  Command BWidget::getname
# ----------------------------------------------------------------------------
proc BWidget::getname { name } {
    if { [string length $name] } {
        set text [option get . "${name}Name" ""]
        if { [string length $text] } {
            return [parsetext $text]
        }
    }
    return {}
 }


# ----------------------------------------------------------------------------
#  Command BWidget::parsetext
# ----------------------------------------------------------------------------
proc BWidget::parsetext { text } {
    set result ""
    set index  -1
    set start  0
    while { [string length $text] } {
        set idx [string first "&" $text]
        if { $idx == -1 } {
            append result $text
            set text ""
        } else {
            set char [string index $text [expr {$idx+1}]]
            if { $char == "&" } {
                append result [string range $text 0 $idx]
                set    text   [string range $text [expr {$idx+2}] end]
                set    start  [expr {$start+$idx+1}]
            } else {
                append result [string range $text 0 [expr {$idx-1}]]
                set    text   [string range $text [expr {$idx+1}] end]
                incr   start  $idx
                set    index  $start
            }
        }
    }
    return [list $result $index]
}


# ----------------------------------------------------------------------------
#  Command BWidget::get3dcolor
# ----------------------------------------------------------------------------
proc BWidget::get3dcolor { path bgcolor {multiplier 0} {divideBy 100} } {
    set fmt "#%04x%04x%04x"

    if {$multiplier} {
        foreach val [winfo rgb $path $bgcolor] {
            lappend list [expr {$multiplier * $val / $divideBy}]
        }
        return [eval format $fmt $list]
    }

    if {[string equal $bgcolor "SystemButtonFace"]} {
        lappend list System3dDarkShadow SystemButtonHighlight
        lappend list SystemButtonShadow System3dLight
        return $list
    }

    foreach val [winfo rgb $path $bgcolor] {
        lappend dark  [expr {48 * $val / 100}]
        lappend dark2 [expr {72 * $val / 100}]

        set tmp1 [expr {14*$val/10}]
        if { $tmp1 > 65535 } { set tmp1 65535 }

        set tmp2 [expr {(65535+$val)/2}]
        lappend light  [expr {($tmp1 > $tmp2) ? $tmp1:$tmp2}]

        set tmp [expr {92 * $val / 90}]
        lappend light2 [expr {($tmp > 65535) ? 65535 : $tmp}]
    }

    lappend list [eval format $fmt $dark]
    lappend list [eval format $fmt $light]
    lappend list [eval format $fmt $dark2]
    lappend list [eval format $fmt $light2]

    return $list
}


proc BWidget::color2hex { path color } {
    if {[catch { winfo rgb $path $color } rgb]} {
	return -code error "Invalid color '$color'"
    }
    foreach {r g b} $rgb { break }
    return [format {#%4.4x%4.4x%4.4x} $r $g $b]
}


proc BWidget::getGradientColors { col1Str col2Str size {offset 0} } {
    if {[catch { winfo rgb . $col1Str } color1]} {
	return -code error "Invalid color '$col1Str'"
    }

    if {[catch { winfo rgb . $col2Str } color2]} {
	return -code error "Invalid color '$col2Str'"
    }

    set max [expr {$size - $offset}]

    foreach {r1 g1 b1} $color1 { break }
    foreach {r2 g2 b2} $color2 { break }
    set rRange [expr {double($r2) - $r1}]
    set gRange [expr {double($g2) - $g1}]
    set bRange [expr {double($b2) - $b1}]
    set rRatio [expr {$rRange / $max}]
    set gRatio [expr {$gRange / $max}]
    set bRatio [expr {$bRange / $max}]

    set colors [list]

    for {set i 0} {$i < $offset} {incr i} {
        lappend colors [format {#%4.4x%4.4x%4.4x} $r1 $g1 $b1]
    }

    for {set i 0} {$i < $max} {incr i} {
	set nR [expr {int( $r1 + ($rRatio * $i) )}]
	set nG [expr {int( $g1 + ($gRatio * $i) )}]
	set nB [expr {int( $b1 + ($bRatio * $i) )}]
        lappend colors [format {#%4.4x%4.4x%4.4x} $nR $nG $nB]
    }

    return $colors
}


# ----------------------------------------------------------------------------
#  Command BWidget::XLFDfont
# ----------------------------------------------------------------------------
proc BWidget::XLFDfont { cmd args } {
    switch -- $cmd {
        create {
            set font "-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
        }
        configure {
            set font [lindex $args 0]
            set args [lrange $args 1 end]
        }
        default {
            return -code error "XLFDfont: command incorrect: $cmd"
        }
    }
    set lfont [split $font "-"]
    if { [llength $lfont] != 15 } {
        return -code error "XLFDfont: description XLFD incorrect: $font"
    }

    foreach {option value} $args {
        switch -- $option {
            -foundry { set index 1 }
            -family  { set index 2 }
            -weight  { set index 3 }
            -slant   { set index 4 }
            -size    { set index 7 }
            default  { return -code error "XLFDfont: option incorrect: $option" }
        }
        set lfont [lreplace $lfont $index $index $value]
    }
    return [join $lfont "-"]
}



# ----------------------------------------------------------------------------
#  Command BWidget::place
# ----------------------------------------------------------------------------
#
# Notes:
#  For Windows systems with more than one monitor the available screen area may
#  have negative positions. Geometry settings with negative numbers are used
#  under X to place wrt the right or bottom of the screen. On windows, Tk
#  continues to do this. However, a geometry such as 100x100+-200-100 can be
#  used to place a window onto a secondary monitor. Passing the + gets Tk
#  to pass the remainder unchanged so the Windows manager then handles -200
#  which is a position on the left hand monitor.
#  I've tested this for left, right, above and below the primary monitor.
#  Currently there is no way to ask Tk the extent of the Windows desktop in 
#  a multi monitor system. Nor what the legal co-ordinate range might be.
#
proc BWidget::place { path w h args } {
    update idletasks
    if {$w == 0} { set w [winfo reqwidth  $path] }
    if {$h == 0} { set h [winfo reqheight $path] }

    set arglen [llength $args]
    if { $arglen > 3 } {
        return -code error "BWidget::place: bad number of argument"
    }

    if { $arglen > 0 } {
        set where [lindex $args 0]
	set list  [list "at" "center" "left" "right" "above" "below"]
        set idx   [lsearch -exact $list $where]
        if { $idx == -1 } {
	    return -code error [BWidget::badOptionString position $where $list]
        }
        if { $idx == 0 } { ## at
            set err [catch {
                # purposely removed the {} around these expressions - [PT]
                set x [expr int([lindex $args 1])]
                set y [expr int([lindex $args 2])]
            }]
            if { $err } {
                return -code error "BWidget::place: incorrect position"
            }
            if {[string equal $::tcl_platform(platform) "windows"]} {
                # handle windows multi-screen. -100 != +-100
                if {[string index [lindex $args 1] 0] != "-"} {
                    set x "+$x"
                }
                if {[string index [lindex $args 2] 0] != "-"} {
                    set y "+$y"
                }
            } else {
                if { $x >= 0 } {
                    set x "+$x"
                }
                if { $y >= 0 } {
                    set y "+$y"
                }
            }
        } else {
            if { $arglen == 2 } {
                set widget [lindex $args 1]
                if { ![winfo exists $widget] } {
                    set msg "BWidget::place: \"$widget\" does not exist"
                    return -code error $msg
                }
	    } else {
		set widget .
	    }

            set sw    [winfo screenwidth  $path]
            set sh    [winfo screenheight $path]
            set rootx [winfo rootx $widget]
            set rooty [winfo rooty $widget]

            if { $idx == 1 } { ## center
                if { $arglen == 2 } {
                    # center to widget
                    set x0 [expr {$rootx + ([winfo width  $widget] - $w)/2}]
                    set y0 [expr {$rooty + ([winfo height $widget] - $h)/2}]
                } else {
                    # center to screen
                    set x0 [expr {($sw - $w)/2 - [winfo vrootx $path]}]
                    set y0 [expr {($sh - $h)/2 - [winfo vrooty $path]}]
                }
                set x "+$x0"
                set y "+$y0"
                if {$::tcl_platform(platform) != "windows"} {
                    if { $x0+$w > $sw } {set x "-0"; set x0 [expr {$sw-$w}]}
                    if { $x0 < 0 }      {set x "+0"}
                    if { $y0+$h > $sh } {set y "-0"; set y0 [expr {$sh-$h}]}
                    if { $y0 < 0 }      {set y "+0"}
                }
            } else {
                set x0 $rootx
                set y0 $rooty
                set x1 [expr {$x0 + [winfo width  $widget]}]
                set y1 [expr {$y0 + [winfo height $widget]}]
                if { $idx == 2 || $idx == 3 } { ## left or right
                    set y "+$y0"
                    if {$::tcl_platform(platform) != "windows"} {
                        if { $y0+$h > $sh } {set y "-0"; set y0 [expr {$sh-$h}]}
                        if { $y0 < 0 }      {set y "+0"}
                    }
                    if { $idx == 2 } {
                        # try left, then right if out, then 0 if out
                        if { $x0 >= $w } {
                            set x [expr {$x0-$sw}]
                        } elseif { $x1+$w <= $sw } {
                            set x "+$x1"
                        } else {
                            set x "+0"
                        }
                    } else {
                        # try right, then left if out, then 0 if out
                        if { $x1+$w <= $sw } {
                            set x "+$x1"
                        } elseif { $x0 >= $w } {
                            set x [expr {$x0-$sw}]
                        } else {
                            set x "-0"
                        }
                    }
                } else { ## above or below
                    set x "+$x0"
                    if {[string equal $::tcl_platform(platform) "windows"]} {
                        if { $x0+$w > $sw } {set x "-0"; set x0 [expr {$sw-$w}]}
                        if { $x0 < 0 }      {set x "+0"}
                    }
                    if { $idx == 4 } {
                        # try top, then bottom, then 0
                        if { $h <= $y0 } {
                            set y [expr {$y0-$sh}]
                        } elseif { $y1+$h <= $sh } {
                            set y "+$y1"
                        } else {
                            set y "+0"
                        }
                    } else {
                        # try bottom, then top, then 0
                        if { $y1+$h <= $sh } {
                            set y "+$y1"
                        } elseif { $h <= $y0 } {
                            set y [expr {$y0-$sh}]
                        } else {
                            set y "-0"
                        }
                    }
                }
            }
        }

        ## If there's not a + or - in front of the number, we need to add one.
        if {[string is integer [string index $x 0]]} { set x +$x }
        if {[string is integer [string index $y 0]]} { set y +$y }

        wm geometry $path "${w}x${h}${x}${y}"
    } else {
        wm geometry $path "${w}x${h}"
    }
    update idletasks
}


# ----------------------------------------------------------------------------
#  Command BWidget::grab
# ----------------------------------------------------------------------------
proc BWidget::grab { option path } {
    variable _gstack

    if { $option == "release" } {
        catch {::grab release $path}
        while { [llength $_gstack] } {
            set grinfo  [lindex $_gstack end]
            set _gstack [lreplace $_gstack end end]
            foreach {oldg mode} $grinfo {
                if { ![string equal $oldg $path] && [winfo exists $oldg] } {
                    if { $mode == "global" } {
                        catch {::grab -global $oldg}
                    } else {
                        catch {::grab $oldg}
                    }
                    return
                }
            }
        }
    } else {
        set oldg [::grab current]
        if { $oldg != "" } {
            lappend _gstack [list $oldg [::grab status $oldg]]
        }
        if { $option == "global" } {
            ::grab -global $path
        } else {
            ::grab $path
        }
    }
}


# ----------------------------------------------------------------------------
#  Command BWidget::focus
# ----------------------------------------------------------------------------
proc BWidget::focus { option path {refocus 1} } {
    variable _fstack

    if { $option == "release" } {
        while { [llength $_fstack] } {
            set oldf [lindex $_fstack end]
            set _fstack [lreplace $_fstack end end]
            if { ![string equal $oldf $path] && [winfo exists $oldf] } {
                if {$refocus} {catch {::focus -force $oldf}}
                return
            }
        }
    } elseif { $option == "set" } {
        lappend _fstack [::focus]
        ::focus -force $path
    }
}

# BWidget::refocus --
#
#	Helper function used to redirect focus from a container frame in 
#	a megawidget to a component widget.  Only redirects focus if
#	focus is already on the container.
#
# Arguments:
#	container	container widget to redirect from.
#	component	component widget to redirect to.
#
# Results:
#	None.

proc BWidget::refocus {container component} {
    if { [string equal $container [::focus]] } {
	::focus $component
    }
    return
}

## These mirror tk::(Set|Restore)FocusGrab

# BWidget::SetFocusGrab --
#   swap out current focus and grab temporarily (for dialogs)
# Arguments:
#   grab	new window to grab
#   focus	window to give focus to
# Results:
#   Returns nothing
#
proc BWidget::SetFocusGrab {grab {focus {}}} {
    variable _focusGrab
    set index "$grab,$focus"

    lappend _focusGrab($index) [::focus]
    set oldGrab [::grab current $grab]
    lappend _focusGrab($index) $oldGrab
    if {[winfo exists $oldGrab]} {
	lappend _focusGrab($index) [::grab status $oldGrab]
    }
    # The "grab" command will fail if another application
    # already holds the grab.  So catch it.
    catch {::grab $grab}
    if {[winfo exists $focus]} {
	::focus $focus
    }
}

# BWidget::RestoreFocusGrab --
#   restore old focus and grab (for dialogs)
# Arguments:
#   grab	window that had taken grab
#   focus	window that had taken focus
#   destroy	destroy|withdraw - how to handle the old grabbed window
# Results:
#   Returns nothing
#
proc BWidget::RestoreFocusGrab {grab focus {destroy destroy}} {
    variable _focusGrab
    set index "$grab,$focus"
    if {[info exists _focusGrab($index)]} {
	foreach {oldFocus oldGrab oldStatus} $_focusGrab($index) break
	unset _focusGrab($index)
    } else {
	set oldGrab ""
    }

    catch {::focus $oldFocus}
    ::grab release $grab
    if {[string equal $destroy "withdraw"]} {
	wm withdraw $grab
    } else {
	::destroy $grab
    }
    if {[winfo exists $oldGrab] && [winfo ismapped $oldGrab]} {
	if {[string equal $oldStatus "global"]} {
	    ::grab -global $oldGrab
	} else {
	    ::grab $oldGrab
	}
    }
}

# BWidget::badOptionString --
#
#	Helper function to return a proper error string when an option
#       doesn't match a list of given options.
#
# Arguments:
#	type	A string that represents the type of option.
#	value	The value that is in-valid.
#       list	A list of valid options.
#
# Results:
#	None.
proc BWidget::badOptionString { type value list } {
    set list [lsort $list]

    ## Make a special case for the -- option.  We always
    ## want that to go at the end of the list.
    set x [lsearch -exact $list "--"]
    if {$x > -1} {
        set list [lreplace $list $x $x]
        lappend list --
    }

    set last [lindex $list end]
    set list [lreplace $list end end]
    set msg  "bad $type \"$value\": must be "
    
    if {![llength $list]} {
        append msg "$last"
    } elseif {[llength $list] == 1} {
        append msg "$list or $last"
    } else {
        append msg "[join $list ", "], or $last"
    }
    
    return $msg
}


proc BWidget::wrongNumArgsString { string } {
    return "wrong # args: should be \"$string\""
}


proc BWidget::read_file { file } {
    set fp [open $file]
    set x  [read $fp [file size $file]]
    close $fp
    return $x
}


proc BWidget::classes { class } {
    variable use

    ${class}::use
    set classes [list $class]
    if {![info exists use($class)]} { return }
    foreach class $use($class) {
	eval lappend classes [classes $class]
    }
    return [lsort -unique $classes]
}


proc BWidget::library { args } {
    variable use

    set exclude [list]
    if {[set x [lsearch -exact $args "-exclude"]] > -1} {
        set exclude [lindex $args [expr {$x + 1}]]
        set args    [lreplace $args $x [expr {$x + 1}]]
    }

    set libs    [list widget init utils]
    set classes [list]
    foreach class $args {
	${class}::use
        foreach c [classes $class] {
            if {[lsearch -exact $exclude $c] > -1} { continue }
            lappend classes $c
        }
    }

    eval lappend libs [lsort -unique $classes]

    set library ""
    foreach lib $libs {
	if {![info exists use($lib,file)]} {
	    set file [file join $::BWIDGET::LIBRARY $lib.tcl]
	} else {
	    set file [file join $::BWIDGET::LIBRARY $use($lib,file).tcl]
	}
        append library [read_file $file]
    }

    return $library
}


proc BWidget::inuse { class } {
    variable ::Widget::_inuse

    if {![info exists _inuse($class)]} { return 0 }
    return [expr $_inuse($class) > 0]
}


proc BWidget::write { filename {mode w} } {
    variable use

    if {![info exists use(classes)]} { return }

    set classes [list]
    foreach class $use(classes) {
	if {![inuse $class]} { continue }
	lappend classes $class
    }

    set fp [open $filename $mode]
    puts $fp [eval library $classes]
    close $fp

    return
}


# BWidget::bindMouseWheel --
#
#	Bind mouse wheel actions to a given widget.
#
# Arguments:
#	widget - The widget to bind.
#
# Results:
#	None.
proc BWidget::bindMouseWheel { widgetOrClass } {
    bind $widgetOrClass <MouseWheel>         {
        if {![string equal [%W yview] "0 1"]} {
            %W yview scroll [expr {-%D/24}]  units
        }
    }

    bind $widgetOrClass <Shift-MouseWheel>   {
        if {![string equal [%W yview] "0 1"]} {
            %W yview scroll [expr {-%D/120}] pages
        }
    }

    bind $widgetOrClass <Control-MouseWheel> {
        if {![string equal [%W yview] "0 1"]} {
            %W yview scroll [expr {-%D/120}] units
        }
    }

    bind $widgetOrClass <Button-4> {event generate %W <MouseWheel> -delta  120}
    bind $widgetOrClass <Button-5> {event generate %W <MouseWheel> -delta -120}
}


proc BWidget::Icon { name } {
    if {![Widget::exists $::BWidget::iconLibrary]} {
        BWidget::LoadBWidgetIconLibrary
    }

    return [$::BWidget::iconLibrary image $name]
}


proc BWidget::LoadBWidgetIconLibrary {} {
    if {![Widget::exists $::BWidget::iconLibrary]} {
        IconLibrary $::BWidget::iconLibrary -file $::BWidget::iconLibraryFile
    }
}


proc BWidget::CreateImage { gifdata pngdata args } {
    lappend args -format $::BWidget::imageFormat
    if {[BWidget::using png]} {
        lappend args -data $pngdata
    } else {
        lappend args -data $gifdata
    }

    return [eval image create photo $args]
}


proc BWidget::ParseArgs { _arrayName _arglist args } {
    upvar 1 $_arrayName array

    array set _args {
        -strict     0
        -options    {}
        -switches   {}
        -required   {}
        -nocomplain 0
    }
    array set _args $args
    if {[info exists _args(-errorvar)]} { upvar 1 $_args(-errorvar) error }

    set switches $_args(-switches)
    foreach switch $switches {
        set array([string range $switch 1 end]) 0
    }

    set options [list]
    foreach opt $_args(-options) {
        set option $opt
        if {[llength $opt] == 2} {
            set option [lindex $opt 0]
            set array([string range $option 1 end]) [lindex $opt 1]
        }
        lappend options $option
    }

    set array(OPTIONS)  [list]
    set array(SWITCHES) [list]

    set oplen   [llength $options]
    set swlen   [llength $switches]
    set index   0
    set waiting 0
    foreach arg $_arglist {
        switch -glob -- $arg {
            "--" {
                incr index
                break
            }

            "-*" {
                if {$waiting} {
                    set waiting 0
                    set array($option) $arg
                    lappend array(OPTIONS) -$option $arg
                    continue
                }

                    if {$swlen && [lsearch -exact $switches $arg] > -1} {
                        lappend array(SWITCHES) $arg
                        set array([string range $arg 1 end]) 1
                    } elseif {$oplen && [lsearch -exact $options $arg] < 0} {
                        if {$_args(-nocomplain)} { return 0 }
                        return -code error "unknown option \"$arg\""
                    } elseif {$_args(-strict)} {
                        ## Option didn't match a switch, and we're being strict.
                        set switches [concat -- $_args(-switches)]
                        set msg [BWidget::badOptionString option $arg $switches]
                        return -code error $msg
                    } else {
                        set waiting 1
                        set option [string range $arg 1 end]
                    }
                }

            default {
                if {$waiting} {
                    set waiting 0
                    set array($option) $arg
                    lappend array(OPTIONS) -$option $arg
                } else {
                    break
                }
            }
        }

        incr index
    }

    set array(_ARGS_) [lrange $_arglist $index end]

    if {[llength $_args(-required)]} {
        foreach arg [lsort -dict $_args(-required)] {
            if {![info exists array([string range $arg 1 end])]} {
                return -code error "missing required argument $arg"
            }
        }
    }

    return 1
}


proc BWidget::CopyBindings { from to } {
    foreach event [bind $from] {
        bind $to $event [bind $from $event]
    }
}


proc BWidget::DrawCanvasBorder { canvas relief color coords args } {
    lassign $coords x0 y0 x1 y1
    lassign [BWidget::get3dcolor $canvas $color] dark light dark2 light2

    switch -- $relief {
        "raised" - "sunken" {
            lappend lines [list $x0 $y1 $x0 $y0 $x1 $y0]
            lappend lines [list $x1 $y0 $x1 $y1 $x0 $y1]
            lappend lines [list \
                [expr {$x0 + 1}] [expr {$y1 - 2}] \
                [expr {$x0 + 1}] [expr {$y0 + 1}] \
                [expr {$x1 - 1}] [expr {$y0 + 1}]]
            lappend lines [list \
                [expr {$x0 + 1}] [expr {$y1 - 1}] \
                [expr {$x1 - 1}] [expr {$y1 - 1}] \
                [expr {$x1 - 1}] $y0]

            set colors [list $light $dark $light2 $dark2]
            if {[string equal $relief "sunken"]} {
                set colors [list $dark $light $dark2 $light2]
            }
        }

        "groove" - "ridge" {
            lappend lines [list \
                $x0 $y1 \
                $x1 $y1 \
                $x1 $y0 \
                $x1 [expr {$y0 + 1}] \
                [expr {$x0 + 1}] [expr {$y0 + 1}] \
                [expr {$x0 + 1}] $y1 \
            ]

            lappend lines [list \
                $x0 $y0 \
                [expr {$x1 - 1}] $y0 \
                [expr {$x1 - 1}] [expr {$y1 - 1}] \
                $x0 [expr {$y1 - 1}] \
                $x0 $y0 \
            ]

            set colors [list $light $dark2]
            if {[string equal $relief "ridge"]} {
                set colors [list $dark2 $light]
            }
        }

        "rounded" {
            set coords [list \
                [expr {$x0 + 1}] $y0 \
                [expr {$x1 - 1}] $y0 \
                $x1 [expr {$y0 + 1}] \
                $x1 [expr {$y1 - 1}] \
                [expr {$x1 - 1}] $y1 \
                [expr {$x0 + 1}] $y1 \
                $x0 [expr {$y1 - 1}] \
                $x0 [expr {$y0 + 1}] \
                [expr {$x0 + 1}] $y0 \
            ]

            set opts [list -outline $dark2 -fill $color]
            eval [list $canvas create poly $coords] $opts $args

            return
        }

        "highlight" {
            set opts [list -outline $dark -fill $light]
            eval [list $canvas create rect $coords] $opts $args

            set coords [list [incr x0] [incr y0] [incr x1 -1] [incr y1 -1]]
            eval [list $canvas create rect $coords -outline $dark2] $args

            return
        }
    }

    foreach line $lines color $colors {
        eval [list $canvas create line $line -fill $color] $args
    }
}

proc ::BWidget::FadeWindowIn { top {increment 0.08} {current 0} } {
    if {[tk windowingsystem] eq "x11"
        || ![package vsatisfies [info patchlevel] 8.4.8]} {
        wm deiconify $top
        return
    }

    if {$current == 0} {
        wm attributes $top -alpha [set current 0.01]
	wm deiconify $top
    }

    set current [expr {$current + $increment}]

    if {$current < 1.0} {
        wm attributes $top -alpha $current
        update idletasks

        after 10 [list BWidget::FadeWindowIn $increment $current]
    } else {
	wm attributes $top -alpha 0.99999
    }
}

proc ::BWidget::FadeWindowOut { top {destroy 0} {increment 0.08} {current 0} } {
    if {![winfo exists $top]} { return }

    if {[tk windowingsystem] eq "x11"
        || ![package vsatisfies [info patchlevel] 8.4.8]} {
        if {$destroy} {
            destroy $top
        } else {
            wm withdraw $top
        }
        return
    }

    if {$current == 0} {
	set current [wm attributes $top -alpha]
    }

    set current [expr {$current - $increment}]

    if {$current >= .01} {
        wm attributes $top -alpha $current
        update idletasks

        after 10 [list BWidget::FadeWindowOut $top $destroy $increment $current]
    } else {
        if {$destroy} {
            destroy $top
        } else {
	    wm withdraw   $top
	    wm attributes $top -alpha 0.99999
        }
    }
}

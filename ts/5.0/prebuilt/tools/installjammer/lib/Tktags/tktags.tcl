##
## TkTags - An interface for associating symbolic names with Tk widgets.
##
## tag add       tagName <widget ?menuItem?> ??widget ?menuItem?? ... ?
## tag addmenu   tagName menu menuItem ?menuItem ...?
## tag addtag    tagName searchSpec ?arg arg ... ?
##
## tag addtag    tagName ?recursive? ?class widgetClass? ?type menuItemType?
##                       ?children widgetName? ?menuentries menuName? ?arg ... ?
##
## tag cget      widgetOrTagName option
## tag configure widgetOrTagName ?option? ?value? ?option value ... ?
## tag delete    tagName ?tagName ... ?
## tag names     ?widget ?menuItem??
## tag remove    tagName <widget ?menuItem?> ??widget ?menuItem?? ... ?
## tag widgets   tagName ?tagName ... ?
##

package require Tk
package provide "Tktags" "1.0"

namespace eval ::TkTags {
    variable tags
    variable widgets
}

proc ::TkTags::Lempty {list} {
    if {[catch {llength $list} len]} { return 0 }
    return [expr $len == 0]
}

proc ::TkTags::Lremove {list args} {
    foreach elem $args {
        set x [lsearch -exact $list $elem]
        if {$x < 0} { continue }
        set list [lreplace $list $x $x]
    }
    return $list
}

proc ::TkTags::OptionErrorString {word type value list} {
    set msg "$word $type \"$value\": must be "
    set last [lindex $list end]
    set list [lrange $list 0 end-1]
    append msg [join $list ", "] ", or $last"
    return $msg
}

proc ::TkTags::add {tagName args} {
    variable tags
    variable widgets
    foreach arg $args {
        if {![info exists tags($tagName)]
            || [lsearch -exact $tags($tagName) $arg] < 0} {
            lappend tags($tagName) $arg
        }

        if {![info exists widgets($arg)]
            || [lsearch -exact $widgets($arg) $tagName] < 0} {
            lappend widgets($arg)  $tagName
        }
    }
}

proc ::TkTags::addmenu {tagName menu args} {
    set list [list]
    foreach index $args {
        lappend list [list $menu $index]
    }
    eval add $tagName $list
}

proc ::TkTags::addtag {tagName args} {
    set recursive 0
    set pass      [list]
    set widgets   [list]
    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]

        switch -glob -- $arg {
            "cl*" { ## class
                set class [lindex $args [incr i]]
                lappend classes $class
                lappend pass class $class
            }

            "r*" { ## recursive
                set recursive 1
                lappend pass recursive
            }

            "t*" { ## type
                set type [lindex $args [incr i]]
                lappend types $type
                lappend pass type $type
            }

            default {
                lappend search $arg
            }
        }
    }

    set args $search

    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]

        switch -glob -- $arg {
            "ch*" { ## children
                set widget [lindex $args [incr i]]
                if {![winfo exists $widget]} { continue }
                foreach widget [winfo children $widget] {
                    if {[string match "*.#*" $widget]} { continue }
                    set class [winfo class $widget]
                    if {![info exists classes]
                        || [lsearch -exact $classes $class] > -1} {
                        lappend widgets $widget
                    }
                    if {$recursive} {
                        eval lappend widgets \
                            [eval addtag $tagName $pass children $widget]
                    }
                }
            }

            "m*" { ## menuentries
                set widget [lindex $args [incr i]]
                if {![winfo exists $widget]} { continue }
                if {[string match "*.#*" $widget]} { continue }
                if {![string equal [winfo class $widget] "Menu"]} {
                    return -code error "$widget is not a menu"
                }
                for {set j 0} {1} {incr j} {
                    if {[$widget index $j] != $j} { break }
                    set type [$widget type $j]
                    if {![info exists types]
                        || [lsearch -exact $types $type] > -1} {
                        lappend widgets [list $widget $j]
                    }

                    if {$type == "cascade" && $recursive} {
                        set menu [$widget entrycget $j -menu]
                        eval lappend widgets \
                            [eval addtag $tagName $pass menuentries $menu]
                    }
                }
            }

            default {
                if {[winfo exists $arg]} { lappend widgets $arg }
            }
        }
    }
    eval add $tagName $widgets
    return $widgets
}

proc ::TkTags::cget {tagName option} {
    variable tags
    if {![info exists tags($tagName)]} {
        set widget [lindex $tagName 0]
        set index  [lindex $tagName 1]
        if {![winfo exists $widget]} { return }
    } else {
        if {[llength $tags($tagName)] > 1} { return }
        set item   [lindex $tags($tagName) 0]
        set widget [lindex $item 0]
        set index  [lindex $item 1]
    }

    if {[Lempty $index]} { return [$widget cget $option] }

    if {[winfo class $widget] == "Menu"} {
        return [$widget entrycget $index $option]
    } else {
        return [$widget itemcget $index $option]
    }
}

proc ::TkTags::configure {tagName args} {
    variable tags
    if {![info exists tags($tagName)]} {
        set widget [lindex $tagName 0]
        if {![winfo exists $widget]} { return }
        set items [list $tagName]
    } else {
        set items $tags($tagName)
    }

    if {[llength $args] < 2} {
        if {[llength $items] > 1} { return }
        set item   [lindex $items 0]
        set widget [lindex $item 0]
        set index  [lindex $item 1]
        if {![winfo exists $widget]} { return }

        if {[Lempty $index]} { return [eval $widget configure $args] }

        if {[winfo class $widget] == "Menu"} {
            return [eval $widget entryconfigure $index $args]
        } else {
            return [eval $widget itemconfigure $index $args]
        }
    }

    foreach {opt val} $args {
        foreach item $items {
            set widget [lindex $item 0]
            set index  [lindex $item 1]
            if {![winfo exists $widget]} { continue }
            if {![Lempty $index]} {
                if {[winfo class $widget] == "Menu"} {
                    catch { $widget entryconfigure $index $opt $val }
                } else {
                    catch { $widget itemconfigure $index $opt $val }
                }
            } else {
                catch { $widget configure $opt $val }
            }
        }
    }
}

proc ::TkTags::delete {args} {
    variable tags
    variable widgets

    foreach tagName $args {
        if {![info exists tags($tagName)]} { continue }
        foreach widget $tags($tagName) {
            if {![info exists widgets($widget)]} { continue }
            set widgets($widget) [Lremove $widgets($widget) $tagName]
            if {[Lempty $widgets($widget)]} { unset widgets($widget) }
        }
        unset tags($tagName)
    }
}

proc ::TkTags::names {{widget ""}} {
    variable tags
    variable widgets
    if {[Lempty $widget]} { return [lsort [array names tags]] }
    if {![info exists widgets($widget)]} { return }
    return $widgets($widget)
}

proc ::TkTags::remove {tagName args} {
    variable tags
    variable widgets

    if {![info exists tags($tagName)]} { return }

    set tags($tagName) [eval Lremove [list $tags($tagName)] $args]
    if {[Lempty $tags($tagName)]} { unset tags($tagName) }

    foreach widget $args {
        if {![info exists widgets($widget)]} { continue }
        set widgets($widget) [Lremove $widgets($widget) $tagName]
        if {[Lempty $widgets($widget)]} { unset widgets($widget) }
    }
}

proc ::TkTags::widgets {args} {
    variable tags
    set widgets [list]
    foreach tagName $args {
        if {![info exists tags($tagName)]} { continue }
        foreach widget $tags($tagName) {
            if {[lsearch -exact $widgets $widget] > -1} { continue }
            lappend widgets $widget
        }
    }
    return $widgets
}

proc ::tag {args} {
    if {[::TkTags::Lempty $args]} {
	set msg "wrong # args: should be tag option arg ?arg ...?"
	return -code error $msg
    }

    set cmd [lindex $args 0]
    set lst [list add addmenu addtag cget configure delete names remove widgets]
    set command [info commands ::TkTags::$cmd]
    if {[::TkTags::Lempty $command]} {
	set cmds [info commands ::TkTags::$cmd*]
	if {[::TkTags::Lempty $cmds]} {
	    set msg [::TkTags::OptionErrorString bad option $cmd $lst]
	    return -code error $msg
	}
	if {[llength $cmds] > 1} {
	    set msg [::TkTags::OptionErrorString ambiguous option $cmd $lst]
	    return -code error $msg
	}
	set command [lindex $cmds 0]
    }

    return [eval $command [lrange $args 1 end]]
}

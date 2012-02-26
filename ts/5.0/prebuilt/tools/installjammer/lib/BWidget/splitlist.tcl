# -----------------------------------------------------------------------------
#  splitlist.tcl
#
#  $Id$
# -----------------------------------------------------------------------------
#  Index of commands:
#     - SplitList::create
#     - SplitList::configure
#     - SplitList::cget
# -----------------------------------------------------------------------------

package require Tk 8.4

namespace eval SplitList {
    Widget::define SplitList splitlist ListBox

    Widget::bwinclude SplitList ListBox .left \
        prefix { left remove -bg -fg -bd }

    Widget::bwinclude SplitList ListBox .right \
        prefix { right remove -bg -fg -bd }

    Widget::tkinclude SplitList frame :cmd \
        include { -background -bg -relief -borderwidth -bd -width -height }
}


proc SplitList::create { path args } {
    Widget::initArgs SplitList $args maps

    eval frame $path $maps(:cmd) -class SplitList

    Widget::initFromODB SplitList $path $maps(SplitList)

    grid rowconfigure    $path 0     -weight 1
    grid columnconfigure $path {0 2} -weight 1

    eval [list ListBox $path.left -dragenabled 1 -dropenabled 1 \
        -dropcmd SplitList::_drag_and_drop -selectmode multiple -selectfill 1] \
        $maps(.left)

    grid $path.left -row 0 -column 0 -sticky news

    ButtonBox $path.buttons -orient vertical
    grid $path.buttons -row 0 -column 1 -padx 5

    $path.buttons add -text ">" -width 5 \
        -command [list SplitList::_shift_items $path right]
    $path.buttons add -text "<" \
        -command [list SplitList::_shift_items $path left]
    $path.buttons add -text ">>" \
        -command [list SplitList::_shift_items $path right 1]
    $path.buttons add -text "<<" \
        -command [list SplitList::_shift_items $path left 1]

    eval [list ListBox $path.right -dragenabled 1 -dropenabled 1 \
        -dropcmd SplitList::_drag_and_drop -selectmode multiple] \
        $maps(.right)
    grid $path.right -row 0 -column 2 -sticky news

    return [Widget::create SplitList $path]
}


proc SplitList::configure { path args } {
    set res [Widget::configure $path $args]
    return $res
}


proc SplitList::cget { path option } {
    return [Widget::cget $path $option]
}


proc SplitList::copy { path item leftOrRight newItem index } {
    Widget::getVariable $path items

    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }

    set newItem [Widget::nextIndex $path $newItem]

    if {[info exists items($newItem)]} {
        return -code error "item \"$newItem\" does not exist"
    }

    set to   [SplitList::getlistbox $path $leftOrRight]
    set from $path.$items($item)

    set options [Widget::options $from.$item]
    set item [eval [linsert $options 0 $to insert $index $newItem]]
    set items($item) $leftOrRight
}


proc SplitList::getlistbox { path leftOrRight } {
    if {$leftOrRight eq "left"} {
        return $path.left
    } elseif {$leftOrRight eq "right"} {
        return $path.right
    } else {
        return -code error \
            [BWidget::badOptionString listbox $leftOrRight [list left right]]
    }
}


proc SplitList::insert { path leftOrRight index item args } {
    Widget::getVariable $path items

    set item [Widget::nextIndex $path $item]

    if {[info exists items($item)]} {
        return -code error "item \"$item\" already exists"
    }

    set items($item) $leftOrRight

    eval [list $path.$leftOrRight insert $index $item] $args
}


proc SplitList::itemcget { path item option } {
    Widget::getVariable $path items

    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }

    return [$path.$items($item) itemcget $item $option]
}


proc SplitList::itemconfigure { path item args } {
    Widget::getVariable $path items

    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }

    return [eval [list $path.$items($item) itemconfigure $item] $args]
}


proc SplitList::move { path item leftOrRight index } {
    Widget::getVariable $path items

    if {![info exists items($item)]} {
        return -code error "item \"$item\" does not exist"
    }

    set to   [SplitList::getlistbox $path $leftOrRight]
    set from $path.$items($item)

    if {$to eq $from} {
        $to move $item $index
    } else {
        set options [Widget::options $from.$item]
        set item [eval [linsert $options 0 $to insert $index $item]]
        set items($item) $leftOrRight
        $from delete $item
    }
}


proc SplitList::_shift_items { path dir {all 0} } {
    set opp [expr {$dir eq "left" ? "right" : "left"}]

    if {$all} {
        set items [$path.$opp items]
    } else {
        set items [$path.$opp selection get]
    }

    foreach item $items {
        SplitList::move $path $item $dir end
    }
}


proc SplitList::_drag_and_drop { path from endItem operation type startItem } {
    set tolist   $path
    set fromlist [winfo parent $from]
    set path     [winfo parent $path]

    if {[winfo parent $tolist] ne [winfo parent $fromlist]} { return }

    set place [lindex $endItem 0]
    set i     [lindex $endItem 1]

    switch -- $place {
        "position" {
            set idx $i
        } 

        "item" {
            set idx [$tolist index $i]
        }

        default {
            set idx end
        }
    }

    if {[string equal $operation "copy"]} {
        set newItem [Widget::nextIndex $path COPY$startItem-#auto]
        SplitList::copy $path $startItem [winfo name $tolist] $newItem $idx
    } else {
        SplitList::move $path $startItem [winfo name $tolist] $idx
    }
}

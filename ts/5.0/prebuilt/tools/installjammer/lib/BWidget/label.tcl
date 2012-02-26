# ------------------------------------------------------------------------------
#  label.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: label.tcl,v 1.10 2003/10/20 21:23:52 damonc Exp $
# ------------------------------------------------------------------------------
#  Index of commands:
#     - Label::create
#     - Label::configure
#     - Label::cget
#     - Label::setfocus
#     - Label::_drag_cmd
#     - Label::_drop_cmd
#     - Label::_over_cmd
# ------------------------------------------------------------------------------

namespace eval Label {
    Widget::define Label label DragSite DropSite DynamicHelp

    Widget::tkinclude Label label .l \
        remove { -foreground -state -text -textvariable -underline }

    Widget::declare Label {
        {-name               String     ""     0}
        {-text               String     ""     0}
        {-textvariable       String     ""     0}
        {-underline          Int        -1     0 "%d >= -1"}
        {-focus              String     ""     0}
        {-foreground         Color      "SystemButtonText"       0}
        {-disabledforeground Color      "SystemDisabledText"     0}
        {-state              Enum       normal 0  {normal disabled}}

        {-autowrap           Boolean    "0"    1}
        {-wrappadx           Int        "10"   0}

        {-elide              Boolean    "0"    1}
        {-ellipsis           String     "..."  0}
        {-elidepadx          Int        "5"    0}
        {-elideside          Enum       "right" 0 {center left right}}

        {-fg                 Synonym    -foreground}
    }

    DynamicHelp::include Label balloon
    DragSite::include    Label "" 1
    DropSite::include    Label {
        TEXT    {move {}}
        IMAGE   {move {}}
        BITMAP  {move {}}
        FGCOLOR {move {}}
        BGCOLOR {move {}}
        COLOR   {move {}}
    }

    Widget::syncoptions Label "" .l {-text {} -underline {}}

    bind BwLabel <FocusIn>   [list Label::setfocus %W]
    bind BwLabel <Destroy>   [list Label::_destroy %W]
}


# ------------------------------------------------------------------------------
#  Command Label::create
# ------------------------------------------------------------------------------
proc Label::create { path args } {
    Widget::initArgs Label $args maps

    frame $path -class Label -borderwidth 0 -highlightthickness 0 -relief flat
    Widget::initFromODB Label $path $maps(Label)

    Widget::getVariable $path data

    set data(width) 0

    eval [list label $path.l] $maps(.l)

    if {[string equal [Widget::cget $path -state] "normal"]} {
        set fg [Widget::cget $path -foreground]
    } else {
        set fg [Widget::cget $path -disabledforeground]
    }

    set var [Widget::cget $path -textvariable]
    if {$var == ""
        && [Widget::cget $path -image] == ""
        && [Widget::cget $path -bitmap] == ""} {
        set desc [BWidget::getname [Widget::cget $path -name]]
        if {[string length $desc]} {
            set text  [lindex $desc 0]
            set under [lindex $desc 1]
        } else {
            set text  [Widget::cget $path -text]
            set under [Widget::cget $path -underline]
        }
    } else {
        set under -1
        set text  ""
    }

    $path.l configure -text $text -underline $under -foreground $fg

    set accel [string tolower [string index $text $under]]
    if {[string length $accel]} {
        bind [winfo toplevel $path] <Alt-$accel> [list Label::setfocus $path]
    }

    bindtags $path   [list BwLabel [winfo toplevel $path] all]
    bindtags $path.l [list $path.l $path Label [winfo toplevel $path] all]
    pack $path.l -expand yes -fill both

    set dragendcmd [Widget::cget $path -dragendcmd]
    DragSite::setdrag $path $path.l Label::_init_drag_cmd $dragendcmd 1
    DropSite::setdrop $path $path.l Label::_over_cmd Label::_drop_cmd 1
    DynamicHelp::sethelp $path $path.l 1

    if {[string length $var]} {
        upvar #0 $var textvar
        _trace_variable $path
        if {![info exists textvar]} {
            set textvar [Widget::getoption $path -text]
        } else {
            _update_textvariable $path "" "" write
        }
    }

    if {[Widget::getoption $path -elide]
        || [Widget::getoption $path -autowrap]} {
        bind $path.l <Configure> [list Label::_redraw $path %w]
    }

    return [Widget::create Label $path]
}


# ------------------------------------------------------------------------------
#  Command Label::configure
# ------------------------------------------------------------------------------
proc Label::configure { path args } {
    set oldunder [$path.l cget -underline]
    if {$oldunder != -1} {
        set oldaccel [string index [$path.l cget -text] $oldunder]
        set oldaccel [string tolower $oldaccel]
    } else {
        set oldaccel ""
    }

    set oldvar [$path.l cget -textvariable]

    set res [Widget::configure $path $args]

    set cfg  [Widget::hasChanged $path -foreground fg]
    set cdfg [Widget::hasChanged $path -disabledforeground dfg]
    set cst  [Widget::hasChanged $path -state state]

    if { $cst || $cfg || $cdfg } {
        if { $state == "normal" } {
            $path.l configure -fg $fg
        } else {
            $path.l configure -fg $dfg
        }
    }

    set cv [Widget::hasChanged $path -textvariable var]
    set cb [Widget::hasChanged $path -image img]
    set ci [Widget::hasChanged $path -bitmap bmp]
    set cn [Widget::hasChanged $path -name name]
    set ct [Widget::hasChanged $path -text text]
    set cu [Widget::hasChanged $path -underline under]

    if { $cv || $cb || $ci || $cn || $ct || $cu } {
        if {  $var == "" && $img == "" && $bmp == "" } {
            set desc [BWidget::getname $name]
            if { $desc != "" } {
                set text  [lindex $desc 0]
                set under [lindex $desc 1]
            }
        } else {
            set under -1
            set text  ""
        }
        set top [winfo toplevel $path]
        if { $oldaccel != "" } {
            bind $top <Alt-$oldaccel> {}
        }
        set accel [string tolower [string index $text $under]]
        if { $accel != "" } {
            bind $top <Alt-$accel> [list Label::setfocus $path]
        }
        $path.l configure -text $text -underline $under -textvariable $var
    }

    if {$cv} {
        if {[string length $oldvar]} {
            trace remove variable $oldvar [list write unset] \
                [list Label::_update_textvariable $path]
        }

        _trace_variable $path
    }

    if {$ct && [Widget::getoption $path -elide]} {
        _redraw $path [winfo width $path]
    }

    set force [Widget::hasChanged $path -dragendcmd dragend]
    DragSite::setdrag $path $path.l Label::_init_drag_cmd $dragend $force
    DropSite::setdrop $path $path.l Label::_over_cmd Label::_drop_cmd
    DynamicHelp::sethelp $path $path.l

    return $res
}


# ------------------------------------------------------------------------------
#  Command Label::cget
# ------------------------------------------------------------------------------
proc Label::cget { path option } {
    return [Widget::cget $path $option]
}


# ------------------------------------------------------------------------------
#  Command Label::setfocus
# ------------------------------------------------------------------------------
proc Label::setfocus { path } {
    if {[string equal [Widget::cget $path -state] "normal"]} {
        set w [Widget::cget $path -focus]
        if { [winfo exists $w] && [Widget::focusOK $w] } {
            focus $w
        }
    }
}


# ------------------------------------------------------------------------------
#  Command Label::_init_drag_cmd
# ------------------------------------------------------------------------------
proc Label::_init_drag_cmd { path X Y top } {
    set path [winfo parent $path]
    if {[set cmd [Widget::cget $path -draginitcmd]] != ""} {
        return [uplevel \#0 $cmd [list $path $X $Y $top]]
    }
    if { [set data [$path.l cget -image]] != "" } {
        set type "IMAGE"
        pack [label $top.l -image $data]
    } elseif { [set data [$path.l cget -bitmap]] != "" } {
        set type "BITMAP"
        pack [label $top.l -bitmap $data]
    } else {
        set data [$path.l cget -text]
        set type "TEXT"
    }
    set usertype [Widget::getoption $path -dragtype]
    if { $usertype != "" } {
        set type $usertype
    }
    return [list $type {copy} $data]
}


# ------------------------------------------------------------------------------
#  Command Label::_drop_cmd
# ------------------------------------------------------------------------------
proc Label::_drop_cmd { path source X Y op type data } {
    set path [winfo parent $path]
    if {[set cmd [Widget::cget $path -dropcmd]] != ""} {
        return [uplevel \#0 $cmd [list $path $source $X $Y $op $type $data]]
    }
    if { $type == "COLOR" || $type == "FGCOLOR" } {
        configure $path -foreground $data
    } elseif { $type == "BGCOLOR" } {
        configure $path -background $data
    } else {
        set text   ""
        set image  ""
        set bitmap ""
        switch -- $type {
            IMAGE   {set image $data}
            BITMAP  {set bitmap $data}
            default {
                set text $data
                if { [set var [$path.l cget -textvariable]] != "" } {
                    configure $path -image "" -bitmap ""
                    BWidget::setglobal $var $data
                    return
                }
            }
        }
        configure $path -text $text -image $image -bitmap $bitmap
    }
    return 1
}


# ------------------------------------------------------------------------------
#  Command Label::_over_cmd
# ------------------------------------------------------------------------------
proc Label::_over_cmd { path source event X Y op type data } {
    set path [winfo parent $path]
    if { [set cmd [Widget::cget $path -dropovercmd]] != "" } {
        set opts [list $path $source $event $X $Y $op $type $data]
        return [uplevel \#0 $cmd $opts]
    }
    if {[Widget::getoption $path -state] == "normal" ||
         $type == "COLOR" || $type == "FGCOLOR" || $type == "BGCOLOR"} {
        DropSite::setcursor based_arrow_down
        return 1
    }
    DropSite::setcursor dot
    return 0
}


proc Label::_redraw { path width } {
    Widget::getVariable $path data

    ## If the width is the same as the requested width we recorded
    ## on the last redraw, this is an event caused by our redraw.
    ## We don't want to keep redrawing in a continous loop, so we'll
    ## just stop.
    if {$width == $data(width)} { return }

    if {[Widget::getoption $path -autowrap]} {
        set padx [Widget::getoption $path -wrappadx]
        $path.l configure -wraplength [expr {$width - $padx}]
    } elseif {[Widget::getoption $path -elide]} {
        set font     [$path.l cget -font]
        set text     [Widget::getoption $path -text]
        set side     [Widget::getoption $path -elideside]
        set ellipsis [Widget::getoption $path -ellipsis]

        set bd    [$path.l cget -bd]
        set padx  [$path.l cget -padx]
        set epadx [Widget::getoption $path -elidepadx]
        set width [expr {($width - (($bd + $padx) * 2)) - $epadx}]

        if {$width > 0} {
            set string $text
            while {[font measure $font $string] > $width} {
                switch -- $side {
                    "left"   {
                        set text   [string range $text 1 end]
                        set string $ellipsis$text
                    }

                    "right"  {
                        set text   [string range $text 0 end-1]
                        set string $text$ellipsis
                    }

                    "center" {
                        set x [expr {[string length $text] / 2}]
                        set l [string range $text 0 $x]
                        set r [string range $text [incr x 2] end]
                        set text   $l$r
                        set string $l$ellipsis$r
                    }
                }

                if {![string length $text]} { break }
            }

            $path.l configure -text $string
        }
    }

    set data(width) [winfo reqwidth $path.l]
}


proc Label::_trace_variable { path } {
    set varName [Widget::getoption $path -textvariable]

    if {[string length $varName]} {
        set ops     [list write unset]
        set command [list Label::_update_textvariable $path]

        uplevel #0 [list trace add variable $varName $ops $command]
    }
}


proc Label::_update_textvariable { path name1 name2 op } {
    set varName [Widget::getoption $path -textvariable]
    upvar #0 $varName var

    switch -- $op {
        "write" {
            Widget::setoption $path -text $var

            $path.l configure -text $var

            _redraw $path [winfo width $path]
        }

        "unset" {
            set var [Widget::getoption $path -text]
            _trace_variable $path
        }
    }
}


proc Label::_destroy { path } {
    set ops     [list write unset]
    set cmd     [list Label::_update_textvariable $path]
    set varName [Widget::getoption $path -textvariable]

    uplevel #0 [list trace remove variable $varName $ops $cmd]

    Widget::destroy $path
}

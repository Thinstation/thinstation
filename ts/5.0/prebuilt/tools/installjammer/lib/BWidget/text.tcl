##  $Id$
##
##  Index of commands:
##     - Text::create
##     - Text::configure
##     - Text::cget

namespace eval Text {
    Widget::define Text text

    Widget::tkinclude Text text :cmd \
    	remove { -state -foreground -background }

    Widget::declare Text {
        {-state               Enum    "normal" 0 {disabled normal readonly}}
        {-textvariable        String  "" 0}
        {-background          Color   "SystemWindow" 0}
        {-foreground          Color   "SystemWindowText" 0}
        {-disabledbackground  Color   "SystemButtonFace" 0}
        {-disabledforeground  Color   "SystemDisabledText" 0}

        {-bg                  Synonym -background}
    }

    bind ReadonlyText <1>   {focus %W}
    bind ReadonlyText <Key> {Text::_handle_key_movement %W %K}
}


# ------------------------------------------------------------------------------
#  Command Text::create
# ------------------------------------------------------------------------------
proc Text::create { path args } {
    Widget::initArgs Text $args maps

    eval [list text $path] $maps(:cmd)
    Widget::initFromODB Text $path $maps(Text)

    bind $path <Destroy> [list Text::_destroy $path]
    bindtags $path [list $path ReadonlyText Text [winfo toplevel $path] all]

    Widget::getVariable $path data

    set data(varName) ""

    set state [Widget::getoption $path -state]

    if {$state eq "disabled" || $state eq "readonly"} {
        $path configure -insertwidth 0
    }

    if {$state eq "disabled"} {
        $path configure \
            -foreground [Widget::getoption $path -disabledforeground] \
            -background [Widget::getoption $path -disabledbackground]
    }

    Widget::create Text $path

    Text::_trace_variable $path

    proc ::$path { cmd args } \
    	"return \[Text::_path_command [list $path] \$cmd \$args\]"

    return $path
}


# ------------------------------------------------------------------------------
#  Command Text::configure
# ------------------------------------------------------------------------------
proc Text::configure { path args } {
    set oldstate [Widget::getoption $path -state]

    set res [Widget::configure $path $args]

    if {[Widget::anyChangedX $path -state -background -foreground]} {
        set state [Widget::getoption $path -state]

        if {$state ne "normal"} {
            $path:cmd configure -insertwidth 0
        } else {
            $path:cmd configure -insertwidth 2
        }

        if {$state eq "disabled"} {
            $path:cmd configure \
                -foreground [Widget::getoption $path -disabledforeground] \
                -background [Widget::getoption $path -disabledbackground]
        } else {
            $path:cmd configure \
                -foreground [Widget::cget $path -foreground] \
                -background [Widget::cget $path -background]
        }
    }

    if {[Widget::hasChanged $path -textvariable textvar]} {
        Text::_trace_variable $path
    }

    return $res
}


# ------------------------------------------------------------------------------
#  Command Text::cget
# ------------------------------------------------------------------------------
proc Text::cget { path option } {
    if { [string equal "-text" $option] } {
	return [$path:cmd get]
    }
    Widget::cget $path $option
}


proc Text::clear { path } {
    $path:cmd delete 1.0 end
}


proc Text::insert { path args } {
    if {[Widget::getoption $path -state] eq "normal"} {
        eval [list $path:cmd insert] $args
        Text::_trace_variable $path 1
    }
}


proc Text::delete { path args } {
    if {[Widget::getoption $path -state] eq "normal"} {
        eval [list $path:cmd delete] $args
        Text::_trace_variable $path 1
    }
}


proc Text::Insert { path args } {
    eval [list $path:cmd insert] $args
}


proc Text::Delete { path args } {
    eval [list $path:cmd delete] $args
}


# ------------------------------------------------------------------------------
#  Command Text::_path_command
# ------------------------------------------------------------------------------
proc Text::_path_command { path cmd larg } {
    if {[info commands ::Text::$cmd] ne ""} {
        return [eval [linsert $larg 0 Text::$cmd $path]]
    } else {
        return [eval [linsert $larg 0 $path:cmd $cmd]]
    }
}


proc Text::_trace_variable { path {doSet 0} } {
    Widget::getVariable $path data

    set varName [Widget::getoption $path -textvariable]

    if {$data(varName) eq "" && $varName eq ""} { return }

    set ops [list unset write]
    set cmd [list Text::_handle_variable_trace $path]

    uplevel #0 [list trace remove variable $data(varName) $ops $cmd]

    set data(varName) $varName

    if {$varName ne ""} {
        upvar #0 $varName var

        if {$doSet} {
            set var [$path:cmd get 1.0 end-1c]
        } else {
            if {![info exists var]} { set var "" }

            $path:cmd delete 1.0 end
            $path:cmd insert end $var
        }

        uplevel #0 [list trace add variable $varName $ops $cmd]
    }
}


proc Text::_handle_variable_trace { path name1 name2 op } {
    if {$name2 ne ""} {
        upvar #0 ${name1}($name2) var
    } else {
        upvar #0 $name1 var
    }

    if {$op eq "write"} {
        $path:cmd delete 1.0 end
        $path:cmd insert end $var
    } else {
        set var [$path:cmd get 1.0 end-1c]
    }
}


proc Text::_handle_key_movement { path key } {
    if {[Widget::getoption $path -state] eq "readonly"} {
        switch -- $key {
            "Up"    { set cmd [list yview scroll -1 unit] }
            "Down"  { set cmd [list yview scroll  1 unit] }
            "Left"  { set cmd [list xview scroll -1 unit] }
            "Right" { set cmd [list xview scroll  1 unit] }
            "Prior" { set cmd [list yview scroll -1 page] }
            "Next"  { set cmd [list yview scroll  1 page] }
            "Home"  { set cmd [list yview moveto 0.0] }
            "End"   { set cmd [list yview moveto 1.0] }
        }
        if {[info exists cmd]} {
            eval [list $path:cmd] $cmd
            return -code break
        }
    }
}


proc Text::_destroy { path } {
    Widget::getVariable $path data

    set ops [list unset write]
    set cmd [list Text::_handle_variable_trace $path]

    uplevel #0 [list trace remove variable $data(varName) $ops $cmd]

    Widget::destroy $path
}

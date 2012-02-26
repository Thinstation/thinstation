# ----------------------------------------------------------------------------
#  button.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands
#     - TTKButton::create
#     - TTKButton::configure
#     - TTKButton::cget
#     - TTKButton::invoke
#
#   Private Commands (event bindings)
#     - TTKButton::_destroy
#     - TTKButton::_enter
#     - TTKButton::_leave
#     - TTKButton::_press
#     - TTKButton::_release
#     - TTKButton::_repeat
# ----------------------------------------------------------------------------

namespace eval TTKButton {
    Widget::define TTKButton button DynamicHelp

    Widget::tkinclude TTKButton ttk::button :cmd \
        remove { -class }

    Widget::declare TTKButton {
        {-name                 String     ""      0 }
        {-repeatdelay          Int        0       0 "%d >= 0" }
        {-repeatinterval       Int        0       0 "%d >= 0" }
    }

    if 0 {
        Widget::declare Button {
            {-name                 String     ""      0 }
            {-text                 String     ""      0 }
            {-textvariable         String     ""      0 }
            {-underline            Int        -1      0 "%d >= -1" }
            {-armcommand           String     ""      0 }
            {-disarmcommand        String     ""      0 }
            {-command              String     ""      0 }
            {-state                TkResource ""      0 button }
            {-repeatdelay          Int        0       0 "%d >= 0" }
            {-repeatinterval       Int        0       0 "%d >= 0" }
            {-relief               Enum       raised  0 
                    {raised sunken flat ridge solid groove link}}
            {-image                String     ""      0 }
            {-activeimage          String     ""      0 }
            {-pressedimage         String     ""      0 }
            {-disabledimage        String     ""      0 }
        }

        Widget::syncoptions Button "" :cmd { -text {} -underline {} }
    }

    DynamicHelp::include TTKButton balloon

    variable _current ""
    variable _pressed ""

    #bind BwButton <Enter>           {Button::_enter %W}
    #bind BwButton <Leave>           {Button::_leave %W}
    #bind BwButton <ButtonPress-1>   {Button::_press %W}
    #bind BwButton <ButtonRelease-1> {Button::_release %W}
    #bind BwButton <Key-space>       {Button::invoke %W; break}
    #bind BwButton <Return>          {Button::invoke %W; break}
    #bind BwButton <Destroy>         {Widget::destroy %W}
}


# ----------------------------------------------------------------------------
#  Command TTKButton::create
# ----------------------------------------------------------------------------
proc TTKButton::create { path args } {
    foreach {opt val} $args {
        if {[Widget::optionExists TTKButton $opt]} {
            lappend opts $opt $val
        }
    }

    Widget::initArgs TTKButton $opts maps

    eval [list ttk::button $path] $maps(:cmd)

    Widget::initFromODB TTKButton $path $maps(TTKButton)

    set var [$path cget -textvariable]
    if {![string length $var]} {
        set desc [BWidget::getname [Widget::getoption $path -name]]
        if {[llength $desc]} {
            set text  [lindex $desc 0]
            set under [lindex $desc 1]
            $path configure -text $text -underline $under
        } else {
            set text  [$path cget -text]
            set under [$path cget -underline]
        }
    } else {
        set text  ""
        set under -1
        $path configure -underline $under
    }

    ## Add our binding to pick up <Destroy> events.
    set top [winfo toplevel $path]
    bindtags $path [list $path TButton TTKButton $top all]

    DynamicHelp::sethelp $path $path 1

    return [Widget::create TTKButton $path]
}


# ----------------------------------------------------------------------------
#  Command TTKButton::configure
# ----------------------------------------------------------------------------
proc TTKButton::configure { path args } {
    set oldunder [$path:cmd cget -underline]
    if {$oldunder != -1} {
        set text      [$path:cmd cget -text]
        set oldaccel1 [string tolower [string index $text $oldunder]]
        set oldaccel2 [string toupper $oldaccel1]
    } else {
        set oldaccel1 ""
        set oldaccel2 ""
    }
    set res [Widget::configure $path $args]

    if {[Widget::anyChangedX $path -textvariable -name -text -underline]} {
	set var   [Widget::cget $path -textvariable]
	set text  [Widget::cget $path -text]
	set under [Widget::cget $path -underline]

        if {![string length $var]} {
            set desc [BWidget::getname [Widget::cget $path -name]]
            if {[llength $desc]} {
                set text  [lindex $desc 0]
                set under [lindex $desc 1]
            }
        } else {
            set under -1
            set text  ""
        }
        set top [winfo toplevel $path]
        if {![string equal $oldaccel1 ""]} {
            bind $top <Alt-$oldaccel1> {}
            bind $top <Alt-$oldaccel2> {}
        }
        set accel1 [string tolower [string index $text $under]]
        set accel2 [string toupper $accel1]
        if {![string equal $accel1 ""]} {
            bind $top <Alt-$accel1> [list TTKButton::invoke $path]
            bind $top <Alt-$accel2> [list TTKButton::invoke $path]
        }
        $path:cmd configure -text $text -underline $under -textvariable $var
    }

    DynamicHelp::sethelp $path $path

    return $res
}


# ----------------------------------------------------------------------------
#  Command TTKButton::cget
# ----------------------------------------------------------------------------
proc TTKButton::cget { path option } {
    Widget::cget $path $option
}


proc TTKButton::state { path args } {
    return [uplevel #0 [list $path:cmd state] $args]
}


proc TTKButton::instate { path args } {
    return [uplevel #0 [list $path:cmd instate] $args]
}


proc TTKButton::invoke { path } {
    return [uplevel #0 [list $path:cmd invoke]]
}


# ----------------------------------------------------------------------------
#  Command TTKButton::_enter
# ----------------------------------------------------------------------------
proc TTKButton::_enter { path } {
    variable _current
    variable _pressed

    set _current $path
    if {![string equal [Widget::cget $path -state] "disabled"]} {
        $path:cmd configure -state active
        if {[string equal $_pressed $path]} {
            $path:cmd configure -relief sunken
        } elseif {[string equal [Widget::cget $path -relief] "link"]} {
            $path:cmd configure -relief raised
        }

        set image [Widget::cget $path -activeimage]
        if {[string equal $_pressed $path]} {
            set pressedimage [Widget::cget $path -pressedimage]
            if {![string equal $pressedimage ""]} { set image $pressedimage }
        }
        if {![string equal $image ""]} { $path:cmd configure -image $image }
    }
}


# ----------------------------------------------------------------------------
#  Command TTKButton::_leave
# ----------------------------------------------------------------------------
proc TTKButton::_leave { path } {
    variable _current
    variable _pressed

    set _current ""
    if {[string equal [Widget::cget $path -state] "disabled"]} {
        set dimg [Widget::cget $path -disabledimage]
        if {![string equal $dimg ""]} { $path:cmd configure -state normal }
    } else {
        set relief [Widget::cget $path -relief]
        if {[string equal $_pressed $path]} {
            if {[string equal $relief "link"]} {
                set relief raised
            }
        } elseif {[string equal $relief "link"]} {
            set relief flat
        }

        $path:cmd configure \
            -relief $relief \
            -state  [Widget::cget $path -state] \
            -image  [Widget::cget $path -image]
    }
}


# ----------------------------------------------------------------------------
#  Command TTKButton::_press
# ----------------------------------------------------------------------------
proc TTKButton::_press { path } {
    variable _pressed

    if {![string equal [Widget::cget $path -state] "disabled"]} {
        set _pressed $path
	$path:cmd configure -relief sunken

        set img [Widget::cget $path -pressedimage]
        if {![string equal $img ""]} { $path:cmd configure -image $img }

	set cmd [Widget::getoption $path -armcommand]
        if {![string equal $cmd ""]} {
            uplevel \#0 $cmd
	    set repeatdelay [Widget::getoption $path -repeatdelay]
	    set repeatint [Widget::getoption $path -repeatinterval]
            if {$repeatdelay > 0} {
                after $repeatdelay [list TTKButton::_repeat $path]
            } elseif {$repeatint > 0} {
                after $repeatint [list TTKButton::_repeat $path]
	    }
        }
    }
}


# ----------------------------------------------------------------------------
#  Command TTKButton::_release
# ----------------------------------------------------------------------------
proc TTKButton::_release { path } {
    variable _current
    variable _pressed

    if {[string equal $_pressed $path]} {
        set pressed $_pressed
        set _pressed ""
        set relief [Widget::getoption $path -relief]
	after cancel [list TTKButton::_repeat $path]

        if {[string equal $relief "link"]} {
            set relief raised
        }
        
        set image [Widget::cget $path -image]
        if {[string equal $pressed $path]} {
            set activeimage [Widget::cget $path -activeimage]
            if {![string equal $activeimage ""]} { set image $activeimage }
        }

        $path:cmd configure -relief $relief -image $image

	set cmd [Widget::getoption $path -disarmcommand]
        if {![string equal $cmd ""]} {
            uplevel \#0 $cmd
        }

        if {[string equal $_current $path] &&
             ![string equal [Widget::cget $path -state] "disabled"] && \
	     [set cmd [Widget::getoption $path -command]] != ""} {
            uplevel \#0 $cmd
        }
    }
}


# ----------------------------------------------------------------------------
#  Command TTKButton::_repeat
# ----------------------------------------------------------------------------
proc TTKButton::_repeat { path } {
    variable _current
    variable _pressed

    if {$_current == $path && $_pressed == $path &&
         ![string equal [Widget::cget $path -state] "disabled"] &&
         [set cmd [Widget::getoption $path -armcommand]] != ""} {
        uplevel \#0 $cmd
    }
    if { $_pressed == $path &&
         ([set delay [Widget::getoption $path -repeatinterval]] >0 ||
          [set delay [Widget::getoption $path -repeatdelay]] > 0) } {
        after $delay [list TTKButton::_repeat $path]
    }
}

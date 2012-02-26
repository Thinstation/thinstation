# ----------------------------------------------------------------------------
#  button.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands
#     - Button::create
#     - Button::configure
#     - Button::cget
#     - Button::invoke
#
#   Private Commands (event bindings)
#     - Button::_destroy
#     - Button::_enter
#     - Button::_leave
#     - Button::_press
#     - Button::_release
#     - Button::_repeat
# ----------------------------------------------------------------------------

namespace eval Button {
    if {[BWidget::using ttk]} {
        Widget::define Button button TTKButton DynamicHelp
    } else {
        Widget::define Button button DynamicHelp
    }

    set remove [list -command -relief -text -textvariable \
        -underline -image -state]
    if {[info tclversion] > 8.3} {
        lappend remove -repeatdelay -repeatinterval
    }

    Widget::tkinclude Button button :cmd remove $remove

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

    Widget::addmap Button "" :cmd { -text {} -underline {} }

    DynamicHelp::include Button balloon

    variable _current ""
    variable _pressed ""

    bind BwButton <Enter>           {Button::_enter %W}
    bind BwButton <Leave>           {Button::_leave %W}
    bind BwButton <ButtonPress-1>   {Button::_press %W}
    bind BwButton <ButtonRelease-1> {Button::_release %W}
    bind BwButton <Key-space>       {Button::invoke %W; break}
    bind BwButton <Return>          {Button::invoke %W; break}
    bind BwButton <Destroy>         {Widget::destroy %W}
}


# ----------------------------------------------------------------------------
#  Command Button::create
# ----------------------------------------------------------------------------
proc Button::create { path args } {
    if {[BWidget::using ttk]} {
        return [eval [list TTKButton::create $path] $args]
    }

    Widget::initArgs Button $args maps

    eval [list button $path] $maps(:cmd)

    Widget::initFromODB Button $path $maps(Button)

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

    # Do some extra configuration on the button
    set relief [Widget::getoption $path -relief]
    if {[string equal $relief "link"]} { set relief flat }

    set opts [list]
    lappend opts -text $text -underline $under -textvariable $var
    lappend opts -relief $relief -state [Widget::cget $path -state]
    lappend opts -image [Widget::cget $path -image]

    eval [list $path configure] $opts

    set top [winfo toplevel $path]
    bindtags $path [list $path BwButton $top all]

    set accel1 [string tolower [string index $text $under]]
    set accel2 [string toupper $accel1]
    if {[string length $accel1]} {
        bind $top <Alt-$accel1> [list Button::invoke $path]
        bind $top <Alt-$accel2> [list Button::invoke $path]
    }

    DynamicHelp::sethelp $path $path 1

    return [Widget::create Button $path]
}


# ----------------------------------------------------------------------------
#  Command Button::configure
# ----------------------------------------------------------------------------
proc Button::configure { path args } {
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

    if {[Widget::anyChangedX $path -relief -state]} {
        set state  [Widget::cget $path -state]
        set relief [Widget::cget $path -relief]
        if {[string equal $relief "link"]} {
            if {[string equal $state "active"]} {
                set relief "raised"
            } else {
                set relief "flat"
            }
        }

        $path:cmd configure -relief $relief

        set dimg [Widget::cget $path -disabledimage]
        if {[string equal $state "disabled"] && ![string equal $dimg ""]} {
            $path:cmd configure -image $dimg
        } else {
            $path:cmd configure \
                -state      $state \
                -image      [Widget::cget $path -image] \
                -background [Widget::cget $path -background] \
                -foreground [Widget::cget $path -foreground]
        }
    }

    if {[Widget::hasChanged $path -image image]} {
        $path:cmd configure -image $image
    }

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
            bind $top <Alt-$accel1> [list Button::invoke $path]
            bind $top <Alt-$accel2> [list Button::invoke $path]
        }
        $path:cmd configure -text $text -underline $under -textvariable $var
    }

    DynamicHelp::sethelp $path $path

    return $res
}


# ----------------------------------------------------------------------------
#  Command Button::cget
# ----------------------------------------------------------------------------
proc Button::cget { path option } {
    Widget::cget $path $option
}


# ----------------------------------------------------------------------------
#  Command Button::invoke
# ----------------------------------------------------------------------------
proc Button::invoke { path } {
    if {[string equal [Widget::cget $path -state] "disabled"]} { return }

    $path:cmd configure -state active -relief sunken
    update idletasks

    set cmd [Widget::getoption $path -armcommand]
    if {![string equal $cmd ""]} {
        uplevel \#0 $cmd
    }
    after 100
    set relief [Widget::getoption $path -relief]
    if {[string equal $relief "link"]} {
        set relief flat
    }
    $path:cmd configure \
        -state  [Widget::getoption $path -state] \
        -relief $relief
    set cmd [Widget::getoption $path -disarmcommand]
    if {![string equal $cmd ""]} {
        uplevel \#0 $cmd
    }
    set cmd [Widget::getoption $path -command]
    if {![string equal $cmd ""]} {
        uplevel \#0 $cmd
    }
}


# ----------------------------------------------------------------------------
#  Command Button::_enter
# ----------------------------------------------------------------------------
proc Button::_enter { path } {
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
#  Command Button::_leave
# ----------------------------------------------------------------------------
proc Button::_leave { path } {
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
#  Command Button::_press
# ----------------------------------------------------------------------------
proc Button::_press { path } {
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
                after $repeatdelay "Button::_repeat $path"
            } elseif {$repeatint > 0} {
                after $repeatint "Button::_repeat $path"
	    }
        }
    }
}


# ----------------------------------------------------------------------------
#  Command Button::_release
# ----------------------------------------------------------------------------
proc Button::_release { path } {
    variable _current
    variable _pressed

    if {[string equal $_pressed $path]} {
        set pressed $_pressed
        set _pressed ""
        set relief [Widget::getoption $path -relief]
	after cancel "Button::_repeat $path"

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
#  Command Button::_repeat
# ----------------------------------------------------------------------------
proc Button::_repeat { path } {
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
        after $delay "Button::_repeat $path"
    }
}

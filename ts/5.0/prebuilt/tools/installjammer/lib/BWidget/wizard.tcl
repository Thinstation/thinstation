# ------------------------------------------------------------------------------
#  wizard.tcl
#
# ------------------------------------------------------------------------------
#  Index of commands:
#
#   Public commands
#     - Wizard::create
#     - Wizard::configure
#     - Wizard::cget
#
#   Private commands
#     - Wizard::_destroy
# ------------------------------------------------------------------------------

namespace eval Wizard {
    Widget::define Wizard wizard ButtonBox Separator

    namespace eval Step {
	Widget::declare Wizard::Step {
            {-background      Color2     ""       0  }
            {-backgroundimage String     ""       0  }
            {-type            String     "step"   1  }
	    {-data            String     ""       0  }
	    {-title           String     ""       0  }
	    {-default         String     "next"   0  }

	    {-text1           String     ""       0  }
	    {-text2           String     ""       0  }
	    {-text3           String     ""       0  }
	    {-text4           String     ""       0  }
	    {-text5           String     ""       0  }

	    {-icon            String     ""       0  }
	    {-image           String     ""       0  }

	    {-bitmap          String     ""       0  }
	    {-iconbitmap      String     ""       0  }

            {-createstep      Boolean2    ""      1  }
            {-appendorder     Boolean    "1"      0  }

            {-nexttext        String     ""       0  }
            {-backtext        String     ""       0  }
            {-helptext        String     ""       0  }
            {-canceltext      String     ""       0  }
            {-finishtext      String     ""       0  }
            {-separatortext   String     ""       0  }

            {-separator       Boolean2   ""       0  }

            {-command         String     ""       0  }

            {-createcommand   String     ""       0  }
            {-raisecommand    String     ""       0  }
	    {-nextcommand     String     ""       0  }
	    {-backcommand     String     ""       0  }
	    {-helpcommand     String     ""       0  }
	    {-cancelcommand   String     ""       0  }
	    {-finishcommand   String     ""       0  }

            {-compoundraise   Boolean    "1"      0  }
            {-compoundcreate  Boolean    "1"      0  }

            {-bg              Synonym    -background }
	}
    }

    namespace eval Branch {
	Widget::declare Wizard::Branch {
            {-type            String     "branch" 1  }
            {-command         String     ""       0  }
            {-action          Enum       "merge"  0  {merge terminate} }
        }
    }

    namespace eval Widget {
	Widget::declare Wizard::Widget {
            {-type            String     "widget" 1  }
            {-step            String     ""       1  }
            {-widget          String     ""       1  }
	}
    }

    namespace eval layout {}

    Widget::tkinclude Wizard frame :cmd \
    	include    { -background -foreground -cursor }

    Widget::declare Wizard {
   	{-type            Enum       "dialog" 1 {dialog frame} }
   	{-width           TkResource "0"      0 frame}
	{-height          TkResource "0"      0 frame}
   	{-minwidth        Int        "475"    0 "%d >= 0"}
	{-minheight       Int        "350"    0 "%d >= 0"}
	{-relief          TkResource "flat"   0 frame}
	{-borderwidth     TkResource "0"      0 frame}
	{-background      Color      "SystemButtonFace" 0}
	{-foreground      String     "#000000" 0      }
        {-backgroundimage String     ""       0      }
	{-title           String     "Wizard" 0      }
	{-createstep      Boolean    "0"      0      }

        {-showbuttons     Boolean    "1"      1      }
	{-autobuttons     Boolean    "1"      0      }
	{-helpbutton      Boolean    "0"      1      }
	{-finishbutton    Boolean    "0"      1      }
        {-resizable       String     "0 0"    0      }
	{-separator       Boolean    "1"      1      }
        {-parent          String     "."      1      }
        {-transient       Boolean    "1"      1      }
        {-place           Enum       "center" 1
                                     {none center left right above below} }

        {-icon            String     ""       0      }
        {-image           String     ""       0      }

	{-bitmap          String     ""       0      }
	{-iconbitmap      String     ""       0      }

        {-raisecommand    String     ""       0      }
        {-createcommand   String     ""       0      }

	{-buttonwidth     Int        "12"     0      }
        {-nexttext        String     "Next >" 0      }
        {-backtext        String     "< Back" 0      }
        {-helptext        String     "Help"   0      }
        {-canceltext      String     "Cancel" 0      }
        {-finishtext      String     "Finish" 0      }
        {-separatortext   String     ""       0      }

        {-fg              Synonym    -foreground     }
        {-bg              Synonym    -background     }
        {-bd              Synonym    -borderwidth    }
    }

    image create photo Wizard::none

    style layout ImageFrame {Label.label -sticky nesw}

    Widget::addmap Wizard "" :cmd { -background {} -relief {} -borderwidth {} }

    bind Wizard <Destroy> [list Wizard::_destroy %W]
}


# ------------------------------------------------------------------------------
#  Command Wizard::create
# ------------------------------------------------------------------------------
proc Wizard::create { path args } {
    Widget::initArgs Wizard $args maps

    Widget::initFromODB Wizard $path $maps(Wizard)

    Widget::getVariable $path data
    Widget::getVariable $path branches

    array set data {
        steps   ""
        buttons ""
        order   ""
	current ""
    }

    array set branches {
        root    ""
    }

    set frame $path

    set type [Widget::getoption $path -type]

    if {[string equal $type "dialog"]} {
        set top $path
        eval [list toplevel $path -bg $::BWidget::colors(SystemButtonFace)] \
            $maps(:cmd) -class Wizard
        wm withdraw   $path
        update idletasks
        wm protocol   $path WM_DELETE_WINDOW [list $path cancel 1]
        if {[Widget::getoption $path -transient]} {
	    wm transient  $path [Widget::getoption $path -parent]
        }
        eval wm resizable $path [Widget::getoption $path -resizable]

	set minwidth  [Widget::getoption $path -minwidth]
	set minheight [Widget::getoption $path -minheight]
	wm minsize $path $minwidth $minheight

        set width  [Widget::cget $path -width]
        set height [Widget::cget $path -height]
	if {$width > 0 && $height > 0} {
	    wm geometry $top ${width}x${height}
	}

        bind $path <Escape>         [list $path cancel]
        bind $path <<WizardFinish>> [list destroy $path]
        bind $path <<WizardCancel>> [list destroy $path]
    } else {
        set top [winfo toplevel $path]
        eval [list frame $path] $maps(:cmd) -class Wizard
    }

    wm title $top [Widget::getoption $path -title]

    grid rowconfigure    $top 0 -weight 1
    grid columnconfigure $top 0 -weight 1

    frame $path.steps
    grid  $path.steps -row 0 -column 0 -sticky news

    grid rowconfigure    $path.steps 0 -weight 1
    grid columnconfigure $path.steps 0 -weight 1

    widget $path set steps -widget $path.steps

    if {[Widget::getoption $path -separator]} {
        frame $path.separator
        grid  $path.separator -row 1 -column 0 -sticky ew -pady [list 5 0]

        grid columnconfigure $path.separator 1 -weight 1

        set text [Widget::getoption $path -separatortext]

        if {[BWidget::using ttk]} {
            ttk::label $path.separator.l -state disabled -text $text
        } else {
            label $path.separator.l -bd 0 -pady 0 -state disabled -text $text
        }

        grid  $path.separator.l -row 0 -column 0 -sticky w -padx 2

        Separator $path.separator.s -orient horizontal
        grid $path.separator.s -row 0 -column 1 -sticky ew \
            -padx [list 0 5] -pady 4

	widget $path set separator      -widget $path.separator.s
	widget $path set separatortext  -widget $path.separator.l
	widget $path set separatorframe -widget $path.separator
    }

    if {[Widget::getoption $path -showbuttons]} {
        ButtonBox $path.buttons -spacing 2 -homogeneous 1
        grid $path.buttons -row 2 -column 0 -sticky e -padx 5 -pady {10 5}

        widget $path set buttons -widget $path.buttons

        Wizard::insert $path button end back -text "< Back" \
            -command [list $path back 1] \
            -width [Widget::getoption $path -buttonwidth]
        Wizard::insert $path button end next -text "Next >" \
            -command [list $path next 1]
        if {[Widget::getoption $path -finishbutton]} {
            Wizard::insert $path button end finish -text "Finish" \
                -command [list $path finish 1]
        }
        Wizard::insert $path button end cancel -text "Cancel" \
            -command [list $path cancel 1] -spacing 10

        if {[Widget::getoption $path -helpbutton]} {
            Wizard::insert $path button 0 help -text "Help" \
                -command [list $path help 1] -spacing 10
        }
    }

    return [Widget::create Wizard $path]
}


# ------------------------------------------------------------------------------
#  Command Wizard::configure
# ------------------------------------------------------------------------------
proc Wizard::configure { path args } {
    set res [Widget::configure $path $args]

    if {[Widget::hasChanged $path -title title]} {
	wm title [winfo toplevel $path] $title
    }

    if {[Widget::hasChanged $path -resizable resize]} {
	eval wm resizable [winfo toplevel $path] $resize
    }

    if {[Widget::getoption $path -separator]
        && [Widget::hasChanged $path -separatortext text]} {
        set text [Wizard::getoption $path [Wizard::raise $path] -separatortext]
        Wizard::itemconfigure $path separatortext -text $text
    }

    if {[Widget::anyChangedX $path -width -height -minwidth -minheight]} {
        set type    [Widget::getoption $path -type]
        set width   [Widget::cget $path -width]
        set height  [Widget::cget $path -height]
	set mwidth  [Widget::getoption $path -minwidth]
	set mheight [Widget::getoption $path -minheight]

        if {[string equal $type "dialog"]} {
	    wm minsize $path $mwidth $mheight

	    if {$width > 0 && $height > 0} {
		wm geometry $top ${width}x${height}
	    }

        } else {
            $path:cmd configure -width $width -height $height
        }
    }

    return $res
}


# ------------------------------------------------------------------------------
#  Command Wizard::cget
# ------------------------------------------------------------------------------
proc Wizard::cget { path option } {
    return [Widget::cget $path $option]
}


proc Wizard::itemcget { path item option } {
    Widget::getVariable $path items
    Widget::getVariable $path steps
    Widget::getVariable $path buttons
    Widget::getVariable $path widgets

    if {[Wizard::_is_step $path $item]} {
        ## It's a step.
        return [Widget::cget $items($item) $option]
    }

    if {[Wizard::_is_branch $path $item]} {
        ## It's a branch.
        return [Widget::cget $items($item) $option]
    }

    if {[Wizard::_is_button $path $item]} {
        ## It's a button.
        return [$path.buttons itemcget $items($item) $option]
    }

    if {[Wizard::_is_widget $path $item]} {
	## It's a widget.
	return [eval [$path widget get $item] cget $option] 
    }

    return -code error "item \"$item\" does not exist"
}


proc Wizard::itemconfigure { path item args } {
    Widget::getVariable $path items
    Widget::getVariable $path steps
    Widget::getVariable $path buttons

    if {[Wizard::_is_step $path $item]} {
        ## It's a step.
        set i $items($item)
        set res [Widget::configure $i $args]

	## Do some more configuration if the step we're configuring
	## is the step that is currently raised.
	if {$item eq [Wizard::step $path current]} {
	    if {[Widget::hasChanged $i -title title]} {
		set title [Wizard::getoption $path $item -title]
		wm title [winfo toplevel $path] $title
	    }

            if {[winfo exists $path.separator]} {
                if {[Widget::getoption $path -separator]
                    && [Widget::hasChanged $i -separator separator]} {
                    if {[Wizard::getoption $path $item -separator]} {
                        grid $path.separator.s
                    } else {
                        grid remove $path.separator.s
                    }
                }

                if {[Widget::getoption $path -separator]
                    && [Widget::hasChanged $i -separatortext text]} {
                    set text [Wizard::getoption $path $item -separatortext]
                    Wizard::itemconfigure $path separatortext -text $text
                }
            }

	    set x [list -nexttext -backtext -canceltext -helptext -finishtext]
            if {[eval [list Widget::anyChangedX $path] $x]} {
                Wizard::adjustbuttons $path
            }
	}

	return $res
    }

    if {[Wizard::_is_branch $path $item]} {
        ## It's a branch.
        return [Widget::configure $items($item) $args]
    }

    if {[Wizard::_is_button $path $item]} {
        ## It's a button.
        return [eval $path.buttons itemconfigure [list $items($item)] $args]
    }

    if {[Wizard::_is_widget $path $item]} {
        ## It's a widget.
	return [eval [Wizard::widget $path get $item] configure $args] 
    }

    return -code error "item \"$item\" does not exist"
}


proc Wizard::show { path } {
    wm deiconify [winfo toplevel $path]
}


proc Wizard::hide { path } {
    wm withdraw [winfo toplevel $path]
}


proc Wizard::invoke { path button } {
    Widget::getVariable $path buttons
    if {![info exists buttons($button)]} {
        return -code error "button \"$button\" does not exist"
    }
    [Wizard::widget $path get $button] invoke
}


proc Wizard::insert { path type idx args } {
    switch -- $type {
        "button" {
            set node [lindex $args 0]
            set node [Widget::nextIndex $path $node]
            set args [lreplace $args 0 0 $node]
        }

        "step" - "branch" {
            set node   [lindex $args 1]
            set branch [lindex $args 0]
            set node   [Widget::nextIndex $path $node]
            set args   [lreplace $args 1 1 $node]

            if {![Wizard::_is_branch $path $branch]} {
                return -code error "branch \"$branch\" does not exist"
            }
	}

	default {
	    set types [list button branch step]
	    set err [BWidget::badOptionString option $type $types]
	    return -code error $err
	}
    }

    if {[Wizard::exists $path $node]} {
        return -code error "item \"$node\" already exists"
    }

    eval _insert_$type $path $idx $args

    return $node
}


proc Wizard::delete { path args } {
    Widget::getVariable $path data
    Widget::getVariable $path items
    Widget::getVariable $path steps
    Widget::getVariable $path buttons
    Widget::getVariable $path widgets
    Widget::getVariable $path branches

    set step [Wizard::step $path current]
    foreach item $args {
        set item [Wizard::step $path $item]
        if {![string length $item]} { continue }

        if {[Wizard::_is_step $path $item]} {
            ## It's a step

            set branch [Wizard::branch $path $item]
            set x [lsearch -exact $branches($branch) $item]
            set branches($branch) [lreplace $branches($branch) $x $x]

            destroy $widgets($item)

            Widget::destroy $items($item) 0

            unset steps($item)
            unset data($item,branch)
            unset items($item)
            unset widgets($item)

            if {[info exists data($item,realized)]} {
                unset data($item,realized)
            }

            if {$item eq $step} { set data(current) "" }
        }

        if {[Wizard::_is_branch $path $item]} {
            ## It's a branch

            set branch [Wizard::branch $path $item]
            set x [lsearch -exact $branches($branch) $item]
            set branches($branch) [lreplace $branches($branch) $x $x]

            Widget::destroy $items($item) 0

            unset branches($item)
            unset data($item,branch)
            unset items($item)
        }

        if {[info exists buttons($item)]} {
            ## It's a button

            set x [$path.buttons index $widgets($item)]
            $path.buttons delete $x

            unset items($item)
            unset buttons($item)
            unset widgets($item)
        }
    }
}


proc Wizard::back { path {generateEvent 0} {executeCommand 1} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set step [Wizard::raise $path]

    if {$executeCommand && [string length $step]} {
        set cmd [Widget::getoption $items($step) -backcommand]
        if {![_eval_command $path $cmd]} { return }
    }

    ## The -backcommand could have decided to move us
    ## somewhere else in the wizard.  If we're not on
    ## the same step we were before the command, stop.
    if {$step ne [Wizard::raise $path]} { return }

    set idx [lsearch -exact $data(order) $step]
    if {$idx < 0} {
        set item [lindex $data(order) end]
    } else {
        set item [lindex $data(order) [expr {$idx - 1}]]
        set data(order) [lreplace $data(order) $idx end]
    }

    Wizard::raise $path $item $generateEvent

    if {$generateEvent} { event generate $path <<WizardBack>> }

    return $item
}


proc Wizard::next { path {generateEvent 0} {executeCommand 1} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set step [Wizard::raise $path]

    if {$executeCommand && [string length $step]} {
        set cmd [Widget::getoption $items($step) -nextcommand]
        if {![_eval_command $path $cmd]} { return }
    }

    ## The -nextcommand could have decided to move us
    ## somewhere else in the wizard.  If we're not on
    ## the same step we were before the command, stop.
    if {$step ne [Wizard::raise $path]} { return }

    set item [Wizard::step $path next]
    if {![string length $item]} { return }

    if {[Widget::getoption $items($item) -appendorder]} {
	lappend data(order) $item
    }

    Wizard::raise $path $item $generateEvent

    if {$generateEvent} { event generate $path <<WizardNext>> }

    return $item
}


proc Wizard::cancel { path {generateEvent 0} {executeCommand 1} } {
    Widget::getVariable $path items

    set step [Wizard::raise $path]

    if {$executeCommand && [string length $step]} {
        set cmd [Widget::getoption $items($step) -cancelcommand]
        if {![_eval_command $path $cmd]} { return }
    }

    if {$generateEvent} { event generate $path <<WizardCancel>> }
}


proc Wizard::finish { path {generateEvent 0} {executeCommand 1} } {
    Widget::getVariable $path items

    set step [Wizard::raise $path]

    if {$executeCommand && [string length $step]} {
        set cmd [Widget::getoption $items($step) -finishcommand]
        if {![_eval_command $path $cmd]} { return }
    }
        
    if {$generateEvent} { event generate $path <<WizardFinish>> }
}


proc Wizard::help { path {generateEvent 0} {executeCommand 1} } {
    Widget::getVariable $path items

    set step [Wizard::raise $path]

    if {$executeCommand && [string length $step]} {
        set cmd [Widget::getoption $items($step) -helpcommand]
        if {![_eval_command $path $cmd]} { return }
    }
        
    if {$generateEvent} { event generate $path <<WizardHelp>> }
}


proc Wizard::order { path args } {
    Widget::getVariable $path data
    if {[llength $args] > 1} {
        set err [BWidget::wrongNumArgsString "$path order ?neworder?"]
        return -code error $err
    }
    if {[llength $args]} { set data(order) [lindex $args 0] }
    return $data(order)
}


proc Wizard::step { path node {start ""} {traverse 1} } {
    Widget::getVariable $path data
    Widget::getVariable $path items
    Widget::getVariable $path branches

    if {[string length $start] && ![info exists items($start)]} {
        return -code error "item \"$start\" does not exist"
    }

    switch -- $node {
        "current" {
            set item [Wizard::raise $path]
        }

        "end" - "last" {
            ## Keep looping through 'next' until we hit the end.
            set item [Wizard::step $path next]
            while {[string length $item]} {
                set last $item
                set item [Wizard::step $path next $item] 
            }
            set item $last
        }

        "back" - "previous" {
            if {![string length $start]} { set start [Wizard::raise $path] }

            set idx [lsearch -exact $data(order) $start]
            if {$idx < 0} {
                set item [lindex $data(order) end]
            } else {
                incr idx -1
                if {$idx < 0} { return }
                set item [lindex $data(order) $idx]
            }
        }

        "next" {
            if {[string length $start]} {
                set step $start
            } else {
                set step [Wizard::raise $path]
            }

            set branch [Wizard::branch $path $step]
            if {$traverse && [Wizard::_is_branch $path $step]} {
                ## This step is a branch.  Let's figure out where to go next.
                if {[Wizard::traverse $path $step]} {
                    ## It's ok to traverse into this branch.
                    set branch $step
                }
            }

            set idx [expr {[lsearch -exact $branches($branch) $step] + 1}]

            if {$idx >= [llength $branches($branch)]} {
                ## We've reached the end of this branch.
                ## If it's the root branch or this branch terminates we return.
                if {$branch eq "root"
                    || [Widget::getoption $items($branch) -action]
                        eq "terminate"} {
                    return
                }

                ## We want to merge back with our parent branch.
                set item [Wizard::step $path next $branch 0]
            } else {
                set item [lindex $branches($branch) $idx]

                ## If this step is a branch, find the next step after it.
                if {[Wizard::_is_branch $path $item]} {
                    if {$traverse} {
                        set item [Wizard::step $path next $item]
                    }
                } else {
                    ## Check the -command of this step and see if
                    ## we want to display it.  If not skip ahead.
                    if {![Wizard::traverse $path $item]} {
                        set item [Wizard::step $path next $item]
                    }
                }
            }
        }

        default {
            set item ""

            ## If this node is a branch, we want to keep
            ## looking util we find the next available step.
            if {[Wizard::_is_branch $path $node]} {
                return [Wizard::step $path next $node]
            }

            if {[Wizard::_is_step $path $node]} { set item $node }
        }
    }

    return $item
}


proc Wizard::nodes { path branch {first ""} {last ""} } {
    Widget::getVariable $path data
    Widget::getVariable $path branches
    if {![string length $first]} { return $branches($branch) }
    if {![string length $last]}  { return [lindex $branches($branch) $first] }
    return [lrange $branches($branch) $first $last]
}


proc Wizard::index { path item } {
    Widget::getVariable $path branches
    set item   [$path step $item]
    set branch [$path branch $item]
    return [lsearch -exact $branches($branch) $item]
}


proc Wizard::raise { path {item ""} {generateEvent 0} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set steps   $path.steps
    set buttons $path.buttons

    if {[string equal $item ""]} { return $data(current) }

    set x $item
    set curr $data(current)
    set item [Wizard::step $path $item]

    if {![string length $item]} {
        return -code error "step \"$x\" does not exist"
    }

    if {[string equal $item $data(current)]} { return }

    Wizard::createstep $path $item

    ## Eval the global raisecommand.
    if {[Widget::getoption $items($item) -compoundraise]} {
        set cmd [Widget::getoption $path -raisecommand]
        Wizard::_eval_command $path $cmd $item
    }

    ## If the $data(current) does not equal $curr, it means
    ## that the -raisecommand has moved us to another pane
    ## before finishing this action.  We need to stop.
    if {$data(current) ne $curr} { return $data(current) }

    ## Eval this item's raisecommand.
    set cmd [Widget::getoption $items($item) -raisecommand]
    Wizard::_eval_command $path $cmd $item

    ## If the $data(current) does not equal $curr, it means
    ## that the -raisecommand has moved us to another pane
    ## before finishing this action.  We need to stop.
    if {$data(current) ne $curr} { return $data(current) }

    wm title [winfo toplevel $path] [Wizard::getoption $path $item -title]

    if {[winfo exists $path.separator]} {
        if {[Wizard::getoption $path $item -separator]} {
            grid $path.separator.s
            set text [Wizard::getoption $path $item -separatortext]
            $path itemconfigure separatortext -text $text
        } else {
            grid remove $path.separator.s
            $path itemconfigure separatortext -text ""
        }
    }

    if {[winfo exists $path.buttons]} {
        set default [Widget::getoption $items($item) -default]
        set button  [lsearch -exact $data(buttons) $default]
        $buttons setfocus $button
    }

    if {[string length $data(current)]} {
        grid remove $steps.f$data(current)
    }

    set data(current) $item

    grid $steps.f$data(current) -row 0 -column 0 -sticky news

    set back [Wizard::step $path back]
    set next [Wizard::step $path next]

    if {[Widget::getoption $path -autobuttons]} { Wizard::adjustbuttons $path }

    set bgimage [Wizard::getoption $path $item -backgroundimage]
    if {$bgimage ne ""} {
        $steps.f$item configure -image $bgimage
    }

    if {$generateEvent} {
        if {$back eq ""} { event generate $path <<WizardFirstStep>> }
        if {$next eq ""} { event generate $path <<WizardLastStep>> }
        event generate $path <<WizardStep>>
    }

    return $item
}


proc Wizard::adjustbuttons { path } {
    Widget::getVariable $path items

    if {![Widget::getoption $path -showbuttons]} { return }

    set item [Wizard::step $path current]
    if {[string equal $item ""]} { return }

    set back [Wizard::step $path back]
    set next [Wizard::step $path next]

    foreach x [list back next cancel] {
        set text [Wizard::getoption $path $item -${x}text]
        $path itemconfigure $x -text $text -state normal
    }

    if {[Widget::getoption $path -helpbutton]} {
        set text [Wizard::getoption $path $item -helptext]
	$path itemconfigure help -text $text
    }

    if {[Widget::getoption $path -finishbutton]} {
        set text [Wizard::getoption $path $item -finishtext]
	$path itemconfigure finish -text $text -state disabled
    }

    if {[string equal $back ""]} {
	$path itemconfigure back -state disabled
    }

    if {[string equal $next ""]} {
	if {[Widget::getoption $path -finishbutton]} {
	    $path itemconfigure next   -state disabled
	    $path itemconfigure finish -state normal
	} else {
            set text [Wizard::getoption $path $item -finishtext]
	    $path itemconfigure next -text $text -command [list $path finish 1]
	}
	$path itemconfigure back   -state disabled
	$path itemconfigure cancel -state disabled
    } else {
        set text [Wizard::getoption $path $item -nexttext]
	$path itemconfigure next -text $text -command [list $path next 1]
    }
}


proc Wizard::widget { path command args } {
    return [eval [list Wizard::widgets $path $command] $args]
}


proc Wizard::widgets { path command args } {
    Widget::getVariable $path items
    Widget::getVariable $path widgets
    Widget::getVariable $path stepWidgets

    switch -- $command {
	"set" {
	    set node [lindex $args 0]
	    if {[string equal $node ""]} {
                set str "$path widget set <name> ?option ..?"
		set err [BWidget::wrongNumArgsString $str]
		return -code error $err
	    }
	    set args [lreplace $args 0 0]
	    set item $path.#widget#$node

	    Widget::init Wizard::Widget $item $args
	    set step   [Widget::getoption $item -step]
	    set widget [Widget::getoption $item -widget]
            set items($node) $item
	    if {[string equal $step ""]} {
		set widgets($node) $widget
	    } else {
		set stepWidgets($step,$node) $widget
	    }
	    return $widget
	}

	"get" {
	    set widget [lindex $args 0]
            if {[string equal [string index $widget 0] "-"]} {
                set widget ""
            } else {
                set args [lreplace $args 0 0]
            }

	    array set map  [list Wizard::Widget {}]
	    array set map  [Widget::parseArgs Wizard::Widget $args]
	    array set data $map(Wizard::Widget)

	    if {[info exists data(-step)]} {
	    	set step $data(-step)

                ## If we weren't given a widget, just return a
                ## list of all the widgets in this step.
                if {[string equal $widget ""]} {
                    set list [list]
                    foreach name [array names stepWidgets $step,*] {
                        set x [lrange [split $name ,] 1 end]
                        lappend list [eval join $x ,]
                    }
                    return $list
                }
	    } else {
                ## If we weren't given a widget, just return all
                ## of the global widgets.
                if {[string equal $widget ""]} {
                    return [array names widgets]
                }

		set step [$path step current]
	    }

	    ## If a widget exists for this step, return it.
	    if {[info exists stepWidgets($step,$widget)]} {
		return $stepWidgets($step,$widget)
	    }

	    ## See if a widget exists on the global level.
	    if {![info exists widgets($widget)]} {
		return -code error "item \"$widget\" does not exist"
	    }

	    return $widgets($widget)
	}

	default {
	    set err [BWidget::badOptionString option $command [list get set]]
	    return -code error $err
	}
    }
}


proc Wizard::variable { path step option } {
    set item [step $path $step]
    if {[string equal $item ""]} {
        return -code error "item \"$step\" does not exist"
    }
    set item $path.$item
    return [Widget::varForOption $item $option]
}


proc Wizard::branch { path {node "current"} } {
    Widget::getVariable $path data

    if {[_is_branch $path $node]} { return $data($node,branch) }

    set node [$path step $node]
    if {[string equal $node ""]} { return "root" }
    if {[info exists data($node,branch)]} { return $data($node,branch) }
    return -code error "item \"$node\" does not exist"
}


proc Wizard::traverse { path node } {
    Widget::getVariable $path items

    if {$node eq "root"} { return 1 }

    if {![info exists items($node)]} {
        return -code error "node \"$node\" does not exist"
    }

    set cmd [Widget::getoption $items($node) -command]
    return [_eval_command $path $cmd]
}


proc Wizard::exists { path item } {
    Widget::getVariable $path items
    return [info exists items($item)]
}


proc Wizard::createstep { path item {delete 0} } {
    Widget::getVariable $path data
    Widget::getVariable $path items

    set item [Wizard::step $path $item]

    if {![Wizard::_is_step $path $item]} { return }

    if {$delete} {
        if {[winfo exists $path.f$item]} {
            destroy $path.f$item
        }
        if {[info exists data($item,realized)]} {
            unset data($item,realized)
        }
    }

    if {![info exists data($item,realized)]} {
        set data($item,realized) 1

        if {[Widget::getoption $items($item) -compoundcreate]} {
            ## Eval the global createcommand.
            set cmd [Widget::getoption $path -createcommand]
            _eval_command $path $cmd $item
        }

        ## Eval this item's createcommand.
        set cmd [Widget::getoption $items($item) -createcommand]
        _eval_command $path $cmd $item
    }

    return $item
}


proc Wizard::getoption { path item option } {
    Widget::getVariable $path items
    set step [Wizard::step $path $item]
    if {![string length $step]} {
        return -code error "item \"$item\" does not exist"
    }
    return [Widget::cgetOption $option "" $items($step) $path]
}


proc Wizard::reorder { path parent nodes } {
    Widget::getVariable $path branches
    set branches($parent) $nodes
    if {[Widget::getoption $path -autobuttons]} { Wizard::adjustbuttons $path }
}


proc Wizard::_insert_button { path idx node args } {
    Widget::getVariable $path data
    Widget::getVariable $path items
    Widget::getVariable $path buttons
    Widget::getVariable $path widgets

    set buttons($node) 1
    set widgets($node) [eval $path.buttons insert $idx $args]
    set item   [string map [list $path.buttons.b {}] $widgets($node)]
    set items($node) $item
    return $widgets($node)
}


proc Wizard::_insert_step { path idx branch node args } {
    Widget::getVariable $path data
    Widget::getVariable $path steps
    Widget::getVariable $path items
    Widget::getVariable $path widgets
    Widget::getVariable $path branches

    set steps($node) 1
    set data($node,branch) $branch
    if {$idx eq "end"} {
        lappend branches($branch) $node
    } else {
	set branches($branch) [linsert $branches($branch) $idx $node]
    }

    Widget::init Wizard::Step $path.$node $args

    set items($node) $path.$node
    set bgcolor [Wizard::getoption $path $node -background]

    set widgets($node) $path.steps.f$node
    ttk::label $widgets($node) -background $bgcolor -style ImageFrame

    if {[getoption $path $node -createstep]} { Wizard::createstep $path $node }

    if {[Widget::getoption $path -autobuttons]} { Wizard::adjustbuttons $path }

    return $widgets($node)
}


proc Wizard::_insert_branch { path idx branch node args } {
    Widget::getVariable $path data
    Widget::getVariable $path items
    Widget::getVariable $path branches

    set branches($node)    [list]
    set data($node,branch) $branch
    if {$idx eq "end"} {
        lappend branches($branch) $node
    } else {
        set branches($branch) [linsert $branches($branch) $idx $node]
    }

    Widget::init Wizard::Branch $path.$node $args

    if {[Widget::getoption $path -autobuttons]} { Wizard::adjustbuttons $path }

    set items($node) $path.$node

    return $items($node)
}


proc Wizard::_is_step { path node } {
    Widget::getVariable $path steps
    return [info exists steps($node)]
}


proc Wizard::_is_branch { path node } {
    Widget::getVariable $path branches
    return [info exists branches($node)]
}


proc Wizard::_is_button { path node } {
    Widget::getVariable $path buttons
    return [info exists buttons($node)]
}


proc Wizard::_is_widget { path node } {
    Widget::getVariable $path widgets
    return [info exists widgets($node)]
}


proc Wizard::_eval_command { path command {step ""} } {
    if {![string length $command]} { return 1 }

    if {![string length $step]} { set step [Wizard::raise $path] }

    set map [list %W $path %S $step]

    if {![Wizard::_is_branch $path $step]} {
        if {[string match "*%B*" $command]} {
            lappend map %B [Wizard::branch $path $step]
        }

        if {[string match "*%n*" $command]} {
            lappend map %n [Wizard::step $path next $step]
        }

        if {[string match "*%b*" $command]} {
            lappend map %b [Wizard::step $path back $step]
        }
    }

    return [uplevel #0 [string map $map $command]]
}


# ------------------------------------------------------------------------------
#  Command Wizard::_destroy
# ------------------------------------------------------------------------------
proc Wizard::_destroy { path } {
    Widget::getVariable $path items

    foreach item [array names items] {
        Widget::destroy $items($item) 0
    }

    Widget::destroy $path
}


proc SimpleWizard { path args } {
    option add *WizLayoutSimple*Label.padX                5    interactive
    option add *WizLayoutSimple*Label.anchor              nw   interactive
    option add *WizLayoutSimple*Label.justify             left interactive
    option add *WizLayoutSimple*Label.borderWidth         0    interactive
    option add *WizLayoutSimple*Label.highlightThickness  0    interactive

    set args [linsert $args 0 -createstep 1]
    lappend args -createcommand [list Wizard::layout::simple %W %S]

    return [eval [list Wizard $path] $args]
}


proc ClassicWizard { path args } {
    option add *WizLayoutClassic*Label.padX                5    interactive
    option add *WizLayoutClassic*Label.anchor              nw   interactive
    option add *WizLayoutClassic*Label.justify             left interactive
    option add *WizLayoutClassic*Label.borderWidth         0    interactive
    option add *WizLayoutClassic*Label.highlightThickness  0    interactive

    set args [linsert $args 0 -createstep 1]
    lappend args -createcommand [list Wizard::layout::classic %W %S]

    return [eval [list Wizard $path] $args]
}


proc Wizard::layout::simple { wizard step } {
    set frame [$wizard widget get $step]

    set layout [$wizard widget set layout -widget $frame.layout -step $step]

    foreach w [list titleframe pretext posttext clientArea] {
	set $w [$wizard widget set $w -widget $layout.$w -step $step]
    }

    foreach w [list title subtitle icon] {
	set $w [$wizard widget set $w -widget $titleframe.$w -step $step]
    }

    frame $layout -class WizLayoutSimple

    pack $layout -expand 1 -fill both

    # Client area. This is where the caller places its widgets.
    frame $clientArea -bd 8 -relief flat

    Separator $layout.sep1 -relief groove -orient horizontal

    # title and subtitle and icon
    frame $titleframe -bd 4 -relief flat -background #FFFFFF

    label $title -background #FFFFFF \
        -textvariable [$wizard variable $step -text1]

    label $subtitle -height 2 -background #FFFFFF -padx 15 -width 40 \
    	-textvariable [$wizard variable $step -text2]

    label $icon -borderwidth 0 -background #FFFFFF -anchor c
    set iconImage [$wizard getoption $step -icon]
    if {$iconImage ne ""} { $icon configure -image $iconImage }

    set labelfont [font actual [$title cget -font]]
    $title configure -font [concat $labelfont -weight bold]

    # put the title, subtitle and icon inside the frame we've built for them
    grid $title    -in $titleframe -row 0 -column 0 -sticky nsew
    grid $subtitle -in $titleframe -row 1 -column 0 -sticky nsew
    grid $icon     -in $titleframe -row 0 -column 1 -rowspan 2 -padx 8
    grid columnconfigure $titleframe 0 -weight 1
    grid columnconfigure $titleframe 1 -weight 0

    set label label
    if {[BWidget::using ttk]} { set label ttk::label }

    # pre and post text.
    $label $pretext  -anchor w -justify left \
        -textvariable [$wizard variable $step -text3]
    $label $posttext -anchor w -justify left \
        -textvariable [$wizard variable $step -text4]

    # when our label widgets change size we want to reset the
    # wraplength to that same size.
    foreach widget [list title subtitle pretext posttext] {
	bind [set $widget] <Configure> {
            # yeah, I know this looks weird having two after idle's, but
            # it helps prevent the geometry manager getting into a tight
            # loop under certain circumstances
            #
            # note that subtracting 10 is just a somewhat arbitrary number
            # to provide a little padding...
            after idle {after idle {%W configure -wraplength [expr {%w -10}]}}
        }
    }

    grid $titleframe  -row 0 -column 0 -sticky nsew -padx 0
    grid $layout.sep1 -row 1 -sticky ew 
    grid $pretext     -row 2 -sticky nsew -padx 8 -pady 8
    grid $clientArea  -row 3 -sticky nsew -padx 8 -pady 8
    grid $posttext    -row 4 -sticky nsew -padx 8 -pady 8

    grid columnconfigure $layout 0 -weight 1
    grid rowconfigure    $layout 0 -weight 0
    grid rowconfigure    $layout 1 -weight 0
    grid rowconfigure    $layout 2 -weight 0
    grid rowconfigure    $layout 3 -weight 1
    grid rowconfigure    $layout 4 -weight 0
}

proc Wizard::layout::classic { wizard step } {
    set frame [$wizard widget get $step]

    set layout [$wizard widget set layout -widget $frame.layout -step $step]
    foreach w [list title subtitle icon pretext posttext clientArea] {
	set $w [$wizard widget set $w -widget $layout.$w -step $step]
    }

    frame $layout -class WizLayoutClassic

    pack $layout -expand 1 -fill both

    # Client area. This is where the caller places its widgets.
    frame $clientArea -bd 8 -relief flat
    
    Separator $layout.sep1 -relief groove -orient vertical

    # title and subtitle
    label $title    -textvariable [$wizard variable $step -text1]
    label $subtitle -textvariable [$wizard variable $step -text2] -height 2

    array set labelfont [font actual [$title cget -font]]
    incr labelfont(-size) 6
    set  labelfont(-weight) bold
    $title configure -font [array get labelfont]

    set label label
    if {[BWidget::using ttk]} { set label ttk::label }

    # pre and post text. 
    $label $pretext  -anchor w -justify left \
        -textvariable [$wizard variable $step -text3]
    $label $posttext -anchor w -justify left \
        -textvariable [$wizard variable $step -text4]

    # when our label widgets change size we want to reset the
    # wraplength to that same size.
    foreach widget [list title subtitle pretext posttext] {
        bind [set $widget] <Configure> {
            # yeah, I know this looks weird having two after idle's, but
            # it helps prevent the geometry manager getting into a tight
            # loop under certain circumstances
            #
            # note that subtracting 10 is just a somewhat arbitrary number
            # to provide a little padding...
            after idle {after idle {%W configure -wraplength [expr {%w -10}]}}
        }
    }

    label $icon -borderwidth 1 -relief sunken -background #FFFFFF \
        -anchor c -width 96 -image Wizard::none
    set iconImage [$wizard getoption $step -icon]
    if {[string length $iconImage]} { $icon configure -image $iconImage }

    grid $icon       -row 0 -column 0 -sticky nsew -padx 8 -pady 8 -rowspan 5
    grid $title      -row 0 -column 1 -sticky ew   -padx 8 -pady 8
    grid $subtitle   -row 1 -column 1 -sticky ew   -padx 8 -pady 8
    grid $pretext    -row 2 -column 1 -sticky ew   -padx 8
    grid $clientArea -row 3 -column 1 -sticky nsew -padx 8
    grid $posttext   -row 4 -column 1 -sticky ew   -padx 8 -pady 24

    grid columnconfigure $layout 0 -weight 0
    grid columnconfigure $layout 1 -weight 1

    grid rowconfigure    $layout 0 -weight 0
    grid rowconfigure    $layout 1 -weight 0
    grid rowconfigure    $layout 2 -weight 0
    grid rowconfigure    $layout 3 -weight 1
    grid rowconfigure    $layout 4 -weight 0
}

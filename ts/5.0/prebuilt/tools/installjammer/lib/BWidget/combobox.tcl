# ----------------------------------------------------------------------------
#  combobox.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: combobox.tcl,v 1.30 2004/04/21 22:26:28 hobbs Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#     - ComboBox::create
#     - ComboBox::configure
#     - ComboBox::cget
#     - ComboBox::setvalue
#     - ComboBox::getvalue
#     - ComboBox::_create_popup
#     - ComboBox::_mapliste
#     - ComboBox::_unmapliste
#     - ComboBox::_select
#     - ComboBox::_modify_value
# ----------------------------------------------------------------------------

# ComboBox uses the 8.3 -listvariable listbox option
package require Tk 8.3

namespace eval ComboBox {
    Widget::define ComboBox combobox ArrowButton Entry ListBox

    Widget::tkinclude ComboBox frame :cmd \
	include {
            -relief -borderwidth -bd -background
        } initialize {
            -relief sunken -borderwidth 2
        }

    Widget::bwinclude ComboBox Entry .e \
	remove {
            -relief -bd -borderwidth -bg
        } rename {
            -background -entrybg
        }

    Widget::declare ComboBox {
        {-data          String     ""   0}
	{-height        Int        10   0}
	{-values        String	   ""   0}
	{-images        String	   ""   0}
	{-indents       String	   ""   0}
	{-postcommand   String	   ""   0}
	{-modifycommand String	   ""   0}
	{-expand        Enum	   none 0 {none tab}}
	{-autocomplete  Boolean	   0    1}
        {-usetable      Boolean    0    1}
        {-tablecolumn   Int        0    0}
        {-usebwlistbox  Boolean    0    1}
        {-dropdownwidth Int        0    0}
        {-hottrack      Boolean    1    1}

        {-postcmd       Synonym    -postcommand}
        {-modifycmd     Synonym    -modifycommand}
        {-bwlistbox     Synonym    -usebwlistbox}
    }

    Widget::addmap ComboBox ArrowButton .a {
	-background {} -foreground {} -disabledforeground {} -state {}
    }

    Widget::syncoptions ComboBox Entry .e { -text {} }

    ::bind ComboBox <FocusIn>       [list after idle {BWidget::refocus %W %W.e}]
    ::bind ComboBox <<TraverseIn>>  [list ComboBox::_traverse_in %W]
    ::bind ComboBox <ButtonPress-1> [list ComboBox::_unmapliste %W]

    ::bind ComboBoxEntry <Key-Up> [list ComboBox::_keyboard_command %W up]
    ::bind ComboBoxEntry <Key-Down> [list ComboBox::_keyboard_command %W down]
    ::bind ComboBoxEntry <Control-Up> [list ComboBox::_keyboard_command %W prev]
    ::bind ComboBoxEntry <Control-Down> \
        [list ComboBox::_keyboard_command %W next]
    ::bind ComboBoxEntry <Control-Prior> \
        [list ComboBox::_keyboard_command %W first]
    ::bind ComboBoxEntry <Control-Next> \
        [list ComboBox::_keyboard_command %W last]

    if {[string equal $::tcl_platform(platform) "windows"]} {
        ::bind ComboBoxEntry <FocusOut>      [list ComboBox::_focus_out %W]
    }

    ::bind ListBoxHotTrack <Motion> {
        %W selection clear 0 end
        %W activate @%x,%y
        %W selection set @%x,%y
    }
}


# ComboBox::create --
#
#	Create a combobox widget with the given options.
#
# Arguments:
#	path	name of the new widget.
#	args	optional arguments to the widget.
#
# Results:
#	path	name of the new widget.

proc ComboBox::create { path args } {
    Widget::initArgs ComboBox $args opts

    eval [list frame $path] $opts(:cmd) \
	 [list -highlightthickness 0 -takefocus 0 -class ComboBox]
    Widget::initFromODB ComboBox $path $opts(ComboBox)

    if {[Widget::getoption $path -usetable]} {
        package require Tktable
    }

    set entry [eval [list Entry::create $path.e] $opts(.e) \
              [list -relief flat -borderwidth 0 -takefocus 1]]
    bindtags $entry [concat [bindtags $entry] ComboBoxEntry]

    Widget::getVariable $path data
    set data(index) -1

    if {[Widget::getoption $path -autocomplete]} {
	::bind $entry <KeyRelease> [list $path _auto_complete %K]
    }

    set ipadx  2
    set width  15
    set height [winfo reqheight $entry]
    set arrow [eval [list ArrowButton::create $path.a] $opts(.a) \
		   -width $width -height $height \
		   -highlightthickness 0 -borderwidth 1 -takefocus 0 \
		   -dir	  bottom \
		   -type  button \
		   -ipadx $ipadx \
		   -command [list [list ComboBox::_mapliste $path]]]

    pack $arrow -side right -fill y
    pack $entry -side left  -fill both -expand yes

    set editable [Widget::cget $path -editable]
    Entry::configure $entry -editable $editable
    if {$editable} {
	::bind $entry <ButtonPress-1> [list ComboBox::_unmapliste $path]
    } else {
	::bind $entry <ButtonPress-1> [list ArrowButton::invoke $path.a]
	if { ![string equal [Widget::cget $path -state] "disabled"] } {
	    Entry::configure $entry -takefocus 1
	}
    }

    if {$editable} {
	set expand [Widget::getoption $path -expand]
	if {[string equal "tab" $expand]} {
	    # Expand entry value on Tab (from -values)
	    ::bind $entry <Tab> "[list ComboBox::_expand $path]; break"
	} elseif {[string equal "auto" $expand]} {
	    # Expand entry value anytime (from -values)
	    #::bind $entry <Key> "[list ComboBox::_expand $path]; break"
	}
    }

    ## If we have images, we have to use a BWidget ListBox.
    set bw [Widget::getoption $path -usebwlistbox]
    if {[llength [Widget::getoption $path -images]]} {
        Widget::configure $path [list -usebwlistbox 1]
    } else {
        Widget::configure $path [list -usebwlistbox $bw]
    }

    return [Widget::create ComboBox $path]
}


# ComboBox::configure --
#
#	Configure subcommand for ComboBox widgets.  Works like regular
#	widget configure command.
#
# Arguments:
#	path	Name of the ComboBox widget.
#	args	Additional optional arguments:
#			?-option?
#			?-option value ...?
#
# Results:
#	Depends on arguments.  If no arguments are given, returns a complete
#	list of configuration information.  If one argument is given, returns
#	the configuration information for that option.  If more than one
#	argument is given, returns nothing.

proc ComboBox::configure { path args } {
    set res [Widget::configure $path $args]
    set entry $path.e

    set list [list -images -values]
    foreach {ci cv} [eval [linsert $list 0 Widget::hasChangedX $path]] break

    if {$ci} {
        if {![Widget::getoption $path -usebwlistbox]} {
            set msg "cannot use -images in a ComboBox without -usebwlistbox"
            return -code error $msg
        }

        ## If the images have changed, destroy the shell so that it
        ## will re-create itself the next time around.
        destroy $path.shell
    }

    set chgedit [Widget::hasChangedX $path -editable]
    if {$chgedit} {
        if {[Widget::cget $path -editable]} {
            ::bind $entry <ButtonPress-1> [list ComboBox::_unmapliste $path]
	    Entry::configure $entry -editable true
	} else {
	    ::bind $entry <ButtonPress-1> [list ArrowButton::invoke $path.a]
	    Entry::configure $entry -editable false

	    # Make sure that non-editable comboboxes can still be tabbed to.

	    if {![string equal [Widget::cget $path -state] "disabled"]} {
		Entry::configure $entry -takefocus 1
	    }
        }
    }

    if {$chgedit || [Widget::hasChangedX $path -expand]} {
	# Unset what we may have created.
	::bind $entry <Tab> {}
	if {[Widget::cget $path -editable]} {
	    set expand [Widget::getoption $path -expand]
	    if {[string equal "tab" $expand]} {
		# Expand entry value on Tab (from -values)
		::bind $entry <Tab> "[list ComboBox::_expand $path]; break"
	    } elseif {[string equal "auto" $expand]} {
		# Expand entry value anytime (from -values)
		#::bind $entry <Key> "[list ComboBox::_expand $path]; break"
	    }
	}
    }

    # If the dropdown listbox is shown, simply force the actual entry
    # colors into it. If it is not shown, the next time the dropdown
    # is shown it'll get the actual colors anyway.
    set listbox [getlistbox $path]
    if {[winfo exists $listbox]} {
        set bg  [Widget::cget $path -entrybg]
        set fg  [Widget::cget $path -foreground]
        set sbg [Widget::cget $path -selectbackground]
        set sfg [Widget::cget $path -selectforeground]

        if {[Widget::getoption $path -usetable]} {
            $listbox configure -bg $bg -fg $fg

            $listbox tag configure sel -bg $sbg -fg $sfg
        } else {
            $listbox configure -bg $bg -fg $fg \
                -selectbackground $sbg -selectforeground $sfg
        }
    }

    if {[Widget::hasChanged $path -text value]} {
        Widget::getVariable $path data
        set values [Widget::getoption $path -values]
        set data(index) [lsearch -exact $values $value]
    }

    if {$cv && [Widget::getoption $path -usetable]} {
        _update_table_values $path
    }

    return $res
}


# ----------------------------------------------------------------------------
#  Command ComboBox::cget
# ----------------------------------------------------------------------------
proc ComboBox::cget { path option } {
    return [Widget::cget $path $option]
}


# ----------------------------------------------------------------------------
#  Command ComboBox::setvalue
# ----------------------------------------------------------------------------
proc ComboBox::setvalue { path index } {
    set idx    [ComboBox::index $path $index 0]
    set value  [Entry::cget $path.e -text]
    set values [Widget::cget $path -values]

    if {$idx >= 0 && $idx < [llength $values]} {
        Widget::getVariable $path data
        set data(index) $idx

        set newval [lindex $values $idx]
        if {[Widget::getoption $path -usetable]} {
            set col [Widget::getoption $path -tablecolumn]
            if {$col > -1} { set newval [lindex $newval $col] }
        }
	Entry::configure $path.e -text $newval
        return 1
    }

    return 0
}


proc ComboBox::icursor { path idx } {
    return [$path.e icursor $idx]
}


proc ComboBox::get { path } {
    return [$path.e get]
}

proc ComboBox::index { path index {strict 1} } {
    Widget::getVariable $path data
    set values [Widget::getoption $path -values]

    set idx  $data(index)
    set last [expr {[llength $values] - 1}]

    switch -- $index {
        "active" {}

        "next" {
            incr idx
        }

        "prev" - "previous" {
            incr idx -1
        }

        "first" {
            set idx 0
        }

        "end" - "last" {
            set idx $last
        }

        default {
            if {[string is integer $index]} {
                set idx $index
            } elseif {[string equal [string index $index 0] "@"]} {
                set idx [string range $index 1 end]
		if {![string is integer -strict $idx]} {
                    return -code error "bad index \"$index\""
                }
            } else {
                return -code error "bad index \"$index\""
            }
        }
    }

    if {$strict} {
        if {$idx < 0} { set idx 0 }
        if {$idx > $last} { set idx $last }
    }

    return $idx
}


# ----------------------------------------------------------------------------
#  Command ComboBox::getvalue
# ----------------------------------------------------------------------------
proc ComboBox::getvalue { path } {
    Widget::getVariable $path data
    return $data(index)
}


proc ComboBox::getlistbox { path } {
    _create_popup $path
    return $path.shell.listb
}


# ----------------------------------------------------------------------------
#  Command ComboBox::post
# ----------------------------------------------------------------------------
proc ComboBox::post { path } {
    _mapliste $path
    return
}


proc ComboBox::unpost { path } {
    _unmapliste $path
    return
}


# ----------------------------------------------------------------------------
#  Command ComboBox::bind
# ----------------------------------------------------------------------------
proc ComboBox::bind { path args } {
    return [eval [list ::bind $path.e] $args]
}


proc ComboBox::insert { path idx args } {
    upvar #0 [Widget::varForOption $path -values] values

    if {[Widget::getoption $path -usebwlistbox]} {
        set l [$path getlistbox]
        set i [eval [list $l insert $idx #auto] $args]
        set text [$l itemcget $i -text]
        set values [linsert $values $idx $text]
    } else {
        set values [eval linsert [list $values] $idx $args]
    }
}

# ----------------------------------------------------------------------------
#  Command ComboBox::_create_popup
# ----------------------------------------------------------------------------
proc ComboBox::_create_popup { path } {
    set shell $path.shell

    if {[winfo exists $shell]} { return }

    set h    [Widget::cget $path -height]
    set lval [Widget::getoption $path -values]

    if { $h <= 0 } {
	set len [llength $lval]
	if { $len < 3 } {
	    set h 3
	} elseif { $len > 10 } {
	    set h 10
	} else {
	    set h $len
	}
    }

    if {[string equal $::tcl_platform(platform) "unix"]} {
	set sbwidth 11
    } else {
	set sbwidth 15
    }

    toplevel            $shell -relief solid -bd 1
    wm withdraw         $shell
    wm overrideredirect $shell 1
    wm transient        $shell [winfo toplevel $path]

    if {$::tcl_platform(platform) eq "windows"} {
        wm attributes $shell -topmost 1
    }

    set sw [ScrolledWindow $shell.sw -managed 0 -size $sbwidth -ipad 0]
    pack $sw -fill both -expand yes
    
    if {[Widget::getoption $path -usetable]} {
        set listb [table $shell.listb \
            -relief flat -borderwidth 0 -highlightthickness 0 \
            -selecttype row -selectmode single -cursor "" \
            -colstretchmode all -resizeborders none \
            -height $h -font [Widget::cget $path -font] \
            -background [Widget::cget $path -entrybg] \
            -foreground [Widget::cget $path -foreground] \
            -variable [Widget::widgetVar $path tableData]]

        BWidget::bindMouseWheel $shell.listb

        _update_table_values $path

        ::bind $listb <ButtonRelease-1> [list ComboBox::_select $path @%x,%y]

        if {[Widget::getoption $path -hottrack]} {
            ::bind $listb <Motion> {
                %W selection clear all
                %W selection set @%x,%y
            }
        }
    } elseif {[Widget::getoption $path -usebwlistbox]} {
        set listb  [ListBox $shell.listb \
                -relief flat -borderwidth 0 -highlightthickness 0 \
                -selectmode single -selectfill 1 -autofocus 0 -height $h \
                -font [Widget::cget $path -font]  \
                -bg [Widget::cget $path -entrybg] \
                -fg [Widget::cget $path -foreground] \
                -selectbackground [Widget::cget $path -selectbackground] \
                -selectforeground [Widget::cget $path -selectforeground]]

        set values [Widget::getoption $path -values]
        set images [Widget::getoption $path -images]
        foreach value $values image $images {
            $listb insert end #auto -text $value -image $image
        }
	$listb bindText  <1> "ComboBox::_select $path"
	$listb bindImage <1> "ComboBox::_select $path"
        if {[Widget::getoption $path -hottrack]} {
            $listb bindText  <Enter> [list $listb selection set]
            $listb bindImage <Enter> [list $listb selection set]
        }
    } else {
        set listb  [listbox $shell.listb \
                -relief flat -borderwidth 0 -highlightthickness 0 \
                -exportselection false \
                -font	[Widget::cget $path -font]  \
                -height $h \
                -bg [Widget::cget $path -entrybg] \
                -fg [Widget::cget $path -foreground] \
                -selectbackground [Widget::cget $path -selectbackground] \
                -selectforeground [Widget::cget $path -selectforeground] \
                -listvariable [Widget::varForOption $path -values]]
        ::bind $listb <ButtonRelease-1> [list ComboBox::_select $path @%x,%y]

        if {[Widget::getoption $path -hottrack]} {
            bindtags $listb [concat [bindtags $listb] ListBoxHotTrack]
        }
    }

    $sw setwidget $listb

    ::bind $listb <Return>   "ComboBox::_select $path \[%W curselection]"
    ::bind $listb <Escape>   [list ComboBox::_unmapliste $path]
    if {[string equal $::tcl_platform(platform) "windows"]} {
        ::bind $listb <FocusOut> [list ComboBox::_focus_out $path]
    }
}


proc ComboBox::_recreate_popup { path } {
    variable background
    variable foreground

    set shell $path.shell
    set h     [Widget::cget $path -height]
    set lval  [Widget::getoption $path -values]

    if { $h <= 0 } {
	set len [llength $lval]
	if { $len < 3 } {
	    set h 3
	} elseif { $len > 10 } {
	    set h 10
	} else {
	    set h $len
	}
    }

    if {$::tcl_platform(platform) == "unix"} {
	set sbwidth 11
    } else {
	set sbwidth 15
    }

    _create_popup $path

    if {![Widget::cget $path -editable]} {
        if {[info exists background]} {
            $path.e configure -bg $background
            $path.e configure -fg $foreground
            unset background
            unset foreground
        }
    }

    set listb $shell.listb
    destroy $shell.sw
    set sw [ScrolledWindow $shell.sw -managed 0 -size $sbwidth -ipad 0]

    set opts [list]
    lappend opts -font [Widget::cget $path -font]
    lappend opts -bg   [Widget::cget $path -entrybg]
    lappend opts -fg   [Widget::cget $path -foreground]

    if {[Widget::getoption $path -usetable]} {
        lappend opts -height $h
    } else {
        lappend opts -height $h
        lappend opts -selectbackground [Widget::cget $path -selectbackground]
        lappend opts -selectforeground [Widget::cget $path -selectforeground]
    }

    eval [list $listb configure] $opts

    pack $sw -fill both -expand yes
    $sw setwidget $listb
    raise $listb
}


# ----------------------------------------------------------------------------
#  Command ComboBox::_mapliste
# ----------------------------------------------------------------------------
proc ComboBox::_mapliste { path } {
    set listb $path.shell.listb
    if {[winfo exists $path.shell] &&
        [string equal [wm state $path.shell] "normal"]} {
	_unmapliste $path
        return
    }

    if { [Widget::cget $path -state] == "disabled" } {
        return
    }

    if {[llength [set cmd [Widget::getoption $path -postcommand]]]} {
        uplevel \#0 $cmd
    }

    if { ![llength [Widget::getoption $path -values]] } {
        return
    }

    _recreate_popup $path

    ArrowButton::configure $path.a -relief sunken
    update

    if {[Widget::getoption $path -usetable]} {
        $listb selection clear all
    } else {
        $listb selection clear 0 end
    }

    set values [Widget::getoption $path -values]
    set curval [Entry::cget $path.e -text]
    set idx 0
    if {[set i [lsearch -exact $values $curval]] != -1 ||
         [set i [lsearch $values "$curval*"]] != -1} {
        set idx $i
    }

    if {[Widget::getoption $path -usetable]} {
        set idx $idx,0
    } elseif {[Widget::getoption $path -usebwlistbox]} {
        set idx [$listb items $idx]
    } else {
        $listb activate $idx
    }

    $listb selection set $idx
    $listb see $idx

    set width [Widget::getoption $path -dropdownwidth]
    if {!$width} { set width [winfo width $path] }
    BWidget::place $path.shell $width 0 below $path

    wm deiconify $path.shell
    raise $path.shell
    BWidget::grab global $path
    BWidget::focus set $listb

    event generate $path <<ComboBoxPost>>
}


# ----------------------------------------------------------------------------
#  Command ComboBox::_unmapliste
# ----------------------------------------------------------------------------
proc ComboBox::_unmapliste { path {refocus 1} } {
    if {[winfo exists $path.shell] && \
	    [string equal [wm state $path.shell] "normal"]} {
        BWidget::grab release $path
        BWidget::focus release $path.shell.listb $refocus
	# Update now because otherwise [focus -force...] makes the app hang!
	if {$refocus} {
	    update
	    focus -force $path.e
	}
        wm withdraw $path.shell
        ArrowButton::configure $path.a -relief raised

        event generate $path <<ComboBoxUnpost>>
    }
}


# ----------------------------------------------------------------------------
#  Command ComboBox::_select
# ----------------------------------------------------------------------------
proc ComboBox::_select { path index } {
    set index [$path.shell.listb index $index]

    _unmapliste $path

    if {[Widget::getoption $path -usetable]} {
        set index [lindex [split $index ,] 0]
    }

    if {$index != -1} {
        if {[ComboBox::setvalue $path @$index]} {
	    set cmd [Widget::getoption $path -modifycommand]
            if {[string length $cmd]} { uplevel #0 $cmd }
        }
    }

    $path.e selection clear
    $path.e selection range 0 end

    event generate $path <<ComboBoxSelected>>
    event generate $path <<ComboboxSelected>>
}


# ----------------------------------------------------------------------------
#  Command ComboBox::_modify_value
# ----------------------------------------------------------------------------
proc ComboBox::_modify_value { path direction } {
    if {[ComboBox::setvalue $path $direction]} {
        $path.e selection clear
        $path.e selection range 0 end
        
        set cmd [Widget::getoption $path -modifycommand]
        if {[string length $cmd]} { uplevel #0 $cmd }
    }
}

# ----------------------------------------------------------------------------
#  Command ComboBox::_expand
# ----------------------------------------------------------------------------
proc ComboBox::_expand {path} {
    set values [Widget::getoption $path -values]
    if {![llength $values]} {
	bell
	return 0
    }

    set found  {}
    set curval [Entry::cget $path.e -text]
    set curlen [$path.e index insert]
    if {$curlen < [string length $curval]} {
	# we are somewhere in the middle of a string.
	# if the full value matches some string in the listbox,
	# reorder values to start matching after that string.
	set idx [lsearch -exact $values $curval]
	if {$idx >= 0} {
	    set values [concat [lrange $values [expr {$idx+1}] end] \
			    [lrange $values 0 $idx]]
	}
    }
    if {$curlen == 0} {
	set found $values
    } else {
	foreach val $values {
	    if {[string equal -length $curlen $curval $val]} {
		lappend found $val
	    }
	}
    }
    if {[llength $found]} {
	Entry::configure $path.e -text [lindex $found 0]
	if {[llength $found] > 1} {
	    set best [_best_match $found [string range $curval 0 $curlen]]
	    set blen [string length $best]
	    $path.e icursor $blen
	    $path.e selection range $blen end
	}
    } else {
	bell
    }
    return [llength $found]
}

# best_match --
#   finds the best unique match in a list of names
#   The extra $e in this argument allows us to limit the innermost loop a
#   little further.
# Arguments:
#   l		list to find best unique match in
#   e		currently best known unique match
# Returns:
#   longest unique match in the list
#
proc ComboBox::_best_match {l {e {}}} {
    set ec [lindex $l 0]
    if {[llength $l]>1} {
	set e  [string length $e]; incr e -1
	set ei [string length $ec]; incr ei -1
	foreach l $l {
	    while {$ei>=$e && [string first $ec $l]} {
		set ec [string range $ec 0 [incr ei -1]]
	    }
	}
    }
    return $ec
}

# possibly faster
#proc match {string1 string2} {
#   set i 1
#   while {[string equal -length $i $string1 $string2]} { incr i }
#   return [string range $string1 0 [expr {$i-2}]]
#}
#proc matchlist {list} {
#   set list [lsort $list]
#   return [match [lindex $list 0] [lindex $list end]]
#}


# ----------------------------------------------------------------------------
#  Command ComboBox::_traverse_in
#  Called when widget receives keyboard focus due to keyboard traversal.
# ----------------------------------------------------------------------------
proc ComboBox::_traverse_in { path } {
    if {[$path.e selection present] != 1} {
	# Autohighlight the selection, but not if one existed
	$path.e selection range 0 end
    }
}


# ----------------------------------------------------------------------------
#  Command ComboBox::_focus_out
# ----------------------------------------------------------------------------
proc ComboBox::_focus_out { path } {
    if {![string length [focus]]} {
	# we lost focus to some other app, make sure we drop the listbox
	return [_unmapliste $path 0]
    }
}


proc ComboBox::_auto_complete { path key } {
    ## Anything that is all lowercase is either a letter, number
    ## or special key we're ok with.  Everything else is a
    ## functional key of some kind.
    if {[string length $key] > 1 && [string tolower $key] != $key} { return }

    set text [string map [list {[} {\[} {]} {\]}] [$path.e get]]
    if {![string length $text]} { return }

    set values [Widget::getoption $path -values]

    if {[Widget::getoption $path -usetable]} {
        set col [Widget::getoption $path -tablecolumn]
        set idx [lsearch -index $col $values $text*]
    } else {
        set idx [lsearch $values $text*]
    }

    if {$idx > -1} {
        set idx [$path.e index insert]
        $path.e configure -text [lindex $values $idx]
        $path.e icursor $idx
        $path.e select range insert end
    }
}


proc ComboBox::_keyboard_command { entry command } {
    set path [winfo parent $entry]

    switch -- $command {
        "up" {
            ComboBox::_unmapliste $path
        }

        "down" {
            ComboBox::_mapliste $path
        }

        default {
            ComboBox::_modify_value $path $command
        }
    }
}


proc ComboBox::_update_table_values { path } {
    Widget::getVariable $path tableData

    set table  [getlistbox $path]
    set values [Widget::getoption $path -values]

    set row  0
    set cols 0
    foreach list $values {
        set len [llength $list]
        if {$len > $cols} { set cols $len }

        for {set col 0} {$col < $len} {incr col} {
            set tableData($row,$col) [lindex $list $col]
        }

        incr row
    }

    $table configure -rows $row -cols $cols -state disabled
}

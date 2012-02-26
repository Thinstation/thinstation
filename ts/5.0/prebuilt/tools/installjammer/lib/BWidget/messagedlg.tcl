# ------------------------------------------------------------------------------
#  messagedlg.tcl
#  This file is part of Unifix BWidget Toolkit
# ------------------------------------------------------------------------------
#  Index of commands:
#     - MessageDlg::create
# ------------------------------------------------------------------------------

namespace eval MessageDlg {
    Widget::define MessageDlg messagedlg Dialog

    if {[BWidget::using ttk]} {
        Widget::tkinclude MessageDlg ttk::label .frame.msg \
            rename {
                -text -message
            } initialize {
                -anchor w -justify left
            }
    } else {
        Widget::tkinclude MessageDlg label .frame.msg \
            remove {
                -cursor -highlightthickness -relief -borderwidth -bd
                -takefocus -textvariable
            } rename {
                -text -message
            } initialize {
                -anchor w -justify left
            }
    }

    Widget::bwinclude MessageDlg Dialog :cmd \
        remove {
            -modal -image -bitmap -side -anchor -separator
            -homogeneous -padx -pady -spacing
        }

    Widget::declare MessageDlg {
        {-name       String     ""     0}
        {-icon       Enum       "info" 0 {none error info question warning}}
        {-type       Enum       "user" 0 
            {abortretryignore ok okcancel retrycancel yesno yesnocancel user}}
        {-buttons     String    ""     0}
        {-buttonwidth String    0      0}
        {-usenative   Boolean   1      0}
    }

    Widget::addmap MessageDlg "" tkMBox {
	-parent {} -message {} -default {} -title {}
    }
}


# ------------------------------------------------------------------------------
#  Command MessageDlg::create
# ------------------------------------------------------------------------------
proc MessageDlg::create { path args } {
    variable dialogs

    array set _args $args

    ## If this dialog has a name, and the user has already opted to
    ## remember the value from last time, just return the saved value.
    if {[info exists _args(-name)] && [info exists dialogs($_args(-name))]} {
        return $dialogs($_args(-name))
    }

    BWidget::LoadBWidgetIconLibrary

    set dialog "$path#Message"

    Widget::initArgs MessageDlg $args maps
    Widget::initFromODB MessageDlg $dialog $maps(MessageDlg)

    set type   [Widget::getoption $dialog -type]
    set icon   [Widget::getoption $dialog -icon]
    set width  [Widget::getoption $dialog -buttonwidth]
    set native [Widget::getoption $dialog -usenative]

    set user  0
    set defb  -1
    set canb  -1
    switch -- $type {
        abortretryignore {set lbut {abort retry ignore}; set defb 0}
        ok               {set lbut {ok}; set defb 0 }
        okcancel         {set lbut {ok cancel}; set defb 0; set canb 1}
        retrycancel      {set lbut {retry cancel}; set defb 0; set canb 1}
        yesno            {set lbut {yes no}; set defb 0; set canb 1}
        yesnocancel      {set lbut {yes no cancel}; set defb 0; set canb 2}
        user             {
            set user   1
            set native 0
            set lbut [Widget::cget $dialog -buttons]
        }
    }

    # If the user didn't specify a default button, use our type-specific
    # default, adding its flag/value to the "user" settings and to the tkMBox
    # settings
    array set dialogArgs $maps(:cmd)

    if {!$user && ![info exists dialogArgs(-default)]} {
        lappend maps(:cmd)   -default [lindex $lbut $defb]
        lappend maps(tkMBox) -default [lindex $lbut $defb]
    }

    if {![info exists dialogArgs(-cancel)]} {
        lappend maps(:cmd) -cancel $canb
    }

    # Same with title as with default
    if {![info exists dialogArgs(-title)]} {
        set frame [frame $path -class MessageDlg]
        set title [option get $frame "${icon}Title" MessageDlg]
        destroy $frame
        if {![string length $title]} {
            set title "Message"
        }
	lappend maps(:cmd) -title $title
	lappend maps(tkMBox) -title $title
    }

    set name [Widget::getoption $dialog -name]
    if {[string length $name]} { set native 0 }

    ## If the user specified a "user" dialog, or we're on UNIX, we
    ## want to create the dialog ourselves.
    if {!$native} {
        if {!$user && !$width} { set width 12 }

        set image ""
        if {![string equal $icon "none"]} {
            set image [BWidget::Icon dialog$icon]
        }

        eval [list Dialog::create $path] $maps(:cmd) \
	    [list -image $image -modal local -side bottom -anchor c]
        wm resizable $path 0 0

        bind $path <Key-Left>  [list MessageDlg::_key_traversal $path left]
        bind $path <Key-Right> [list MessageDlg::_key_traversal $path right]

        foreach but $lbut {
            Dialog::add $path -text $but -name $but -width $width
        }

        set frame [Dialog::getframe $path]

        if {[BWidget::using ttk]} {
            eval [list ttk::label $frame.msg] $maps(.frame.msg) -wraplength 800
        } else {
            eval [list label $frame.msg] $maps(.frame.msg) \
                -relief flat -bd 0 -highlightthickness 0 -wraplength 800
        }

        pack $frame.msg -fill both -expand 1 -padx {5 10} -pady {5 0}

        if {[string length $name]} {
            set msg "Don't ask me again"
            set varName [Widget::widgetVar $dialog dontAskAgain]
            if {[BWidget::using ttk]} {
                ttk::checkbutton $path.check -text $msg -variable $varName
            } else {
                checkbutton $path.check -text $msg -variable $varName
            }

            pack $path.check -anchor w -side bottom -pady {0 2}

            bind $path.bbox <Map> [list pack configure $path.bbox -pady 5]
        }

        set res [Dialog::draw $path]
        if {!$user} { set res [lindex $lbut $res] }

	destroy $path
    } else {
	array set tkMBoxArgs $maps(tkMBox)

	if {![string equal $icon "none"]} {
	    set tkMBoxArgs(-icon) $icon
	}

	if {[info exists tkMBoxArgs(-parent)]
	    && ![winfo exists $tkMBoxArgs(-parent)]} {
            unset tkMBoxArgs(-parent)
	}

	set tkMBoxArgs(-type) $type
	set res [eval tk_messageBox [array get tkMBoxArgs]]
    }

    ## If this dialog has a name, and the user checked to remember
    ## the value, store it in the dialogs array for next time.
    if {[string length $name]} {
        upvar #0 $varName var
        if {$var} { set dialogs($name) $res }
    }

    Widget::destroy $dialog

    return $res
}


proc MessageDlg::_key_traversal { path dir } {
    set but [focus -lastfor $path]
    if {$but eq $path} {
        set def [ButtonBox::index $path.bbox default]
        set but [ButtonBox::index $path.bbox $def]
        ButtonBox::configure $path.bbox -default -1
    }

    set idx [ButtonBox::index $path.bbox $but]
    set max [ButtonBox::index $path.bbox end]

    if {$dir eq "left"} { incr idx -1 }
    if {$dir eq "right"} { incr idx 1 }

    if {$idx < 0} { set idx $max }
    if {$idx > $max} { set idx 0 }

    focus [ButtonBox::buttons $path.bbox $idx]
}

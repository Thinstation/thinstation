# -----------------------------------------------------------------------------
#  passwddlg.tcl
#  This file is part of Unifix BWidget Toolkit
#   by Stephane Lavirotte (Stephane.Lavirotte@sophia.inria.fr)
#  $Id: passwddlg.tcl,v 1.8 2003/10/20 21:23:52 damonc Exp $
# -----------------------------------------------------------------------------
#  Index of commands:
#     - PasswdDlg::create
#     - PasswdDlg::configure
#     - PasswdDlg::cget
#     - PasswdDlg::_verifonlogin
#     - PasswdDlg::_verifonpasswd
#     - PasswdDlg::_max
#------------------------------------------------------------------------------

namespace eval PasswdDlg {
    Widget::define PasswdDlg passwddlg Dialog LabelEntry

    Widget::bwinclude PasswdDlg Dialog :cmd \
        remove {
            -image -bitmap -side -default -cancel separator
        } initialize {
            -modal local -anchor c
        }

    Widget::bwinclude PasswdDlg LabelEntry .frame.lablog \
        remove {
            -command -justify -name -show -side -state -takefocus
            -width -xscrollcommand -padx -pady -dragenabled -dragendcmd
            -dragevent -draginitcmd -dragtype -dropenabled -dropcmd
            -dropovercmd -droptypes
        } prefix {
            login -editable -helptext -helpvar -label -text
            -textvariable -underline
        } initialize {
            -relief sunken -borderwidth 2 -labelanchor w -width 15
            -label "Login"
        }

    Widget::bwinclude PasswdDlg LabelEntry .frame.labpass \
        remove {
            -command -justify -name -show -side -state -takefocus
            -width -xscrollcommand -padx -pady -dragenabled -dragendcmd
            -dragevent -draginitcmd -dragtype -dropenabled -dropcmd
            -dropovercmd -droptypes
        } prefix {
            passwd -editable -helptext -helpvar -label -text
            -textvariable -underline
        } initialize {
            -relief sunken -borderwidth 2 -labelanchor w -width 15
            -label "Password"
        }

    Widget::declare PasswdDlg {
        {-type        Enum       ok           0 {ok okcancel}}
        {-labelwidth  TkResource -1           0 {label -width}}
        {-command     String     ""           0}

        {-login       String     ""           0}
        {-password    String     ""           0}
    }
}


# -----------------------------------------------------------------------------
#  Command PasswdDlg::create
# -----------------------------------------------------------------------------
proc PasswdDlg::create { path args } {
    Widget::initArgs PasswdDlg $args maps

    set bmp [Bitmap::get passwd]
    eval [list Dialog::create $path] $maps(:cmd) \
         [list -class PasswdDlg -image $bmp -side bottom -spacing 0]

    Widget::initFromODB PasswdDlg "$path#PasswdDlg" $maps(PasswdDlg)

    # Extract the PasswdDlg megawidget options (those that don't map to a
    # subwidget)
    set type      [Widget::cget "$path#PasswdDlg" -type]
    set cmd       [Widget::cget "$path#PasswdDlg" -command]

    set defb -1
    set canb -1
    switch -- $type {
        ok        { set lbut {ok}; set defb 0 }
        okcancel  { set lbut {ok cancel} ; set defb 0; set canb 1 }
    }

    $path configure -default $defb -cancel $canb

    foreach but $lbut {
        if {[string equal $but "ok"] && [string length $cmd]} {
            Dialog::add $path -text $but -name $but -command $cmd -width 12
        } else {
            Dialog::add $path -text $but -name $but -width 12
        }
    }

    set frame [Dialog::getframe $path]
    #bind $path  <Return>  ""
    bind $frame <Destroy> [list Widget::destroy $path\#PasswdDlg]

    set lablog [eval [list LabelEntry::create $frame.lablog] \
		    $maps(.frame.lablog) \
		    [list -name login -dragenabled 0 -dropenabled 0 \
			 -command [list PasswdDlg::_verifonpasswd \
				       $path $frame.labpass]]]

    set labpass [eval [list LabelEntry::create $frame.labpass] \
		     $maps(.frame.labpass) \
		     [list -name password -show "*" \
			  -dragenabled 0 -dropenabled 0 \
			  -command [list PasswdDlg::_verifonlogin \
					$path $frame.lablog]]]

    set labwidth [$lablog cget -labelwidth]
    if {$labwidth == 0} {
        set loglabel  [$lablog cget -label]
        set passlabel [$labpass cget -label]
        set labwidth [_max [string length $loglabel] [string length $passlabel]]
        incr labwidth 1
    }
    $lablog  configure -labelwidth $labwidth
    $labpass configure -labelwidth $labwidth

    Widget::create PasswdDlg $path 0

    pack  $lablog $labpass -fill x -expand 1

    # added by bach@mwgdna.com
    #  give focus to loginlabel unless the state is disabled
    set focus $labpass.e
    if {[$lablog cget -editable]} { set focus $lablog.e }

    set login [Widget::getoption $path#PasswdDlg -login]
    if {[string length $login]} {
        $lablog configure -text $login
        set focus $labpass.e
    }

    set password [Widget::getoption $path#PasswdDlg -password]
    if {[string length $password]} {
        $labpass configure -text $password
        set focus $lablog.e
    }

    focus $focus
    
    set res [Dialog::draw $path]

    if { $res == 0 } {
        set res [list [$lablog.e cget -text] [$labpass.e cget -text]]
    } else {
        set res [list]
    }
    Widget::destroy "$path#PasswdDlg"
    destroy $path

    return $res
}

# -----------------------------------------------------------------------------
#  Command PasswdDlg::configure
# -----------------------------------------------------------------------------

proc PasswdDlg::configure { path args } {
    set res [Widget::configure "$path#PasswdDlg" $args]
}

# -----------------------------------------------------------------------------
#  Command PasswdDlg::cget
# -----------------------------------------------------------------------------

proc PasswdDlg::cget { path option } {
    return [Widget::cget "$path#PasswdDlg" $option]
}


# -----------------------------------------------------------------------------
#  Command PasswdDlg::_verifonlogin
# -----------------------------------------------------------------------------
proc PasswdDlg::_verifonlogin { path labpass } {
    if { [$labpass.e cget -text] == "" } {
        focus $labpass
    } else {
        Dialog::setfocus $path default
    }
}

# -----------------------------------------------------------------------------
#  Command PasswdDlg::_verifonpasswd
# -----------------------------------------------------------------------------
proc PasswdDlg::_verifonpasswd { path lablog } {
    if { [$lablog.e cget -text] == "" } {
        focus $lablog
    } else {
        Dialog::setfocus $path default
    }
}

# -----------------------------------------------------------------------------
#  Command PasswdDlg::_max
# -----------------------------------------------------------------------------
proc PasswdDlg::_max { val1 val2 } { 
    return [expr {($val1 > $val2) ? ($val1) : ($val2)}] 
}

# ----------------------------------------------------------------------------
#  progressdlg.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#     - ProgressDlg::create
# ----------------------------------------------------------------------------

namespace eval ProgressDlg {
    Widget::define ProgressDlg progressdlg Dialog ProgressBar

    Widget::bwinclude ProgressDlg Dialog :cmd \
        remove {
            -modal -image -bitmap -side -anchor -cancel -default
            -homogeneous -padx -pady -spacing
        }

    Widget::bwinclude ProgressDlg ProgressBar .frame.pb \
        remove {-orient -width -height}

    Widget::declare ProgressDlg {
        {-width        TkResource 25 0 label}
        {-height       TkResource 2  0 label}
        {-textvariable String     "" 0}
        {-font         String     "TkTextFont" 0}
        {-stop         String "" 0}
        {-command      String "" 0}
    }

    Widget::addmap ProgressDlg :cmd .frame.msg \
        {-width {} -height {} -textvariable {} -font {} -background {}}
}


# ----------------------------------------------------------------------------
#  Command ProgressDlg::create
# ----------------------------------------------------------------------------
proc ProgressDlg::create { path args } {
    Widget::initArgs ProgressDlg $args maps

    eval [list Dialog::create $path] $maps(:cmd) \
	 [list -image [Bitmap::get hourglass]] \
         -modal none -side bottom -anchor c -class ProgressDlg -spacing 0

    Widget::initFromODB ProgressDlg "$path#ProgressDlg" $maps(ProgressDlg)

    wm protocol $path WM_DELETE_WINDOW {;}

    set frame [Dialog::getframe $path]
    bind $frame <Destroy> [list Widget::destroy $path\#ProgressDlg]
    $frame configure -cursor watch

    eval [list label $frame.msg] $maps(.frame.msg) \
	-relief flat -borderwidth 0 \
	    -highlightthickness 0 -anchor w -justify left
    pack $frame.msg -side top -pady 3m -anchor nw -fill x -expand yes

    eval [list ProgressBar::create] $frame.pb $maps(.frame.pb) -width 100
    pack $frame.pb -side bottom -anchor w -fill x -expand yes

    set stop [Widget::cget "$path#ProgressDlg" -stop]
    set cmd  [Widget::cget "$path#ProgressDlg" -command]
    if { $stop != "" && $cmd != "" } {
        set width [string length $stop]
        if {$width < 12} { set width 12 }
        Dialog::add $path -text $stop -name $stop -command $cmd -width $width
    }
    Dialog::draw $path
    BWidget::grab local $path

    return [Widget::create ProgressDlg $path 0]
}


# ----------------------------------------------------------------------------
#  Command ProgressDlg::configure
# ----------------------------------------------------------------------------
proc ProgressDlg::configure { path args } {
    return [Widget::configure "$path#ProgressDlg" $args]
}


# ----------------------------------------------------------------------------
#  Command ProgressDlg::cget
# ----------------------------------------------------------------------------
proc ProgressDlg::cget { path option } {
    return [Widget::cget "$path#ProgressDlg" $option]
}

# ----------------------------------------------------------------------------
#  font.tcl
#  This file is part of Unifix BWidget Toolkit
# ----------------------------------------------------------------------------
#  Index of commands:
#     - SelectFont::create
#     - SelectFont::configure
#     - SelectFont::cget
#     - SelectFont::_draw
#     - SelectFont::_destroy
#     - SelectFont::_update_style
#     - SelectFont::_update
#     - SelectFont::_getfont
#     - SelectFont::_init
# ----------------------------------------------------------------------------

namespace eval SelectFont {
    Widget::define SelectFont font Dialog LabelFrame ScrolledWindow

    Widget::declare SelectFont {
        {-title		String		"Select a Font" 0}
        {-parent	String		"" 0}
        {-background	Color           "SystemButtonFace" 0}

        {-type		Enum		dialog        0 {dialog toolbar}}
        {-font		String          "TkTextFont"  0}
	{-families	String		"all"         1}
	{-querysystem	Boolean		1             0}
	{-styles	String		"bold italic underline overstrike" 1}
        {-command	String		""            0}
        {-sampletext	String		"Sample Text" 0}
        {-bg		Synonym		-background}
        {-sizes         String          "6 8 9 10 11 12 14 16 18 20 22 24" 1}

        {-size          String          ""            1}
        {-family        String          ""            1}
    }

    if {[string equal $::tcl_platform(platform) "windows"]} {
        set sizes [list 8 9 10 11 12 14 16 18 20 22 24 26 28 36 48 72]
        Widget::declare SelectFont [list [list -sizes String $sizes 1]]
    }

    variable _families
    variable _styleOff
    array set _styleOff [list bold normal italic roman]
    
    # Set up preset lists of fonts, so the user can avoid the painfully slow
    # loadfont process if desired.
    if { [string equal $::tcl_platform(platform) "windows"] } {
	set presetVariable [list	\
		7x14			\
		Arial			\
		{Arial Narrow}		\
		{Lucida Sans}		\
		{MS Sans Serif}		\
		{MS Serif}		\
		{Times New Roman}	\
		]
	set presetFixed    [list	\
		6x13			\
		{Courier New}		\
		FixedSys		\
		Terminal		\
		]
	set presetAll      [list	\
		6x13			\
		7x14			\
		Arial			\
		{Arial Narrow}		\
		{Courier New}		\
		FixedSys		\
		{Lucida Sans}		\
		{MS Sans Serif}		\
		{MS Serif}		\
		Terminal		\
		{Times New Roman}	\
		]
    } else {
	set presetVariable [list	\
		helvetica		\
		lucida			\
		lucidabright		\
		{times new roman}	\
		]
	set presetFixed    [list	\
		courier			\
		fixed			\
		{lucida typewriter}	\
		screen			\
		serif			\
		terminal		\
		]
	set presetAll      [list	\
		courier			\
		fixed			\
		helvetica		\
		lucida			\
		lucidabright		\
		{lucida typewriter}	\
		screen			\
		serif			\
		terminal		\
		{times new roman}	\
		]
    }
    array set _families [list \
	    presetvariable	$presetVariable	\
	    presetfixed		$presetFixed	\
	    presetall		$presetAll	\
	    ]
		
    variable _widget
}


# ----------------------------------------------------------------------------
#  Command SelectFont::create
# ----------------------------------------------------------------------------
proc SelectFont::create { path args } {
    variable _sizes
    variable _styles
    variable _families

    set widg $path#SelectFont

    # Initialize the internal rep of the widget options
    Widget::init SelectFont $widg $args

    Widget::getVariable $widg data

    set _sizes [Widget::cget $widg -sizes]

    if {[Widget::getoption $widg -querysystem]} {
        loadfont [Widget::getoption $widg -families]
    }

    set _styles [Widget::getoption $widg -styles]

    return [eval [list SelectFont::[Widget::getoption $widg -type] $path] $args]
}


proc SelectFont::dialog { path args } {
    variable _sizes
    variable _styles
    variable _families

    set widg $path#SelectFont

    ## Initialize the internal rep of the widget options.
    Widget::init SelectFont $widg $args

    set bg   [Widget::getoption $widg -background]
    set font [Widget::getoption $widg -font]

    array set tmp [font actual $font]
    Widget::setoption $widg -size   $tmp(-size)
    Widget::setoption $widg -family $tmp(-family)

    Widget::getVariable $widg data

    Dialog::create $path -modal local -default 0 -cancel 1 \
        -background $bg -anchor e \
        -title  [Widget::getoption $widg -title] \
        -parent [Widget::getoption $widg -parent]

    ## Turn off the Return key closing the dialog.
    bind $path <Return> ""

    set frame [Dialog::getframe $path]
    set topf  [frame $frame.topf -relief flat -bd 0 -background $bg]

    set labf1 [LabelFrame::create $topf.labf1 -text "Font:" -name font \
               -side top -anchor w -relief flat -background $bg]

    set f [LabelFrame::getframe $labf1]

    Entry $f.fontEntry -textvariable [Widget::varForOption $widg -family] \
        -command [list SelectFont::_update $path]
    pack  $f.fontEntry -fill x

    set sw [ScrolledWindow::create $f.sw -bg $bg]
    pack $sw -fill both -expand yes

    set lbf [listbox $sw.lb -height 5 -width 25 \
        -exportselection 0 -selectmode browse \
        -listvariable [Widget::widgetVar $widg data(familyList)]]
    ScrolledWindow::setwidget $sw $lbf

    LabelFrame::configure $labf1 -focus $f.fontEntry

    if {[Widget::getoption $widg -querysystem]} {
        set fam [Widget::getoption $widg -families]
    } else {
        set fam "preset"
        append fam [Widget::getoption $widg -families]
    }
    eval [list $lbf insert end] $_families($fam)

    set script [list SelectFont::_update_family $path %W]

    bind $lbf <1>               [list focus %W]
    bind $lbf <ButtonRelease-1> $script
    bind $lbf <space>           $script
    bind $lbf <Up>              $script
    bind $lbf <Down>            $script
    bind $lbf <KeyRelease-Up>   $script
    bind $lbf <KeyRelease-Down> $script

    set labf2 [LabelFrame::create $topf.labf2 -text "Size:" -name size \
                   -side top -anchor w -relief flat -background $bg]

    set f [LabelFrame::getframe $labf2]

    Entry $f.sizeEntry -textvariable [Widget::varForOption $widg -size] \
        -command [list SelectFont::_update $path]
    pack  $f.sizeEntry -fill x

    set sw [ScrolledWindow::create $f.sw -scrollbar vertical -background $bg]
    pack $sw -fill both -expand yes

    set lbs [listbox $sw.lb -height 5 -width 6 \
        -exportselection 0 -selectmode browse \
        -listvariable [Widget::widgetVar $widg data(sizeList)]]
    ScrolledWindow::setwidget $sw $lbs

    LabelFrame::configure $labf2 -focus $f.sizeEntry

    eval [list $lbs insert end] $_sizes

    set script [list SelectFont::_update_size $path %W]

    bind $lbs <1>               [list focus %W]
    bind $lbs <ButtonRelease-1> $script
    bind $lbs <space>           $script
    bind $lbs <Up>              $script
    bind $lbs <Down>            $script
    bind $lbs <KeyRelease-Up>   $script
    bind $lbs <KeyRelease-Down> $script

    set labf3 [LabelFrame::create $topf.labf3 -text "Font Style:" -name style \
                   -side top -anchor w -relief sunken -bd 1 -background $bg]
    set subf  [LabelFrame::getframe $labf3]

    foreach st $_styles {
        set name [lindex [BWidget::getname $st] 0]
        if {![string length $name]} { set name [string toupper $name 0] }

        if {[BWidget::using ttk]} {
            ttk::checkbutton $subf.$st -text $name \
                -command  [list SelectFont::_update $path] \
                -variable [Widget::widgetVar $widg data($st)]
        } else {
            $checkbutton $subf.$st -text $name -background $bg \
                -command  [list SelectFont::_update $path] \
                -variable [Widget::widgetVar $widg data($st)]
        }
        bind $subf.$st <Return> break
        pack $subf.$st -anchor w -padx [list 0 5]
    }
    LabelFrame::configure $labf3 -focus $subf.[lindex $_styles 0]

    pack $labf1 -side left -anchor n -fill both -expand yes
    pack $labf2 -side left -anchor n -fill both -expand yes -padx 8
    pack $labf3 -side left -anchor n -fill both -expand yes

    text $frame.sample -bg #FFFFFF -width 0 -height 3 \
        -font "Courier 10" -wrap none
    $frame.sample tag configure text -justify center -font $font
    $frame.sample insert end [Widget::cget $widg -sampletext] text
    $frame.sample configure -state disabled

    pack $topf -pady 4 -fill both -expand 1
    pack $frame.sample -pady 4 -fill x

    Dialog::add $path -name ok -width 12
    Dialog::add $path -name cancel -width 12

    set data(lbf)  $lbf
    set data(lbs)  $lbs
    set data(text) $frame.sample

    _getfont $path

    Widget::create SelectFont $path 0

    return [_draw $path]
}


proc SelectFont::toolbar { path args } {
    variable _sizes
    variable _styles
    variable _families

    set widg $path#SelectFont

    ## Initialize the internal rep of the widget options.
    Widget::init SelectFont $widg $args

    array set tmp [font actual [Widget::getoption $widg -font]]
    Widget::setoption $widg -size   $tmp(-size)
    Widget::setoption $widg -family $tmp(-family)

    set bg [Widget::getoption $widg -background]

    if {[Widget::getoption $widg -querysystem]} {
        set fams [Widget::getoption $widg -families]
    } else {
        set fams "preset"
        append fams [Widget::getoption $widg -families]
    }

    if {[BWidget::using ttk]} {
        ttk::frame $path
        set lbf [ttk::combobox $path.font \
                -takefocus 0 -exportselection 0 \
                -values $_families($fams) -state readonly \
                -textvariable [Widget::varForOption $widg -family]]
        set lbs [ttk::combobox $path.size \
                -takefocus 0 -exportselection 0 \
                -width 4 -values $_sizes -state readonly \
                -textvariable [Widget::varForOption $widg -size]]
        bind $lbf <<ComboboxSelected>> [list SelectFont::_update $path]
        bind $lbs <<ComboboxSelected>> [list SelectFont::_update $path]
    } else {
        frame $path -background $bg
        set lbf [ComboBox::create $path.font \
                     -highlightthickness 0 -takefocus 0 -background $bg \
                     -values   $_families($fams) \
                     -textvariable [Widget::varForOption $widg -family] \
                     -editable 0 \
                     -modifycmd [list SelectFont::_update $path]]
        set lbs [ComboBox::create $path.size \
                     -highlightthickness 0 -takefocus 0 -background $bg \
                     -width    4 \
                     -values   $_sizes \
                     -textvariable [Widget::varForOption $widg -size] \
                     -editable 0 \
                     -modifycmd [list SelectFont::_update $path]]
    }

    bind $path <Destroy> [list SelectFont::_destroy $path]
    pack $lbf -side left -anchor w
    pack $lbs -side left -anchor w -padx 4

    foreach st $_styles {
        if {[BWidget::using ttk]} {
            ttk::checkbutton $path.$st -takefocus 0 \
                -style BWSlim.Toolbutton \
                -image [Bitmap::get $st] \
                -variable [Widget::widgetVar $widg data($st)] \
                -command [list SelectFont::_update $path]
        } else {
            button $path.$st \
                -highlightthickness 0 -takefocus 0 -padx 0 -pady 0 -bd 2 \
                -background $bg -image  [Bitmap::get $st] \
                -command [list SelectFont::_update_style $path $st]
        }
        pack $path.$st -side left -anchor w
    }
    set data(lbf) $lbf
    set data(lbs) $lbs
    _getfont $path

    return [Widget::create SelectFont $path]
}


# ----------------------------------------------------------------------------
#  Command SelectFont::configure
# ----------------------------------------------------------------------------
proc SelectFont::configure { path args } {
    set widg $path#SelectFont

    set _styles [Widget::getoption $widg -styles]

    set res [Widget::configure $widg $args]

    if { [Widget::hasChanged $widg -font font] } {
        _getfont $path
    }

    if { [Widget::hasChanged $widg -background bg] } {
        switch -- [Widget::getoption $widg -type] {
            "dialog" {
                Dialog::configure $path -background $bg
                set topf [Dialog::getframe $path].topf
                $topf configure -background $bg
                foreach labf {labf1 labf2} {
                    LabelFrame::configure $topf.$labf -background $bg
                    set subf [LabelFrame::getframe $topf.$labf]
                    ScrolledWindow::configure $subf.sw -background $bg
                    $subf.sw.lb configure -background $bg
                }
                LabelFrame::configure $topf.labf3 -background $bg
                set subf [LabelFrame::getframe $topf.labf3]
                foreach w [winfo children $subf] {
                    $w configure -background $bg
                }
            }

            "toolbar" {
                $path configure -background $bg
                ComboBox::configure $path.font -background $bg
                ComboBox::configure $path.size -background $bg
                foreach st $_styles {
                    $path.$st configure -background $bg
                }
            }
        }
    }
    return $res
}


# ----------------------------------------------------------------------------
#  Command SelectFont::cget
# ----------------------------------------------------------------------------
proc SelectFont::cget { path option } {
    return [Widget::cget "$path#SelectFont" $option]
}


# ----------------------------------------------------------------------------
#  Command SelectFont::loadfont
# ----------------------------------------------------------------------------
proc SelectFont::loadfont {{which all}} {
    variable _families

    # initialize families
    if {![info exists _families(all)]} {
	set _families(all) [lsort -dictionary [font families]]
    }

    if {[regexp {fixed|variable} $which] && ![info exists _families($which)]} {
	# initialize families
	set _families(fixed) {}
	set _families(variable) {}
	foreach family $_families(all) {
	    if { [font metrics [list $family] -fixed] } {
		lappend _families(fixed) $family
	    } else {
		lappend _families(variable) $family
	    }
	}
    }
    return
}


proc SelectFont::_update_family { path listbox } {
    set sel [$listbox curselection]
    Widget::setoption $path#SelectFont -family [$listbox get $sel]

    _update $path
}


proc SelectFont::_update_size { path listbox } {
    set sel [$listbox curselection]
    Widget::setoption $path#SelectFont -size [$listbox get $sel]

    _update $path
}


# ----------------------------------------------------------------------------
#  Command SelectFont::_update_style
# ----------------------------------------------------------------------------
proc SelectFont::_update_style { path style } {
    Widget::getVariable $path#SelectFont data

    if { $data($style) == 1 } {
        $path.$style configure -relief raised
        set data($style) 0
    } else {
        $path.$style configure -relief sunken
        set data($style) 1
    }

    _update $path
}


# ----------------------------------------------------------------------------
#  Command SelectFont::_update
# ----------------------------------------------------------------------------
proc SelectFont::_update { path } {
    variable _families
    variable _sizes
    variable _styleOff

    set widg $path#SelectFont

    Widget::getVariable $widg data

    set type    [Widget::getoption $widg -type]
    set size    [Widget::getoption $widg -size]
    set family  [Widget::getoption $widg -family]
    set _styles [Widget::getoption $widg -styles]

    set font    [list $family $size]

    if {[Widget::getoption $widg -querysystem]} {
	set fams [Widget::getoption $widg -families]
    } else {
	set fams "preset"
	append fams [Widget::getoption $widg -families]
    }

    if {[string equal $type "dialog"]} {
        set curs [$path:cmd cget -cursor]
        $path:cmd configure -cursor watch
    }

    foreach st $_styles {
        if {$data($st)} { lappend font $st }
    }
    Widget::setoption $widg -font $font

    if {[string equal $type "dialog"]} {
        $data(text) tag configure text -font $font
        $path:cmd configure -cursor $curs
    }

    set cmd [Widget::getoption $widg -command]
    if {![string equal $cmd ""]} { uplevel \#0 $cmd }
}


# ----------------------------------------------------------------------------
#  Command SelectFont::_draw
# ----------------------------------------------------------------------------
proc SelectFont::_draw { path } {
    set widg $path#SelectFont

    Widget::getVariable $widg data

    set idx [lsearch -exact $data(familyList) [Widget::getoption $widg -family]]
    $data(lbf) selection clear 0 end
    $data(lbf) selection set $idx
    $data(lbf) activate $idx
    $data(lbf) see $idx

    set idx [lsearch -exact $data(sizeList) [Widget::getoption $widg -size]]
    $data(lbs) selection clear 0 end
    $data(lbs) selection set $idx
    $data(lbs) activate $idx
    $data(lbs) see $idx

    _update $path

    if {![Dialog::draw $path]} {
        set result [Widget::getoption $widg -font]
    } else {
        set result ""
    }

    Widget::destroy $widg
    destroy $path

    return $result
}


# ----------------------------------------------------------------------------
#  Command SelectFont::_getfont
# ----------------------------------------------------------------------------
proc SelectFont::_getfont { path } {
    variable _sizes
    variable _families

    set widg $path#SelectFont

    Widget::getVariable $widg data

    array set font [font actual [Widget::getoption $widg -font]]
    set data(bold)       [expr {![string equal $font(-weight) "normal"]}]
    set data(italic)     [expr {![string equal $font(-slant)  "roman"]}]
    set data(underline)  $font(-underline)
    set data(overstrike) $font(-overstrike)
    set _styles [Widget::getoption $widg -styles]
    if {[Widget::getoption $widg -querysystem]} {
	set fams [Widget::getoption $widg -families]
    } else {
	set fams "preset"
	append fams [Widget::getoption $widg -families]
    }

    Widget::setoption $widg -size   $font(-size)
    Widget::setoption $widg -family $font(-family)

    if {[string equal [Widget::getoption $widg -type] "toolbar"]
        && ![BWidget::using ttk]} {
        foreach st $_styles {
            $path.$st configure -relief [expr {$data($st) ? "sunken":"raised"}]
        }
    }
}

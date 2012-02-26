## $Id$
##
## BEGIN LICENSE BLOCK
##
## Copyright (C) 2002  Damon Courtney
## 
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## version 2 as published by the Free Software Foundation.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License version 2 for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the
##     Free Software Foundation, Inc.
##     51 Franklin Street, Fifth Floor
##     Boston, MA  02110-1301, USA.
##
## END LICENSE BLOCK

proc CreateWindow.Background { wizard id } {
    variable images

    proc ::InstallJammer::DrawGradient { win axis col1Str col2Str } {
        if {[winfo class $win] ne "Canvas"} {
            return -code error "$win must be a canvas widget"
        }

        $win delete gradient

        set width  [winfo reqwidth $win]
        set height [winfo reqheight $win]
        switch -- $axis {
            "x" { set max $width;  set x 1 }
            "y" { set max $height; set x 0 }
            default {
                return -code error "Invalid axis $axis: must be x or y"
            }
        }

        if {[catch {winfo rgb $win $col1Str} color1]} {
            return -code error "Invalid color $col1Str"
        }

        if {[catch {winfo rgb $win $col2Str} color2]} {
            return -code error "Invalid color $col2Str"
        }

        foreach {r1 g1 b1} $color1 break
        foreach {r2 g2 b2} $color2 break
        set rRange [expr $r2.0 - $r1]
        set gRange [expr $g2.0 - $g1]
        set bRange [expr $b2.0 - $b1]

        set rRatio [expr $rRange / $max]
        set gRatio [expr $gRange / $max]
        set bRatio [expr $bRange / $max]

        for {set i 0} {$i < $max} {incr i} {
            set nR [expr int( $r1 + ($rRatio * $i) )]
            set nG [expr int( $g1 + ($gRatio * $i) )]
            set nB [expr int( $b1 + ($bRatio * $i) )]

            set col [format {%4.4x} $nR]
            append col [format {%4.4x} $nG]
            append col [format {%4.4x} $nB]
            if {$x} {
                $win create line $i 0 $i $height -tags gradient -fill #${col}
            } else {
                $win create line 0 $i $width $i -tags gradient -fill #${col}
            }
        }

        $win lower gradient

        return $win
    }

    set base [$id window]

    lassign [wm maxsize .] w h

    $id get ShowTitleBar showTitleBar
    $id get HideProgramManager hideProgramManager

    toplevel     $base
    wm withdraw  $base
    update idletasks
    wm transient $base .
    wm protocol  $base WM_DELETE_WINDOW exit

    if {!$showTitleBar} {
    	wm overrideredirect $base 1

        if {$::tcl_platform(platform) ne "windows"} {
            incr w 15
        }

	incr h 10
    } else {
        if {$::tcl_platform(platform) eq "windows"} {
            incr w -10
        } else {
            incr w 5
            incr h -15
        }

        incr h -20
    }

    if {$hideProgramManager} { incr h 100 }

    wm geometry  $base ${w}x${h}+0+0
    wm resizable $base 0 0

    ::InstallJammer::SetTitle $base $id

    set gradient   0
    set background "#FFFFFF"
    $id get TitleFont font
    $id get TextColor foreground
    $id get BackgroundGradient1 gradient1
    $id get BackgroundGradient2 gradient2
    $id get GradientAxis axis
    $id get Image image

    if {(![lempty $gradient1] && [lempty $gradient2])
    	|| ($gradient1 == $gradient2)} {
	## Background color only.
	set background $gradient1
    } else {
	if {![lempty $gradient1] && ![lempty $gradient2]} { set gradient 1 }
    }

    canvas $base.c -background $background -bd 0 -highlightthickness 0 \
        -width $w -height $h
    pack $base.c -expand 1 -fill both

    if {$gradient} {
	switch -- $axis {
	    "horizontal" { set axis x }
	    default      { set axis y }
	}
	::InstallJammer::DrawGradient $base.c $axis $gradient1 $gradient2
    }

    if {![lempty $image]} {
	$base.c create image 40 10 -anchor nw -image $image
    } else {
	$base.c create text 40 10 -anchor nw \
	    -font $font -fill $foreground \
            -text [::InstallJammer::GetText $id Text]
    }

    wm deiconify $base
}

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

proc RaiseStep { wizard id } {
    $wizard itemconfigure $id -title [::InstallJammer::GetText $id Title]
}

namespace eval ::Progressbar {
    variable options
    variable initialized 0
}

proc ::Progressbar::Init {} {
    variable initialized
    variable options

    if {$initialized} { return }
    set initialized 1

    option add *Progressbar.borderWidth	1	widgetDefault
    option add *Progressbar.relief	sunken	widgetDefault

    array set options {
	-troughcolor	"#FFFFFF"
	-value  	0
	-text		"0%"
	-foreground	"#000000"
	-showtext	1
	-doneforeground	"#FFFFFF"
	-background	"#1B009C"
	-height		20
	-width		200
    }
}

proc ::Progressbar::New {w args} {
    variable options

    ::Progressbar::Init

    namespace eval ::Progressbar::$w {
	variable w
	variable percent
	variable options
    }

    upvar #0 ::Progressbar::${w}::options widgetOptions

    array set widgetOptions [array get options]

    foreach {opt val} $args {
	switch -- $opt {
	    "-fg"     { set widgetOptions(-foreground) $val }
	    "-bg"     { set widgetOptions(-background) $val }
	    "-donefg" { set widgetOptions(-doneforeground) $val }
	    default   {
		if {[info exists options($opt)]} {
		    set widgetOptions($opt) $val
		}
	    }
	}
    }

    uplevel 1 [list eval frame $w -class Progressbar]

    set varname ::Progressbar::${w}::percent

    frame $w.l \
    	-borderwidth 0 \
    	-background $widgetOptions(-troughcolor)
    label $w.l.l -textvariable $varname -borderwidth 0 \
	    -foreground $widgetOptions(-foreground) \
    	    -background $widgetOptions(-troughcolor)
    $w.l configure -height [expr {int([winfo reqheight $w.l.l]+2)}]
    frame $w.l.fill -background $widgetOptions(-background)
    label $w.l.fill.l -textvariable $varname -borderwidth 0 \
	    -foreground $widgetOptions(-doneforeground) \
    	    -background $widgetOptions(-background)

    bind $w.l <Configure> [namespace code [list ProgressConf $w "%w"]]

    pack  $w.l -fill both -expand 1
    place $w.l.l -relx 0.5 -rely 0.5 -anchor center
    place $w.l.fill -x 0 -y 0 -relheight 1 -relwidth 0
    place $w.l.fill.l -x 0 -rely 0.5 -anchor center

    rename $w ::Progressbar::${w}::w
    interp alias {} ::$w {} ::Progressbar::WidgetProc $w

    $w configure -value 0 -height $widgetOptions(-height) \
    	-width $widgetOptions(-width)

    return $w
}

proc ::Progressbar::ProgressConf {widget width} {
    place configure $widget.l.fill.l -x [expr {int($width/2)}]
}

proc ::Progressbar::WidgetProc {widget cmd args} {
    set w ::Progressbar::${widget}::w
    upvar #0 ::Progressbar::${widget}::options options

    switch -- $cmd {
	"configure" {
	    set realOpts {}
	    foreach {opt val} $args {
		switch -- $opt {
		    "-value" {
			if {$val > 100} { set val 100 }
			set progress [expr {int(100*$val)/int(100)}]
			set relwidth [expr {double($val)/double(100)}]
			place configure $widget.l.fill -relwidth $relwidth
			if {$options(-showtext)} {
			    set [$widget.l.l cget -textvariable] $val%
			}
		    }
		    "-height" {
			$widget.l configure -height $options(-height)
		    }
		    "-width" {
			$widget.l configure -width $options(-width)
		    }
		    "-troughcolor" {
			$widget.l configure -background $val
			$widget.l.l configure -background $val
		    }
		    "-bg" - "-background" {
			$widget.l.fill configure -background $val
			$widget.l.fill.l configure -background $val
		    }
		    "-fg" - "-foreground" {
			$widget.l.l configure -foreground $val
		    }
		    "-donefg" - "-doneforeground" {
			$widget.l.fill.l configure -foreground $val
		    }
		    "-textvariable" {
			$widget.l.l configure -textvariable $val
			$widget.l.fill.l configure -textvariable $val
		    }
		    "-text" {
			set [$widget.l.l cget -textvariable] $val
		    }
		    "-showtext" {
			set options(-showtext) $val
		    }

		    default {
			lappend realOpts $opt $val
		    }
		}
	    }
	    if {[llength $args] > 0 && [llength $realOpts] == 0} { return }
	    eval $w configure $realOpts
	}

	default {
	    eval $w $cmd $args
	}
    }
}

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

if {[info exists ::InstallJammer]} { return }

namespace eval ::BWIDGET {
    variable LIBRARY [file join $::installkit::root lib InstallJammer]
}

proc BWidgetInit {} {
    set ::BWidget::imageDir $::BWIDGET::LIBRARY
    set ::BWidget::iconLibraryFile [file join $::BWIDGET::LIBRARY icons.tkico]

    BWidget::use ttk
    BWidget::use png
}

namespace eval DragSite    { proc use {} {} }
namespace eval DropSite    { proc use {} {} }
namespace eval DynamicHelp { proc use {} {} }

proc DragSite::include { class type event } {
    set dragoptions [list \
	    [list	-dragenabled	Boolean	0	0] \
	    [list	-draginitcmd	String	""	0] \
	    [list	-dragendcmd	String	""	0] \
	    [list	-dragtype	String	$type	0] \
	    [list	-dragevent	Enum	$event	0	[list 1 2 3]] \
	    ]
    Widget::declare $class $dragoptions
}
proc DragSite::setdrag {args} { }

proc DropSite::include { class types } {
    set dropoptions [list \
	    [list	-dropenabled	Boolean	0	0] \
	    [list	-dropovercmd	String	""	0] \
	    [list	-dropcmd	String	""	0] \
	    [list	-droptypes	String	$types	0] \
	    ]
    Widget::declare $class $dropoptions
}

proc DynamicHelp::include { class type } {
    set helpoptions [list \
	    [list -helptext String "" 0] \
	    [list -helpvar  String "" 0] \
	    [list -helptype Enum $type 0 [list balloon variable]] \
	    ]
    Widget::declare $class $helpoptions
}

proc DropSite::setdrop    { args } { }
proc DropSite::setcursor  { args } { }
proc DynamicHelp::sethelp { args } { }

package provide BWidget 1.8

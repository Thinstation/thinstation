# ----------------------------------------------------------------------------
#  widget.tcl
#  This file is part of Unifix BWidget Toolkit
#  $Id: widget.tcl,v 1.27 2003/10/28 05:03:17 damonc Exp $
# ----------------------------------------------------------------------------
#  Index of commands:
#
#   Public Commands:
#     - Widget::tkinclude
#     - Widget::bwinclude
#     - Widget::declare
#     - Widget::addmap
#     - Widget::init
#     - Widget::destroy
#     - Widget::setoption
#     - Widget::configure
#     - Widget::cget
#     - Widget::subcget
#     - Widget::hasChanged
#     - Widget::options
#
#   Private Commands:
#     - Widget::_get_tkwidget_options
#     - Widget::_test_tkresource
#     - Widget::_test_bwresource
#     - Widget::_test_synonym
#     - Widget::_test_string
#     - Widget::_test_flag
#     - Widget::_test_enum
#     - Widget::_test_int
#     - Widget::_test_boolean
# ----------------------------------------------------------------------------
# Each megawidget gets a namespace of the same name inside the Widget namespace
# Each of these has an array opt, which contains information about the 
# megawidget options.  It maps megawidget options to a list with this format:
#     {optionType defaultValue isReadonly {additionalOptionalInfo}}
# Option types and their additional optional info are:
#	TkResource	{genericTkWidget genericTkWidgetOptionName}
#	BwResource	{nothing}
#	Enum		{list of enumeration values}
#	Int		{Boundary information}
#	Boolean		{nothing}
#	String		{nothing}
#	Flag		{string of valid flag characters}
#	Synonym		{nothing}
#	Color		{nothing}
#
# Next, each namespace has an array map, which maps class options to their
# component widget options:
#	map(-foreground) => {.e -foreground .f -foreground}
#
# Each has an array ${path}:opt, which contains the value of each megawidget
# option for a particular instance $path of the megawidget, and an array
# ${path}:mod, which stores the "changed" status of configuration options.

# Steps for creating a bwidget megawidget:
# 1. parse args to extract subwidget spec
# 2. Create frame with appropriate class and command line options
# 3. Get initialization options from optionDB, using frame
# 4. create subwidgets

# Uses newer string operations
package require Tcl 8.1.1

namespace eval Widget {
    variable _class
    variable _tk_widget

    ## This controls whether we try to use themed widgets from Ttk.
    variable _theme 0

    variable  _optiontype
    array set _optiontype {
        TkResource Widget::_test_tkresource
        BwResource Widget::_test_bwresource
        Enum       Widget::_test_enum
        Int        Widget::_test_int
        Boolean    Widget::_test_boolean
        Boolean2   Widget::_test_boolean2
        String     Widget::_test_string
        Flag       Widget::_test_flag
        Synonym    Widget::_test_synonym
        Color      Widget::_test_color
        Color2     Widget::_test_color2
        Padding    Widget::_test_padding
    }

    proc use {} {}
}


proc Widget::CreateTempWidget { class {command frame} } {
    set class [string map [list :: ""] $class]
    set path  ".#BWidget.#Class#$class"
    if {![winfo exists .#BWidget]} { frame .#BWidget }
    if {![winfo exists $path]} {
        if {[string equal $command "frame"]
            || [string equal $command "toplevel"]} {
            $command $path -class $class
            if {[string equal $command "toplevel"]} { wm withdraw $path }
        } else {
            $command $path
        }
    }
    return $path
}


# ----------------------------------------------------------------------------
#  Command Widget::tkinclude
#     Includes tk widget resources to BWidget widget.
#  class      class name of the BWidget
#  tkwidget   tk widget to include
#  subpath    subpath to configure
#  args       additionnal args for included options
# ----------------------------------------------------------------------------
proc Widget::tkinclude { class tkwidget subpath args } {
    foreach {cmd lopt} $args {
        # cmd can be
        #   include      options to include            lopt = {opt ...}
        #   remove       options to remove             lopt = {opt ...}
        #   rename       options to rename             lopt = {opt newopt ...}
        #   prefix       options to prefix             lopt = {pref opt opt ..}
        #   initialize   set default value for options lopt = {opt value ...}
        #   readonly     set readonly flag for options lopt = {opt flag ...}
        switch -- $cmd {
            remove {
                foreach option $lopt {
                    set remove($option) 1
                }
            }

            include {
                foreach option $lopt {
                    set include($option) 1
                }
            }

            prefix {
                set prefix [lindex $lopt 0]
                foreach option [lrange $lopt 1 end] {
                    set rename($option) "-$prefix[string range $option 1 end]"
                }
            }

            rename - readonly - initialize {
                array set $cmd $lopt
            }

            default {
                return -code error "invalid argument \"$cmd\""
            }
        }
    }

    namespace eval $class {}
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::map classmap
    upvar 0 ${class}::map$subpath submap
    upvar 0 ${class}::optionExports exports
    upvar 0 ${class}::subpaths subpaths

    if {![info exists subpaths($subpath)]} { set subpaths($subpath) [list] }
    eval [list lappend subpaths($subpath)] [array get initialize]

    set widg [Widget::CreateTempWidget $tkwidget $tkwidget]
    # create resources informations from tk widget resources
    foreach optdesc [_get_tkwidget_options $tkwidget] {
        set option [lindex $optdesc 0]

        if {[info exists remove($option)]} { continue }
        if {[info exists include] && ![info exists include($option)]} {continue}

        if {[llength $optdesc] == 3} {
            # option is a synonym
            set syn [lindex $optdesc 1]
            if {![info exists remove($syn)]} {
                # original option is not removed
                if {[info exists rename($syn)]} {
                    set classopt($option) [list Synonym $rename($syn)]
                } else {
                    set classopt($option) [list Synonym $syn]
                }
            }

            continue
        }

        set ro      0
        set value   [lindex $optdesc 1]
        set realopt $option

        if {[info exists rename($option)]} {
            set realopt $option
            set option  $rename($option)
        }

        if {[info exists readonly($option)]} {
            set ro $readonly($option)
        }

        set optionval [list $tkwidget $realopt]
        set classopt($option) [list TkResource $value $ro $optionval]

        if {![info exists initialize($option)]} {
            set conf    [_configure_option $option ""]
            set dbName  [lindex $conf 0]
            set dbClass [lindex $conf 1]

            set def [option get $widg $dbName $dbClass]
            if {[string length $def]} {
                set value $def
                lappend subpaths($subpath) $option $value
            }
        }

        # Add an option database entry for this option
        #set optionDbName ".[lindex [_configure_option $option ""] 0]"
        #if {![string equal $subpath ":cmd"]} {
            #set optionDbName "$subpath$optionDbName"
        #}
        #option add *${class}$optionDbName $value widgetDefault
        #lappend exports($option) "$optionDbName"

        # Store the forward and backward mappings for this
        # option <-> realoption pair
        lappend classmap($option) $subpath "" $realopt
        set submap($realopt) $option
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::bwinclude
#     Includes BWidget resources to BWidget widget.
#  class    class name of the BWidget
#  subclass BWidget class to include
#  subpath  subpath to configure
#  args     additionnal args for included options
# ----------------------------------------------------------------------------
proc Widget::bwinclude { class subclass subpath args } {
    upvar 0 ${subclass}::opt subclassopt

    foreach {cmd lopt} $args {
        # cmd can be
        #   include      options to include          lopt = {opt ...}
        #   remove       options to remove           lopt = {opt ...}
        #   rename       options to rename           lopt = {opt newopt ...}
        #   prefix       options to prefix           lopt = {prefix opt opt ...}
        #   initialize   set default value for options lopt = {opt value ...}
        #   readonly     set readonly flag for options lopt = {opt flag ...}
        switch -- $cmd {
            remove {
                foreach option $lopt {
                    set remove($option) 1
                }
            }

            include {
                foreach option $lopt {
                    set include($option) 1
                }
            }

            prefix {
                set prefix   [lindex $lopt 0]
                set options  [lrange $lopt 1 end]
                set doremove [string equal [lindex $options 0] "remove"]
                if {![llength $options] || $doremove} {
                    set options  [list]
                    set toremove [lrange $options 1 end]
                    foreach option [array names subclassopt] {
                        if {[lsearch -exact $toremove $option] < 0} {
                            lappend options $option
                        }
                    }
                }

                foreach option $options {
                    set rename($option) "-$prefix[string range $option 1 end]"
                }
            }

            rename - readonly - initialize {
                array set $cmd $lopt
            }

            default {
                return -code error "invalid argument \"$cmd\""
            }
        }
    }

    namespace eval $class {}
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::map classmap
    upvar 0 ${class}::map$subpath submap
    upvar 0 ${class}::optionExports exports
    upvar 0 ${subclass}::optionExports subexports
    upvar 0 ${class}::subpaths subpaths

    if {![info exists subpaths($subpath)]} { set subpaths($subpath) [list] }
    eval [list lappend subpaths($subpath)] [array get initialize]

    set path [Widget::CreateTempWidget $class]
    # create resources informations from BWidget resources
    foreach {option optdesc} [array get subclassopt] {
	set subOption $option

        if {[info exists remove($option)]} { continue }
        if {[info exists include] && ![info exists include($option)]} {continue}

        set type [lindex $optdesc 0]
        if {[string equal $type "Synonym"]} {
            # option is a synonym
            set syn [lindex $optdesc 1]
            if {![info exists remove($syn)]} {
                if {[info exists rename($syn)]} {
                    set classopt($option) [list Synonym $rename($syn)]
                } else {
                    set classopt($option) [list Synonym $syn]
                }
            }
            continue
        }

        set ro      [lindex $optdesc 2]
        set value   [lindex $optdesc 1]
        set realopt $option

        if {[info exists rename($option)]} {
            set realopt $option
            set option  $rename($option)
        }

        if {[info exists initialize($option)]} {
            set value $initialize($option)
        }

        if {[info exists readonly($option)]} {
            set ro $readonly($option)
        }

        if {![info exists initialize($option)]} {
            set conf    [_configure_option $option ""]
            set dbName  [lindex $conf 0]
            set dbClass [lindex $conf 1]

            set def [option get $path $dbName $dbClass]
            if {[string length $def]} {
                set value $def
                lappend subpaths($subpath) $option $value
            }
        }

        set classopt($option) [list $type $value $ro [lindex $optdesc 3]]

        # Add an option database entry for this option
        #foreach optionDbName $subexports($subOption) {
            #if {![string equal $subpath ":cmd"]} {
                #set optionDbName "$subpath$optionDbName"
            #}
            # Only add the option db entry if we are overriding the
            # normal widget default
            #if {[info exists initialize($option)]} {
                #option add *${class}$optionDbName $value widgetDefault
            #}
            #lappend exports($option) "$optionDbName"
        #}

        # Store the forward and backward mappings for this
        # option <-> realoption pair
        lappend classmap($option) $subpath $subclass $realopt
        set submap($realopt) $option
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::declare
#    Declares new options to BWidget class.
# ----------------------------------------------------------------------------
proc Widget::declare { class optlist } {
    variable _optiontype

    namespace eval $class {}
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::optionExports exports
    upvar 0 ${class}::optionClass optionClass

    set path [Widget::CreateTempWidget $class]
    foreach optdesc $optlist {
        set option  [lindex $optdesc 0]
        set optdesc [lrange $optdesc 1 end]
        set type    [lindex $optdesc 0]

        if {![info exists _optiontype($type)]} {
            return -code error "invalid option type \"$type\""
        }

        if {[string equal $type "Synonym"]} {
            # test existence of synonym option
            set syn [lindex $optdesc 1]
            if {![info exists classopt($syn)]} {
                return -code error \
                    "unknow option \"$syn\" for Synonym \"$option\""
            }
            set classopt($option) [list Synonym $syn]
            continue
        }

        # all other resource may have default value, readonly flag and
        # optional arg depending on type
        set value [lindex $optdesc 1]
        set ro    [lindex $optdesc 2]
        set arg   [lindex $optdesc 3]

        ## Check the option database for this option.
        set conf    [_configure_option $option ""]
        set dbName  [lindex $conf 0]
        set dbClass [lindex $conf 1]
        set default [option get $path $dbName $dbClass]
        #if {[string length $default]} { set value $default }

        if {[string equal $type "BwResource"]} {
            # We don't keep BwResource. We simplify to type of sub BWidget
            set subclass    [lindex $arg 0]
            set realopt     [lindex $arg 1]
            if {![string length $realopt]} { set realopt $option }

            upvar 0 ${subclass}::opt subclassopt
            if {![info exists subclassopt($realopt)]} {
                return -code error "unknow option \"$realopt\""
            }

            set suboptdesc $subclassopt($realopt)
            if {![string length $value]} {
                # We initialize default value
                set value [lindex $suboptdesc 1]
            }

            set type [lindex $suboptdesc 0]
            set ro   [lindex $suboptdesc 2]
            set arg  [lindex $suboptdesc 3]
	    #set optionDbName ".[lindex [_configure_option $option ""] 0]"
	    #option add *${class}${optionDbName} $value widgetDefault
	    #set exports($option) $optionDbName
            set classopt($option) [list $type $value $ro $arg]
            continue
        }

        # retreive default value for TkResource
        if {[string equal $type "TkResource"]} {
            set tkwidget [lindex $arg 0]
	    set widg [Widget::CreateTempWidget $tkwidget $tkwidget]
            set realopt  [lindex $arg 1]
            if { ![string length $realopt] } {
                set realopt $option
            }
            set tkoptions [_get_tkwidget_options $tkwidget]
            if {![string length $value]} {
                # We initialize default value
		set ind [lsearch $tkoptions [list $realopt *]]
                set value [lindex [lindex $tkoptions $ind] end]
            }
	    #set optionDbName ".[lindex [_configure_option $option ""] 0]"
	    #option add *${class}${optionDbName} $value widgetDefault
	    #set exports($option) $optionDbName
            set classopt($option) [list TkResource $value $ro \
		    [list $tkwidget $realopt]]
	    set optionClass($option) [lindex [$widg configure $realopt] 1]
            continue
        }

        if {[string equal $type "Color"]} {
            if {[info exists ::BWidget::colors($value)]} {
                set value $::BWidget::colors($value)
            }
        }

	#set optionDbName ".[lindex [_configure_option $option ""] 0]"
	#option add *${class}${optionDbName} $value widgetDefault
	#set exports($option) $optionDbName

        # for any other resource type, we keep original optdesc
        set classopt($option) [list $type $value $ro $arg]
    }
}


proc Widget::define { class filename args } {
    variable _inuse
    variable ::BWidget::use

    proc ::${class}::use {} {}

    if {[set x [lsearch -exact $args "-classonly"]] > -1} {
	set args [lreplace $args $x $x]
    } else {
	interp alias {} ::${class} {} ${class}::create

        ## Define the basic cget and configure commands every
        ## widget should have.
        proc ::${class}::cget { path option } {
            return [Widget::cget $path $option]
        }

        proc ::${class}::configure { path args } {
            return [Widget::configure $path $args]
        }

        ## Bind the class to cleanup BWidget information
        ## when a BWidget is destroyed.
	bind $class <Destroy> [list Widget::destroy %W]
    }

    set _inuse($class) 0

    set use($class)      $args
    set use($class,file) $filename
    lappend use(classes) $class

    foreach class $args { ${class}::use }
}


proc Widget::create { class path {rename 1} } {
    if {$rename} { rename $path ::$path:cmd }
    set cmd "${class}::\$cmd"
    proc ::$path { cmd args } \
    	[subst {return \[eval \[linsert \$args 0 $cmd [list $path]\]\]}]
    return $path
}


# ----------------------------------------------------------------------------
#  Command Widget::addmap
# ----------------------------------------------------------------------------
proc Widget::addmap { class subclass subpath options } {
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::optionExports exports
    upvar 0 ${class}::optionClass optionClass
    upvar 0 ${class}::map classmap
    upvar 0 ${class}::map$subpath submap
    upvar 0 ${class}::subpaths subpaths

    if {![info exists subpaths($subpath)]} { set subpaths($subpath) [list] }

    foreach {option realopt} $options {
        if {![string length $realopt]} { set realopt $option }

	#set val [lindex $classopt($option) 1]
	#set optDb ".[lindex [_configure_option $realopt ""] 0]"
	#if { ![string equal $subpath ":cmd"] } {
	    #set optDb "$subpath$optDb"
	#}
	#option add *${class}${optDb} $val widgetDefault
	#lappend exports($option) $optDb

	# Store the forward and backward mappings for this
	# option <-> realoption pair
        lappend classmap($option) $subpath $subclass $realopt
	set submap($realopt) $option

        lappend subpaths($subpath) $realopt [lindex $classopt($option) 1]
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::syncoptions
# ----------------------------------------------------------------------------
proc Widget::syncoptions { class subclass subpath options } {
    upvar 0 ${class}::sync classync
    upvar 0 ${class}::subpaths subpaths

    if {![info exists subpaths($subpath)]} { set subpaths($subpath) [list] }

    foreach {option realopt} $options {
        if {![string length $realopt]} { set realopt $option }
        set classync($option) [list $subpath $subclass $realopt]
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::init
# ----------------------------------------------------------------------------
proc Widget::init { class path options {initFromODB 0} } {
    variable _inuse

    upvar 0 Widget::_optiontype opttype
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::map classmap
    upvar 0 ${class}::$path:opt  pathopt
    upvar 0 ${class}::$path:mod  pathmod
    upvar 0 ${class}::$path:init pathinit

    if {[info exists pathopt]} { unset pathopt }
    if {[info exists pathmod]} { unset pathmod }

    # We prefer to use the actual widget for option db queries, but if it
    # doesn't exist yet, do the next best thing:  create a widget of the
    # same class and use that.
    set fpath    $path
    set rdbclass [string map [list :: ""] $class]
    if {![winfo exists $path]} { set fpath [Widget::CreateTempWidget $class] }

    foreach {option optdesc} [array get classopt] {
        set pathmod($option) 0
	if {[info exists classmap($option)]} { continue }

        set type [lindex $optdesc 0]
        if {[string equal $type "Synonym"]} { continue }

        set alt ""
        if {[string equal $type "TkResource"]} {
            set alt [lindex [lindex $optdesc 3] 1]
        }

        set optdb [lindex [_configure_option $option $alt] 0]
        set def   [option get $fpath $optdb $rdbclass]
        if {[string length $def]} {
            set pathopt($option) $def
        } else {
            set pathopt($option) [lindex $optdesc 1]
        }
    }

    if {![info exists _inuse($class)]} { set _inuse($class) 0 }
    incr _inuse($class)

    set Widget::_class($path) $class

    if {$initFromODB} {
        array set pathopt $options
    } else {
        foreach {option value} $options {
            if {![info exists classopt($option)]} {
                unset pathopt
                unset pathmod
                return -code error "unknown option \"$option\""
            }

            set optdesc $classopt($option)
            set type    [lindex $optdesc 0]
            if {[string equal $type "Synonym"]} {
                set option  [lindex $optdesc 1]
                set optdesc $classopt($option)
                set type    [lindex $optdesc 0]
            }

            set arg [lindex $optdesc 3]
            set pathopt($option)  [$opttype($type) $option $value $arg]
            set pathinit($option) $pathopt($option)
        }
    }
}


# Widget::initFromODB --
#
#	Initialize a megawidgets options with information from the option
#	database and from the command-line arguments given.
#
# Arguments:
#	class	class of the widget.
#	path	path of the widget -- should already exist.
#	options	command-line arguments.
#
# Results:
#	None.

proc Widget::initFromODB { class path options } {
    Widget::init $class $path $options 1
}


# Bastien Chevreux (bach@mwgdna.com)
#
# copyinit performs basically the same job as init, but it uses a
#  existing template to initialize its values. So, first a perferct copy
#  from the template is made just to be altered by any existing options
#  afterwards.
# But this still saves time as the first initialization parsing block is
#  skipped.
# As additional bonus, items that differ in just a few options can be
#  initialized faster by leaving out the options that are equal.

# This function is currently used only by ListBox::multipleinsert, but other
#  calls should follow :)

# ----------------------------------------------------------------------------
#  Command Widget::copyinit
# ----------------------------------------------------------------------------
proc Widget::copyinit { class templatepath path options } {
    upvar 0 ${class}::opt classopt \
	    ${class}::$path:opt	 pathopt \
	    ${class}::$path:mod	 pathmod \
	    ${class}::$path:init pathinit \
	    ${class}::$templatepath:opt	 templatepathopt \
	    ${class}::$templatepath:mod	 templatepathmod \
	    ${class}::$templatepath:init templatepathinit

    if {[info exists pathopt]} { unset pathopt }
    if {[info exists pathmod]} { unset pathmod }

    # We use the template widget for option db copying, but it has to exist!
    array set pathmod  [array get templatepathmod]
    array set pathopt  [array get templatepathopt]
    array set pathinit [array get templatepathinit]

    set Widget::_class($path) $class
    foreach {option value} $options {
	if {![info exists classopt($option)]} {
	    unset pathopt
	    unset pathmod
	    return -code error "unknown option \"$option\""
	}

	set optdesc $classopt($option)
	set type    [lindex $optdesc 0]
	if {[string equal $type "Synonym"]} {
	    set option	[lindex $optdesc 1]
	    set optdesc $classopt($option)
	    set type	[lindex $optdesc 0]
	}

        set arg [lindex $optdesc 3]
	set pathopt($option)  [$Widget::_optiontype($type) $option $value $arg]
	set pathinit($option) $pathopt($option)
    }
}


# Widget::parseArgs --
#
#	Given a widget class and a command-line spec, cannonize and validate
#	the given options, and return a keyed list consisting of the 
#	component widget and its masked portion of the command-line spec, and
#	one extra entry consisting of the portion corresponding to the 
#	megawidget itself.
#
# Arguments:
#	class	  Widget class to parse for.
#	options	  Command-line spec.
#       errorOut  If true, an error will be thrown for invalid options.
#
# Results:
#	result	keyed list of portions of the megawidget and that segment of
#		the command line in which that portion is interested.
proc Widget::parseArgs { class options {errorOut 1} } {
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::map classmap

    foreach {option val} $options {
	if {![info exists classopt($option)]} {
            if {$errorOut} { return -code error "unknown option \"$option\"" }
            continue
	}

        set optdesc $classopt($option)
        set type    [lindex $optdesc 0]
        if {[string equal $type "Synonym"]} {
            set option  [lindex $optdesc 1]
            set optdesc $classopt($option)
            set type    [lindex $optdesc 0]
        }

	if {[string equal $type "TkResource"]} {
	    # Make sure that the widget used for this TkResource exists
	    Widget::_get_tkwidget_options [lindex [lindex $optdesc 3] 0]
	}

	set val [$Widget::_optiontype($type) $option $val [lindex $optdesc 3]]
		
	if {[info exists classmap($option)]} {
	    foreach {subpath subclass realopt} $classmap($option) {
		lappend maps($subpath) $realopt $val
	    }
	} else {
	    lappend maps($class) $option $val
	}
    }

    return [array get maps]
}


# Widget::initArgs --
#
#       Given a widget class and a command-line spec, setup the default
#       values for each subpath of the widget with the initial values we
#       stored when creating the class.  Then, parse the arguments and
#       append any further command-line arguments to overwrite the initial
#       values.  Store the results in the given arrayName.
#
# Arguments:
#	class	   Widget class to parse for.
#	options	   Command-line spec.
#       arrayName  Array to store the maps.
#
# Results:
#       Empty string

proc Widget::initArgs { class options arrayName } {
    upvar 1 $arrayName maps
    upvar 0 ${class}::subpaths subpaths

    ## Setup empty lists for each subpath.
    array set maps [list $class {} :cmd {}]
    foreach subpath [array names subpaths] {
        set maps($subpath) [list]
    }
    
    ## Setup the array with the default values for each subpath
    array set maps [array get subpaths]

    ## Parse the arguments and append them to our array.
    foreach {var val} [Widget::parseArgs $class $options] {
        eval lappend maps($var) $val
    }
}


# Widget::splitArgs --
#
#       Given multiple widget classes and a list of arguments, parse
#       the arguments and set each class with the list of arguments
#       that pertain to it.  Any argument that exists in none of the
#       given classes will simply be lost in the returned array map.
#
#       Note: This proc does not return an error for invalid arguments.
#
# Arguments: options class ?class ...?
#	options	  Command-line spec.
#	class	  Widget class to parse for.
#
# Results:
#       A map of classes to options.

proc Widget::splitArgs { options args } {
    array set maps [list :cmd {}]
    foreach class $args {
        if {![info exists maps($class)]} { set maps($class) [list] }
        array set maps [Widget::parseArgs $class $options 0]
    }

    return [array get maps]
}


# Widget::optionExists --
#
#       Determine whether a given option exists for a given class.
#
# Arguments:
#       class    Widget class.
#       option   Widget option.
#
# Results:
#       True if the option exists for the class, false otherwise.
proc Widget::optionExists { class option } {
    return [info exists ${class}::opt($option)]
}


# Widget::class --
#
#       Return the class of a given widget.
#
# Arguments:
#       path    Widget name.
#
# Results:
#       The class name of the widget.
proc Widget::class { path } {
    if {[info exists Widget::_class($path)]} { return $Widget::_class($path) }
    return -code error "unknown widget $path"
}


# ----------------------------------------------------------------------------
#  Command Widget::destroy
# ----------------------------------------------------------------------------
proc Widget::destroy { path {unsetVariables 1} } {
    variable _class
    variable _inuse

    if {[info exists _class($path)]} {
        set class $_class($path)

        if {[info exists _inuse($class)]} { incr _inuse($class) -1 }

        if {![string equal [info commands $path] ""]} { rename $path "" }

        ## Unset the variables that all widgets use.
        foreach x {opt mod init} {
            if {[info exists ${class}::$path:$x]} {
                unset ${class}::$path:$x
            }
        }

        ## Unset any other variables used in this widget.
        if {$unsetVariables} { eval unset [info vars ${class}::$path:*] }

        unset _class($path)
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::configure
# ----------------------------------------------------------------------------
proc Widget::configure { path options } {
    set len [llength $options]
    if {$len < 2} { return [_get_configure $path $options] }
    if {$len % 2} { return -code error "incorrect number of arguments" }

    variable _class
    variable _optiontype

    set class $_class($path)
    upvar 0 ${class}::opt  classopt
    upvar 0 ${class}::map  classmap
    upvar 0 ${class}::$path:opt pathopt
    upvar 0 ${class}::$path:mod pathmod

    set window [_get_window $class $path]
    foreach {option value} $options {
        if {![info exists classopt($option)]} {
            return -code error "unknown option \"$option\""
        }

        set optdesc $classopt($option)
        set type    [lindex $optdesc 0]
        if {[string equal $type "Synonym"]} {
            set option  [lindex $optdesc 1]
            set optdesc $classopt($option)
            set type    [lindex $optdesc 0]
        }

        ## If the option is read-only just skip it.
        if {[lindex $optdesc 2]} { continue }

        set newval [$_optiontype($type) $option $value [lindex $optdesc 3]]

        if {[info exists classmap($option)]} {
            set window [_get_window $class $window]
            foreach {subpath subclass realopt} $classmap($option) {
                if {[string length $subclass]} {
                    set curval [${subclass}::cget $window$subpath $realopt]
                    ${subclass}::configure $window$subpath $realopt $newval
                } else {
                    set curval [$window$subpath cget $realopt]
                    $window$subpath configure $realopt $newval
                }
            }
        } else {
            set curval $pathopt($option)
            set pathopt($option) $newval
        }

        set pathmod($option) [expr {![string equal $newval $curval]}]
    }

    return
}


# ----------------------------------------------------------------------------
#  Command Widget::cget
# ----------------------------------------------------------------------------
proc Widget::cget { path option } {
    if {![info exists ::Widget::_class($path)]} {
        return -code error "unknown widget \"$path\""
    }

    set class $::Widget::_class($path)
    if {![info exists ${class}::opt($option)]} {
        return -code error "unknown option \"$option\""
    }

    set optdesc [set ${class}::opt($option)]
    set type    [lindex $optdesc 0]
    if {[string equal $type "Synonym"]} {
        set option [lindex $optdesc 1]
    }

    if {[info exists ${class}::map($option)]} {
	foreach {subpath subclass realopt} [set ${class}::map($option)] {break}
	set path "[_get_window $class $path]$subpath"
	return [$path cget $realopt]
    }
    upvar 0 ${class}::$path:opt pathopt
    set pathopt($option)
}


# ----------------------------------------------------------------------------
#  Command Widget::subcget
# ----------------------------------------------------------------------------
proc Widget::subcget { path subwidget } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::$path:opt pathopt
    upvar 0 ${class}::map$subwidget submap
    upvar 0 ${class}::$path:init pathinit

    set result [list]
    foreach realopt [array names submap] {
	if {[info exists pathinit($submap($realopt))]} {
	    lappend result $realopt $pathopt($submap($realopt))
	}
    }
    return $result
}


# ----------------------------------------------------------------------------
#  Command Widget::hasChanged
# ----------------------------------------------------------------------------
proc Widget::hasChanged { path option varName } {
    upvar 1 $varName value
    Widget::getVariable $path mod pathmod

    set value   [Widget::cget $path $option]
    set result  $pathmod($option)
    set pathmod($option) 0

    return $result
}

proc Widget::hasChangedX { path option args } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::$path:mod pathmod

    set result  $pathmod($option)
    set pathmod($option) 0
    foreach option $args {
	lappend result $pathmod($option)
	set pathmod($option) 0
    }

    set result
}


proc Widget::anyChangedX { path args } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::$path:mod pathmod

    set result 0
    foreach option $args {
        incr result $pathmod($option)
        set pathmod($option) 0
    }
    return $result
}


# Widget::getoption --
#
#	Bypass the superfluous checks in cget and just directly peer at the
#	widget's data space.  This is much more fragile than cget, so it 
#	should only be used with great care, in places where speed is critical.
#
# Arguments:
#	path	widget to lookup options for.
#	option	option to retrieve.
#
# Results:
#	value	option value.
proc Widget::getoption { path option } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::${path}:opt pathopt
    set pathopt($option)
}


# Widget::setoption --
#
#	Bypass the superfluous checks in cget and just directly poke at the
#	widget's data space.  This is much more fragile than configure, so it 
#	should only be used with great care, in places where speed is critical.
#
# Arguments:
#	path	widget to lookup options for.
#	option	option to retrieve.
#	value	option value.
#
# Results:
#	value	option value.
proc Widget::setoption { path args } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::${path}:opt pathopt
    foreach [list option value] $args {
        set pathopt($option) $value
    }
}


# Widget::getMegawidgetOption -- (deprecated -- use Widget::getoption)
#
#	Bypass the superfluous checks in cget and just directly peer at the
#	widget's data space.  This is much more fragile than cget, so it 
#	should only be used with great care, in places where speed is critical.
#
# Arguments:
#	path	widget to lookup options for.
#	option	option to retrieve.
#
# Results:
#	value	option value.
proc Widget::getMegawidgetOption { path option } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::${path}:opt pathopt
    set pathopt($option)
}


# Widget::setMegawidgetOption -- (deprecated -- use Widget::setoption)
#
#	Bypass the superfluous checks in cget and just directly poke at the
#	widget's data space.  This is much more fragile than configure, so it 
#	should only be used with great care, in places where speed is critical.
#
# Arguments:
#	path	widget to lookup options for.
#	option	option to retrieve.
#	value	option value.
#
# Results:
#	value	option value.
proc Widget::setMegawidgetOption { path option value } {
    set class $::Widget::_class($path)
    upvar 0 ${class}::${path}:opt pathopt
    set pathopt($option) $value
}


# ----------------------------------------------------------------------------
#  Command Widget::_get_window
#  returns the window corresponding to widget path
# ----------------------------------------------------------------------------
proc Widget::_get_window { class path } {
    set idx [expr {[string last "#" $path] + 1}]
    if {$idx && [string equal [string range $path $idx end] $class]} {
        return [string range $path 0 [expr {$idx - 2}]]
    }
    return $path
}


# ----------------------------------------------------------------------------
#  Command Widget::_get_configure
#  returns the configuration list of options
#  (as tk widget do - [$w configure ?option?])
# ----------------------------------------------------------------------------
proc Widget::_get_configure { path options } {
    variable _class

    set class $_class($path)
    upvar 0 ${class}::opt classopt
    upvar 0 ${class}::$path:opt pathopt

    if {[llength $options] == 1} {
        ## Just return the option description for the one option.
        set option  [lindex $options 0]
        if { ![info exists classopt($option)] } {
            return -code error "unknown option \"$option\""
        }
        set optdesc $classopt($option)
        set type    [lindex $optdesc 0]
        if { [string equal $type "Synonym"] } {
            set option  [lindex $optdesc 1]
            set optdesc $classopt($option)
            set type    [lindex $optdesc 0]
        }
        if { [string equal $type "TkResource"] } {
            set alt [lindex [lindex $optdesc 3] 1]
        } else {
            set alt ""
        }

        set res [list $option]
        eval lappend res [_configure_option $option $alt]
        lappend res [lindex $optdesc 1] [${class}::cget $path $option]

        return $res
    }

    ## Return a list of option descriptions for all of the
    ## options for this widget.

    set result [list]
    foreach option [lsort [array names classopt]] {
        set alt     ""
        set syn     ""
        set optdesc $classopt($option)
        set type    [lindex $optdesc 0]

        if {[string equal $type "Synonym"]} {
            set syn     $option
            set option  [lindex $optdesc 1]
            set optdesc $classopt($option)
            set type    [lindex $optdesc 0]
        }

        if {[string equal $type "TkResource"]} {
            set alt [lindex [lindex $optdesc 3] 1]
        }

        set res [_configure_option $option $alt]
        if {![string length $syn]} {
            lappend result [concat $option $res \
                    [list [lindex $optdesc 1]] [list [cget $path $option]]]
        } else {
            lappend result [list $syn [lindex $res 0]]
        }
    }

    return $result
}


# ----------------------------------------------------------------------------
#  Command Widget::_configure_option
# ----------------------------------------------------------------------------
proc Widget::_configure_option { option altopt } {
    variable _optiondb
    variable _optionclass

    if {[info exists _optiondb($option)]} {
        set optdb $_optiondb($option)
    } else {
        set optdb [string range $option 1 end]
    }

    if {[info exists _optionclass($option)]} {
        set optclass $_optionclass($option)
    } elseif {[string length $altopt]} {
        if {[info exists _optionclass($altopt)]} {
            set optclass $_optionclass($altopt)
        } else {
            set optclass [string range $altopt 1 end]
        }
    } else {
        set optclass [string range $option 1 end]
    }

    return [list $optdb $optclass]
}


# ----------------------------------------------------------------------------
#  Command Widget::_get_tkwidget_options
# ----------------------------------------------------------------------------
proc Widget::_get_tkwidget_options { tkwidget } {
    variable _tk_widget
    variable _optiondb
    variable _optionclass
    
    if {![info exists _tk_widget($tkwidget)]} {
        set widget [Widget::CreateTempWidget $tkwidget $tkwidget]

	set config [$widget configure]
	foreach optlist $config {
	    set opt [lindex $optlist 0]
	    if {[llength $optlist] == 2} {
		set refsyn [lindex $optlist 1]

		# search for class
		set idx [lsearch $config [list * $refsyn *]]
		if {$idx == -1} {
		    if {[string index $refsyn 0] == "-"} {
			# search for option (tk8.1b1 bug)
			set idx [lsearch $config [list $refsyn * *]]
		    } else {
			# last resort
                        set refsyn [string tolower $refsyn]
			set idx [lsearch $config [list -$refsyn * *]]
		    }

		    if {$idx == -1} {
			# fed up with "can't read classopt()"
			return -code error "can't find option of synonym $opt"
		    }
		}

		set syn [lindex [lindex $config $idx] 0]
		# JDC: used 4 (was 3) to get def from optiondb
		set def [lindex [lindex $config $idx] 4]
		lappend _tk_widget($tkwidget) [list $opt $syn $def]
	    } else {
		# JDC: used 4 (was 3) to get def from optiondb
		set def [lindex $optlist 4]
		lappend _tk_widget($tkwidget) [list $opt $def]
		set _optiondb($opt)    [lindex $optlist 1]
		set _optionclass($opt) [lindex $optlist 2]
	    }
	}
    }

    return $_tk_widget($tkwidget)
}


# ----------------------------------------------------------------------------
#  Command Widget::_test_tkresource
# ----------------------------------------------------------------------------
proc Widget::_test_tkresource { option value arg } {
    set tkwidget [lindex $arg 0]
    set realopt  [lindex $arg 1]
    set path     [Widget::CreateTempWidget $tkwidget $tkwidget]
    set old      [$path cget $realopt]
    $path configure $realopt $value
    set res      [$path cget $realopt]
    $path configure $realopt $old
    return $res
}


# ----------------------------------------------------------------------------
#  Command Widget::_test_bwresource
# ----------------------------------------------------------------------------
proc Widget::_test_bwresource { option value arg } {
    return -code error "bad option type BwResource in widget"
}


# ----------------------------------------------------------------------------
#  Command Widget::_test_synonym
# ----------------------------------------------------------------------------
proc Widget::_test_synonym { option value arg } {
    return -code error "bad option type Synonym in widget"
}

# ----------------------------------------------------------------------------
#  Command Widget::_test_color
# ----------------------------------------------------------------------------
proc Widget::_test_color { option value arg } {
    ## Check to see if this is a BWidget named color.
    if {[info exists ::BWidget::colors($value)]} {
        set value $::BWidget::colors($value)
    }

    if {[catch {winfo rgb . $value} color]} {
        return -code error \
            "bad $option value \"$value\": must be a colorname or #RRGGBB"
    }

    return $value
}


proc Widget::_test_color2 { option value arg } {
    if {![string length $value]} { return }

    ## Check to see if this is a BWidget named color.
    if {[info exists ::BWidget::colors($value)]} {
        set value $::BWidget::colors($value)
    }

    if {[catch {winfo rgb . $value} color]} {
        return -code error \
            "bad $option value \"$value\": must be a colorname or #RRGGBB"
    }

    return $value
}


# ----------------------------------------------------------------------------
#  Command Widget::_test_string
# ----------------------------------------------------------------------------
proc Widget::_test_string { option value arg } {
    return $value
}


# ----------------------------------------------------------------------------
#  Command Widget::_test_flag
# ----------------------------------------------------------------------------
proc Widget::_test_flag { option value arg } {
    set len [string length $value]
    set res ""
    for {set i 0} {$i < $len} {incr i} {
        set c [string index $value $i]
        if {[string first $c $arg] == -1} {
            set name [string range $option 1 end]
            return -code error [BWidget::badOptionString $name $value $arg]
        }
        if {[string first $c $res] == -1} { append res $c }
    }
    return $res
}


# -----------------------------------------------------------------------------
#  Command Widget::_test_enum
# -----------------------------------------------------------------------------
proc Widget::_test_enum { option value arg } {
    if {[lsearch -exact $arg $value] == -1} {
        set name [string range $option 1 end]
        return -code error [BWidget::badOptionString $name $value $arg]
    }
    return $value
}


# -----------------------------------------------------------------------------
#  Command Widget::_test_int
# -----------------------------------------------------------------------------
proc Widget::_test_int { option value arg } {
    set map [list %d $value]
    if {![string is int -strict $value]
        || ([string length $arg] && ![expr [string map $map $arg]])} {
        return -code error \
            "bad $option value \"$value\": must be integer ($arg)"
    }
    return $value
}


# -----------------------------------------------------------------------------
#  Command Widget::_test_boolean
# -----------------------------------------------------------------------------
proc Widget::_test_boolean { option value arg } {
    if {![string is boolean -strict $value]} {
        set name [string range $option 1 end]
        return -code error [BWidget::badOptionString $name $value boolean]
    }

    # Get the canonical form of the boolean value (1 for true, 0 for false)
    return [string is true $value]
}


# -----------------------------------------------------------------------------
#  Command Widget::_test_boolean2
#
# A Boolean2 can be either an empty string or a boolean value.
# -----------------------------------------------------------------------------
proc Widget::_test_boolean2 { option value arg } {
    if {![string is boolean $value]} {
        set name [string range $option 1 end]
        set opts [list empty boolean]
        return -code error [BWidget::badOptionString $name $value $opts]
    }

    # Get the canonical form of the boolean value (1 for true, 0 for false)
    if {[string length $value]} { return [string is true $value] }
}


# -----------------------------------------------------------------------------
#  Command Widget::_test_padding
# -----------------------------------------------------------------------------
proc Widget::_test_padding { option values arg } {
    set len [llength $values]
    if {$len < 1 || $len > 2} {
        return -code error \
            "bad pad value \"$values\": must be positive screen distance"
    }

    foreach value $values {
        set map [list %d $value]
        if {![string is int -strict $value]
            || ([string length $arg] && ![expr [string map $map $arg]])} {
            return -code error \
                "bad pad value \"$value\": must be positive screen distance"
        }
    }
    return $values
}


# Widget::_get_padding --
#
#       Return the requesting padding value for a padding option.
#
# Arguments:
#	path		Widget to get the options for.
#       option          The name of the padding option.
#	index		The index of the padding.  If the index is empty,
#                       the first padding value is returned.
#
# Results:
#	Return a numeric value that can be used for padding.
proc Widget::_get_padding { args } {
    if {[llength $args] == 2} {
        set padding [lindex $args 0]
        set index   [lindex $args 1]
    } elseif {[llength $args] == 3} {
        set path    [lindex $args 0]
        set option  [lindex $args 1]
        set index   [lindex $args 2]
        set padding [Widget::cget $path $option]
    }
    set val [lindex $padding $index]
    if {![string length $val]} { set val [lindex $padding 0] }
    return $val
}


# -----------------------------------------------------------------------------
#  Command Widget::focusNext
#  Same as tk_focusNext, but call Widget::focusOK
# -----------------------------------------------------------------------------
proc Widget::focusNext { w } {
    set cur $w
    while 1 {

	# Descend to just before the first child of the current widget.

	set parent $cur
	set children [winfo children $cur]
	set i -1

	# Look for the next sibling that isn't a top-level.

	while 1 {
	    incr i
	    if {$i < [llength $children]} {
		set cur [lindex $children $i]
		if {[winfo toplevel $cur] == $cur} {
		    continue
		} else {
		    break
		}
	    }

	    # No more siblings, so go to the current widget's parent.
	    # If it's a top-level, break out of the loop, otherwise
	    # look for its next sibling.

	    set cur $parent
	    if {[winfo toplevel $cur] == $cur} {
		break
	    }
	    set parent [winfo parent $parent]
	    set children [winfo children $parent]
	    set i [lsearch -exact $children $cur]
	}
	if {($cur == $w) || [focusOK $cur]} {
	    return $cur
	}
    }
}


# -----------------------------------------------------------------------------
#  Command Widget::focusPrev
#  Same as tk_focusPrev, but call Widget::focusOK
# -----------------------------------------------------------------------------
proc Widget::focusPrev { w } {
    set cur $w
    while 1 {

	# Collect information about the current window's position
	# among its siblings.  Also, if the window is a top-level,
	# then reposition to just after the last child of the window.
    
	if {[winfo toplevel $cur] == $cur}  {
	    set parent $cur
	    set children [winfo children $cur]
	    set i [llength $children]
	} else {
	    set parent [winfo parent $cur]
	    set children [winfo children $parent]
	    set i [lsearch -exact $children $cur]
	}

	# Go to the previous sibling, then descend to its last descendant
	# (highest in stacking order.  While doing this, ignore top-levels
	# and their descendants.  When we run out of descendants, go up
	# one level to the parent.

	while {$i > 0} {
	    incr i -1
	    set cur [lindex $children $i]
	    if {[winfo toplevel $cur] == $cur} {
		continue
	    }
	    set parent $cur
	    set children [winfo children $parent]
	    set i [llength $children]
	}
	set cur $parent
	if {($cur == $w) || [focusOK $cur]} {
	    return $cur
	}
    }
}


# ----------------------------------------------------------------------------
#  Command Widget::focusOK
#  Same as tk_focusOK, but handles -editable option and whole tags list.
# ----------------------------------------------------------------------------
proc Widget::focusOK { w } {
    set code [catch {$w cget -takefocus} value]
    if {$code == 1} { return 0 }

    if {!$code && [string length $value]} {
	if {$value == 0} {
	    return 0
	} elseif {$value == 1} {
	    return [winfo viewable $w]
	} else {
	    set value [uplevel \#0 $value $w]
            if {[string length $value]} { return $value }
        }
    }

    if {![winfo viewable $w]} { return 0 }

    set code [catch {$w cget -state} value]
    if {!$code && [string equal $value "disabled"]} { return 0 }

    set code [catch {$w cget -editable} value]
    if {!$code && $value == 0} { return 0 }

    set top [winfo toplevel $w]
    foreach tag [bindtags $w] {
        if {![string equal $tag $top]
            && ![string equal $tag "all"]
            && [string match *Key* [bind $tag]]} {
            return 1
        }
    }
    return 0
}


proc Widget::traverseTo { w } {
    set focus [focus]
    if {[string length $focus]} {
	event generate $focus <<TraverseOut>>
    }
    focus $w

    event generate $w <<TraverseIn>>
}


# Widget::varForOption --
#
#	Retrieve a fully qualified variable name for the option specified.
#	If the option is not one for which a variable exists, throw an error 
#	(ie, those options that map directly to widget options).
#
# Arguments:
#	path	megawidget to get an option var for.
#	option	option to get a var for.
#
# Results:
#	varname	name of the variable, fully qualified, suitable for tracing.

proc Widget::varForOption { path option } {
    variable _class
    variable _optiontype

    set class $_class($path)
    upvar 0 ${class}::$path:opt pathopt

    if {![info exists pathopt($option)]} {
	return -code error "unable to find variable for option \"$option\""
    }

    return ::Widget::${class}::$path:opt($option)
}


proc Widget::widgetVar { path varName } {
    set class $Widget::_class($path)
    return ::Widget::${class}::$path:$varName
}


# Widget::getVariable --
#
#       Get a variable from within the namespace of the widget.
#
# Arguments:
#	path		Megawidget to get the variable for.
#	varName		The variable name to retrieve.
#       newVarName	The variable name to refer to in the calling proc.
#
# Results:
#	Creates a reference to newVarName in the calling proc.
proc Widget::getVariable { path varName {newVarName ""} } {
    if {![string length $newVarName]} { set newVarName $varName }
    uplevel 1 [list upvar \#0 [Widget::widgetVar $path $varName] $newVarName]
}


# Widget::options --
#
#       Return a key-value list of options for a widget.  This can
#       be used to serialize the options of a widget and pass them
#       on to a new widget with the same options.
#
# Arguments:
#	path		Widget to get the options for.
#	args		A list of options.  If empty, all options are returned.
#
# Results:
#	Returns list of options as: -option value -option value ...
proc Widget::options { path args } {
    if {[llength $args]} {
        foreach option $args {
            lappend options [_get_configure $path $option]
        }
    } else {
        set options [_get_configure $path {}]
    }

    set result [list]
    foreach list $options {
        if {[llength $list] < 5} { continue }
        lappend result [lindex $list 0] [lindex $list end]
    }
    return $result
}


# Widget::getOption --
#
#	Given a list of widgets, determine which option value to use.
#	The widgets are given to the command in order of lowest to
#	highest.  Starting with the lowest widget, whichever one does
#	not match the default option value is returned as the value.
#	If all the widgets are default, we return the highest widget's
#	value.
#
# Arguments:
#	option		The option to check.
#	default		The default value.  If any widget in the list
#			does not match this default, its value is used.
#	args		A list of widgets.
#
# Results:
#	Returns the value of the given option to use.
#
proc Widget::getOption { option default args } {
    foreach widget $args {
	set value  [Widget::getoption $widget $option]
        if {$value != $default} { break }
    }
    return $value
}


proc Widget::cgetOption { option default args } {
    foreach widget $args {
	set value  [Widget::cget $widget $option]
        if {$value != $default} { break }
    }
    return $value
}


# Widget::nextIndex --
#
#       Given a widget path and a node name, substitute all occurrences
#       of #auto with the next index number for the path.
#
# Arguments:
#       path            The widget path.
#       node            The name of the node.
#
# Results:
#       Returns a string to use as the new name for the node.
#
proc Widget::nextIndex { path node } {
    Widget::getVariable $path autoIndex
    if {![info exists autoIndex]} { set autoIndex -1 }
    return [string map [list #auto [incr autoIndex]] $node]
}


# Widget::exists --
#
#       Determine if the given widget path exists in the BWidget system.
#
# Arguments:
#       path            The widget path.
#
# Results:
#       Returns boolean.
#
proc Widget::exists { path } {
    return [info exists ::Widget::_class($path)]
}


proc Widget::theme {{bool {}}} {
    # Private, *experimental* API that may change at any time - JH
    variable _theme
    if {[llength [info level 0]] == 2} {
        # set theme-ability
        if {[catch {package require tile 0.6}]
            && [catch {package require tile 1}]} {
            return -code error "BWidget's theming requires tile 0.6+"
        } else {
            catch {style default BWSlim.Toolbutton -padding 0}
        }
        set _theme [string is true -strict $bool]
    }
    return $_theme
}

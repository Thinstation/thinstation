# ------------------------------------------------------------------------------
#  icons.tcl
#  $Id$
# ------------------------------------------------------------------------------
#  Index of commands:
#     - IconLibrary::delete
#     - IconLibrary::image
#     - IconLibrary::load
# ------------------------------------------------------------------------------

if {0} {
    ## Example of how to load a KDE theme as an icon library.
    ## Replace $kdedir with the directory where the KDE theme is.

    ## Create the icon library.
    IconLibrary icons

    icons load -find 1 -directory $kdedir -extension png -findgroups \
            [list {actions act} {apps app} {devices dev}
                {filesystems file} {mimetypes mime}]
}


package require Tcl 8.4

namespace eval IconLibrary {
    Widget::define IconLibrary icons

    Widget::declare IconLibrary {
        {-file          String    "tkIcons"                 0}
        {-icons         String    ""                        0}
        {-sizes         String    ""                        0}
        {-groups        String    ""                        0}
        {-create        Boolean   0                         0}
        {-directory     String    ""                        0}

        {-find          Boolean   0                         0}
        {-extension     String    "gif"                     0}
        {-findsizes     String    "16 22"                   0}
        {-findgroups    String    "act app dev file mime"   0}
    }

    namespace eval Icon {
        Widget::declare IconLibrary::Icon {
            {-size      String    ""                        1}
            {-type      String    ""                        1}
            {-file      String    ""                        1}
            {-data      String    ""                        1}
            {-image     String    ""                        1}
            {-imageargs String    ""                        1}
            {-filegroup String    ""                        1}
            {-workgroup String    ""                        1}
        }
    }

    namespace eval NamesArgs {
        Widget::declare IconLibrary::NamesArgs {
            {-icons         String    ""                        0}
            {-sizes         String    ""                        0}
            {-groups        String    ""                        0}
        }
    }

    ## Setup a quick look-up array of common icon sizes.
    variable  sizeMap
    array set sizeMap {
        16x16   16
        22x22   22
        32x32   32
        48x48   48
        64x64   64
        128x128 128
    }

    variable  groupMapArray
    array set groupMapArray {
        apps            app
        actions         act
        devices         dev
        mimetypes       mime
        filesystems     file
    }

    variable groupMap 

    foreach name [array names groupMapArray] {
        lappend groupMap [list $name $groupMapArray($name)]
    }
}


proc IconLibrary::create { library args } {
    Widget::init IconLibrary $library $args

    Widget::getVariable $library data

    set data(icons) [list]

    if {[llength $args]} { eval [list IconLibrary::load $library] $args }

    return [Widget::create IconLibrary $library 0]
}


proc IconLibrary::load { library args } {
    Widget::getVariable $library data

    Widget::init IconLibrary $library $args

    set file      [Widget::getoption $library -file]
    set create    [Widget::getoption $library -create]
    set iconlist  [Widget::getoption $library -icons]
    set sizelist  [Widget::getoption $library -sizes]
    set grouplist [Widget::getoption $library -groups]
    set directory [Widget::getoption $library -directory]

    set filename $file
    if {![string length $directory]} {
        set directory [file dirname $file]
    } elseif {[string length $file]} {
        set filename [file join $directory $file]
    }

    if {[Widget::getoption $library -find]} {
        if {![string length $directory]} {
            return -code error "cannot find images without -directory"
        }

        set ext        [Widget::getoption $library -extension]
        set findsizes  [Widget::getoption $library -findsizes]
        set findgroups [Widget::getoption $library -findgroups]

        foreach size $findsizes {
            set size  [IconLibrary::_get_size $size]

            set sizedir [file join $directory $size]
            if {![file exists $sizedir]} { continue }

            foreach group $findgroups {
                set filegroup [lindex $group 0]
                set workgroup [lindex $group 1]
                if {[llength $group] == 1} { set workgroup $filegroup }

                set groupdir [file join $sizedir $filegroup]
                if {![file exists $groupdir]} { continue }

                foreach imagefile [glob -nocomplain -dir $groupdir *.$ext] {
                    set image [file root [file tail $imagefile]]
                    set image $workgroup$image$size
                    lappend data(icons) $image

                    set icon $library#$image
                    set exists [expr {[Widget::exists $icon]
                        && [string length [Widget::getoption $icon -image]]}]

                    Widget::init IconLibrary::Icon $icon \
                        [list -size $size -type file -file $imagefile \
                        -filegroup $filegroup -workgroup $workgroup \
                        -data "" -image ""]

                    ## If we already had this icon, and the image had
                    ## already been created, we want to re-create it.
                    if {$exists && !$create} {
                        IconLibrary::image $library $image
                    }
                }
            }
        }

        if {![file exists $filename]} {
            if {$create} { _create_icons $library $data(icons) }
            set data(icons) [lsort -unique $data(icons)]
            return $data(icons)
        }
    }

    if {![file isfile $filename] || ![file readable $filename]} {
        return -code error "couldn't open \"$filename\": no such file"
    }

    set iLen [llength $iconlist]
    set sLen [llength $sizelist]
    set gLen [llength $grouplist]

    set fp [open $filename]

    while {[gets $fp line] != -1} {
        if {[string equal [string index $line 0] "#"]} { continue }

        set list [split $line :]
        if {[llength $list] < 5} { continue }

        BWidget::lassign $list image workgroup filegroup size type imagedata
        set size [IconLibrary::_get_size_int $size]

        if {($gLen && [lsearch -exact $grouplist $workgroup] < 0)
            || ($sLen && [lsearch -exact $sizelist $size] < 0)
            || ($iLen && [lsearch -exact $iconlist $image] < 0)} { continue }

        set file ""
        if {[string equal $type "file"]} {
            if {![string length $imagedata]} { continue }

            if {[string is integer $size]} { set size ${size}x${size} }
            set file [file join $directory $size $filegroup $imagedata]
            set images($image,file) $file
        }

        lappend data(icons) $image

        set icon $library#$image
        set exists [expr {[Widget::exists $icon]
            && [string length [Widget::getoption $icon -image]]}]

        Widget::init IconLibrary::Icon $icon \
            [list -size $size -type $type -file $file -data $imagedata \
            -filegroup $filegroup -workgroup $workgroup -image ""]

        ## If we already had this icon, and the image had
        ## already been created, we want to re-create it.
        if {$exists && !$create} {
            IconLibrary::image $library $image
        }
    }

    close $fp

    if {$create} { _create_icons $library $icons }

    set data(icons) [lsort -unique $data(icons)]
}


proc IconLibrary::cget { library option } {
    return [Widget::cget $library $option]
}


proc IconLibrary::configure { library args } {
    return [Widget::configure $library $args]
}


proc IconLibrary::itemcget { library image option } {
    if {![IconLibrary::exists $library $image]} {
        return -code error "no such icon '$image'"
    }

    set path    $library#$image
    set image   [Widget::getoption $path -image]
    set created [string length $image]
    if {$created && ($option eq "-file" || $option eq "-data")} {
        return [$image cget $option]
    }
    return [Widget::cget $path $option]
}


proc IconLibrary::itemconfigure { library image args } {
    if {![IconLibrary::exists $library $image]} {
        return -code error "no such icon '$image'"
    }

    set path    $library#$image
    set image   [Widget::getoption $path -image]
    set created [string length $image]

    if {![llength $args]} {
        set return [list]
        foreach list [Widget::configure $path $args] {
            set option [lindex $list 0]
            if {$created && ($option eq "-file" || $option eq "-data")} {
                lappend return [$image configure $option]
            } else {
                lappend return $list
            }
        }
        return $return
    } elseif {[llength $args] == 1} {
        set option [lindex $args 0]
        if {$created && ($option eq "-file" || $option eq "-data")} {
            return [$image configure $option]
        } else {
            return [Widget::configure $path $option]
        }
    }

    set imageOpts  [list]
    set widgetOpts [list]
    foreach [list option value] $args {
        if {$created && ($option eq "-file" || $option eq "-data")} {
            lappend imageOpts $option $value
        } else {
            lappend widgetOpts $option $value
        }
    }

    if {[llength $imageOpts]} {
        eval [list $image configure] $imageOpts
    }

    if {[llength $widgetOpts]} {
        Widget::configure $path $widgetOpts
    }
}


proc IconLibrary::exists { library image } {
    return [Widget::exists $library#$image]
}


proc IconLibrary::icons { library {pattern ""} } {
    Widget::getVariable $library data
    if {![string length $pattern]} { return $data(icons) }
    return [lsearch -glob -all -inline $data(icons) $pattern]
}


proc IconLibrary::add { library image args } {
    Widget::getVariable $library data

    if {[IconLibrary::exists $library $image]} {
        return -code error "icon \"$image\" already exists"
    }

    array set _args $args

    set create 0
    if {[info exists _args(-create)]} {
        if {$_args(-create)} { set create 1 }
        unset _args(-create)
    }

    Widget::init IconLibrary::Icon $library#$image [array get _args]
    lappend data(icons) $image

    if {$create} { IconLibrary::image $library $image }

    return $image
}


proc IconLibrary::image { library image } {
    Widget::getVariable $library images

    if {![IconLibrary::exists $library $image]} {
        return -code error "no such icon '$image'"
    }

    set path $library#$image

    ## If an icon is type 'icon', it's a link to another
    ## icon in the library.
    if {[string equal [Widget::getoption $path -type] "icon"]} {
        set icon  $image
        set image [Widget::getoption $path -data]
        set path  $library#$image
        if {![IconLibrary::exists $library $image]} {
            return -code error "no such icon '$image' while loading '$icon'"
        }
    }

    if {![string length [Widget::getoption $path -image]]} {
        set img ::Icons::${library}::$image

        set data [Widget::getoption $path -data]
        set file [Widget::getoption $path -file]
        set args [Widget::getoption $path -imageargs]

        if {[string length $data]} {
            lappend args -data $data
        } elseif {[string length $file]} {
            lappend args -file $file
        }

        eval [list ::image create photo $img] $args

        Widget::setoption $path -image $img -file "" -data ""
    }

    return [Widget::getoption $path -image]
}


proc IconLibrary::delete { library args } {
    Widget::getVariable $library data

    set images [list]
    foreach icon $args {
        set image [Widget::getoption $library#$icon -image]
        if {[string length $image]} { lappend images $image }
        Widget::destroy $library#$icon 0
    }

    if {[llength $images]} { eval ::image delete $images }

    set data(icons) [eval [list BWidget::lremove $data(icons)] $args]

    return
}


proc IconLibrary::clear { library } {
    Widget::getVariable $library data
    eval [list IconLibrary::delete $library] $data(icons)
}


proc IconLibrary::destroy { library } {
    IconLibrary::clear $library
    Widget::destroy $library
}


proc IconLibrary::_get_size { size } {
    if {[string is integer -strict $size]} { return ${size}x${size} }
    return $size
}


proc IconLibrary::_get_size_int { size } {
    variable sizeMap
    if {[info exists sizeMap($size)]} { return $sizeMap($size) }
    if {[scan $size "%dx%d" w h] == 2 && $w == $h} { return $w }
    return $size
}


proc IconLibrary::_create_icons { library icons } {
    foreach icon $icons {
        IconLibrary::image $library $icon
    }
}

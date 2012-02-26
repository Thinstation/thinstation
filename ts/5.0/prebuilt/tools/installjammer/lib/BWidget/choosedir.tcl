namespace eval ChooseDirectory {
    Widget::define ChooseDirectory choosedir Dialog ScrolledWindow \
        Tree IconLibrary

    Widget::bwinclude ChooseDirectory Dialog :cmd

    Widget::declare ChooseDirectory {
        {-name          String   ""        1}
        {-message       String   "Please choose a directory, then select OK." 0}
        {-folders       String   ""        0}
        {-newfoldertext String   "Make New Folder" 0}
        {-oktext        String   ""        0}
        {-canceltext    String   ""        0}
        {-initialdir    String   ""        0}
        {-includevfs    Boolean  "0"       0}
    }

    bind ChooseDirectory <Destroy> [list ChooseDirectory::_destroy %W]
}


proc ChooseDirectory::create { path args } {
    variable dialogs

    BWidget::LoadBWidgetIconLibrary

    set dialog $path#choosedir

    array set maps [Widget::splitArgs $args Dialog ChooseDirectory]

    Widget::initFromODB ChooseDirectory $dialog $maps(ChooseDirectory)

    Widget::getVariable $dialog nodes
    set nodes(count) 0

    eval [list Dialog::create $path -class ChooseDirectory \
        -anchor e -default 1 -cancel 2 -modal local -spacing 5 -homogeneous 0 \
        -title "Browse for Folder"] $maps(:cmd) $maps(Dialog)
    wm minsize  $path 340 300
    wm protocol $path WM_DELETE_WINDOW [list $path cancel]

    Widget::getVariable $path folder

    set frame [Dialog::getframe $path]

    grid rowconfigure    $frame 3 -weight 1
    grid columnconfigure $frame 0 -weight 1

    Label $frame.message -anchor w -autowrap 1 -justify left \
        -text [Widget::getoption $dialog -message]
    grid  $frame.message -row 0 -column 0 -sticky new -pady 5

    if {[BWidget::using ttk]} {
        ttk::entry $frame.e -textvariable [Widget::widgetVar $path folder]
    } else {
        entry $frame.e -textvariable [Widget::widgetVar $path folder]
    }
    grid $frame.e -row 2 -column 0 -sticky ew -pady 2 -padx 1
    trace add variable [Widget::widgetVar $path folder] write \
        [list ChooseDirectory::_update_ok_button $path]

    ScrolledWindow $frame.sw
    grid $frame.sw -row 3 -column 0 -sticky news

    set tree $frame.tree
    Tree $tree -width 35 \
        -opencmd  [list ChooseDirectory::_open_directory $path $tree] \
        -closecmd [list ChooseDirectory::_close_directory $path $tree]

    $frame.sw setwidget $tree

    bind $tree <<TreeSelect>> \
        [list ChooseDirectory::_selection_change $path $tree]

    set text [Widget::getoption $dialog -newfoldertext]
    Dialog::add $path -text " $text " -spacing 20 -state disabled \
        -command [list ChooseDirectory::_create_directory $path $tree]

    set text [Widget::getoption $dialog -oktext]
    if {$text eq ""} {
        Dialog::add $path -name ok -width 12 \
            -command [list ChooseDirectory::_validate_directory $path]
    } else {
        Dialog::add $path -text $text -width 12 \
            -command [list ChooseDirectory::_validate_directory $path]
    }

    set text [Widget::getoption $dialog -canceltext]
    if {$text eq ""} {
        Dialog::add $path -name cancel -width 12
    } else {
        Dialog::add $path -text $text -width 12
    }

    set initdir [Widget::getoption $dialog -initialdir]
    if {$initdir eq ""} {
        set cwd [pwd]
    } else {
        set cwd $initdir
    }
    set cwd [file normalize $cwd]

    set folders [Widget::getoption $dialog -folders]
    if {![llength $folders]} {
        set desktop   [file normalize [file join ~ Desktop]]
        set documents [file normalize [file join ~ Documents]]

        set desktopText   "Desktop"
        set documentsText "Documents"
        if {[info exists ::env(HOME)]} {
            if {$::tcl_platform(platform) eq "windows"} {
                foreach text {"Documents" "My Documents"} {
                    set dir [file join ~ $text]
                    if {[file exists $dir]} {
                        set documents     $dir
                        set documentsText $text
                        break
                    }
                }
            } else {
                lappend folders [list [file normalize ~] "Home"]
            }
        }

        if {[file exists $desktop]} {
            lappend folders [list [file normalize $desktop] $desktopText]
        }

        if {[file exists $documents]} {
            lappend folders [list [file normalize $documents] $documentsText]
        }

        if {$::tcl_platform(platform) eq "windows"} {
            foreach volume [file volumes] {
                set volume [string toupper $volume]
                if {[string match "?:/" $volume]} {
                    lappend volumes $volume
                    lappend folders [list $volume [string range $volume 0 1]]
                }
            }

            set volume [lindex [file split $cwd] 0]
            if {[lsearch -exact $volumes $volume] < 0} {
                lappend folders [list $volume $volume]
            }
        } else {
            lappend folders [list / /]
        }
    }

    foreach list $folders {
        set dir   [lindex $list 0]
        set text  [lindex $list 1]
        set image [lindex $list 2]

        if {![string length $image]} { set image [BWidget::Icon folder16] }

        set nodes(root,$dir) [incr nodes(count)]
        $tree insert end root $nodes(root,$dir) -text $text -image $image \
            -data $dir -drawcross allways
    }

    set name [Widget::getoption $dialog -name]
    if {[info exists dialogs($name)]} { set cwd $dialogs($name) }

    if {[file exists $cwd]} {
        set dirpath [list]
        foreach sub [file split $cwd] {
            if {![llength $dirpath]} {
                set node $nodes(root,$sub)
                set rootNode $node

                lappend dirpath $sub
                $tree itemconfigure $node -open 1
            } else {
                set parent $node
                lappend dirpath $sub
                set subpath [eval file join $dirpath]

                if {![info exists nodes($rootNode,$subpath)]} {
                    set nodes($rootNode,$subpath) [incr nodes(count)]
                    $tree insert end $parent $nodes($rootNode,$subpath) \
                        -open 1 -image [BWidget::Icon folder16] -text $sub \
                        -data $subpath
                }
                set node $nodes($rootNode,$subpath)
            }

            ChooseDirectory::_open_directory $path $tree $node
        }

        _select_directory $path $tree $node
    } elseif {$initdir ne ""} {
        set folder [file nativename [file normalize $initdir]]
    }

    $frame.e selection range 0 end

    set result [Dialog::draw $path $frame.e]

    set dir $folder

    destroy $path

    if {$result == 2} { return }

    if {[string length $name]} { set dialogs($name) $dir }

    return $dir
}


proc ChooseDirectory::_select_directory { path tree node } {
    $tree see $node
    $tree selection set $node
    ChooseDirectory::_selection_change $path $tree
}


proc ChooseDirectory::_selection_change { path tree } {
    Widget::getVariable $path folder

    set node   [$tree selection get]
    set folder [file nativename [$tree itemcget $node -data]]

    [$path getframe].e selection clear

    if {[file writable $folder]} {
        ButtonBox::itemconfigure $path.bbox 0 -state normal
    } else {
        ButtonBox::itemconfigure $path.bbox 0 -state disabled
    }
}


proc ChooseDirectory::_open_directory { path tree node } {
    Widget::getVariable $path#choosedir nodes

    set parent   [$tree parent $node]
    set rootNode $node
    while {$parent ne "root"} {
        set rootNode $parent
        set parent   [$tree parent $parent]
    }

    set sort -ascii
    if {$::tcl_platform(platform) eq "windows"} { set sort -dict }

    set rootdir [$tree itemcget $node -data]

    set dirs [glob -nocomplain -type d -dir $rootdir *]
    eval lappend dirs [glob -nocomplain -type {d hidden} -dir $rootdir *]

    set found 0
    set include [Widget::getoption $path#choosedir -includevfs]
    foreach dir [lsort $sort $dirs] {
        if {!$include && [string match "*vfs*" [file system $dir]]} { continue }
        set tail [file tail $dir]
        if {$tail eq "." || $tail eq ".."} { continue }

        set found 1
        if {![info exists nodes($rootNode,$dir)]} {
            set nodes($rootNode,$dir) [incr nodes(count)]
            $tree insert end $node $nodes($rootNode,$dir) \
                -drawcross allways -image [BWidget::Icon folder16] \
                -text [file tail $dir] -data $dir
        }
    }

    set opts [list -open 1 -image [BWidget::Icon folderopen16]]

    if {!$found} { lappend opts -drawcross never }
    eval [list $tree itemconfigure $node] $opts
}


proc ChooseDirectory::_close_directory { path tree node } {
    $tree itemconfigure $node -image [BWidget::Icon folder16]
}


proc ChooseDirectory::_next_directory { root text } {
    set i 1
    set dir [file join $root $text]
    while {[file exists $dir]} {
        set dir [file join $root "$text ([incr i])"]
    }
    return $dir
}


proc ChooseDirectory::_create_directory { path tree } {
    Widget::getVariable $path folder
    Widget::getVariable $path#choosedir nodes

    set sel [lindex [$tree selection get] 0]
    $tree itemconfigure $sel -open 1

    set text [_next_directory $folder "New Folder"]
    set i [$tree insert end $sel new#auto -text [file tail $text] \
        -image [BWidget::Icon folder16]]

    $tree edit $i [file tail $text] \
        [list ChooseDirectory::_verify_new_directory $path $tree $i] 1

    set dir [file join $folder [$tree itemcget $i -text]]

    set parent   [$tree parent $sel]
    set rootNode $sel
    while {$parent ne "root"} {
        set rootNode $parent
        set parent   [$tree parent $parent]
    }

    set nodes($rootNode,$dir) [incr nodes(count)]
    set node $nodes($rootNode,$dir)

    $tree delete $i
    $tree insert end $sel $node -text [file tail $dir] -data $dir \
        -image [BWidget::Icon folder16]

    _select_directory $path $tree $node

    file mkdir $dir
}


proc ChooseDirectory::_verify_new_directory { path tree node newtext } {
    Widget::getVariable $path folder

    set txt [$tree itemcget $node -text]
    if {![string length $newtext]} { set newtext $txt }

    set dir [file join $folder $newtext]

    if {[regexp {[/\\:\*\?\"<>|]} $newtext]} {
        set title  "Error Renaming File or Folder"
        set msg "A directory name cannot contain any of the following\
            characters:\n\t\\ / : * ? \" < > |"
        tk_messageBox -parent $path -icon error -title $title -message $msg
        return 0
    }

    if {[file exists $dir]} {
        set title  "Error Renaming File or Folder"
        set    msg "Cannot rename $txt: A file with the name you specified "
        append msg "already exists. Specify a different file name."
        tk_messageBox -parent $path -icon error -title $title -message $msg
        return 0
    }

    $tree itemconfigure $node -text $newtext
    return 1
}


proc ChooseDirectory::_update_ok_button { path args } {
    if {[Widget::exists $path]} {
        Widget::getVariable $path folder
        if {[string trim $folder] eq ""} {
            ButtonBox::itemconfigure $path.bbox 1 -state disabled
        } else {
            ButtonBox::itemconfigure $path.bbox 1 -state normal
        }
    }
}


proc ChooseDirectory::_validate_directory { path } {
    Widget::getVariable $path folder

    set dir $folder
    if {[file pathtype $dir] eq "relative"} {
        set dir [file join [pwd] $dir]
    }
    set dirs [file split $dir]
    if {$::tcl_platform(platform) eq "windows"} {
        set drive [lindex $dirs 0]
        if {[string match {[a-zA-Z]:/} $drive]} {
            set dirs [lrange $dirs 1 end]
        }
    }

    foreach dir $dirs {
        if {[regexp {[:\*\?\"<>|]} $dir]} {
            set title  "Error in Folder Name"
            set msg "A directory name cannot contain any of the following\
                characters:\n\t\\ / : * ? \" < > |"
            tk_messageBox -parent $path -icon error -title $title -message $msg
            return
        }
    }

    set folder [file normalize $folder]

    $path enddialog 1
}


proc ChooseDirectory::_destroy { path } {
    Widget::destroy $path#choosedir
    Widget::destroy $path
}

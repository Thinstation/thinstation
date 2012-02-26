## TODO
##
## Need to handle details view.  Turn on the view menubutton when we do.
##
## Need to handle the autoposting and type-ahead on the file combobox.
## Turn it back into a combobox when we do.
##

namespace eval ChooseFile {
    if {[BWidget::using ttk]} {
        Widget::define ChooseFile choosefile Dialog ScrolledWindow \
            ListBox IconLibrary
    } else {
        Widget::define ChooseFile choosefile Dialog ScrolledWindow \
            ComboBox ListBox IconLibrary
    }

    Widget::bwinclude ChooseFile Dialog :cmd

    Widget::declare ChooseFile {
        {-name             String   ""         1}
        {-type             Enum     "open"     0 {open save}}
        {-folders          String   ""         0}
        {-restrictdir      Boolean  0          0}
        {-defaultextension String   ""         0}
        {-filetypes        String   ""         0}
        {-initialdir       String   ""         0}
        {-initialfile      String   ""         0}
        {-multiple         Boolean  0          0}
        {-message          String   ""         0}
        {-title            String   ""         0}
        {-includevfs       Boolean  0          0}
    }

    bind ChooseFile <Map>     [list ChooseFile::_map %W]
    bind ChooseFile <Destroy> [list ChooseFile::_destroy %W]
}


proc ChooseFile::create { path args } {
    variable dialogs

    BWidget::LoadBWidgetIconLibrary

    set dialog $path#choosefile

    array set maps [Widget::splitArgs $args Dialog ChooseFile]

    Widget::initFromODB ChooseFile $dialog $maps(ChooseFile)

    Widget::getVariable $dialog data

    set data(histidx)    0
    set data(history)    [list]
    set data(realized)   0
    set data(showHidden) 0

    set n [expr {20 / [set x [font measure TkTextFont " "]]}]
    if {$x * $n < 20} { incr n }
    set data(comboSpaces) $n
    set data(listboxPadx) [expr {$n * $x}]

    set type [Widget::getoption $dialog -type]

    array set _args $args
    if {![info exists _args(-title)]} {
        if {$type eq "open"} {
            set title "Open"
        } elseif {$type eq "save"} {
            set title "Save As"
        }
    } else {
        set title $_args(-title)
    }

    Widget::setoption $dialog -title $title

    eval [list Dialog::create $path -class ChooseFile -geometry 400x250 \
        -modal local -title $title] $maps(:cmd) $maps(Dialog)
    wm minsize  $path 400 250
    wm protocol $path WM_DELETE_WINDOW [list ChooseFile::enddialog $path 0]
    bind $path <Escape> [list ChooseFile::enddialog $path 0]

    set frame [Dialog::getframe $path]

    grid rowconfigure    $frame 2 -weight 1
    grid columnconfigure $frame 1 -weight 1

    set pady 2
    set message [Widget::getoption $dialog -message]

    if {[string length $message]} {
        set pady 0
        Label $frame.message -anchor w -autowrap 1 -justify left -text $message
        grid  $frame.message -row 0 -column 1 -sticky new -pady {0 5}
    }

    set f [frame $frame.top -height 26]
    grid $f -row 1 -column 1 -sticky ew -padx 5 -pady $pady

    label $f.l -text "Look in:"
    pack  $f.l -side left

    set data(FolderCombo) $f.cb

    if {[BWidget::using ttk]} {
        set comboBoxCmd   ttk::combobox
        set comboBoxEvent <<ComboboxSelected>>
        set opts [list -style Toolbutton]
	set bwidth ""

        $comboBoxCmd $data(FolderCombo) -state readonly \
            -textvariable [Widget::widgetVar $dialog data(dirtail)]

        set popdown ::tile::combobox::PopdownShell
        if {![string length [info commands $popdown]]} {
            set popdown ::ttk::combobox::PopdownShell
        }
        set shell [$popdown $data(FolderCombo)]
        set listbox $shell.l
        destroy $listbox $shell.sb

        bind $shell <Unmap> [list after idle [list focus $frame.listbox]]

        ScrolledWindow $shell.sw
        grid $shell.sw -row 0 -column 0 -sticky news

        ListBox $listbox -borderwidth 2 -relief flat -deltay 18 \
            -highlightthickness 0 -selectmode single -selectfill 1 \
            -yscrollcommand [list $shell.sb set] -padx $data(listboxPadx)
        $shell.sw setwidget $listbox

        $listbox bindText  <1> \
            [list ChooseFile::_select_folder $path $data(FolderCombo)]
        $listbox bindImage <1> \
            [list ChooseFile::_select_folder $path $data(FolderCombo)]

        $listbox bindText  <Enter> [list $listbox selection set]
        $listbox bindImage <Enter> [list $listbox selection set]

        set data(FolderListBox) $listbox
    } else {
        set comboBoxCmd   ComboBox
        set comboBoxEvent <<ComboBoxSelected>>
        set opts [list -relief link]
	set bwidth 12

        $comboBoxCmd $data(FolderCombo) -editable 0 -usebwlistbox 1 \
            -hottrack 1 -textvariable [Widget::widgetVar $dialog data(dirtail)]

        set data(FolderListBox) [$data(FolderCombo) getlistbox]
        $data(FolderListBox) configure -deltay 18 -padx $data(listboxPadx)

        bind $data(FolderCombo) <<ComboBoxSelected>> \
            [list ChooseFile::_select_folder $path $data(FolderCombo)]
    }
    pack $data(FolderCombo) -side left -padx 5 -expand 1 -fill both

    set data(FolderIconLabel) [label $path.icon -bg #FFFFFF]

    ButtonBox $f.bbox -spacing 1
    pack $f.bbox -side left

    eval [list $f.bbox add -image [BWidget::Icon actback16] \
        -command [list ChooseFile::_back $path] \
        -helptext "Go To Last Folder Visited"] $opts

    eval [list $f.bbox add -image [BWidget::Icon actup16] \
        -command [list ChooseFile::_up $path] \
        -helptext "Up One Level"] $opts

    eval [list $f.bbox add -image [BWidget::Icon foldernew16] \
        -command [list ChooseFile::_create_directory $path] \
        -helptext "Create New Folder"] $opts

    if 0 {
    menu $path.viewPopup -tearoff 0
    $path.viewPopup add radiobutton -label "List"
    $path.viewPopup add radiobutton -label "Details"

    if {[BWidget::using ttk]} {
        ttk::menubutton $f.view -menu $path.viewPopup
    } else {
        menubutton $f.view -menu $path.viewPopup
    }
    $f.view configure -image [BWidget::Icon viewmulticolumn16]
    pack $f.view -side left
    } ; # if 0

    ScrolledWindow $frame.sw
    grid $frame.sw -row 2 -column 1 -sticky news -padx 5 -pady {2 5}

    set selectmode single
    if {[Widget::getoption $dialog -type] eq "open"
        && [Widget::getoption $dialog -multiple]} { set selectmode multiple }

    ListBox $frame.listbox -deltay 18 -multicolumn 1 -selectmode $selectmode
    $frame.sw setwidget $frame.listbox

    bind $frame.listbox <<ListboxSelect>> \
        [list ChooseFile::_update_selection $path]

    $frame.listbox bindText  <Double-1> [list ChooseFile::_double_click $path]
    $frame.listbox bindImage <Double-1> [list ChooseFile::_double_click $path]

    ttk::checkbutton $frame.hiddencb -text "Show hidden directories" \
        -variable [Widget::widgetVar $dialog data(showHidden)] \
        -command  [list ChooseFile::_refresh_view $path]
    grid $frame.hiddencb -row 3 -column 1 -sticky nw -padx 10 -pady 2

    set f [frame $frame.bottom]
    grid $f -row 4 -column 1 -sticky ew -padx 5

    grid columnconfigure $f 1 -weight 1

    label $f.fileNameL -text "File name:"
    grid  $f.fileNameL -row 0 -column 0 -pady 2

    set data(FileEntry) $f.fileNameCB

    #$comboBoxCmd $data(FileEntry) \
            #-textvariable [Widget::widgetVar $dialog data(filetail)]
    if {[BWidget::using ttk]} {
        ttk::entry $data(FileEntry) \
            -textvariable [Widget::widgetVar $dialog data(filetail)]
    } else {
        entry $data(FileEntry) \
            -textvariable [Widget::widgetVar $dialog data(filetail)]
    }
    grid $data(FileEntry) -row 0 -column 1 -padx 20 -pady 2 -sticky ew

    bind $data(FileEntry) <Return> [list ChooseFile::enddialog $path 1]

    focus $data(FileEntry)

    Button $f.ok -text [string totitle $type] -width $bwidth \
    	-command [list ChooseFile::enddialog $path 1]
    grid $f.ok -row 0 -column 2 -pady 2 -sticky ew

    label $f.fileTypeL -text "Files of type:"
    grid  $f.fileTypeL -row 1 -column 0 -pady 2

    $comboBoxCmd $f.fileTypeCB -state readonly \
        -textvariable [Widget::widgetVar $dialog data(filetype)]
    grid $f.fileTypeCB -row 1 -column 1 -pady 2 -padx 20 -sticky ew

    bind $f.fileTypeCB $comboBoxEvent [list ChooseFile::_select_filetype $path]

    Button $f.cancel -text "Cancel" -width $bwidth \
	-command [list ChooseFile::enddialog $path 0]
    grid $f.cancel -row 1 -column 2 -pady 2 -sticky ew

    ## Initialize the directory.
    set name       [Widget::getoption $dialog -name]
    set initialdir [Widget::getoption $dialog -initialdir]

    if {![string length $initialdir]} {
        if {[info exists dialogs($name)]} {
            set initialdir [lindex $dialogs($name) 0]
        } else {
            set initialdir [pwd]
        }
    }

    set initialfile [Widget::getoption $dialog -initialfile]
    if {![string length $initialfile]} {
        if {[info exists dialogs($name)]} {
            set initialfile [lindex $dialogs($name) 1]
        }
    }

    if {[string length $initialfile]} {
        set initialdir [file dirname $initialfile]
    }

    Widget::setoption $dialog -initialdir  [file normalize $initialdir]
    Widget::setoption $dialog -initialfile [file normalize $initialfile]

    ## Populate the filetypes combobox.
    set filetypes [Widget::getoption $dialog -filetypes]
    if {![llength $filetypes]} {
        set filetypes {{"All Files" *}}
    }

    foreach typelist $filetypes {
        set txt [lindex $typelist 0]
        foreach ext [lindex $typelist 1] {
        if {[string index $ext 0] ne "."} { set ext .$ext }
            set ext [file extension $ext]
        if {![info exists exts($txt)]} { lappend exts(list) $txt }
        lappend exts($txt) *$ext
    }
    }

    set first   1
    set default [Widget::getoption $dialog -defaultextension]
    foreach txt $exts(list) {
        set text "$txt ([join [lsort $exts($txt)] ,])"
        lappend values $text

        foreach ext $exts($txt) {
            set ext [file extension $ext]
            lappend data(filetype,$text) [string tolower $ext]
            if {$::tcl_platform(platform) ne "windows" && $ext ne ".*"} {
                lappend data(filetype,$text) [string toupper $ext]
            }
        }

        if {![info exists data(filetype)]} {
            if {[string length $default]} {
                foreach ext $exts($txt) {
                    if {$ext eq "*$default"} {
                        set data(filetype) $text
                    }
                }
            } else {
                if {$first} {
                    set first 0
                    set data(filetype) $text
                }
            }
        }
    }
    $f.fileTypeCB configure -values $values

    set result [Dialog::draw $path]

    set file ""
    if {$result} { set file $data(file) }

    destroy $path

    return $file
}


proc ChooseFile::enddialog { path result } {
    set dialog $path#choosefile
    Widget::getVariable $dialog data

    if {$result} {
        if {![info exists data(filetail)]} { return }

        set type [Widget::getoption $dialog -type]
        if {$type eq "save"} {
            set file [file join $data(directory) $data(filetail)]

            set ext [Widget::getoption $dialog -defaultextension]
            if {![string length [file extension $file]]} {
                set filetype [lindex $data(filetype,$data(filetype)) 0]
                if {$filetype ne ".*"} {
                    set ext [string range $filetype 1 end]
                }
                append file .$ext
            }

            if {[file exists $file]} {
                set title   [Widget::getoption $dialog -title]
                set message "$file already exists.\nDo you want to replace it?"
                set res [MessageDlg $path.__replaceFile -type yesno \
                    -icon warning -title $title -message $message]
                if {$res eq "no"} {
                    focus $data(FileEntry)
                    return
                }
            }

            set data(file) $file
        } elseif {$type eq "open"} {
            ## If it doesn't begin and end with a quote, it's a single file.
            if {![string match {"*"} $data(filetail)]} {
                set file [file join $data(directory) $data(filetail)]

                if {![file exists $file]} {
                    set tail    [file tail $file]
                    set title   [Widget::getoption $dialog -title]
                    set message "$tail\nFile not found.\nPlease\
                        verify the correct file name was given."
                    set res [MessageDlg $path.__replaceFile -type ok \
                        -icon warning -title $title -message $message]
                    focus $data(FileEntry)
                    return
                }

                if {[Widget::getoption $dialog -multiple]} {
                    set data(file) [list $file]
                } else {
                    set data(file) $file
                }
            } else {
                foreach tail $data(filetail) {
                    set file [file join $data(directory) $tail]

                    if {![file exists $file]} {
                        set title   [Widget::getoption $dialog -title]
                        set message "$tail\nFile not found.\nPlease\
                            verify the correct file name was given."
                        set res [MessageDlg $path.__replaceFile -type ok \
                            -icon warning -title $title -message $message]
                        focus $data(FileEntry)
                        return
                    }

                    lappend files $file
                }

                set data(file) $files
            }
        }
    }

    set [Widget::widgetVar $path data(result)] $result
}


proc ChooseFile::getlistbox { path } {
    return [Dialog::getframe $path].listbox
}


proc ChooseFile::_update_folders { path } {
    set dialog $path#choosefile

    Widget::getVariable $dialog data

    $data(FolderListBox) clear

    set folders  [Widget::getoption $dialog -folders]
    set restrict [Widget::getoption $dialog -restrictdir]
    if {!$restrict && ![llength $folders]} {
        set desktop     [file normalize [file join ~ Desktop]]
        set myDocuments [file normalize [file join ~ Documents]]
        if {[info exists ::env(HOME)]} {
            set desktopText Desktop

            if {$::tcl_platform(platform) eq "windows"} {
                set myDocumentsText "My Documents"
            } else {
                set myDocumentsText "Documents"
            }

            set desktop     [file join $::env(HOME) $desktopText]
            set myDocuments [file join $::env(HOME) $myDocumentsText]
        }

        if {$::tcl_platform(platform) ne "windows" && [file exists ~]} {
            lappend folders [list [file normalize ~] "Home"]
        }

        if {[file exists $desktop]} {
            lappend folders [list $desktop "Desktop"]
        }

        if {[file exists $myDocuments]} {
            lappend folders [list $myDocuments $myDocumentsText]
        }

        foreach volume [file volumes] {
            if {![string match "*vfs" [lindex [file system $volume] 0]]} {
                lappend folders [list $volume $volume]
            }
        }
    }

    if {!$restrict} {
        set i 0
        foreach list $folders {
            set dir   [file normalize [lindex $list 0]]
            set text  [lindex $list 1]
            set image [lindex $list 2]

            if {![string length $image]} { set image [BWidget::Icon folder16] }

            $data(FolderListBox) insert end #auto -text $text \
                -data $dir -image $image
            lappend values $text

            set folderdirs($dir) $i
            incr i
        }
    }

    set i       0
    set idx     end
    set dirlist [list]
    foreach x [file split $data(directory)] {
        lappend dirlist $x
        if {[info exists folderdirs($x)]} {
            set idx $folderdirs($x)
        } else {
            set dir [file normalize [eval file join $dirlist]]
            $data(FolderListBox) insert $idx #auto -text $x \
                -data $dir -indent [expr {$i * 20}] \
                -image [BWidget::Icon folder16]
            lappend values $x
        }

        incr i

        if {[string is integer $idx]} { incr idx }
    }

    if {[BWidget::using ttk]} {
        $data(FolderCombo) configure -values $values
    }
}


proc ChooseFile::_update_selection { path {item ""} } {
    Widget::getVariable $path#choosefile data

    set listbox [ChooseFile::getlistbox $path]
    if {[string length $item]} {
        set sel [list $item]
        $listbox selection set $item
    } else {
        set sel [$listbox selection get]
    }

    set files [list]
    foreach item $sel {
        if {![$listbox exists $item]} { continue }

        set file [$listbox itemcget $item -data]

        if {[file isfile $file]} {
            if {[llength $sel] == 1} {
                set files [file tail $file]
            } else {
            lappend files \"[file tail $file]\"
        }
    }
    }

    set data(filetail) [join $files " "]
}


proc ChooseFile::_double_click { path item } {
    Widget::getVariable $path#choosefile data

    set listbox [ChooseFile::getlistbox $path]

    set file [$listbox itemcget $item -data]

    if {[file isfile $file]} {
        set data(file)     [file normalize $file]
        set data(filetail) [file tail $data(file)]
        ChooseFile::enddialog $path 1
    } else {
        ChooseFile::_select_directory $path $file
    }
}


proc ChooseFile::_refresh_view { path } {
    Widget::getVariable $path#choosefile data
    ChooseFile::_select_directory $path $data(directory)
}


proc ChooseFile::_select_directory { path directory {appendHistory 1} } {
    set dialog $path#choosefile

    Widget::getVariable $dialog data

    set directory  [file normalize $directory]
    set initialdir [Widget::getoption $dialog -initialdir]

    ## Configure the up button.  If -restrictdir is true, the user
    ## can only go up as far as the -initialdir.
    [Dialog::getframe $path].top.bbox.b1 configure -state normal
    if {[Widget::getoption $dialog -restrictdir]} {
        if {$directory eq $initialdir} {
            [Dialog::getframe $path].top.bbox.b1 configure -state disabled
        }

        ## If this directory isn't underneath our initial directory,
        ## restrict them back to the initialdir.
        if {![string match $initialdir* $directory]} {
            set directory $initialdir
        }
    }

    ## If we're at the top of the drive, disable the up button.
    if {[file dirname $directory] eq $directory} {
        [Dialog::getframe $path].top.bbox.b1 configure -state disabled
    }

    set data(directory) $directory
    set data(dirtail)   [file tail $data(directory)]
    if {![string length $data(dirtail)]} { set data(dirtail) $directory }

    if {$appendHistory} {
        lappend data(history) $data(directory)
        set data(histidx) [expr {[llength $data(history)] - 1}]
    }

    ## Configure the back button.
    if {$data(histidx) == 0} {
        [Dialog::getframe $path].top.bbox.b0 configure -state disabled
    } else {
        [Dialog::getframe $path].top.bbox.b0 configure -state normal
    }

    ## Set the combobox value with enough room to the left
    ## to place our icon.
    set n $data(comboSpaces)
    set data(dirtail) [string repeat " " $n]$data(dirtail)
    if {![BWidget::using ttk]} {
        $data(FolderCombo).e selection clear
    }

    ChooseFile::_update_folders $path

    ## Place a label with the icon for this folder over the top
    ## of the folder combobox to the left of the directory.
    place forget $data(FolderIconLabel)
    foreach item [$data(FolderListBox) items] {
        if {$directory eq [$data(FolderListBox) itemcget $item -data]} {
            $data(FolderIconLabel) configure \
                -image [$data(FolderListBox) itemcget $item -image]
            set y [expr {[winfo height $data(FolderCombo)] / 2}]
            place $data(FolderIconLabel) -x 4 -y $y -anchor w \
                -in $data(FolderCombo)
            break
        }
    }

    set listbox [ChooseFile::getlistbox $path]

    $listbox clear

    set sort -ascii
    if {$::tcl_platform(platform) eq "windows"} { set sort -dict }

    set dirs [glob -nocomplain -dir $directory -type d *]
    if {$data(showHidden)} {
        eval lappend dirs [glob -nocomplain -dir $directory -type {d hidden} *]
    }

    set include [Widget::getoption $dialog -includevfs]
    foreach dir [lsort $sort $dirs] {
        if {!$include && [string match "*vfs*" [file system $dir]]} { continue }
        set tail [file tail $dir]
        if {$tail eq "." || $tail eq ".."} { continue }
        $listbox insert end #auto -text [file tail $dir] -data $dir \
            -image [BWidget::Icon folder16]
    }

    set windows [expr {$::tcl_platform(platform) eq "windows"}]
    set files [list]

    if {$data(filetype,$data(filetype)) eq ".*"} {
        set patt *
    } else {
        set patt "*\{[join $data(filetype,$data(filetype)) ,]\}"
    }

    eval lappend files [glob -nocomplain -dir $directory -type f $patt]
    eval lappend files [glob -nocomplain -dir $directory -type {f hidden} $patt]

    set initialfile [Widget::getoption $dialog -initialfile]
    foreach file [lsort $sort $files] {
        set tail [file tail $file]
        if {$windows && [file extension $tail] eq ".lnk"} {
            set tail [file root $tail]
        }
        set i [$listbox insert end #auto -text $tail \
            -data $file -image [BWidget::Icon mimeunknown16]]
        if {!$data(realized) && $file eq $initialfile} {
            $listbox selection set $i
        }
    }
}


proc ChooseFile::_select_folder { path combo {item ""} } {
    Widget::getVariable $path#choosefile data

    set listbox $data(FolderListBox)
    if {![string length $item]} { set item [$listbox selection get] }
    ChooseFile::_select_directory $path [$listbox itemcget $item -data]

    if {[BWidget::using ttk]} {
        set unpost ::tile::combobox::Unpost
        if {![string length [info commands $unpost]]} {
            set unpost ::ttk::combobox::Unpost
        }
        $unpost $data(FolderCombo)
    }

    focus [ChooseFile::getlistbox $path]
}


proc ChooseFile::_select_filetype { path } {
    Widget::getVariable $path#choosefile data
    ChooseFile::_select_directory $path $data(directory)
}


proc ChooseFile::_back { path } {
    Widget::getVariable $path#choosefile data
    incr data(histidx) -1
    ChooseFile::_select_directory $path [lindex $data(history) $data(histidx)] 0
}


proc ChooseFile::_up { path } {
    Widget::getVariable $path#choosefile data
    ChooseFile::_select_directory $path [file dirname $data(directory)]
}


proc ChooseFile::_next_directory { root text } {
    set i 1
    set dir [file join $root $text]
    while {[file exists $dir]} {
        set dir [file join $root "$text ([incr i])"]
    }
    return $dir
}


proc ChooseFile::_create_directory { path } {
    Widget::getVariable $path#choosefile data

    set listbox [ChooseFile::getlistbox $path]

    set i    [$listbox insert end #auto -image [BWidget::Icon folder16]]
    set text [_next_directory $data(directory) "New Folder"]

    while {1} {
        set result [$listbox edit $i [file tail $text] \
            [list ChooseFile::_verify_directory $path $listbox $i]]

        if {![string length $result]} {
            set dir $text
            break
        }

        set txt [$listbox itemcget $i -text]
        set dir [file join $data(directory) [$listbox itemcget $i -text]]

        if {[file exists $dir]} {
            set title  "Error Renaming File or Folder"
            set    msg "Cannot rename [file tail $text]: A file with the name "
            append msg "you specified already exists. Specify a different "
            append msg "file name."
            MessageDlg $path.__error -type ok -icon error \
                -title $title -message $msg
            continue
        }

        break
    }

    ChooseFile::_update_selection $path $i

    file mkdir $dir
}


proc ChooseFile::_verify_directory { path listbox node newtext } {
    $listbox itemconfigure $node -text $newtext
    return 1
}


proc ChooseFile::_map { path } {
    Widget::getVariable $path#choosefile data

    update idletasks
    ChooseFile::_select_directory $path \
        [Widget::getoption $path#choosefile -initialdir]

    set data(realized) 1
}


proc ChooseFile::_destroy { path } {
    Widget::destroy $path#choosefile
    Widget::destroy $path
}

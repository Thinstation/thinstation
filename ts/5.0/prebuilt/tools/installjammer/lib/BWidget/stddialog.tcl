# ----------------------------------------------------------------------------
#  stddialog.tcl
#  $Id$
# ----------------------------------------------------------------------------
#  Index of commands:
#     - StandardDialog::create
# ----------------------------------------------------------------------------

namespace eval StandardDialog {
    Widget::define StandardDialog stddialog Dialog

    Widget::bwinclude StandardDialog Dialog :cmd

    Widget::declare StandardDialog {
        {-buttonwidth           Int     12              1}
        {-applybutton           Boolean 1               1}
        {-cancelbutton          Boolean 1               1}
    }
}


proc StandardDialog::create { path args } {
    array set maps [Widget::splitArgs $args Dialog StandardDialog]

    array set _args {
        -buttonwidth    12
        -applybutton    1
        -cancelbutton   1
    }
    array set _args $maps(StandardDialog)

    set width   $_args(-buttonwidth)
    set apply   $_args(-applybutton)
    set cancel  $_args(-cancelbutton)
    set buttons [list OK]

    switch -- [tk windowingsystem] {
        "aqua" {
            ## Apply Cancel OK

            set cancelidx  0
            set defaultidx 2

            if {$cancel} { set buttons [linsert $buttons 0 Cancel] }
            if {$apply}  { set buttons [linsert $buttons 0 Apply]  }
        }

        default {
            ## OK Cancel Apply

            set cancelidx  1
            set defaultidx 0

            if {$cancel} { lappend buttons Cancel }
            if {$apply}  { lappend buttons Apply  }
        }
    }

    if {!$cancel} { set cancelidx $defaultidx }

    eval [list Dialog::create $path -class StandardDialog -anchor e \
        -homogeneous 1 -default $defaultidx -cancel $cancelidx -modal local] \
        $maps(:cmd) $maps(Dialog)

    foreach text $buttons {
        set val [string tolower $text]
        $path add -text $text -width $width -name $val -value $val
    }

    return $path
}

if {[string equal $::tcl_platform(platform) "windows"]} {
    option add *ListBox.background      SystemWindow            widgetDefault
    option add *ButtonBox.padY          0                       widgetDefault
    option add *Dialog.padY             0                       widgetDefault
} elseif {[tk windowingsystem] eq "aqua"} {

} else {
    option add *Scrollbar.width         12                      widgetDefault
    option add *Scrollbar.borderWidth   1                       widgetDefault
    option add *Dialog.separator        1                       widgetDefault
    option add *MainFrame.relief        raised                  widgetDefault
    option add *MainFrame.separator     none                    widgetDefault
    option add *MessageDlg.usenative    0                       widgetDefault
}

option read [file join $::BWIDGET::LIBRARY lang en.rc]

## Add a TraverseIn binding to standard Tk widgets to handle
## some of the BWidget-specific things we do.
bind Entry   <<TraverseIn>> { %W selection range 0 end; %W icursor end }
bind Spinbox <<TraverseIn>> { %W selection range 0 end; %W icursor end }

bind all <Key-Tab>       { Widget::traverseTo [Widget::focusNext %W] }
bind all <<PrevWindow>>  { Widget::traverseTo [Widget::focusPrev %W] }

namespace eval ::BWidget {
    variable library     $::BWIDGET::LIBRARY
    variable langDir     [file join $library lang]
    variable imageDir    [file join $library images]
    variable imageFormat GIF

    variable iconLibrary
    if {![info exists iconLibrary]} {
        set iconLibrary BWidgetIcons
    }

    variable iconLibraryFile
    if {![info exists iconLibraryFile]} {
        set iconLibraryFile [file join $imageDir BWidget.gif.tkico]
    }

    variable colors
    if {[string equal $::tcl_platform(platform) "windows"]} {
        array set colors {
            SystemButtonFace    SystemButtonFace
            SystemButtonText    SystemButtonText
            SystemDisabledText  SystemDisabledText
            SystemHighlight     SystemHighlight
            SystemHighlightText SystemHighlightText
            SystemMenu          SystemMenu
            SystemMenuText      SystemMenuText
            SystemScrollbar     SystemScrollbar
            SystemWindow        SystemWindow
            SystemWindowFrame   SystemWindowFrame
            SystemWindowText    SystemWindowText
        }
    } else {
        array set colors {
            SystemButtonFace    #d9d9d9
            SystemButtonText    #000000
            SystemDisabledText  #a3a3a3
            SystemHighlight     #c3c3c3
            SystemHighlightText #FFFFFF
            SystemMenu          #d9d9d9
            SystemMenuText      #FFFFFF
            SystemScrollbar     #d9d9d9
            SystemWindow        #FFFFFF
            SystemWindowFrame   #d9d9d9
            SystemWindowText    #000000
        }
    }

    if {[lsearch -exact [font names] "TkTextFont"] < 0} {
        catch {font create TkTextFont}
        catch {font create TkDefaultFont}
        catch {font create TkHeadingFont}
        catch {font create TkCaptionFont}
        catch {font create TkTooltipFont}

        switch -- [tk windowingsystem] {
            win32 {
                if {$::tcl_platform(osVersion) >= 5.0} {
                    variable family "Tahoma"
                } else {
                    variable family "MS Sans Serif"
                }
                variable size 8

                font configure TkDefaultFont -family $family -size $size
                font configure TkTextFont    -family $family -size $size
                font configure TkHeadingFont -family $family -size $size
                font configure TkCaptionFont -family $family -size $size \
                    -weight bold
                font configure TkTooltipFont -family $family -size $size
            }

            classic - aqua {
                variable family "Lucida Grande"
                variable size 13
                variable viewsize 12
                variable smallsize 11

                font configure TkDefaultFont -family $family -size $size
                font configure TkTextFont    -family $family -size $size
                font configure TkHeadingFont -family $family -size $smallsize
                font configure TkCaptionFont -family $family -size $size \
                    -weight bold
                font configure TkTooltipFont -family $family -size $viewsize
            }

            x11 {
                if {![catch {tk::pkgconfig get fontsystem} fs]
                    && [string equal $fs "xft"]} {
                    variable family "sans-serif"
                } else {
                    variable family "Helvetica"
                }
                variable size -12
                variable ttsize -10
                variable capsize -14

                font configure TkDefaultFont -family $family -size $size
                font configure TkTextFont    -family $family -size $size
                font configure TkHeadingFont -family $family -size $size \
                    -weight bold
                font configure TkCaptionFont -family $family -size $capsize \
                    -weight bold
                font configure TkTooltipFont -family $family -size $ttsize
            }
        }
    }
} ; ## namespace eval ::BWidget

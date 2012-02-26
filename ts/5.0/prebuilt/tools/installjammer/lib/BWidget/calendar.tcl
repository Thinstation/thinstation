#==========================================================
# Index of commands:
#
#   Public commands
#       - Calendar::cget
#       - Calendar::configure
#       - Calendar::create
#       - Calendar::dates
#
#   Private commands (internal helper procs)
#       - Calendar::_flip
#==========================================================

namespace eval Calendar {
    Widget::define Calendar calendar Dialog

    Widget::tkinclude Calendar frame :cmd \
        remove { -bg -background -class -colormap -container -visual }

    Widget::declare Calendar {
        {-title               String      "Select a Date"       0}
        {-background          Color       "SystemButtonFace"    0}
        {-foreground          Color       "SystemButtonText"    0}
        {-disabledforeground  Color       "SystemDisabledText"  0}
        {-font                String      "TkTextFont"          0}
        {-days                String      "S M T W T F S"       0}
        {-selectmode          Enum        "single"    0 {single multiple}}
        {-selectbackground    Color       "SystemHighlight"     0}
        {-selectforeground    Color       "SystemHighlightText" 0}

        {-type                Enum        "dialog"    1 {dialog frame popup}}
        {-format              String      "%D"        0}
        {-dates               String      ""          1}
        {-month               String      ""          0}
        {-year                String      ""          0}

        {-ipadx               Int         "30"        1}
        {-ipady               Int         "5"         1}
        {-place               String      "center"    1}
        {-parent              String      ""          1}
        {-calendarbackground  Color      "SystemButtonFace"  0}
        {-repeatdelay         Int         400         0 "%d >= 0"}
        {-repeatinterval      Int         100         0 "%d >= 0"}

        {-showleaddays        Boolean     "1"         1}
        {-showheader          Boolean     "1"         1}
        {-showseparators      Boolean     "1"         1}
        {-showtitles          Boolean     "1"         1}
        {-titlemenus          Boolean     "1"         1}
        {-hottrack            Boolean     "1"         1}

        {-calendars           Int         1            1 "%d >= 1"}
        {-orient              Enum        "horizontal" 1 {horizontal vertical}}

        {-popupfont           String      "Arial 6"         0}
        {-popupipadx          Int         "10"              1}
        {-popupipady          Int         "3"               1}
        {-popupbackground     String      "#FFFFFF"         0}

        {-bg                  Synonym     -background}
        {-fg                  Synonym     -foreground}
    }

    variable _days
    set _days [list sunday monday tuesday wednesday thursday friday saturday]

    variable _months
    set _months [list January February March April May June July \
                August September October November December]

    Widget::declare Calendar [list \
        [list -months     String $_months  1] \
        [list -startday   Enum   "sunday"  0 $_days] \
    ]

    bind Calendar <Destroy> [list Calendar::_destroy %W]
}


proc Calendar::create { path args } {
    set cal $path#Calendar

    Widget::init Calendar $cal $args

    Widget::getVariable $cal data

    set data(dates)    [list]
    set data(hottrack) [list]
    set data(popup)    [string equal [Widget::getoption $cal -type] "popup"]

    set dates  [Widget::getoption $cal -dates]
    set format [Widget::getoption $cal -format]
    set mode   [Widget::getoption $cal -selectmode]
    if {![llength $dates]} {
        set dates [clock format [clock seconds] -format $format]
    }

    foreach date $dates {
        set secs [clock scan $date]
        if {![info exists data(month)]} {
            set data(month) [clock format $secs -format %B]
        }
        if {![info exists data(year)]} {
            set data(year)  [clock format $secs -format %Y]
        }
        lappend data(dates) $secs

        if {[string equal $mode "single"]} { break }
    }

    set month [Widget::getoption $cal -month]
    if {![string equal $month ""]} { set data(month) $month }

    set year  [Widget::getoption $cal -year]
    if {![string equal $year ""]} { set data(year) $year }

    Widget::setoption $cal -month $data(month)
    Widget::setoption $cal -year  $data(year)

    switch -- [Widget::getoption $cal -type] {
        "popup" {
            set data(bg)     [Widget::getoption $cal -popupbackground]
            set data(font)   [Widget::getoption $cal -popupfont]
            set data(ipadx)  [Widget::getoption $cal -popupipadx]
            set data(ipady)  [Widget::getoption $cal -popupipady]
            set data(header) [Widget::getoption $cal -showheader]

            set list   [list at center left right above below]
            set place  [Widget::getoption $cal -place]
            set parent [Widget::getoption $cal -parent]
            set where  [lindex $place 0]

            if {[lsearch -exact $list $where] < 0} {
                return -code error \
                    [BWidget::badOptionString placement $place $list]
            }

            ## If they specified a parent and didn't pass a second argument
            ## in the placement, set the placement relative to the parent.
            if {[string length $parent]} {
                if {[llength $place] == 1} { lappend place $parent }
            }

            set data(place) $place
        }

        "dialog" - "frame" {
            set data(bg)     [Widget::getoption $cal -calendarbackground]
            set data(font)   [Widget::getoption $cal -font]
            set data(ipadx)  [Widget::getoption $cal -ipadx]
            set data(ipady)  [Widget::getoption $cal -ipady]
            set data(place)  [Widget::getoption $cal -place]
            set data(header) [Widget::getoption $cal -showheader]
        }
    }

    _calculate_font_size $path

    set type [Widget::getoption $cal -type]
    return [eval [list Calendar::_create_$type $path] $args]
}


proc Calendar::cget { path option } {
    return [Widget::cget $path#Calendar $option]
}


proc Calendar::configure { path args } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set type  [Widget::getoption $cal -type]
    set popup $data(popup)

    set res [Widget::configure $cal $args]

    set redraw [Widget::anyChangedX $cal -foreground \
                    -disabledforeground -days -selectbackground \
                    -selectforeground -calendarbackground -popupfont \
                    -popupbackground]

    if {[Widget::hasChanged $cal -title title]} {
        wm title $path $title
    }

    if {[Widget::hasChanged $cal -background bg]} {
        switch -- $type {
            "dialog" {
                $path.bbox   configure -background $bg
                $path.frame  configure -background $bg
                $path:cmd    configure -background $bg
            }

            "frame" - "popup" {
                $path:cmd configure -background $bg
            }
        }
    }

    if {[Widget::hasChanged $cal -font font]} {
        set redraw 1
    }

    if {[Widget::hasChanged $cal -month month]} {
        set data(month) $month
        set redraw 1
    }

    if {[Widget::hasChanged $cal -year year]} {
        set data(year) $year
        set redraw 1
    }

    if {!$popup && [Widget::anyChangedX $cal -repeatdelay -repeatinterval]} {
        set repdelay [Widget::getoption $cal -repeatdelay]
        set repinter [Widget::getoption $cal -repeatinterval]

        $data(frame).header.back configure \
            -repeatinterval $repinter -repeatdelay $repdelay
        $data(frame).header.next configure \
            -repeatinterval $repinter -repeatdelay $repdelay
    }

    if {$redraw} {
        switch -- $type {
            "popup" {
                set data(bg)     [Widget::getoption $cal -popupbackground]
                set data(font)   [Widget::getoption $cal -popupfont]
            }

            "dialog" - "frame" {
                set data(bg)     [Widget::getoption $cal -calendarbackground]
                set data(font)   [Widget::getoption $cal -font]
            }
        }

        _calculate_font_size $path

        _redraw $path
    }

    return $res
}


proc Calendar::dates { path {inSeconds 0} } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set dates  [list]
    set format [Widget::getoption $cal -format]
    foreach date [lsort -integer $data(dates)] {
        if {!$inSeconds} { set date [clock format $date -format $format] }
        lappend dates $date
    }

    return $dates
}


proc Calendar::_create_frame { path args } {
    Widget::init Calendar $path $args

    set cal $path#Calendar

    Widget::getVariable $cal data

    set bg [Widget::getoption $cal -background]
    eval [list ::frame $path] [list -bg $bg -class Calendar]
    Widget::create Calendar $path

    set data(frame) $path

    Calendar::_build_calendar $path $data(frame)

    return $path
}


proc Calendar::_create_dialog { path args } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set args [list -anchor e -separator 1 -class Calendar]
    lappend args -place      [Widget::getoption $cal -place]
    lappend args -title      [Widget::getoption $cal -title]
    lappend args -parent     [Widget::getoption $cal -parent]
    lappend args -background [Widget::getoption $cal -background]

    eval [list Dialog::create $path] $args
    wm resizable $path 0 0

    set data(frame) [Dialog::getframe $path]

    Calendar::_build_calendar $path $data(frame)

    Dialog::add $path -text "OK"     -width 12
    Dialog::add $path -text "Cancel" -width 12

    set res [Dialog::draw $path]

    set dates [list]
    if {!$res} { set dates [Calendar::dates $path] }

    destroy $path

    return $dates
}


proc Calendar::_create_popup { path args } {
    Widget::init Calendar $path $args

    set cal $path#Calendar

    Widget::getVariable $cal data

    toplevel     $path -class Calendar
    wm withdraw  $path
    wm override  $path 1
    wm transient $path [winfo toplevel [winfo parent $path]]

    Widget::create Calendar $path

    set font [Widget::getoption $cal -popupfont]

    if {![string length $font]} {
        set font [Widget::getoption $cal -font]
        array set info [font actual $font]
        set data(font) [list $info(-family) 6]
    }

    set data(frame) $path

    Calendar::_build_calendar $path $data(frame)

    eval [list BWidget::place $path 0 0] $data(place)

    wm deiconify $path
    raise $path

    BWidget::grab set $path
    tkwait variable [Widget::widgetVar $cal data(dates)]
    BWidget::grab release $path

    if {![info exists data(dates)]} { return }

    if {[info exists data(custom)]} {
        set options [Widget::options $cal]
        puts "OPTIONS = $options"
        destroy $path
        return [eval [list Calendar $path] $options -type dialog]
    } else {
        set dates  [Calendar::dates $path]
        destroy $path
        return $dates
    }
}


proc Calendar::_build_calendar { path frame } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set place    [Widget::getoption $cal -place]
    set title    [Widget::getoption $cal -title]
    set parent   [Widget::getoption $cal -parent]
    set repdelay [Widget::getoption $cal -repeatdelay]
    set repinter [Widget::getoption $cal -repeatinterval]

    if {$data(header)} {
        if {$data(popup)} {
            Button $frame.header -font $data(font) -relief flat -bd 0 \
                -background $data(bg) -style Toolbutton \
                -command [list Calendar::_select_date $path "custom"] \
                -textvariable [Widget::widgetVar $cal data(month)]
            pack $frame.header -fill x
        } else {
            set header [::frame $frame.header -bg $data(bg)]
            pack $header -fill x ;# -pady 5

            grid rowconfigure $header 0 -weight 1

            ArrowButton $header.back -dir left -width 18 \
                -repeatdelay $repdelay -repeatinterval $repinter \
                -armcommand [list Calendar::_flip $path -]
            grid $header.back  -row 0 -column 0 -padx [list 5 0] -sticky ns

            ArrowButton $header.next -dir right -width 18 \
                -repeatdelay $repdelay -repeatinterval $repinter \
                -armcommand [list Calendar::_flip $path +]
            grid $header.next  -row 0 -column 3 -padx [list 0 5] -sticky ns

            set command [list Calendar::_redraw $path]

            ComboBox $header.month \
                -editable 1 -width 16 -height 12 -hottrack 1 \
                -text $data(month) \
                -values [Widget::getoption $cal -months] \
                -textvariable [Widget::widgetVar $cal data(month)] \
                -modifycmd $command
            grid $header.month -row 0 -column 1 -padx 5

            SpinBox $header.year \
                -editable 1 -width 8 -range [list 1492 2525 1] \
                -text $data(year) \
                -textvariable [Widget::widgetVar $cal data(year)] \
                -modifycmd $command -command $command
            grid $header.year  -row 0 -column 2 -padx 5
        }
    }

    if {[Widget::getoption $cal -titlemenus]} { ::menu $path.popup -tearoff 0 }

    set single     [string equal [Widget::getoption $cal -selectmode] "single"]
    set orient     [Widget::getoption $cal -orient]
    set hottrack   [Widget::getoption $cal -hottrack]
    set calendars  [Widget::getoption $cal -calendars]
    set separators [Widget::getoption $cal -showseparators]
    for {set i 0} {$i < $calendars} {incr i} {
        set canvas $frame.calendar$i
        ::canvas $canvas -background $data(bg) -highlightthickness 0
        if {$separators && $i != [expr {$calendars - 1}]} {
            if {[string equal $orient "vertical"]} {
                Separator $frame.sep$i -orient horizontal
            } else {
                Separator $frame.sep$i -orient vertical
            }
        }

        $canvas bind back <1> [list Calendar::_flip $path - $canvas]
        $canvas bind next <1> [list Calendar::_flip $path + $canvas]
        $canvas bind day  <1> [list Calendar::_select_date $path $canvas]

        if {$single
            && ![string equal [Widget::getoption $cal -type] "frame"]} {
            $canvas bind day <Double-1> "
                [list Calendar::_select_date $path $canvas]
                [list Dialog::invoke $path 0]
            "
        }

        if {$hottrack} {
            $canvas bind date <Enter> \
                [list Calendar::_highlight_date $path $canvas]
            $canvas bind date <Leave> \
                [list Calendar::_highlight_date $path $canvas ""]
        }
    }

    Calendar::_redraw $path
}


proc Calendar::_redraw { path } {
    set cal $path#Calendar

    Widget::getVariable $cal data
    set frame $data(frame)

    set month      $data(month)
    set year       $data(year)
    set orient     [Widget::getoption $cal -orient]
    set separators [Widget::getoption $cal -showseparators]

    Widget::setoption $cal -month $data(month)
    Widget::setoption $cal -year  $data(year)

    if {$data(popup) && ![BWidget::using ttk]} {
        $frame.header configure -background $data(bg)
    }

    for {set i 0} {$i < [Widget::getoption $cal -calendars]} {incr i} {
        set calendar $frame.calendar$i

        $calendar configure -background $data(bg)

        set side left
        set fill y
        if {[string equal $orient "vertical"]} { set side top; set fill x }
        pack $calendar -side $side -padx 2 -pady 2

        if {$separators && [winfo exists $frame.sep$i]} {
            pack $frame.sep$i -side $side -fill $fill
        }

        _redraw_calendar $path $frame.calendar$i $month $year $i
        BWidget::lassign [_next_month_year $month $year] month year
    }

    if {[string equal [Widget::getoption $cal -type] "dialog"]} {
        wm geometry $path {}
    }
}


proc Calendar::_redraw_calendar { path canvas month year calnum } {
    variable _days

    set cal $path#Calendar

    Widget::getVariable $cal data
    
    set num    [Widget::getoption $cal -calendars]
    set type   [Widget::getoption $cal -type]
    set start  [Widget::getoption $cal -startday]
    set extra  [Widget::getoption $cal -showleaddays]
    set format [Widget::getoption $cal -format]

    set idx    [lsearch -exact $_days $start]
    set incrX  [expr {$data(sizeX) + $data(ipadx)}]
    set incrY  [expr {$data(sizeY) + $data(ipady)}]
    set startX [expr {$incrX / 2}]
    set startY [expr {$incrY / 2}]
    set width  [expr {$incrX * 7}]
    set height [expr {$incrY * 7}]

    set days  [Widget::getoption $cal -days]
    
    $canvas delete items

    set x $startX
    set y $startY
    set count 0

    if {[Widget::getoption $cal -showtitles]
        && (!$data(header) || ![string equal $type "popup"])} {
        $canvas create text [expr {$width / 2}] $y \
            -text "$month  $year" -font $data(font) -tags [list title items]
        incr y $incrY
        incr height $incrY

        if {[Widget::getoption $cal -titlemenus]} {
            set cmd Calendar::_post_title_menu
            $canvas bind title <1> [list $cmd $path $month $year $calnum %X %Y]
        }
    }

    ## Draw the days of the week across the top.
    for {set i $idx} {$i < [expr {$idx + 7}]} {incr i} {
        set day [lindex $days [expr {$i % 7}]]
        $canvas create text $x $y -text $day -font $data(font) \
            -tags [list header items]
        incr x $incrX
    }

    ## Add a line between the days of the week and the main calendar.
    incr y $startY
    $canvas create line [list 0 $y $x $y] -fill #B8B8B8 -tags items
    incr y $startY

    set start [clock format [clock scan "1-$month-$year"] -format %A]
    set idx   [lsearch -exact $_days [string tolower $start]]

    set dfg [Widget::getoption $cal -disabledforeground]

    if {$extra && (($num == 1) || ($num > 1 && $calnum == 0))} {
        ## Draw the lead days at the head of the month.
        BWidget::lassign [_last_month_year $month $year] lastMonth lastYear
        set x     $startX
        set max   [_days_in_month "1-$lastMonth-$lastYear"]
        set start [expr {$idx - 1}]
        if {$start < 0} { set start 6 }
        for {set i $start} {$i >= 0} {incr i -1; incr count} {
            set day [expr {$max - $i}]
            set date "$day-$lastMonth-$lastYear"
            set date [clock format [clock scan $date] -format %D]
            $canvas create text $x $y -text $day -font $data(font) \
                -tags [list $date disabled back date items] -fill $dfg
            
            incr x $incrX
        }

        if {!$idx} {
            set  x $startX
            incr y $incrY
        }
    } else {
        incr count $idx
        set x [expr {$startX + ($incrX * $idx)}]
    }

    ## Draw all the days in the month.
    set max [_days_in_month "1-$month-$year"]
    for {set i 1; set j [expr {$idx + 1}]} {$i <= $max} {incr i; incr j} {
        set date "$i-$month-$year"
        set date [clock format [clock scan $date] -format %D]
        $canvas create text $x $y -text $i -font $data(font) \
            -tags [list $date day date items]

        incr x $incrX
        if {![expr {$j % 7}]} { set x $startX; incr y $incrY }
        incr count
    }

    if {$extra && (($num == 1) || ($num > 1 && $calnum == [expr {$num - 1}]))} {
        ## Draw the lead days at the end of the month.
        BWidget::lassign [_next_month_year $month $year] nextMonth nextYear
        for {set i 1} {$count < 42} {incr i; incr j; incr count} {
            set date "$i-$nextMonth-$nextYear"
            set date [clock format [clock scan $date] -format %D]
            $canvas create text $x $y -text $i -font $data(font) \
                -tags [list $date disabled next date items] -fill $dfg
            incr x $incrX
            if {![expr {$j % 7}]} { set x $startX; incr y $incrY }
        }
    }

    foreach date $data(dates) {
        set date [clock format $date -format %D]
        _highlight_date $path $canvas $date
    }

    $canvas configure -width $width -height $height
}


proc Calendar::_days_in_month { date } {
    set seconds [clock scan $date]
    BWidget::lassign [clock format $seconds -format "%B %Y"] month year
    BWidget::lassign [_next_month_year $month $year] nextMonth nextYear

    set date "1-$nextMonth-$nextYear - 1 day"
    return [clock format [clock scan $date] -format "%d"]
}


proc Calendar::_last_month_year { month year } {
    set date "1-$month-$year - 1 month"
    return [clock format [clock scan $date] -format "%B %Y"]
}


proc Calendar::_next_month_year { month year } {
    set date "1-$month-$year + 1 month"
    return [clock format [clock scan $date] -format "%B %Y"]
}


proc Calendar::_flip { path dir {canvas ""} } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set type  [Widget::getoption $cal -type]
    set month $data(month)
    set year  $data(year)

    set day "1-$month-$year"
    set day [clock format [clock scan "$day $dir 1 month"] -format %D]

    set data(month) [clock format [clock scan $day] -format "%B"]
    set data(year)  [clock format [clock scan $day] -format "%Y"]

    Widget::setoption $cal -month $data(month)
    Widget::setoption $cal -year  $data(year)

    set frame $path.calendar
    if {[string equal $type "dialog"]} {
        set frame [Dialog::getframe $path].calendar
        if {![string equal $canvas ""]} { _select_date $path $canvas }
    }

    event generate $path <<CalendarChange>>

    Calendar::_redraw $path
}


proc Calendar::_select_date { path canvas {item current} } {
    set cal $path#Calendar

    Widget::getVariable $cal data
    set frame $data(frame)

    if {[string equal $canvas "custom"]} {
        set data(dates)  [list]
        set data(custom) 1
        return
    }

    set item [$canvas find withtag $item]
    set tags [$canvas gettags $item]

    set date [lindex $tags 0]
    set secs [clock scan $date]

    set fg     [Widget::getoption $cal -foreground]
    set format [Widget::getoption $cal -format]
    if {[string equal [Widget::getoption $cal -selectmode] "multiple"]} {
        if {[lsearch -exact $data(dates) $secs] > -1} {
            set data(dates) [BWidget::lremove $data(dates) $secs]
            $canvas delete select-$date
            $canvas itemconfigure $date -fill $fg
        } else {
            lappend data(dates) $secs
            _highlight_date $path $canvas $item
        }
    } else {
        if {[llength $data(dates)]} {
            set calendars [Widget::getoption $cal -calendars]
            foreach date $data(dates) {
                set date [clock format $date -format %D]
                for {set i 0} {$i < $calendars} {incr i} {
                    $frame.calendar$i delete select-$date
                    $frame.calendar$i itemconfigure $date -fill $fg
                }
            }
        }
        set data(dates) $secs
        _highlight_date $path $canvas $item
    }

    Widget::setoption $cal -dates $data(dates)

    event generate $path <<CalendarSelect>>
}


proc Calendar::_highlight_date { path canvas {item current} } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set bg [Widget::getoption $cal -selectbackground]
    set fg [Widget::getoption $cal -selectforeground]

    set hottrack 0
    if {[string equal $item "current"]} { set hottrack 1 }
    set item [$canvas find withtag $item]

    if {[string equal $item ""]} {
        $canvas delete hottrack

        ## Reconfigure the previously highlighted item's foreground.
        if {![string equal $data(hottrack) ""]} {
            set tags [$canvas gettags $data(hottrack)]
            if {[lsearch -exact $tags "disabled"] > -1} {
                set fg [Widget::getoption $cal -disabledforeground]
            } elseif {![_is_selected $path $data(hottrack)]} {
                set fg [Widget::getoption $cal -foreground]
            }

            $canvas itemconfigure $data(hottrack) -fill $fg
        }
        return
    }

    BWidget::lassign [$canvas coords $item] x y

    set x2 [expr {$data(sizeX) / 2}]
    set y2 [expr {$data(sizeY) / 2}]
    set x0 [expr {$x - 3 - $x2}]
    set x1 [expr {$x + 3 + $x2}]
    set y0 [expr {$y - 2 - $y2}]
    set y1 [expr {$y + 2 + $y2}]

    set date [lindex [$canvas gettags $item] 0]

    if {!$hottrack} {
        $canvas create rect [list $x0 $y0 $x1 $y1] \
            -fill $bg -tags [list select-$date items]
        $canvas itemconfigure $item -fill $fg
        $canvas lower select-$date
    } else {
        set data(hottrack) $date

        BWidget::lassign [BWidget::get3dcolor $canvas $bg] dark light
        
        set coords [list $x0 $y0 $x1 $y1]
        BWidget::DrawCanvasBorder $canvas rounded $bg $coords \
            -outline $dark -fill $light -tags hottrack

        $canvas itemconfigure $item -fill $fg
        $canvas lower hottrack
    }
}


proc Calendar::_is_selected { path date } {
    set cal $path#Calendar
    Widget::getVariable $cal data
    set secs [clock scan $date]
    return [expr [lsearch -exact $data(dates) $secs] > -1]
}


proc Calendar::_calculate_font_size { path } {
    set cal $path#Calendar
    Widget::getVariable $cal data

    set data(sizeX) 0
    foreach day [Widget::getoption $cal -days] {
        set x [font measure $data(font) $day]
        if {$x > $data(sizeX)} { set data(sizeX) $x }
    }

    for {set i 1} {$i <= 31} {incr i} {
        set x [font measure $data(font) $i]
        if {$x > $data(sizeX)} { set data(sizeX) $x }
    }

    array set tmp [font metrics $data(font)]
    set data(sizeY) $tmp(-linespace)
}


proc Calendar::_post_title_menu { path month year calnum X Y } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set menu $path.popup

    $menu delete 0 end

    for {set i -3} {$i <= 3} {incr i} {
        if {$i > 0} { set i +$i }
        set secs [clock scan "1-$month-$year $i months"]
        set text [clock format $secs -format "%B %Y"]
        $menu insert end command -label $text -font $data(font) \
            -command [list Calendar::_select_title_month $path $text $calnum]
    }

    update idletasks
    set x [expr {[winfo reqwidth $menu] / 2}]
    $menu activate 3
    set y [expr {[$menu yposition 3] + ($data(sizeY) / 2)}]

    $menu post [expr {$X - $x}] [expr {$Y - $y}]
}


proc Calendar::_select_title_month { path date calnum } {
    set cal $path#Calendar

    Widget::getVariable $cal data

    set date 1-[join $date -]
    set secs [clock scan "$date - $calnum months"]
    BWidget::lassign [clock format $secs -format "%B %Y"] data(month) data(year)

    Widget::setoption $cal -month $data(month)
    Widget::setoption $cal -year  $data(year)

    event generate $path <<CalendarChange>>

    _redraw $path
}


proc Calendar::_destroy { path } {
    Widget::destroy $path
    Widget::destroy $path#Calendar
}

#
# Copyright (c) 2004, Ashok P. Nadkarni
# All rights reserved.
#
# See the file LICENSE for license

namespace eval twapi {
}

#
# Allocate a new console
proc twapi::allocate_console {} {
    AllocConsole
}

#
# Free a console
proc twapi::free_console {} {
    FreeConsole
}

#
# Get a console handle
proc twapi::get_console_handle {type} {
    variable windefs
    switch -exact -- $type {
        0 -
        stdin { set fn "CONIN\$" }
        1 -
        stdout -
        2 -
        stderr { set fn "CONOUT\$" }
        default {
            error "Unknown console handle type '$type'"
        }
    }
    return [CreateFile $fn \
                [expr {$windefs(GENERIC_READ) | $windefs(GENERIC_WRITE)}] \
                [expr {$windefs(FILE_SHARE_READ) | $windefs(FILE_SHARE_WRITE)}] \
                {{} 1} \
                $windefs(OPEN_EXISTING) \
                0 \
                NULL]
}

#
# Get a console handle
proc twapi::get_standard_handle {type} {
    switch -exact -- $type {
        0 -
        -11 -
        stdin { set type -11 }
        1 -
        -12 -
        stdout { set type -12 }
        2 -
        -13 -
        stderr { set type -13 }
        default {
            error "Unknown console handle type '$type'"
        }
    }
    return [GetStdHandle $type]
}


#
# Get a console handle
proc twapi::set_standard_handle {type handle} {
    switch -exact -- $type {
        0 -
        -11 -
        stdin { set type -11 }
        1 -
        -12 -
        stdout { set type -12 }
        2 -
        -13 -
        stderr { set type -13 }
        default {
            error "Unknown console handle type '$type'"
        }
    }
    return [SetStdHandle $type $handle]
}


array set twapi::_console_input_mode_syms {
    -processedinput 0x0001
    -lineinput      0x0002
    -echoinput      0x0004
    -windowinput    0x0008
    -mouseinput     0x0010
    -insertmode     0x0020
    -quickeditmode  0x0040
    -extendedmode   0x0080
    -autoposition   0x0100
}

array set twapi::_console_output_mode_syms {
    -processedoutput 1
    -wrapoutput      2
}

array set twapi::_console_output_attr_syms {
    -fgblue 1
    -fggreen 2
    -fgturquoise 3
    -fgred 4
    -fgpurple 5
    -fgyellow 6
    -fggray 7
    -fgbright 8
    -fgwhite 15
    -bgblue 16
    -bggreen 32
    -bgturquoise 48
    -bgred 64
    -bgyellow 96
    -bgbright 128
    -bgwhite 240
}

#
# Get the current mode settings for the console
proc twapi::_get_console_input_mode {conh} {
    set mode [GetConsoleMode $conh]
    return [_bitmask_to_switches $mode twapi::_console_input_mode_syms]
}
interp alias {} twapi::get_console_input_mode {} twapi::_do_console_proc twapi::_get_console_input_mode stdin

#
# Get the current mode settings for the console
proc twapi::_get_console_output_mode {conh} {
    set mode [GetConsoleMode $conh]
    return [_bitmask_to_switches $mode twapi::_console_output_mode_syms]
}
interp alias {} twapi::get_console_output_mode {} twapi::_do_console_proc twapi::_get_console_output_mode stdout

#
# Set console input mode
proc twapi::_set_console_input_mode {conh args} {
    set mode [_switches_to_bitmask $args twapi::_console_input_mode_syms]
    # If insertmode or quickedit mode are set, make sure to set extended bit
    if {$mode & 0x60} {
        setbits mode 0x80;              # ENABLE_EXTENDED_FLAGS
    }

    SetConsoleMode $conh $mode
}
interp alias {} twapi::set_console_input_mode {} twapi::_do_console_proc twapi::_set_console_input_mode stdin

#
# Modify console input mode
proc twapi::_modify_console_input_mode {conh args} {
    set prev [GetConsoleMode $conh]
    set mode [_switches_to_bitmask $args twapi::_console_input_mode_syms $prev]
    # If insertmode or quickedit mode are set, make sure to set extended bit
    if {$mode & 0x60} {
        setbits mode 0x80;              # ENABLE_EXTENDED_FLAGS
    }

    SetConsoleMode $conh $mode
    # Returns the old modes
    return [_bitmask_to_switches $prev twapi::_console_input_mode_syms]
}
interp alias {} twapi::modify_console_input_mode {} twapi::_do_console_proc twapi::_modify_console_input_mode stdin

#
# Set console output mode
proc twapi::_set_console_output_mode {conh args} {
    set mode [_switches_to_bitmask $args twapi::_console_output_mode_syms]

    SetConsoleMode $conh $mode

}
interp alias {} twapi::set_console_output_mode {} twapi::_do_console_proc twapi::_set_console_output_mode stdout

#
# Set console output mode
proc twapi::_modify_console_output_mode {conh args} {
    set prev [GetConsoleMode $conh]
    set mode [_switches_to_bitmask $args twapi::_console_output_mode_syms $prev]

    SetConsoleMode $conh $mode
    # Returns the old modes
    return [_bitmask_to_switches $prev twapi::_console_output_mode_syms]
}
interp alias {} twapi::modify_console_output_mode {} twapi::_do_console_proc twapi::_modify_console_output_mode stdout


#
# Create and return a handle to a screen buffer
proc twapi::create_console_screen_buffer {args} {
    array set opts [parseargs args {
        {inherit.bool 0}
        {mode.arg readwrite {read write readwrite}}
        {secd.arg ""}
        {share.arg readwrite {none read write readwrite}}
    } -maxleftover 0]

    switch -exact -- $opts(mode) {
        read       { set mode [_access_rights_to_mask generic_read] }
        write      { set mode [_access_rights_to_mask generic_write] }
        readwrite  {
            set mode [_access_rights_to_mask {generic_read generic_write}]
        }
    }
    switch -exact -- $opts(share) {
        none {
            set share 0
        }
        read       {
            set share 1 ;# FILE_SHARE_READ
        }
        write      {
            set share 2 ;# FILE_SHARE_WRITE
        }
        readwrite  {
            set share 3
        }
    }
    
    return [CreateConsoleScreenBuffer \
                $mode \
                $share \
                [_make_secattr $opts(secd) $opts(inherit)] \
                1]
}


#
# Retrieve information about a console screen buffer
proc twapi::_get_console_screen_buffer_info {conh args} {
    array set opts [parseargs args {
        all
        textattr
        cursorpos
        maxwindowsize
        size
        windowpos
        windowsize
    } -maxleftover 0]

    foreach {size cursorpos textattr windowrect maxwindowsize} [GetConsoleScreenBufferInfo $conh] break

    set result [list ]
    foreach opt {size cursorpos maxwindowsize} {
        if {$opts($opt) || $opts(all)} {
            lappend result -$opt [set $opt]
        }
    }

    if {$opts(windowpos) || $opts(all)} {
        lappend result -windowpos [lrange $windowrect 0 1]
    }

    if {$opts(windowsize) || $opts(all)} {
        foreach {left top right bot} $windowrect break
        lappend result -windowsize [list [expr {$right-$left+1}] [expr {$bot-$top+1}]]
    }

    if {$opts(textattr) || $opts(all)} {
        set result [concat $result [_bitmask_to_switches $textattr twapi::_console_output_attr_syms]]
    }

    return $result
}
interp alias {} twapi::get_console_screen_buffer_info {} twapi::_do_console_proc twapi::_get_console_screen_buffer_info stdout

#
# Set the cursor position
proc twapi::_set_console_cursor_position {conh pos} {
    SetConsoleCursorPosition $conh $pos
}
interp alias {} twapi::set_console_cursor_position {} twapi::_do_console_proc twapi::_set_console_cursor_position stdout

#
# Write the specified string to the console
proc twapi::_write_console {conh s args} {
    # Note writes are always in raw mode, 
    # TBD - support for  scrolling
    # TBD - support for attributes

    array set opts [parseargs args {
        position.arg
        {newlinemode.arg column {line column}}
        {restoreposition.bool 0}
    } -maxleftover 0]

    # Get screen buffer info including cursor position
    array set csbi [get_console_screen_buffer_info $conh -cursorpos -size]

    # Get current console mode for later restoration
    # If console is in processed mode, set it to raw mode
    set oldmode [get_console_output_mode $conh]
    set processed_index [lsearch -exact $oldmode "processed"]
    if {$processed_index >= 0} {
        # Console was in processed mode. Set it to raw mode
        set newmode [lreplace $oldmode $processed_index $processed_index]
        set_console_output_mode $conh $newmode
    }
    
    try {
        # x,y are starting position to write
        if {[info exists opts(position)]} {
            foreach {x y} [_parse_integer_pair $opts(position)] break
        } else {
            # No position specified, get current cursor position
            foreach {x y} $csbi(-cursorpos) break
        }
        
        set startx [expr {$opts(newlinemode) == "column" ? $x : 0}]

        # Get screen buffer limits
        foreach {width height} $csbi(-size) break

        # Ensure line terminations are just \n
        set s [string map "\r\n \n" $s]

        # Write out each line at ($x,$y)
        # Either \r or \n is considered a newline
        foreach line [split $s \r\n] {
            if {$y >= $height} break

            if {$x < $width} {
                # Write the characters - do not write more than buffer width
                set num_chars [expr {$width-$x}]
                if {[string length $line] < $num_chars} {
                    set num_chars [string length $line]
                }
                WriteConsole $conh $line $num_chars
            }
            
            
            # Calculate starting position of next line
            incr y
            set x $startx
        }

    } finally {
        # Restore cursor if requested
        if {$opts(restoreposition)} {
            set_console_cursor_position $conh $csbi(-cursorpos)
        }
        # Restore output mode if changed
        if {[info exists newmode]} {
            set_console_output_mode $conh $oldmode
        }
    }

    return
}
interp alias {} twapi::write_console {} twapi::_do_console_proc twapi::_write_console stdout

#
# Fill an area of the console with the specified attribute
proc twapi::_fill_console {conh args} {
    array set opts [parseargs args {
        position.arg
        numlines.int
        numcols.int
        {mode.arg column {line column}}
        window.bool
        fillchar.arg
    } -ignoreunknown]

    # args will now contain attribute switches if any
    set attr [_switches_to_bitmask $args twapi::_console_output_attr_syms]

    # Get screen buffer info for window and size of buffer
    array set csbi [get_console_screen_buffer_info $conh -windowpos -windowsize -size]
    # Height and width of the console
    foreach {conx cony} $csbi(-size) break

    # Figure out what area we want to fill
    # startx,starty are starting position to write
    # sizex, sizey are the number of rows/lines
    if {[info exists opts(window)]} {
        if {[info exists opts(numlines)] || [info exists opts(numcols)]
            || [info exists opts(position)]} {
            error "Option -window cannot be used togther with options -position, -numlines or -numcols"
        }
        foreach {startx starty} [_parse_integer_pair $csbi(-windowpos)] break
        foreach {sizex sizey} [_parse_integer_pair $csbi(-windowsize)] break
    } else {
        if {[info exists opts(position)]} {
            foreach {startx starty} [_parse_integer_pair $opts(position)] break
        } else {
            set startx 0
            set starty 0
        }
        if {[info exists opts(numlines)]} {
            set sizey $opts(numlines)
        } else {
            set sizey $cony
        }
        if {[info exists opts(numcols)]} {
            set sizex $opts(numcols)
        } else {
            set sizex [expr {$conx - $startx}]
        }
    }
    
    set firstcol [expr {$opts(mode) == "column" ? $startx : 0}]

    # Fill attribute at ($x,$y)
    set x $startx
    set y $starty
    while {$y < $cony && $y < ($starty + $sizey)} {
        if {$x < $conx} {
            # Write the characters - do not write more than buffer width
            set max [expr {$conx-$x}]
            if {[info exists attr]} {
                FillConsoleOutputAttribute $conh $attr [expr {$sizex > $max ? $max : $sizex}] [list $x $y]
            }
            if {[info exists opts(fillchar)]} {
                FillConsoleOutputCharacter $conh $opts(fillchar) [expr {$sizex > $max ? $max : $sizex}] [list $x $y]
            }
        }
        
        # Calculate starting position of next line
        incr y
        set x $firstcol
    }
    
    return
}
interp alias {} twapi::fill_console {} twapi::_do_console_proc twapi::_fill_console stdout

#
# Clear the console
proc twapi::_clear_console {conh args} {
    # I support we could just call fill_console but this code was already
    # written and is faster
    array set opts [parseargs args {
        {fillchar.arg " "}
        {windowonly.bool 0}
    } -maxleftover 0]

    array set cinfo [get_console_screen_buffer_info $conh -size -windowpos -windowsize]
    foreach {width height} $cinfo(-size) break
    if {$opts(windowonly)} {
        # Only clear portion visible in the window. We have to do this
        # line by line since we do not want to erase text scrolled off
        # the window either in the vertical or horizontal direction
        foreach {x y} $cinfo(-windowpos) break
        foreach {w h} $cinfo(-windowsize) break
        for {set i 0} {$i < $h} {incr i} {
            FillConsoleOutputCharacter \
                $conh \
                $opts(fillchar)  \
                $w \
                [list $x [expr {$y+$i}]]
        }
    } else {
        FillConsoleOutputCharacter \
            $conh \
            $opts(fillchar)  \
            [expr {($width*$height) }] \
            [list 0 0]
    }
    return
}
interp alias {} twapi::clear_console {} twapi::_do_console_proc twapi::_clear_console stdout
#
# Flush console input
proc twapi::_flush_console_input {conh} {
    FlushConsoleInputBuffer $conh
}
interp alias {} twapi::flush_console_input {} twapi::_do_console_proc twapi::_flush_console_input stdin

#
# Return number of pending console input events
proc twapi::_get_console_pending_input_count {conh} {
    return [GetNumberOfConsoleInputEvents $conh]
}
interp alias {} twapi::get_console_pending_input_count {} twapi::_do_console_proc twapi::_get_console_pending_input_count stdin

#
# Generate a console control event
proc twapi::generate_console_control_event {event {procgrp 0}} {
    switch -exact -- $event {
        ctrl-c {set event 0}
        ctrl-break {set event 1}
        default {error "Invalid event definition '$event'"}
    }
    GenerateConsoleCtrlEvent $event $procgrp
}

#
# Get number of mouse buttons
proc twapi::num_console_mouse_buttons {} {
    return [GetNumberOfConsoleMouseButtons]
}

#
# Get console title text
proc twapi::get_console_title {} {
    return [GetConsoleTitle]
}

#
# Set console title text
proc twapi::set_console_title {title} {
    return [SetConsoleTitle $title]
}

#
# Get the handle to the console window
proc twapi::get_console_window {} {
    return [GetConsoleWindow]
}

#
# Get the largest console window size
proc twapi::_get_console_window_maxsize {conh} {
    return [GetLargestConsoleWindowSize $conh]
}
interp alias {} twapi::get_console_window_maxsize {} twapi::_do_console_proc twapi::_get_console_window_maxsize stdout
#
#
proc twapi::_set_console_active_screen_buffer {conh} {
    SetConsoleActiveScreenBuffer $conh
}
interp alias {} twapi::set_console_active_screen_buffer {} twapi::_do_console_proc twapi::_set_console_active_screen_buffer stdout

#
# Set the size of the console screen buffer
proc twapi::_set_console_screen_buffer_size {conh size} {
    SetConsoleScreenBufferSize $conh [_parse_integer_pair $size]
}
interp alias {} twapi::set_console_screen_buffer_size {} twapi::_do_console_proc twapi::_set_console_screen_buffer_size stdout

#
# Set the default text attribute
proc twapi::_set_console_default_attr {conh args} {
    SetConsoleTextAttribute $conh [_switches_to_bitmask $args twapi::_console_output_attr_syms]
}
interp alias {} twapi::set_console_default_attr {} twapi::_do_console_proc twapi::_set_console_default_attr stdout

#
# Set the console window position
proc twapi::_set_console_window_location {conh rect args} {
    array set opts [parseargs args {
        {absolute.bool true}
    } -maxleftover 0]

    SetConsoleWindowInfo $conh $opts(absolute) $rect
}
interp alias {} twapi::set_console_window_location {} twapi::_do_console_proc twapi::_set_console_window_location stdout

#
# Get the console code page
proc twapi::get_console_output_codepage {} {
    return [GetConsoleOutputCP]
}

#
# Set the console code page
proc twapi::set_console_output_codepage {cp} {
    SetConsoleOutputCP $cp
}

#
# Get the console input code page
proc twapi::get_console_input_codepage {} {
    return [GetConsoleCP]
}

#
# Set the console input code page
proc twapi::set_console_input_codepage {cp} {
    SetConsoleCP $cp
}

#
# Read a line of input
proc twapi::_console_read {conh args} {
    if {[llength $args]} {
        set oldmode \
            [eval modify_console_input_mode [list $conh] $args]
    }
    try {
        return [ReadConsole $conh 1024]
    } finally {
        if {[info exists oldmode]} {
            eval set_console_input_mode $conh $oldmode
        }
    }

}
interp alias {} twapi::console_gets {} twapi::_do_console_proc twapi::_console_gets stdin

#
# Set up a console handler
proc twapi::set_console_control_handler {script {timeout 100}} {
    if {[string length $script]} {
        RegisterConsoleEventNotifier $script $timeout
    } else {
        UnregisterConsoleEventNotifier
    }
}

# 
# Utilities
#

#
# Helper to call a proc after doing a stdin/stdout/stderr -> handle
# mapping. The handle is closed after calling the proc. The first
# arg in $args must be the console handle i $args is not an empty list
proc twapi::_do_console_proc {proc default args} {
    if {![llength $args]} {
        set args [list $default]
    }
    set conh [lindex $args 0]
    switch -exact -- [string tolower $conh] {
        stdin  -
        stdout -
        stderr {
            set real_handle [get_console_handle $conh]
            try {
                lset args 0 $real_handle
                return [eval [list $proc] $args]
            } finally {
                close_handles $real_handle
            }
        }
    }
    
    return [eval [list $proc] $args]
}
